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
      END OF ty_filters,
      BEGIN OF ty_clas_comp,
        id          TYPE string,
        title       TYPE string,
        kind        TYPE string,
        include     TYPE string,
        line_count  TYPE i,
        has_content TYPE abap_bool,
        source      TYPE string,
      END OF ty_clas_comp,
      tt_clas_comp TYPE STANDARD TABLE OF ty_clas_comp WITH DEFAULT KEY.

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
    DATA ls_filter       TYPE ty_filters.
    DATA lt_entity       TYPE tt_entity.
    DATA ls_entity       TYPE zcr_scort_obj_src.
    DATA lv_tgt_obj_name TYPE sobj_name.
    DATA lv_dump_tgt     TYPE string.

    ls_filter = parse_filters( io_request ).

    IF ls_filter-object_type IS INITIAL OR ls_filter-object_name IS INITIAL.
      zcl_scort_query_utl=>respond(
        EXPORTING io_request = io_request io_response = io_response
        CHANGING  ct_data = lt_entity ).
      RETURN.
    ENDIF.

    IF ls_filter-object_type = 'CLAS' AND ls_filter-object_name CS '='.
      SPLIT ls_filter-object_name AT '=' INTO ls_filter-object_name DATA(lv_dummy_cln).
      CONDENSE ls_filter-object_name.
    ENDIF.

    CLEAR ls_entity.
    ls_entity-ServerType = ls_filter-server_type.

    ls_entity-ObjectType = ls_filter-object_type.
    ls_entity-ObjectName = ls_filter-object_name.

    TRY.
        IF ls_filter-server_type = c_server_target.
          DATA ls_tgt TYPE zcl_scort_t_reader=>ty_source.
          lv_tgt_obj_name = ls_filter-object_name.
          IF ls_filter-object_type = 'CLAS' AND lv_tgt_obj_name CS '='.
            SPLIT lv_tgt_obj_name AT '=' INTO lv_tgt_obj_name lv_dump_tgt.
          ENDIF.
          ls_entity-ObjectName = lv_tgt_obj_name.
          IF ls_filter-version_no IS NOT INITIAL.
            ls_tgt = zcl_scort_t_reader=>read_version(
                       iv_object_type = ls_filter-object_type
                       iv_object_name = lv_tgt_obj_name
                       iv_version_no  = ls_filter-version_no ).
          ELSE.
            ls_tgt = zcl_scort_t_reader=>read_current(
                       iv_object_type = ls_filter-object_type
                       iv_object_name = lv_tgt_obj_name ).
          ENDIF.
          ls_entity-VersionNo = ls_tgt-version_no.
          ls_entity-Message   = ls_tgt-message.

          IF ls_tgt-found = abap_true.
            IF ls_filter-object_type = 'TABL' AND ls_tgt-text CS '===SCORT_TABLE_DATA_START==='.
              SPLIT ls_tgt-text AT '===SCORT_TABLE_DATA_START===' INTO DATA(lv_ddl_t) DATA(lv_data_t).
              DATA(lv_len_t) = strlen( lv_ddl_t ).
              IF lv_len_t > 0 AND substring( val = lv_ddl_t off = lv_len_t - 1 len = 1 ) = cl_abap_char_utilities=>newline.
                lv_ddl_t = substring( val = lv_ddl_t off = 0 len = lv_len_t - 1 ).
                lv_len_t = strlen( lv_ddl_t ).
                IF lv_len_t > 0 AND substring( val = lv_ddl_t off = lv_len_t - 1 len = 1 ) = cl_abap_char_utilities=>cr_lf(1).
                  lv_ddl_t = substring( val = lv_ddl_t off = 0 len = lv_len_t - 1 ).
                ENDIF.
              ENDIF.
              ls_entity-SourceCodeText = lv_ddl_t.
              ls_entity-LineCount      = lines( zcl_scort_hash_utl=>text_to_lines( lv_ddl_t ) ).
              ls_entity-SrcHash        = zcl_scort_hash_utl=>calculate_checksum( lv_ddl_t ).
              ls_entity-MetadataText   = condense( lv_data_t ).
            ELSE.
              ls_entity-SourceCodeText = ls_tgt-text.
              ls_entity-LineCount      = ls_tgt-line_count.
              ls_entity-SrcHash        = ls_tgt-hash_stored.
              IF ls_entity-SrcHash IS INITIAL.
                ls_entity-SrcHash = ls_tgt-hash_calc.
              ENDIF.
              IF ls_filter-object_type = 'CLAS'.
                DATA lt_tgt_comps TYPE tt_clas_comp.
                APPEND VALUE #( id = 'CP' title = 'Global Class' kind = 'CLAS'
                                include = |{ ls_filter-object_name WIDTH = 30 PAD = '=' }CP|
                                line_count = ls_tgt-line_count
                                has_content = abap_true
                                source = ls_tgt-text ) TO lt_tgt_comps.
                APPEND VALUE #( id = 'CCDEF' title = 'Class-relevant Local Types' kind = 'CCDEF'
                                include = |{ ls_filter-object_name WIDTH = 30 PAD = '=' }CCDEF|
                                has_content = abap_false ) TO lt_tgt_comps.
                APPEND VALUE #( id = 'CCIMP' title = 'Local Types' kind = 'CCIMP'
                                include = |{ ls_filter-object_name WIDTH = 30 PAD = '=' }CCIMP|
                                has_content = abap_false ) TO lt_tgt_comps.
                APPEND VALUE #( id = 'CCAU' title = 'Test Classes' kind = 'CCAU'
                                include = |{ ls_filter-object_name WIDTH = 30 PAD = '=' }CCAU|
                                has_content = abap_false ) TO lt_tgt_comps.
                APPEND VALUE #( id = 'CCMAC' title = 'Macros' kind = 'CCMAC'
                                include = |{ ls_filter-object_name WIDTH = 30 PAD = '=' }CCMAC|
                                has_content = abap_false ) TO lt_tgt_comps.
                ls_entity-MetadataText = /ui2/cl_json=>serialize(
                                           data        = lt_tgt_comps
                                           pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).
              ENDIF.
            ENDIF.
          ELSE.
            CLEAR: ls_entity-SourceCodeText, ls_entity-LineCount, ls_entity-SrcHash, ls_entity-MetadataText.
          ENDIF.
        ELSE.
          IF ls_filter-version_no IS NOT INITIAL
              AND ls_filter-version_no <> zcl_scort_v_reader=>c_vers_active.
            DATA(ls_ver) = zcl_scort_v_reader=>read_version(
                             iv_object_type = ls_filter-object_type
                             iv_object_name = ls_filter-object_name
                             iv_version_no  = ls_filter-version_no
                             iv_component   = 'CP' ).
            ls_entity-VersionNo = ls_ver-version_no.
            IF ls_filter-object_type = 'TABL' AND ls_ver-text CS '===SCORT_TABLE_DATA_START==='.
              SPLIT ls_ver-text AT '===SCORT_TABLE_DATA_START===' INTO DATA(lv_ddl_v) DATA(lv_data_v).
              DATA(lv_len_v) = strlen( lv_ddl_v ).
              IF lv_len_v > 0 AND substring( val = lv_ddl_v off = lv_len_v - 1 len = 1 ) = cl_abap_char_utilities=>newline.
                lv_ddl_v = substring( val = lv_ddl_v off = 0 len = lv_len_v - 1 ).
                lv_len_v = strlen( lv_ddl_v ).
                IF lv_len_v > 0 AND substring( val = lv_ddl_v off = lv_len_v - 1 len = 1 ) = cl_abap_char_utilities=>cr_lf(1).
                  lv_ddl_v = substring( val = lv_ddl_v off = 0 len = lv_len_v - 1 ).
                ENDIF.
              ENDIF.
              ls_entity-SourceCodeText = lv_ddl_v.
              ls_entity-LineCount      = lines( zcl_scort_hash_utl=>text_to_lines( lv_ddl_v ) ).
              ls_entity-SrcHash        = zcl_scort_hash_utl=>calculate_checksum( lv_ddl_v ).
              ls_entity-MetadataText   = condense( lv_data_v ).
            ELSE.
              ls_entity-SourceCodeText = ls_ver-text.
              ls_entity-LineCount      = ls_ver-line_count.
              ls_entity-SrcHash        = ls_ver-hash.
              IF ls_filter-object_type = 'CLAS'.
                DATA lv_clas_v_json TYPE string.
                DATA lv_clas_v_ok   TYPE abap_bool.
                zcl_scort_v_reader=>read_clas_components_version(
                  EXPORTING
                    iv_classname  = ls_filter-object_name
                    iv_version_no = ls_filter-version_no
                  IMPORTING
                    ev_json       = lv_clas_v_json
                    ev_ok         = lv_clas_v_ok ).
                IF lv_clas_v_ok = abap_true.
                  ls_entity-MetadataText = lv_clas_v_json.
                ENDIF.
              ENDIF.
            ENDIF.
            ls_entity-Message        = ls_ver-message.
          ELSE.
            DATA(ls_ori) = zcl_scort_l_reader=>read_active(
                             iv_object_type = ls_filter-object_type
                             iv_object_name = ls_filter-object_name ).
            ls_entity-VersionNo      = zcl_scort_v_reader=>c_vers_active.
            ls_entity-SourceCodeText = ls_ori-text.
            ls_entity-LineCount      = ls_ori-line_count.
            ls_entity-SrcHash        = ls_ori-hash.
            ls_entity-Message        = ls_ori-message.

            IF ls_filter-object_type = 'TABL'.
              DATA lv_tab_l_json TYPE string.
              DATA lv_tab_l_cnt  TYPE i.
              DATA lv_tab_l_ok   TYPE abap_bool.
              zcl_scort_l_reader=>read_table_data(
                EXPORTING
                  iv_tabname   = ls_filter-object_name
                  iv_max_rows  = 100
                IMPORTING
                  ev_json      = lv_tab_l_json
                  ev_row_count = lv_tab_l_cnt
                  ev_ok        = lv_tab_l_ok ).
              IF lv_tab_l_ok = abap_true.
                ls_entity-MetadataText = lv_tab_l_json.
              ENDIF.
            ELSEIF ls_filter-object_type = 'CLAS'.
              DATA lv_clas_l_json TYPE string.
              DATA lv_clas_l_ok   TYPE abap_bool.
              zcl_scort_l_reader=>read_clas_components(
                EXPORTING
                  iv_classname = ls_filter-object_name
                IMPORTING
                  ev_json      = lv_clas_l_json
                  ev_ok        = lv_clas_l_ok ).
              IF lv_clas_l_ok = abap_true.
                ls_entity-MetadataText = lv_clas_l_json.
              ENDIF.
            ENDIF.
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
