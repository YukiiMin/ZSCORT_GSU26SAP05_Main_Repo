*"*---------------------------------------------------------------------*
*"* Class: ZCL_SCORT_R_SRC
*"* Query Provider — ZCR_SCORT_OBJ_SRC (preview 1 phía).
*"*   'L' → Active Origin (L_READER)
*"*   'T' → ZA026_SCORT_REPO (T_READER; VersionNo optional)
*"*---------------------------------------------------------------------*
CLASS zcl_scort_r_src DEFINITION
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
      tt_entity TYPE STANDARD TABLE OF zcr_scort_obj_src WITH DEFAULT KEY,
      BEGIN OF ty_filters,
        server_type TYPE c LENGTH 1,

        object_type TYPE trobjtype,
        object_name TYPE sobj_name,
        version_no  TYPE versno,
      END OF ty_filters.

    METHODS select_source
      IMPORTING
        io_request  TYPE REF TO if_rap_query_request
        io_response TYPE REF TO if_rap_query_response.

    METHODS parse_filters
      IMPORTING
        io_request       TYPE REF TO if_rap_query_request
      RETURNING
        VALUE(rs_filter) TYPE ty_filters.

ENDCLASS.


CLASS zcl_scort_r_src IMPLEMENTATION.

  METHOD if_rap_query_provider~select.
    DATA lt_empty TYPE tt_entity.
    TRY.
        select_source( io_request = io_request io_response = io_response ).
      CATCH cx_root.
        zcl_scort_query_utl=>respond(
          EXPORTING io_request = io_request io_response = io_response
          CHANGING  ct_data = lt_empty ).
    ENDTRY.
  ENDMETHOD.

  METHOD select_source.
    DATA ls_filter TYPE ty_filters.
    DATA lt_entity TYPE tt_entity.
    DATA ls_entity TYPE zcr_scort_obj_src.

    ls_filter = parse_filters( io_request ).

    IF ls_filter-object_type IS INITIAL OR ls_filter-object_name IS INITIAL.
      zcl_scort_query_utl=>respond(
        EXPORTING io_request = io_request io_response = io_response
        CHANGING  ct_data = lt_entity ).
      RETURN.
    ENDIF.

    CLEAR ls_entity.
    ls_entity-ServerType = ls_filter-server_type.

    ls_entity-ObjectType = ls_filter-object_type.
    ls_entity-ObjectName = ls_filter-object_name.

    TRY.
        IF ls_filter-server_type = c_server_target.
          DATA ls_tgt TYPE zcl_scort_t_reader=>ty_source.
          IF ls_filter-version_no IS NOT INITIAL.
            ls_tgt = zcl_scort_t_reader=>read_version(
                       iv_object_type = ls_filter-object_type
                       iv_object_name = ls_filter-object_name

                       iv_version_no  = ls_filter-version_no ).
          ELSE.
            ls_tgt = zcl_scort_t_reader=>read_current(
                       iv_object_type = ls_filter-object_type
                       iv_object_name = ls_filter-object_name ).
          ENDIF.
          ls_entity-VersionNo      = ls_tgt-version_no.
          ls_entity-SourceCodeText = ls_tgt-text.
          ls_entity-LineCount      = ls_tgt-line_count.
          ls_entity-SrcHash        = CONV #( ls_tgt-hash_stored ).
          IF ls_entity-SrcHash IS INITIAL.
            ls_entity-SrcHash = CONV #( ls_tgt-hash_calc ).
          ENDIF.
          ls_entity-Message = ls_tgt-message.
        ELSE.
          IF ls_filter-version_no IS NOT INITIAL
              AND ls_filter-version_no <> zcl_scort_v_reader=>c_vers_active.
            DATA(ls_ver) = zcl_scort_v_reader=>read_version(
                             iv_object_type = ls_filter-object_type
                             iv_object_name = ls_filter-object_name
                             iv_version_no  = ls_filter-version_no ).
            ls_entity-VersionNo      = ls_ver-version_no.
            ls_entity-SourceCodeText = ls_ver-text.
            ls_entity-LineCount      = ls_ver-line_count.
            ls_entity-SrcHash        = CONV #( ls_ver-hash ).
            ls_entity-Message        = ls_ver-message.
          ELSE.
            DATA(ls_ori) = zcl_scort_l_reader=>read_active(
                             iv_object_type = ls_filter-object_type
                             iv_object_name = ls_filter-object_name ).
            ls_entity-VersionNo      = zcl_scort_v_reader=>c_vers_active.
            ls_entity-SourceCodeText = ls_ori-text.
            ls_entity-LineCount      = ls_ori-line_count.
            ls_entity-SrcHash        = CONV #( ls_ori-hash ).
            ls_entity-Message        = ls_ori-message.
          ENDIF.
        ENDIF.
      CATCH cx_root INTO DATA(lx).
        ls_entity-Message = lx->get_text( ).
    ENDTRY.

    APPEND ls_entity TO lt_entity.

    zcl_scort_query_utl=>respond(
      EXPORTING io_request = io_request io_response = io_response
      CHANGING  ct_data = lt_entity ).
  ENDMETHOD.

  METHOD parse_filters.
    CLEAR rs_filter.
    rs_filter-server_type = CONV char1(
      zcl_scort_query_utl=>filter_low( io_request = io_request iv_field = 'SERVERTYPE' ) ).

    rs_filter-object_type = CONV trobjtype(
      zcl_scort_query_utl=>filter_low( io_request = io_request iv_field = 'OBJECTTYPE' ) ).
    rs_filter-object_name = CONV sobj_name(
      zcl_scort_query_utl=>filter_low( io_request = io_request iv_field = 'OBJECTNAME' ) ).
    rs_filter-version_no = CONV versno(
      zcl_scort_query_utl=>filter_low( io_request = io_request iv_field = 'VERSIONNO' ) ).

    IF rs_filter-server_type IS INITIAL.
      rs_filter-server_type = c_server_local.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
