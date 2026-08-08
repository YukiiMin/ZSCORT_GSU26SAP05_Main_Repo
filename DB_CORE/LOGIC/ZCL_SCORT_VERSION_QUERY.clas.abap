*"*---------------------------------------------------------------------*
*"* Class: ZCL_SCORT_VERSION_QUERY
*"* REQ3 — danh sách Version cho Compare.
*"*   ServerType = 'L' → VRSD / V_READER (+ Active 99998)
*"*   ServerType = 'T' → ZA026_SCORT_REPO (Target simulator)
*"* Cover đủ RAP: sort + paging + set_data/count.
*"*---------------------------------------------------------------------*
CLASS zcl_scort_version_query DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

    CONSTANTS:
      c_server_local  TYPE c LENGTH 1  VALUE 'L',
      c_server_target TYPE c LENGTH 1  VALUE 'T',
      c_server_tgt_id TYPE c LENGTH 10 VALUE 'TGT'.

  PRIVATE SECTION.
    TYPES:
      tt_entity TYPE STANDARD TABLE OF zcr_scort_obj_version WITH DEFAULT KEY,
      BEGIN OF ty_filters,
        server_type TYPE c LENGTH 1,

        object_type TYPE trobjtype,
        object_name TYPE sobj_name,
        version_no  TYPE versno,
      END OF ty_filters.

    METHODS select_versions
      IMPORTING
        io_request  TYPE REF TO if_rap_query_request
        io_response TYPE REF TO if_rap_query_response.

    METHODS parse_filters
      IMPORTING
        io_request       TYPE REF TO if_rap_query_request
      RETURNING
        VALUE(rs_filter) TYPE ty_filters.

    CLASS-METHODS read_local
      IMPORTING
        is_filter        TYPE ty_filters
      RETURNING
        VALUE(rt_entity) TYPE tt_entity.

    CLASS-METHODS read_target
      IMPORTING
        is_filter        TYPE ty_filters
      RETURNING
        VALUE(rt_entity) TYPE tt_entity.

    CLASS-METHODS ensure_active_row
      IMPORTING
        is_filter TYPE ty_filters
      CHANGING
        ct_entity TYPE tt_entity.

ENDCLASS.


CLASS zcl_scort_version_query IMPLEMENTATION.

  METHOD if_rap_query_provider~select.
    DATA lt_empty TYPE tt_entity.
    TRY.
        select_versions( io_request = io_request io_response = io_response ).
      CATCH cx_root.
        zcl_scort_query_utl=>respond(
          EXPORTING io_request = io_request io_response = io_response
          CHANGING  ct_data = lt_empty ).
    ENDTRY.
  ENDMETHOD.

  METHOD select_versions.
    DATA ls_filter TYPE ty_filters.
    DATA lt_entity TYPE tt_entity.

    ls_filter = parse_filters( io_request ).

    IF ls_filter-object_type IS INITIAL OR ls_filter-object_name IS INITIAL.
      zcl_scort_query_utl=>respond(
        EXPORTING io_request = io_request io_response = io_response
        CHANGING  ct_data = lt_entity ).
      RETURN.
    ENDIF.

    TRY.
        IF ls_filter-server_type = c_server_target.
          lt_entity = read_target( ls_filter ).
        ELSE.
          lt_entity = read_local( ls_filter ).
        ENDIF.
      CATCH cx_root.
        CLEAR lt_entity.
        IF ls_filter-server_type <> c_server_target.
          ensure_active_row( EXPORTING is_filter = ls_filter CHANGING ct_entity = lt_entity ).
        ENDIF.
      ENDTRY.

    IF ls_filter-version_no IS NOT INITIAL.
      DELETE lt_entity WHERE VersionNo <> ls_filter-version_no.
    ENDIF.

    " Local VRSD: bỏ 00000 (nhãn UI SE80 không dùng)
    IF ls_filter-server_type <> c_server_target.
      DELETE lt_entity WHERE VersionNo = '00000' OR VersionNo IS INITIAL.
    ENDIF.

    zcl_scort_query_utl=>respond(
      EXPORTING io_request = io_request io_response = io_response
      CHANGING  ct_data = lt_entity ).
  ENDMETHOD.

  METHOD parse_filters.
    CLEAR rs_filter.

    rs_filter-object_type = CONV trobjtype(
      zcl_scort_query_utl=>filter_low( io_request = io_request iv_field = 'OBJECTTYPE' ) ).
    rs_filter-object_name = CONV sobj_name(
      zcl_scort_query_utl=>filter_low( io_request = io_request iv_field = 'OBJECTNAME' ) ).
    rs_filter-server_type = CONV char1(
      zcl_scort_query_utl=>filter_low( io_request = io_request iv_field = 'SERVERTYPE' ) ).

    rs_filter-version_no = CONV versno(
      zcl_scort_query_utl=>filter_low( io_request = io_request iv_field = 'VERSIONNO' ) ).

    IF rs_filter-server_type IS INITIAL.
      rs_filter-server_type = c_server_local.
    ENDIF.
    IF rs_filter-server_id IS INITIAL.
      rs_filter-server_id = c_server_tgt_id.
    ENDIF.
  ENDMETHOD.

  METHOD read_local.
    DATA lt_vers   TYPE zcl_scort_v_reader=>tt_version.
    DATA ls_entity TYPE zcr_scort_obj_version.

    TRY.
        lt_vers = zcl_scort_v_reader=>list_versions(
                    iv_object_type = is_filter-object_type
                    iv_object_name = is_filter-object_name ).
      CATCH cx_root.
        CLEAR lt_vers.
    ENDTRY.

    LOOP AT lt_vers INTO DATA(ls_v).
      CLEAR ls_entity.
      ls_entity-ServerType = c_server_local.

      ls_entity-ObjectType = ls_v-object_type.
      ls_entity-ObjectName = ls_v-object_name.
      ls_entity-VersionNo  = ls_v-version_no.
      ls_entity-Author     = ls_v-author.
      ls_entity-Datum      = ls_v-datum.
      ls_entity-Uzeit      = ls_v-uzeit.
      ls_entity-Korrnum    = ls_v-korrnum.
      ls_entity-IsActive   = ls_v-is_active.
      ls_entity-SourceKind = 'VRSD'.
      ls_entity-Message    = ls_v-message.
      APPEND ls_entity TO rt_entity.
    ENDLOOP.

    IF rt_entity IS INITIAL.
      ensure_active_row( EXPORTING is_filter = is_filter CHANGING ct_entity = rt_entity ).
    ENDIF.
  ENDMETHOD.

  METHOD read_target.
    DATA lt_vers   TYPE zcl_scort_t_reader=>tt_version.
    DATA ls_entity TYPE zcr_scort_obj_version.

    TRY.
        lt_vers = zcl_scort_t_reader=>list_versions(
                    iv_object_type = is_filter-object_type
                    iv_object_name = is_filter-object_name ).
      CATCH cx_root.
        CLEAR lt_vers.
    ENDTRY.

    LOOP AT lt_vers INTO DATA(ls_v).
      CLEAR ls_entity.
      ls_entity-ServerType = c_server_target.

      ls_entity-ObjectType = is_filter-object_type.
      ls_entity-ObjectName = is_filter-object_name.
      ls_entity-VersionNo  = ls_v-version_no.
      ls_entity-Author     = ls_v-author.
      ls_entity-Korrnum    = ls_v-trkorr.
      ls_entity-SrcHash    = ls_v-checksum.
      ls_entity-IsActive   = ls_v-is_current.
      ls_entity-SourceKind = 'REPO'.
      ls_entity-Message    = ls_v-message.
      APPEND ls_entity TO rt_entity.
    ENDLOOP.
  ENDMETHOD.

  METHOD ensure_active_row.
    DATA ls_entity TYPE zcr_scort_obj_version.

    READ TABLE ct_entity WITH KEY VersionNo = zcl_scort_v_reader=>c_vers_active
      TRANSPORTING NO FIELDS.
    IF sy-subrc = 0.
      RETURN.
    ENDIF.

    CLEAR ls_entity.
    ls_entity-ServerType = COND #( WHEN is_filter-server_type = c_server_target
                                   THEN c_server_target ELSE c_server_local ).

    ls_entity-ObjectType = is_filter-object_type.
    ls_entity-ObjectName = is_filter-object_name.
    ls_entity-VersionNo  = zcl_scort_v_reader=>c_vers_active.
    ls_entity-Author     = sy-uname.
    ls_entity-Datum      = sy-datum.
    ls_entity-Uzeit      = sy-uzeit.
    ls_entity-IsActive   = abap_true.
    ls_entity-SourceKind = 'VRSD'.
    ls_entity-Message    = 'Active'.
    INSERT ls_entity INTO ct_entity INDEX 1.
  ENDMETHOD.

ENDCLASS.
