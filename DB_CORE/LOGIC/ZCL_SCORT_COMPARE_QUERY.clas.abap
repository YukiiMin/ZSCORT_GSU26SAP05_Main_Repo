CLASS zcl_scort_compare_query DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

    CONSTANTS:
      c_mode_l_vs_t        TYPE c LENGTH 20 VALUE 'L_VS_T',
      c_mode_ver_vs_ver    TYPE c LENGTH 20 VALUE 'VER_VS_VER',
      c_mode_active_vs_ver TYPE c LENGTH 20 VALUE 'ACTIVE_VS_VER',
      c_mode_table_data    TYPE c LENGTH 20 VALUE 'TABLE_DATA',
      c_server_tgt         TYPE c LENGTH 10 VALUE 'TGT'.

    TYPES:
      BEGIN OF ty_detail,
        object_type      TYPE trobjtype,
        object_name      TYPE sobj_name,
        compare_mode     TYPE c LENGTH 20,
        version_no       TYPE versno,
        version_no_right TYPE versno,
        status_code      TYPE c LENGTH 20,
        target_code      TYPE string,
        source_code      TYPE string,
        target_hash      TYPE c LENGTH 40,
        source_hash      TYPE c LENGTH 40,
        target_lines     TYPE i,
        source_lines     TYPE i,
        message          TYPE string,
      END OF ty_detail.

    CLASS-METHODS load_sources
      IMPORTING
        iv_object_type   TYPE trobjtype
        iv_object_name   TYPE sobj_name
        iv_server_id     TYPE c DEFAULT c_server_tgt
        iv_compare_mode  TYPE c DEFAULT c_mode_l_vs_t
        iv_version_no    TYPE versno OPTIONAL
        iv_version_right TYPE versno OPTIONAL
      RETURNING
        VALUE(rs_detail) TYPE ty_detail.

  PRIVATE SECTION.
    TYPES:
      tt_entity TYPE STANDARD TABLE OF zcr_scort_compare WITH DEFAULT KEY,
      BEGIN OF ty_keys,
        object_type   TYPE trobjtype,
        object_name   TYPE sobj_name,
        server_id     TYPE c LENGTH 10,
        compare_mode  TYPE c LENGTH 20,
        version_no    TYPE versno,
        version_right TYPE versno,
      END OF ty_keys.

    METHODS select_compare
      IMPORTING
        io_request  TYPE REF TO if_rap_query_request
        io_response TYPE REF TO if_rap_query_response.

    METHODS parse_keys
      IMPORTING
        io_request     TYPE REF TO if_rap_query_request
      RETURNING
        VALUE(rs_keys) TYPE ty_keys.

    METHODS fill_response
      IMPORTING
        io_request  TYPE REF TO if_rap_query_request
        io_response TYPE REF TO if_rap_query_response
      CHANGING
        ct_entity   TYPE tt_entity.

    CLASS-METHODS to_versno
      IMPORTING
        iv_raw         TYPE clike
      RETURNING
        VALUE(rv_vers) TYPE versno.

    CLASS-METHODS compare_versions
      IMPORTING
        iv_object_type   TYPE trobjtype
        iv_object_name   TYPE sobj_name
        iv_mode          TYPE c
        iv_version_no    TYPE versno
        iv_version_right TYPE versno
      CHANGING
        cs_detail        TYPE ty_detail.

    CLASS-METHODS compare_local_target
      IMPORTING
        iv_object_type TYPE trobjtype
        iv_object_name TYPE sobj_name
        iv_version_no  TYPE versno OPTIONAL
      CHANGING
        cs_detail      TYPE ty_detail.

    CLASS-METHODS compare_table_data
      IMPORTING
        iv_object_type   TYPE trobjtype
        iv_object_name   TYPE sobj_name
        iv_version_no    TYPE versno OPTIONAL
        iv_version_right TYPE versno OPTIONAL
      CHANGING
        cs_detail        TYPE ty_detail.

ENDCLASS.


CLASS zcl_scort_compare_query IMPLEMENTATION.

  METHOD if_rap_query_provider~select.
    DATA lt_empty TYPE tt_entity.
    TRY.
        select_compare( io_request = io_request io_response = io_response ).
      CATCH cx_root.
        fill_response( EXPORTING io_request = io_request io_response = io_response
                       CHANGING  ct_entity = lt_empty ).
    ENDTRY.
  ENDMETHOD.

  METHOD select_compare.
    DATA ls_keys   TYPE ty_keys.
    DATA ls_detail TYPE ty_detail.
    DATA ls_entity TYPE zcr_scort_compare.
    DATA lt_entity TYPE tt_entity.
    DATA lv_srv    TYPE c LENGTH 10.
    DATA lv_mode   TYPE c LENGTH 20.

    ls_keys = parse_keys( io_request ).

    IF ls_keys-object_type IS INITIAL OR ls_keys-object_name IS INITIAL.
      fill_response( EXPORTING io_request = io_request io_response = io_response
                     CHANGING  ct_entity = lt_entity ).
      RETURN.
    ENDIF.

    lv_srv = COND #( WHEN ls_keys-server_id IS INITIAL THEN c_server_tgt ELSE ls_keys-server_id ).
    lv_mode = COND #( WHEN ls_keys-compare_mode IS INITIAL THEN c_mode_l_vs_t ELSE ls_keys-compare_mode ).

    TRY.
        ls_detail = load_sources(
                      iv_object_type   = ls_keys-object_type
                      iv_object_name   = ls_keys-object_name
                      iv_server_id     = lv_srv
                      iv_compare_mode  = lv_mode
                      iv_version_no    = ls_keys-version_no
                      iv_version_right = ls_keys-version_right ).
      CATCH cx_root INTO DATA(lx).
        CLEAR ls_detail.
        ls_detail-object_type  = ls_keys-object_type.
        ls_detail-object_name  = ls_keys-object_name.
        ls_detail-compare_mode = lv_mode.
        ls_detail-status_code  = 'SOURCE_MISSING'.
        ls_detail-message      = lx->get_text( ).
    ENDTRY.

    CLEAR ls_entity.
    ls_entity-ObjectType     = ls_keys-object_type.
    ls_entity-ObjectName     = ls_keys-object_name.
    ls_entity-ServerId       = lv_srv.
    ls_entity-CompareMode    = lv_mode.
    IF ls_detail-compare_mode IS NOT INITIAL.
      ls_entity-CompareMode = ls_detail-compare_mode.
    ENDIF.
    ls_entity-VersionNo = COND #(
      WHEN ls_detail-version_no IS NOT INITIAL THEN ls_detail-version_no
      ELSE ls_keys-version_no ).
    ls_entity-VersionNoRight = COND #(
      WHEN ls_detail-version_no_right IS NOT INITIAL THEN ls_detail-version_no_right
      ELSE ls_keys-version_right ).
    ls_entity-StatusCode     = ls_detail-status_code.
    ls_entity-TargetCode     = ls_detail-target_code.
    ls_entity-SourceCode     = ls_detail-source_code.
    ls_entity-TargetHash     = ls_detail-target_hash.
    ls_entity-SourceHash     = ls_detail-source_hash.
    ls_entity-TargetLines    = ls_detail-target_lines.
    ls_entity-SourceLines    = ls_detail-source_lines.
    ls_entity-Message        = ls_detail-message.
    APPEND ls_entity TO lt_entity.

    fill_response( EXPORTING io_request = io_request io_response = io_response
                   CHANGING  ct_entity = lt_entity ).
  ENDMETHOD.

  METHOD fill_response.
    DATA lt_page TYPE tt_entity.
    DATA lv_skip TYPE i.
    DATA lv_top  TYPE i.
    DATA lv_from TYPE i.
    DATA lv_to   TYPE i.
    DATA lv_data TYPE abap_bool.
    DATA lv_count TYPE abap_bool.
    DATA lv_total TYPE int8.

    lv_total = lines( ct_entity ).

    TRY.
        lv_skip = CONV i( io_request->get_paging( )->get_offset( ) ).
      CATCH cx_root.
        lv_skip = 0.
    ENDTRY.
    TRY.
        lv_top = CONV i( io_request->get_paging( )->get_page_size( ) ).
      CATCH cx_root.
        lv_top = 0.
    ENDTRY.

    IF lv_top <= 0 OR lv_top >= 2147483647.
      lt_page = ct_entity.
    ELSE.
      lv_from = lv_skip + 1.
      lv_to   = lv_skip + lv_top.
      LOOP AT ct_entity INTO DATA(ls) FROM lv_from TO lv_to.
        APPEND ls TO lt_page.
      ENDLOOP.
    ENDIF.

    TRY.
        lv_data = io_request->is_data_requested( ).
      CATCH cx_root.
        lv_data = abap_true.
    ENDTRY.
    TRY.
        lv_count = io_request->is_total_numb_of_rec_requested( ).
      CATCH cx_root.
        lv_count = abap_true.
    ENDTRY.

    IF lv_data = abap_true.
      TRY.
          io_response->set_data( lt_page ).
        CATCH cx_root.
          LOOP AT lt_page ASSIGNING FIELD-SYMBOL(<ls>).
            CLEAR: <ls>-TargetCode, <ls>-SourceCode.
            IF <ls>-Message IS INITIAL.
              <ls>-Message = 'Source truncated for Preview'.
            ENDIF.
          ENDLOOP.
          TRY.
              io_response->set_data( lt_page ).
            CATCH cx_root.
              CLEAR lt_page.
              TRY.
                  io_response->set_data( lt_page ).
                CATCH cx_root.
              ENDTRY.
          ENDTRY.
      ENDTRY.
    ENDIF.

    IF lv_count = abap_true.
      TRY.
          io_response->set_total_number_of_records( lv_total ).
        CATCH cx_root.
      ENDTRY.
    ENDIF.

    IF lv_data = abap_false AND lv_count = abap_false.
      TRY.
          io_response->set_data( lt_page ).
        CATCH cx_root.
      ENDTRY.
      TRY.
          io_response->set_total_number_of_records( lv_total ).
        CATCH cx_root.
      ENDTRY.
    ENDIF.
  ENDMETHOD.

  METHOD parse_keys.
    CLEAR rs_keys.
    rs_keys-object_type = CONV trobjtype(
      zcl_scort_query_utl=>filter_low( io_request = io_request iv_field = 'OBJECTTYPE' ) ).
    rs_keys-object_name = CONV sobj_name(
      zcl_scort_query_utl=>filter_low( io_request = io_request iv_field = 'OBJECTNAME' ) ).
    rs_keys-server_id = CONV char10(
      zcl_scort_query_utl=>filter_low( io_request = io_request iv_field = 'SERVERID' ) ).
    rs_keys-compare_mode = CONV char20(
      zcl_scort_query_utl=>filter_low( io_request = io_request iv_field = 'COMPAREMODE' ) ).
    rs_keys-version_no = to_versno(
      zcl_scort_query_utl=>filter_low( io_request = io_request iv_field = 'VERSIONNO' ) ).
    rs_keys-version_right = to_versno(
      zcl_scort_query_utl=>filter_low( io_request = io_request iv_field = 'VERSIONNORIGHT' ) ).
  ENDMETHOD.

  METHOD to_versno.
    DATA lv_n TYPE n LENGTH 5.
    DATA lv_raw TYPE string.

    CLEAR rv_vers.
    lv_raw = CONDENSE( iv_raw ).
    IF lv_raw IS INITIAL.
      RETURN.
    ENDIF.
    REPLACE ALL OCCURRENCES OF `'` IN lv_raw WITH ``.
    TRY.
        lv_n = lv_raw.
        rv_vers = lv_n.
      CATCH cx_root.
        CLEAR rv_vers.
        RETURN.
    ENDTRY.
    IF rv_vers = '00000'.
      CLEAR rv_vers.
    ENDIF.
  ENDMETHOD.

  METHOD load_sources.
    DATA lv_mode TYPE c LENGTH 20.

    CLEAR rs_detail.
    rs_detail-object_type = iv_object_type.
    rs_detail-object_name = iv_object_name.

    lv_mode = to_upper( CONDENSE( iv_compare_mode ) ).
    IF lv_mode IS INITIAL.
      lv_mode = c_mode_l_vs_t.
    ENDIF.
    rs_detail-compare_mode = lv_mode.

    IF zcl_scort_l_reader=>is_supported( iv_object_type ) = abap_false.
      rs_detail-status_code = 'NOT_SUPPORTED'.
      rs_detail-message     = zcm_scort=>get_text_by_key(
                                is_t100_key = zcm_scort=>obj_type_not_supported
                                iv_attr1    = CONV #( iv_object_type ) ).
      RETURN.
    ENDIF.

    IF lv_mode = c_mode_table_data OR lv_mode = 'TABLE_DATA' OR ( iv_object_type = 'TABL' AND ( lv_mode = 'TABLE' OR lv_mode = 'DATA' ) ).
      compare_table_data(
        EXPORTING
          iv_object_type   = iv_object_type
          iv_object_name   = iv_object_name
          iv_version_no    = iv_version_no
          iv_version_right = iv_version_right
        CHANGING
          cs_detail        = rs_detail ).
      RETURN.
    ENDIF.

    IF lv_mode = c_mode_ver_vs_ver OR lv_mode = c_mode_active_vs_ver.
      compare_versions(
        EXPORTING
          iv_object_type   = iv_object_type
          iv_object_name   = iv_object_name
          iv_mode          = lv_mode
          iv_version_no    = iv_version_no
          iv_version_right = iv_version_right
        CHANGING
          cs_detail        = rs_detail ).
      RETURN.
    ENDIF.

    compare_local_target(
      EXPORTING
        iv_object_type = iv_object_type
        iv_object_name = iv_object_name
        iv_version_no  = iv_version_no
      CHANGING
        cs_detail      = rs_detail ).
  ENDMETHOD.

  METHOD compare_versions.
    DATA ls_left  TYPE zcl_scort_v_reader=>ty_source.
    DATA ls_right TYPE zcl_scort_v_reader=>ty_source.
    DATA lv_left  TYPE versno.
    DATA lv_right TYPE versno.

    IF iv_version_no IS INITIAL.
      lv_left = zcl_scort_v_reader=>c_vers_active.
    ELSE.
      lv_left = to_versno( iv_version_no ).
    ENDIF.

    IF iv_mode = c_mode_active_vs_ver.
      lv_right = zcl_scort_v_reader=>c_vers_active.
    ELSEIF iv_version_right IS INITIAL.
      lv_right = zcl_scort_v_reader=>c_vers_active.
    ELSE.
      lv_right = to_versno( iv_version_right ).
    ENDIF.

    IF lv_left = lv_right.
      cs_detail-status_code = 'NOT_SUPPORTED'.
      cs_detail-message     = 'Left and right version must differ (empty = Active 99998)'.
      RETURN.
    ENDIF.

    cs_detail-compare_mode     = c_mode_ver_vs_ver.
    cs_detail-version_no       = lv_left.
    cs_detail-version_no_right = lv_right.

    ls_left = zcl_scort_v_reader=>read_version(
                iv_object_type = iv_object_type
                iv_object_name = iv_object_name
                iv_version_no  = lv_left ).
    IF ls_left-found = abap_false.
      cs_detail-status_code = 'SOURCE_MISSING'.
      cs_detail-message     = |Left { lv_left }: { ls_left-message }|.
      RETURN.
    ENDIF.

    ls_right = zcl_scort_v_reader=>read_version(
                 iv_object_type = iv_object_type
                 iv_object_name = iv_object_name
                 iv_version_no  = lv_right ).
    IF ls_right-found = abap_false.
      cs_detail-status_code = 'SOURCE_MISSING'.
      cs_detail-message     = |Right { lv_right }: { ls_right-message }|.
      RETURN.
    ENDIF.

    cs_detail-target_code  = ls_left-text.
    cs_detail-target_hash  = CONV #( ls_left-hash ).
    cs_detail-target_lines = ls_left-line_count.
    cs_detail-source_code  = ls_right-text.
    cs_detail-source_hash  = CONV #( ls_right-hash ).
    cs_detail-source_lines = ls_right-line_count.

    IF cs_detail-source_hash = cs_detail-target_hash.
      cs_detail-status_code = 'IDENTICAL'.
      cs_detail-message     = zcm_scort=>get_text_by_key(
                                is_t100_key = zcm_scort=>hashes_identical
                                iv_attr1    = CONV #( iv_object_type )
                                iv_attr2    = CONV #( iv_object_name ) ).
    ELSE.
      cs_detail-status_code = 'DIFFERENT'.
      cs_detail-message     = zcm_scort=>get_text_by_key(
                                is_t100_key = zcm_scort=>hashes_different
                                iv_attr1    = CONV #( iv_object_type )
                                iv_attr2    = CONV #( iv_object_name ) ).
    ENDIF.
  ENDMETHOD.

  METHOD compare_local_target.
    DATA ls_ori TYPE zcl_scort_l_reader=>ty_source.
    DATA ls_tgt TYPE zcl_scort_t_reader=>ty_source.
    DATA lv_vers TYPE versno.

    cs_detail-compare_mode = c_mode_l_vs_t.

    ls_ori = zcl_scort_l_reader=>read_active(
               iv_object_type = iv_object_type
               iv_object_name = iv_object_name ).
    IF ls_ori-found = abap_false.
      cs_detail-status_code = 'SOURCE_MISSING'.
      cs_detail-message     = ls_ori-message.
      RETURN.
    ENDIF.

    cs_detail-source_code  = ls_ori-text.
    cs_detail-source_hash  = CONV #( ls_ori-hash ).
    cs_detail-source_lines = ls_ori-line_count.

    lv_vers = to_versno( iv_version_no ).
    IF lv_vers IS NOT INITIAL.
      ls_tgt = zcl_scort_t_reader=>read_version(
                 iv_object_type = iv_object_type
                 iv_object_name = iv_object_name
                 iv_version_no  = lv_vers ).
    ELSE.
      ls_tgt = zcl_scort_t_reader=>read_current(
                 iv_object_type = iv_object_type
                 iv_object_name = iv_object_name ).
    ENDIF.

    IF ls_tgt-is_new_target = abap_true.
      cs_detail-status_code  = 'NEW_AT_TARGET'.
      cs_detail-target_code  = ``.
      cs_detail-target_lines = 0.
      cs_detail-version_no   = ls_tgt-version_no.
      cs_detail-message      = zcm_scort=>get_text_by_key(
                                 is_t100_key = zcm_scort=>target_initial_apply
                                 iv_attr1    = CONV #( iv_object_type )
                                 iv_attr2    = CONV #( iv_object_name ) ).
      RETURN.
    ENDIF.

    IF ls_tgt-found = abap_false.
      cs_detail-status_code = 'BAD_HEX'.
      cs_detail-message     = ls_tgt-message.
      RETURN.
    ENDIF.

    cs_detail-target_code  = ls_tgt-text.
    cs_detail-target_hash  = CONV #( ls_tgt-hash_stored ).
    IF cs_detail-target_hash IS INITIAL.
      cs_detail-target_hash = CONV #( ls_tgt-hash_calc ).
    ENDIF.
    cs_detail-target_lines = ls_tgt-line_count.
    cs_detail-version_no   = ls_tgt-version_no.

    IF cs_detail-source_hash = cs_detail-target_hash.
      cs_detail-status_code = 'IDENTICAL'.
      cs_detail-message     = zcm_scort=>get_text_by_key(
                                is_t100_key = zcm_scort=>hashes_identical
                                iv_attr1    = CONV #( iv_object_type )
                                iv_attr2    = CONV #( iv_object_name ) ).
    ELSE.
      cs_detail-status_code = 'DIFFERENT'.
      cs_detail-message     = zcm_scort=>get_text_by_key(
                                is_t100_key = zcm_scort=>hashes_different
                                iv_attr1    = CONV #( iv_object_type )
                                iv_attr2    = CONV #( iv_object_name ) ).
    ENDIF.
  ENDMETHOD.

  METHOD compare_table_data.
    TYPES: BEGIN OF ty_col_info,
             name   TYPE string,
             is_key TYPE abap_bool,
             type   TYPE string,
             text   TYPE string,
           END OF ty_col_info,
           tt_cols TYPE STANDARD TABLE OF ty_col_info WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_summary,
             total_left  TYPE i,
             total_right TYPE i,
             total_diff  TYPE i,
             inserted    TYPE i,
             updated     TYPE i,
             deleted     TYPE i,
             is_capped   TYPE abap_bool,
           END OF ty_summary.

    TYPES: BEGIN OF ty_diff_row,
             diff_type      TYPE string,
             key_value      TYPE string,
             changed_fields TYPE STANDARD TABLE OF string WITH DEFAULT KEY,
             left_row_json  TYPE string,
             right_row_json TYPE string,
           END OF ty_diff_row,
           tt_diff_rows TYPE STANDARD TABLE OF ty_diff_row WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_diff_result,
             table_name TYPE string,
             summary    TYPE ty_summary,
             columns    TYPE tt_cols,
             diff_rows  TYPE tt_diff_rows,
           END OF ty_diff_result.

    DATA: ls_dd02v        TYPE dd02v,
          lt_dd03p        TYPE STANDARD TABLE OF dd03p WITH DEFAULT KEY,
          lv_tab          TYPE tabname,
          lt_cols         TYPE tt_cols,
          lt_key_fields   TYPE STANDARD TABLE OF fieldname WITH DEFAULT KEY,
          lt_all_fields   TYPE STANDARD TABLE OF fieldname WITH DEFAULT KEY,
          lr_left_tab     TYPE REF TO data,
          lr_right_tab    TYPE REF TO data,
          lv_left_json    TYPE string,
          lv_right_json   TYPE string,
          lv_keystr       TYPE string,
          ls_res          TYPE ty_diff_result,
          lv_left_vers    TYPE versno,
          lv_right_vers   TYPE versno.

    FIELD-SYMBOLS: <lt_left>  TYPE STANDARD TABLE,
                   <lt_right> TYPE STANDARD TABLE.

    cs_detail-compare_mode = c_mode_table_data.
    lv_tab = to_upper( CONV string( iv_object_name ) ).
    CONDENSE lv_tab.
    ls_res-table_name = lv_tab.

    CALL FUNCTION 'DDIF_TABL_GET'
      EXPORTING
        name      = lv_tab
        langu     = sy-langu
      IMPORTING
        dd02v_wa  = ls_dd02v
      TABLES
        dd03p_tab = lt_dd03p
      EXCEPTIONS
        OTHERS    = 1.

    IF sy-subrc <> 0 OR ls_dd02v-tabname IS INITIAL.
      cs_detail-status_code = 'NOT_FOUND'.
      cs_detail-message     = |Table { lv_tab } not found in DDIC|.
      RETURN.
    ENDIF.

    IF ls_dd02v-tabclass = 'INTTAB'.
      cs_detail-status_code = 'NOT_SUPPORTED'.
      cs_detail-message     = |{ lv_tab } is a structure (INTTAB) - no table data available|.
      RETURN.
    ENDIF.

    LOOP AT lt_dd03p INTO DATA(ls_p) WHERE fieldname IS NOT INITIAL.
      IF ls_p-fieldname(1) = '.'.
        CONTINUE.
      ENDIF.
      DATA(ls_col) = VALUE ty_col_info(
        name   = ls_p-fieldname
        is_key = boolc( ls_p-keyflag = 'X' )
        type   = ls_p-datatype
        text   = ls_p-ddtext
      ).
      APPEND ls_col TO lt_cols.
      APPEND ls_p-fieldname TO lt_all_fields.
      IF ls_p-keyflag = 'X'.
        APPEND ls_p-fieldname TO lt_key_fields.
      ENDIF.
    ENDLOOP.
    ls_res-columns = lt_cols.

    IF lt_key_fields IS INITIAL.
      lt_key_fields = lt_all_fields.
    ENDIF.

    TRY.
        CREATE DATA lr_left_tab TYPE STANDARD TABLE OF (lv_tab) WITH DEFAULT KEY.
        ASSIGN lr_left_tab->* TO <lt_left>.

        CREATE DATA lr_right_tab TYPE STANDARD TABLE OF (lv_tab) WITH DEFAULT KEY.
        ASSIGN lr_right_tab->* TO <lt_right>.
      CATCH cx_root INTO DATA(lx_alloc).
        cs_detail-status_code = 'ERROR'.
        cs_detail-message     = lx_alloc->get_text( ).
        RETURN.
    ENDTRY.

    lv_left_vers = to_versno( iv_version_no ).
    IF lv_left_vers IS INITIAL OR lv_left_vers = zcl_scort_v_reader=>c_vers_active.
      TRY.
          SELECT * FROM (lv_tab) UP TO 5000 ROWS INTO TABLE @<lt_left>.
        CATCH cx_root.
          CLEAR <lt_left>.
      ENDTRY.
    ELSE.
      DATA(ls_src_l) = zcl_scort_t_reader=>read_version(
                         iv_object_type = 'TABL'
                         iv_object_name = iv_object_name
                         iv_version_no  = lv_left_vers ).
      IF ls_src_l-text CS '===SCORT_TABLE_DATA_START==='.
        SPLIT ls_src_l-text AT '===SCORT_TABLE_DATA_START===' INTO DATA(lv_ddl_l) lv_left_json.
        lv_left_json = condense( lv_left_json ).
        TRY.
            /ui2/cl_json=>deserialize(
              EXPORTING
                json        = lv_left_json
                pretty_name = /ui2/cl_json=>pretty_mode-none
              CHANGING
                data        = <lt_left> ).
          CATCH cx_root.
            CLEAR <lt_left>.
        ENDTRY.
      ENDIF.
    ENDIF.

    lv_right_vers = to_versno( iv_version_right ).
    IF lv_right_vers = zcl_scort_v_reader=>c_vers_active.
      TRY.
          SELECT * FROM (lv_tab) UP TO 5000 ROWS INTO TABLE @<lt_right>.
        CATCH cx_root.
          CLEAR <lt_right>.
      ENDTRY.
    ELSEIF lv_right_vers IS NOT INITIAL.
      DATA(ls_src_r) = zcl_scort_t_reader=>read_version(
                         iv_object_type = 'TABL'
                         iv_object_name = iv_object_name
                         iv_version_no  = lv_right_vers ).
      IF ls_src_r-text CS '===SCORT_TABLE_DATA_START==='.
        SPLIT ls_src_r-text AT '===SCORT_TABLE_DATA_START===' INTO DATA(lv_ddl_r) lv_right_json.
        lv_right_json = condense( lv_right_json ).
        TRY.
            /ui2/cl_json=>deserialize(
              EXPORTING
                json        = lv_right_json
                pretty_name = /ui2/cl_json=>pretty_mode-none
              CHANGING
                data        = <lt_right> ).
          CATCH cx_root.
            CLEAR <lt_right>.
        ENDTRY.
      ENDIF.
    ELSE.
      DATA(ls_src_cur) = zcl_scort_t_reader=>read_current(
                           iv_object_type = 'TABL'
                           iv_object_name = iv_object_name ).
      IF ls_src_cur-text CS '===SCORT_TABLE_DATA_START==='.
        SPLIT ls_src_cur-text AT '===SCORT_TABLE_DATA_START===' INTO DATA(lv_ddl_c) lv_right_json.
        lv_right_json = condense( lv_right_json ).
        TRY.
            /ui2/cl_json=>deserialize(
              EXPORTING
                json        = lv_right_json
                pretty_name = /ui2/cl_json=>pretty_mode-none
              CHANGING
                data        = <lt_right> ).
          CATCH cx_root.
            CLEAR <lt_right>.
        ENDTRY.
      ENDIF.
    ENDIF.

    ls_res-summary-total_left  = lines( <lt_left> ).
    ls_res-summary-total_right = lines( <lt_right> ).

    TYPES: BEGIN OF ty_idx,
             key_str TYPE string,
             idx     TYPE i,
           END OF ty_idx.
    DATA lt_l_idx TYPE STANDARD TABLE OF ty_idx WITH DEFAULT KEY.
    DATA lt_r_idx TYPE STANDARD TABLE OF ty_idx WITH DEFAULT KEY.

    DATA lv_row_idx TYPE i.
    lv_row_idx = 0.
    LOOP AT <lt_left> ASSIGNING FIELD-SYMBOL(<ls_l_row>).
      lv_row_idx = lv_row_idx + 1.
      CLEAR lv_keystr.
      LOOP AT lt_key_fields INTO DATA(lv_kf1).
        ASSIGN COMPONENT lv_kf1 OF STRUCTURE <ls_l_row> TO FIELD-SYMBOL(<lv_k_l>).
        IF sy-subrc = 0.
          lv_keystr = |{ lv_keystr }{ <lv_k_l> }\||.
        ENDIF.
      ENDLOOP.
      APPEND VALUE ty_idx( key_str = lv_keystr idx = lv_row_idx ) TO lt_l_idx.
    ENDLOOP.
    SORT lt_l_idx BY key_str.

    lv_row_idx = 0.
    LOOP AT <lt_right> ASSIGNING FIELD-SYMBOL(<ls_r_row>).
      lv_row_idx = lv_row_idx + 1.
      CLEAR lv_keystr.
      LOOP AT lt_key_fields INTO DATA(lv_kf2).
        ASSIGN COMPONENT lv_kf2 OF STRUCTURE <ls_r_row> TO FIELD-SYMBOL(<lv_k_r>).
        IF sy-subrc = 0.
          lv_keystr = |{ lv_keystr }{ <lv_k_r> }\||.
        ENDIF.
      ENDLOOP.
      APPEND VALUE ty_idx( key_str = lv_keystr idx = lv_row_idx ) TO lt_r_idx.
    ENDLOOP.
    SORT lt_r_idx BY key_str.

    LOOP AT lt_l_idx INTO DATA(ls_li).
      READ TABLE <lt_left> INDEX ls_li-idx ASSIGNING FIELD-SYMBOL(<ls_l_diff>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      READ TABLE lt_r_idx WITH KEY key_str = ls_li-key_str BINARY SEARCH INTO DATA(ls_ri).
      IF sy-subrc <> 0.
        ls_res-summary-deleted = ls_res-summary-deleted + 1.
        IF lines( ls_res-diff_rows ) < 200.
          DATA(ls_diff_del) = VALUE ty_diff_row(
            diff_type     = 'DELETE'
            key_value     = ls_li-key_str
            left_row_json = /ui2/cl_json=>serialize( data = <ls_l_diff> pretty_name = /ui2/cl_json=>pretty_mode-none )
          ).
          APPEND ls_diff_del TO ls_res-diff_rows.
        ENDIF.
      ELSE.
        READ TABLE <lt_right> INDEX ls_ri-idx ASSIGNING FIELD-SYMBOL(<ls_r_diff>).
        IF sy-subrc = 0.
          DATA lt_diff_flds TYPE STANDARD TABLE OF string WITH DEFAULT KEY.
          CLEAR lt_diff_flds.
          LOOP AT lt_all_fields INTO DATA(lv_fld).
            ASSIGN COMPONENT lv_fld OF STRUCTURE <ls_l_diff> TO FIELD-SYMBOL(<lv_diff_val_l>).
            ASSIGN COMPONENT lv_fld OF STRUCTURE <ls_r_diff> TO FIELD-SYMBOL(<lv_diff_val_r>).
            IF sy-subrc = 0 AND <lv_diff_val_l> <> <lv_diff_val_r>.
              APPEND CONV string( lv_fld ) TO lt_diff_flds.
            ENDIF.
          ENDLOOP.

          IF lt_diff_flds IS NOT INITIAL.
            ls_res-summary-updated = ls_res-summary-updated + 1.
            IF lines( ls_res-diff_rows ) < 200.
              DATA(ls_diff_upd) = VALUE ty_diff_row(
                diff_type      = 'UPDATE'
                key_value      = ls_li-key_str
                changed_fields = lt_diff_flds
                left_row_json  = /ui2/cl_json=>serialize( data = <ls_l_diff> pretty_name = /ui2/cl_json=>pretty_mode-none )
                right_row_json = /ui2/cl_json=>serialize( data = <ls_r_diff> pretty_name = /ui2/cl_json=>pretty_mode-none )
              ).
              APPEND ls_diff_upd TO ls_res-diff_rows.
            ENDIF.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDLOOP.

    LOOP AT lt_r_idx INTO DATA(ls_rj).
      READ TABLE lt_l_idx WITH KEY key_str = ls_rj-key_str BINARY SEARCH TRANSPORTING NO FIELDS.
      IF sy-subrc <> 0.
        ls_res-summary-inserted = ls_res-summary-inserted + 1.
        IF lines( ls_res-diff_rows ) < 200.
          READ TABLE <lt_right> INDEX ls_rj-idx ASSIGNING FIELD-SYMBOL(<ls_r_ins>).
          IF sy-subrc = 0.
            DATA(ls_diff_ins) = VALUE ty_diff_row(
              diff_type      = 'INSERT'
              key_value      = ls_rj-key_str
              right_row_json = /ui2/cl_json=>serialize( data = <ls_r_ins> pretty_name = /ui2/cl_json=>pretty_mode-none )
            ).
            APPEND ls_diff_ins TO ls_res-diff_rows.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDLOOP.

    ls_res-summary-total_diff = ls_res-summary-inserted + ls_res-summary-updated + ls_res-summary-deleted.
    IF ls_res-summary-total_diff > 200.
      ls_res-summary-is_capped = abap_true.
    ENDIF.

    cs_detail-source_code = /ui2/cl_json=>serialize(
                              data        = ls_res
                              pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).
    cs_detail-target_code = cs_detail-source_code.
    cs_detail-source_lines = ls_res-summary-total_left.
    cs_detail-target_lines = ls_res-summary-total_right.

    IF ls_res-summary-total_diff = 0.
      cs_detail-status_code = 'MATCH'.
      cs_detail-message     = |Data Match: { ls_res-summary-total_left } rows identical|.
    ELSE.
      cs_detail-status_code = 'DIFF'.
      cs_detail-message     = |Data Diff: { ls_res-summary-total_diff } diffs (Ins: { ls_res-summary-inserted }, Upd: { ls_res-summary-updated }, Del: { ls_res-summary-deleted })|.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
