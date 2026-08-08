*"*---------------------------------------------------------------------*
*"* Class: ZCL_SCORT_TR_CMP_QUERY
*"* REQ3 — BƯỚC 1 (Cột Master): quét object của Transport Request và tô
*"* Status Badge chỉ bằng so Hash. KHÔNG giải nén GZIP, KHÔNG chạy LCS.
*"*
*"* Query Provider của Custom Entity ZCR_SCORT_TR_CMP.
*"* Filter: Trkorr (bắt buộc), ServerId (mặc định TGT),
*"*         ReleasedOnly (mặc định 'X' theo SPEC — TR phải đã Release).
*"*---------------------------------------------------------------------*
CLASS zcl_scort_tr_cmp_query DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

    CONSTANTS c_server_tgt TYPE c LENGTH 10 VALUE 'TGT'.

    TYPES:
      BEGIN OF ty_master_row,
        trkorr         TYPE trkorr,
        object_type    TYPE trobjtype,
        object_name    TYPE sobj_name,
        " IDENTICAL | DIFFERENT | NEW_AT_TARGET | NOT_SUPPORTED
        " | SOURCE_MISSING | BAD_HEX
        compare_status TYPE c LENGTH 20,
        origin_hash    TYPE c LENGTH 40,
        target_hash    TYPE c LENGTH 40,
        origin_lines   TYPE i,
        target_vers    TYPE numc5,
        message        TYPE string,
      END OF ty_master_row,
      tt_master TYPE STANDARD TABLE OF ty_master_row WITH DEFAULT KEY.

    "! Quét toàn bộ object R3TR của TR (kèm Task con) và tính badge.
    CLASS-METHODS scan_tr
      IMPORTING
        iv_trkorr        TYPE trkorr
        iv_server_id     TYPE c DEFAULT c_server_tgt
        iv_released_only TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(rt_rows)   TYPE tt_master.

    "! Badge của 1 object: Active hash vs SRC_HASH ở Target.
    CLASS-METHODS status_of_object
      IMPORTING
        iv_object_type TYPE trobjtype
        iv_object_name TYPE sobj_name
        iv_server_id   TYPE c DEFAULT c_server_tgt
      RETURNING
        VALUE(rs_row)  TYPE ty_master_row.

  PRIVATE SECTION.
    TYPES:
      tt_entity TYPE STANDARD TABLE OF zcr_scort_tr_cmp WITH DEFAULT KEY,
      tt_e071   TYPE STANDARD TABLE OF e071 WITH DEFAULT KEY,
      BEGIN OF ty_filters,
        trkorr          TYPE trkorr,
        server_id       TYPE c LENGTH 10,
        object_type     TYPE trobjtype,
        object_name     TYPE sobj_name,
        compare_status  TYPE c LENGTH 20,
        released_only   TYPE abap_bool,
      END OF ty_filters.

    CLASS-METHODS collect_e071
      IMPORTING
        iv_trkorr      TYPE trkorr
      RETURNING
        VALUE(rt_e071) TYPE tt_e071.

    "! LIMU REPS/… → R3TR PROG/… (SE09 "Report Source Code" thường là LIMU)
    CLASS-METHODS normalize_e071_object
      IMPORTING
        iv_pgmid  TYPE e071-pgmid
        iv_object TYPE e071-object
      EXPORTING
        ev_pgmid  TYPE e071-pgmid
        ev_object TYPE e071-object
        ev_ok     TYPE abap_bool.

    CLASS-METHODS map_criticality
      IMPORTING
        iv_status      TYPE clike
      RETURNING
        VALUE(rv_crit) TYPE i.

    METHODS select_tr_cmp
      IMPORTING
        io_request  TYPE REF TO if_rap_query_request
        io_response TYPE REF TO if_rap_query_response.

    METHODS parse_filters
      IMPORTING
        io_request       TYPE REF TO if_rap_query_request
      RETURNING
        VALUE(rs_filter) TYPE ty_filters.

ENDCLASS.


CLASS zcl_scort_tr_cmp_query IMPLEMENTATION.

  METHOD if_rap_query_provider~select.
    DATA lt_empty TYPE tt_entity.
    TRY.
        select_tr_cmp( io_request = io_request io_response = io_response ).
      CATCH cx_root.
        zcl_scort_query_utl=>respond(
          EXPORTING io_request = io_request io_response = io_response
          CHANGING  ct_data = lt_empty ).
    ENDTRY.
  ENDMETHOD.

  METHOD select_tr_cmp.
    DATA ls_filter TYPE ty_filters.
    DATA lt_rows   TYPE tt_master.
    DATA lt_entity TYPE tt_entity.
    DATA ls_entity TYPE zcr_scort_tr_cmp.
    DATA lv_srv    TYPE c LENGTH 10.

    ls_filter = parse_filters( io_request ).

    IF ls_filter-trkorr IS INITIAL.
      zcl_scort_query_utl=>respond(
        EXPORTING io_request = io_request io_response = io_response
        CHANGING  ct_data = lt_entity ).
      RETURN.
    ENDIF.

    IF ls_filter-server_id IS INITIAL.
      lv_srv = c_server_tgt.
    ELSE.
      lv_srv = ls_filter-server_id.
    ENDIF.

    TRY.
        lt_rows = scan_tr(
                    iv_trkorr        = ls_filter-trkorr
                    iv_server_id     = lv_srv
                    iv_released_only = ls_filter-released_only ).
      CATCH cx_root.
        CLEAR lt_rows.
    ENDTRY.

    LOOP AT lt_rows INTO DATA(ls_row).
      IF ls_filter-object_type IS NOT INITIAL
          AND ls_row-object_type <> ls_filter-object_type.
        CONTINUE.
      ENDIF.
      IF ls_filter-object_name IS NOT INITIAL
          AND ls_row-object_name NS ls_filter-object_name.
        CONTINUE.
      ENDIF.
      IF ls_filter-compare_status IS NOT INITIAL
          AND ls_row-compare_status <> ls_filter-compare_status.
        CONTINUE.
      ENDIF.

      CLEAR ls_entity.
      ls_entity-Trkorr            = ls_row-trkorr.
      ls_entity-ObjectType        = ls_row-object_type.
      ls_entity-ObjectName        = ls_row-object_name.
      ls_entity-CompareStatus     = ls_row-compare_status.
      ls_entity-StatusCriticality = map_criticality( ls_row-compare_status ).
      ls_entity-OriginHash        = ls_row-origin_hash.
      ls_entity-TargetHash        = ls_row-target_hash.
      ls_entity-OriginLines       = ls_row-origin_lines.
      ls_entity-TargetVers        = ls_row-target_vers.
      ls_entity-ServerId          = lv_srv.
      ls_entity-Message           = ls_row-message.
      APPEND ls_entity TO lt_entity.
    ENDLOOP.

    zcl_scort_query_utl=>respond(
      EXPORTING io_request = io_request io_response = io_response
      CHANGING  ct_data = lt_entity ).
  ENDMETHOD.

  METHOD parse_filters.
    DATA lv_sql  TYPE string.
    DATA lv_flag TYPE string.

    CLEAR rs_filter.
    lv_sql = zcl_scort_query_utl=>get_filter_sql( io_request ).

    rs_filter-trkorr = CONV trkorr(
      zcl_scort_query_utl=>filter_low( io_request = io_request iv_field = 'TRKORR' ) ).
    IF rs_filter-trkorr IS INITIAL.
      rs_filter-trkorr = CONV trkorr(
        zcl_scort_query_utl=>value_of( iv_sql = lv_sql iv_field = 'TRKORR' ) ).
    ENDIF.

    rs_filter-server_id = CONV char10(
      zcl_scort_query_utl=>filter_low( io_request = io_request iv_field = 'SERVERID' ) ).
    IF rs_filter-server_id IS INITIAL.
      rs_filter-server_id = CONV char10(
        zcl_scort_query_utl=>value_of( iv_sql = lv_sql iv_field = 'SERVERID' ) ).
    ENDIF.
    IF rs_filter-server_id IS INITIAL.
      rs_filter-server_id = CONV char10(
        zcl_scort_query_utl=>value_of( iv_sql = lv_sql iv_field = 'SERVER_ID' ) ).
    ENDIF.

    rs_filter-object_type = CONV trobjtype(
      zcl_scort_query_utl=>filter_low( io_request = io_request iv_field = 'OBJECTTYPE' ) ).
    rs_filter-object_name = CONV sobj_name(
      zcl_scort_query_utl=>filter_low( io_request = io_request iv_field = 'OBJECTNAME' ) ).
    rs_filter-compare_status = CONV char20(
      zcl_scort_query_utl=>filter_low( io_request = io_request iv_field = 'COMPARESTATUS' ) ).

    " SPEC: mặc định chỉ mở Compare khi TR đã Release.
    " Dev có thể nới bằng filter ReleasedOnly eq ''.
    rs_filter-released_only = abap_true.
    IF lv_sql CS 'RELEASEDONLY'.
      lv_flag = zcl_scort_query_utl=>value_of( iv_sql = lv_sql iv_field = 'RELEASEDONLY' ).
      IF lv_flag IS INITIAL OR lv_flag = ' ' OR lv_flag = 'FALSE'.
        rs_filter-released_only = abap_false.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD normalize_e071_object.
    CLEAR: ev_pgmid, ev_object, ev_ok.
    ev_pgmid  = iv_pgmid.
    ev_object = iv_object.

    IF iv_pgmid = 'R3TR'.
      ev_ok = abap_true.
      RETURN.
    ENDIF.

    " SE09: "Report Source Code" / class includes… thường ghi LIMU trên E071
    IF iv_pgmid = 'LIMU'.
      ev_pgmid = 'R3TR'.
      CASE iv_object.
        WHEN 'REPS' OR 'REPT'.
          ev_object = 'PROG'.
          ev_ok     = abap_true.
        WHEN 'FUNC'.
          ev_object = 'FUGR'.
          ev_ok     = abap_true.
        WHEN 'CPUB' OR 'CPRI' OR 'CPRO' OR 'CLSD' OR 'METH' OR 'CINC'.
          ev_object = 'CLAS'.
          ev_ok     = abap_true.
        WHEN OTHERS.
          CLEAR: ev_pgmid, ev_object, ev_ok.
      ENDCASE.
    ENDIF.
  ENDMETHOD.

  METHOD collect_e071.
    DATA lt_task TYPE STANDARD TABLE OF e070 WITH DEFAULT KEY.
    DATA lt_raw  TYPE tt_e071.
    DATA lt_one  TYPE tt_e071.
    DATA ls_out  TYPE e071.
    DATA lv_pgmid TYPE e071-pgmid.
    DATA lv_object TYPE e071-object.
    DATA lv_ok TYPE abap_bool.

    " Parent + task: lấy cả R3TR và LIMU (không chỉ R3TR)
    SELECT * FROM e071
      WHERE trkorr = @iv_trkorr
        AND ( pgmid = 'R3TR' OR pgmid = 'LIMU' )
      INTO TABLE @lt_one.
    APPEND LINES OF lt_one TO lt_raw.

    SELECT * FROM e070
      WHERE strkorr = @iv_trkorr
      INTO TABLE @lt_task.

    LOOP AT lt_task INTO DATA(ls_task).
      CLEAR lt_one.
      SELECT * FROM e071
        WHERE trkorr = @ls_task-trkorr
          AND ( pgmid = 'R3TR' OR pgmid = 'LIMU' )
        INTO TABLE @lt_one.
      APPEND LINES OF lt_one TO lt_raw.
    ENDLOOP.

    CLEAR rt_e071.
    LOOP AT lt_raw INTO DATA(ls_raw).
      normalize_e071_object(
        EXPORTING
          iv_pgmid  = ls_raw-pgmid
          iv_object = ls_raw-object
        IMPORTING
          ev_pgmid  = lv_pgmid
          ev_object = lv_object
          ev_ok     = lv_ok ).
      CHECK lv_ok = abap_true.
      CLEAR ls_out.
      ls_out = ls_raw.
      ls_out-pgmid  = lv_pgmid.
      ls_out-object = lv_object.
      APPEND ls_out TO rt_e071.
    ENDLOOP.

    SORT rt_e071 BY object obj_name.
    DELETE ADJACENT DUPLICATES FROM rt_e071 COMPARING object obj_name.
  ENDMETHOD.

  METHOD status_of_object.
    DATA ls_ori TYPE zcl_scort_l_reader=>ty_source.
    DATA ls_tgt TYPE zcl_scort_t_reader=>ty_source.

    CLEAR rs_row.
    rs_row-object_type = iv_object_type.
    rs_row-object_name = iv_object_name.

    IF zcl_scort_l_reader=>is_supported( iv_object_type ) = abap_false.
      rs_row-compare_status = 'NOT_SUPPORTED'.
      rs_row-message        = 'Object type not supported'.
      RETURN.
    ENDIF.

    ls_ori = zcl_scort_l_reader=>read_active(
               iv_object_type = iv_object_type
               iv_object_name = iv_object_name ).
    IF ls_ori-found = abap_false.
      rs_row-compare_status = 'SOURCE_MISSING'.
      rs_row-message        = ls_ori-message.
      RETURN.
    ENDIF.

    rs_row-origin_hash  = ls_ori-hash.
    rs_row-origin_lines = ls_ori-line_count.

    ls_tgt = zcl_scort_t_reader=>read_current(
               iv_object_type = iv_object_type
               iv_object_name = iv_object_name
               iv_server_id   = iv_server_id ).

    rs_row-target_vers = ls_tgt-version_no.
    rs_row-target_hash = ls_tgt-hash_stored.
    IF rs_row-target_hash IS INITIAL.
      rs_row-target_hash = ls_tgt-hash_calc.
    ENDIF.

    IF ls_tgt-is_new_target = abap_true.
      rs_row-compare_status = 'NEW_AT_TARGET'.
      rs_row-message        = 'Chưa có trong ZA05_SCORT_T — lần Apply đầu'.
      CLEAR rs_row-target_hash.
      RETURN.
    ENDIF.

    IF ls_tgt-found = abap_false.
      rs_row-compare_status = 'BAD_HEX'.
      rs_row-message        = ls_tgt-message.
      RETURN.
    ENDIF.

    IF ls_ori-hash = rs_row-target_hash.
      rs_row-compare_status = 'IDENTICAL'.
      rs_row-message        = 'Hash trùng nhau'.
    ELSE.
      rs_row-compare_status = 'DIFFERENT'.
      rs_row-message        = 'Hash khác nhau'.
    ENDIF.
  ENDMETHOD.

  METHOD scan_tr.
    DATA lt_e071   TYPE tt_e071.
    DATA ls_row    TYPE ty_master_row.
    DATA lv_status TYPE trstatus.

    CLEAR rt_rows.

    SELECT SINGLE trstatus FROM e070
      WHERE trkorr = @iv_trkorr
      INTO @lv_status.

    IF sy-subrc <> 0.
      ls_row-trkorr         = iv_trkorr.
      ls_row-compare_status = 'SOURCE_MISSING'.
      ls_row-message        = 'Không tìm thấy TR trong E070'.
      APPEND ls_row TO rt_rows.
      RETURN.
    ENDIF.

    IF iv_released_only = abap_true AND lv_status <> 'R'.
      ls_row-trkorr         = iv_trkorr.
      ls_row-compare_status = 'NOT_SUPPORTED'.
      ls_row-message        = |TR status={ lv_status } — chưa Release, không mở Compare|.
      APPEND ls_row TO rt_rows.
      RETURN.
    ENDIF.

    lt_e071 = collect_e071( iv_trkorr ).
    IF lt_e071 IS INITIAL.
      " Released nhưng không có R3TR (chỉ LIMU / TR rỗng) — báo rõ, không im lặng
      ls_row-trkorr         = iv_trkorr.
      ls_row-compare_status = 'SOURCE_MISSING'.
      ls_row-message        = 'TR không có object so Compare được (R3TR/LIMU→PROG/CLAS/…) trong E071'.
      APPEND ls_row TO rt_rows.
      RETURN.
    ENDIF.

    LOOP AT lt_e071 INTO DATA(ls_e071).
      ls_row = status_of_object(
                 iv_object_type = ls_e071-object
                 iv_object_name = CONV sobj_name( ls_e071-obj_name )
                 iv_server_id   = iv_server_id ).
      ls_row-trkorr = iv_trkorr.
      APPEND ls_row TO rt_rows.
    ENDLOOP.
  ENDMETHOD.

  METHOD map_criticality.
    CASE to_upper( iv_status ).
      WHEN 'DIFFERENT' OR 'BAD_HEX'.
        rv_crit = 1. " Error
      WHEN 'SOURCE_MISSING'.
        rv_crit = 2. " Warning
      WHEN 'NEW_AT_TARGET'.
        rv_crit = 3. " Success
      WHEN OTHERS.
        rv_crit = 0. " Neutral / IDENTICAL / NOT_SUPPORTED
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
