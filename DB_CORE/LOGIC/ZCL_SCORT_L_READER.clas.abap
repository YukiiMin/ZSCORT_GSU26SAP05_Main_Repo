*"*---------------------------------------------------------------------*
*"* Class: ZCL_SCORT_L_READER
*"* Read Active Source on Origin (DEV) — PROG / CLAS / INTF / FUNC / FUGR
*"*---------------------------------------------------------------------*
CLASS zcl_scort_l_reader DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_string_tab TYPE STANDARD TABLE OF string WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_source,
        object_type TYPE trobjtype,
        object_name TYPE sobj_name,
        found       TYPE abap_bool,
        supported   TYPE abap_bool,
        lines       TYPE ty_string_tab,
        text        TYPE string,
        hash        TYPE c LENGTH 40,
        line_count  TYPE i,
        message     TYPE string,
      END OF ty_source.

    CLASS-METHODS is_supported
      IMPORTING iv_object_type TYPE trobjtype
      RETURNING VALUE(rv_ok) TYPE abap_bool.

    CLASS-METHODS read_active
      IMPORTING
        iv_object_type   TYPE trobjtype
        iv_object_name   TYPE sobj_name
      RETURNING
        VALUE(rs_source) TYPE ty_source.

  PRIVATE SECTION.
    CLASS-METHODS read_prog
      IMPORTING iv_name TYPE sobj_name
      EXPORTING et_lines TYPE ty_string_tab ev_ok TYPE abap_bool.

    CLASS-METHODS read_oo
      IMPORTING
        iv_name    TYPE sobj_name
        iv_is_intf TYPE abap_bool
      EXPORTING
        et_lines TYPE ty_string_tab
        ev_ok    TYPE abap_bool.

    CLASS-METHODS read_func
      IMPORTING iv_name TYPE sobj_name
      EXPORTING et_lines TYPE ty_string_tab ev_ok TYPE abap_bool.

    CLASS-METHODS read_fugr
      IMPORTING iv_name TYPE sobj_name
      EXPORTING et_lines TYPE ty_string_tab ev_ok TYPE abap_bool.

ENDCLASS.


CLASS zcl_scort_l_reader IMPLEMENTATION.

  METHOD is_supported.
    CASE iv_object_type.
      WHEN 'PROG' OR 'CLAS' OR 'INTF' OR 'FUNC' OR 'FUGR'.
        rv_ok = abap_true.
      WHEN OTHERS.
        rv_ok = abap_false.
    ENDCASE.
  ENDMETHOD.

  METHOD read_prog.
    CLEAR: et_lines, ev_ok.
    READ REPORT iv_name INTO et_lines.
    IF sy-subrc = 0 AND et_lines IS NOT INITIAL.
      ev_ok = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD read_oo.
    " CL_OO_SOURCE đã obsolete / method private trên nhiều hệ.
    " Dùng CL_OO_FACTORY + IF_OO_CLIF_SOURCE (ADT/source-based).
    DATA lo_source TYPE REF TO if_oo_clif_source.
    DATA lt_src    TYPE rswsourcet.
    DATA lv_pool   TYPE programm.
    DATA lv_line   TYPE string.

    CLEAR: et_lines, ev_ok.

    TRY.
        lo_source = cl_oo_factory=>create_instance( )->create_clif_source(
                      clif_name = CONV seoclsname( iv_name )
                      version   = if_oo_clif_source=>co_version_active ).
        lo_source->get_source( IMPORTING source = lt_src ).
        LOOP AT lt_src INTO lv_line.
          APPEND lv_line TO et_lines.
        ENDLOOP.
        IF et_lines IS NOT INITIAL.
          ev_ok = abap_true.
          RETURN.
        ENDIF.
      CATCH cx_root.
        CLEAR et_lines.
    ENDTRY.

    " Fallback: đọc class/interface pool include (=====CP / =====IP)
    CLEAR et_lines.
    TRY.
        IF iv_is_intf = abap_true.
          lv_pool = cl_oo_classname_service=>get_interfacepool_name(
                      CONV seoclsname( iv_name ) ).
        ELSE.
          lv_pool = cl_oo_classname_service=>get_classpool_name(
                      CONV seoclsname( iv_name ) ).
        ENDIF.
      CATCH cx_root.
        IF iv_is_intf = abap_true.
          lv_pool = |{ iv_name WIDTH = 30 PAD = '=' }IP|.
        ELSE.
          lv_pool = |{ iv_name WIDTH = 30 PAD = '=' }CP|.
        ENDIF.
    ENDTRY.

    READ REPORT lv_pool INTO et_lines.
    IF sy-subrc = 0 AND et_lines IS NOT INITIAL.
      ev_ok = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD read_func.
    DATA lv_fname   TYPE rs38l-name. " RS38L-NAME — không dùng rs38l_incl-name
    DATA lv_include TYPE programm.
    DATA lt_fm      TYPE STANDARD TABLE OF rssource WITH DEFAULT KEY.
    DATA lv_line    TYPE rssource.

    CLEAR: et_lines, ev_ok.
    lv_fname = iv_name.

    " Ưu tiên: tìm include vật lý rồi READ REPORT
    CALL FUNCTION 'FUNCTION_INCLUDE_INFO'
      EXPORTING
        funcname               = lv_fname
      IMPORTING
        include                = lv_include
      EXCEPTIONS
        function_not_exists    = 1
        input_incomplete       = 2
        no_function_include    = 3
        OTHERS                 = 4.
    IF sy-subrc = 0 AND lv_include IS NOT INITIAL.
      READ REPORT lv_include INTO et_lines.
      IF sy-subrc = 0 AND et_lines IS NOT INITIAL.
        ev_ok = abap_true.
        RETURN.
      ENDIF.
    ENDIF.

    " Fallback: RPY_FUNCTIONMODULE_READ
    CLEAR et_lines.
    CALL FUNCTION 'RPY_FUNCTIONMODULE_READ'
      EXPORTING
        functionname  = lv_fname
      TABLES
        source        = lt_fm
      EXCEPTIONS
        error_message = 1
        OTHERS        = 2.
    IF lt_fm IS INITIAL.
      RETURN.
    ENDIF.
    LOOP AT lt_fm INTO lv_line.
      APPEND CONV string( lv_line ) TO et_lines.
    ENDLOOP.
    ev_ok = abap_true.
  ENDMETHOD.

  METHOD read_fugr.
    " Đọc include chính của Function Group: SAPL<name> hoặc L<name>TOP + UXX
    DATA lv_main TYPE programm.
    DATA lt_all  TYPE ty_string_tab.
    DATA lt_one  TYPE ty_string_tab.
    DATA lv_ok   TYPE abap_bool.

    CLEAR: et_lines, ev_ok.
    lv_main = |SAPL{ iv_name }|.
    read_prog( EXPORTING iv_name = CONV sobj_name( lv_main )
               IMPORTING et_lines = lt_one ev_ok = lv_ok ).
    IF lv_ok = abap_true.
      APPEND LINES OF lt_one TO lt_all.
    ENDIF.

    " TOP include
    CLEAR lt_one.
    lv_main = |L{ iv_name }TOP|.
    read_prog( EXPORTING iv_name = CONV sobj_name( lv_main )
               IMPORTING et_lines = lt_one ev_ok = lv_ok ).
    IF lv_ok = abap_true.
      APPEND LINES OF lt_one TO lt_all.
    ENDIF.

    IF lt_all IS INITIAL.
      RETURN.
    ENDIF.
    et_lines = lt_all.
    ev_ok = abap_true.
  ENDMETHOD.

  METHOD read_active.
    DATA lt_lines TYPE ty_string_tab.
    DATA lv_ok    TYPE abap_bool.

    CLEAR rs_source.
    rs_source-object_type = iv_object_type.
    rs_source-object_name = iv_object_name.

    IF is_supported( iv_object_type ) = abap_false.
      rs_source-supported = abap_false.
      rs_source-message   = 'NOT_SUPPORTED'.
      RETURN.
    ENDIF.
    rs_source-supported = abap_true.

    CASE iv_object_type.
      WHEN 'PROG'.
        read_prog( EXPORTING iv_name = iv_object_name
                   IMPORTING et_lines = lt_lines ev_ok = lv_ok ).
      WHEN 'CLAS'.
        read_oo( EXPORTING iv_name = iv_object_name iv_is_intf = abap_false
                 IMPORTING et_lines = lt_lines ev_ok = lv_ok ).
      WHEN 'INTF'.
        read_oo( EXPORTING iv_name = iv_object_name iv_is_intf = abap_true
                 IMPORTING et_lines = lt_lines ev_ok = lv_ok ).
      WHEN 'FUNC'.
        read_func( EXPORTING iv_name = iv_object_name
                   IMPORTING et_lines = lt_lines ev_ok = lv_ok ).
      WHEN 'FUGR'.
        read_fugr( EXPORTING iv_name = iv_object_name
                   IMPORTING et_lines = lt_lines ev_ok = lv_ok ).
    ENDCASE.

    IF lv_ok = abap_false OR lt_lines IS INITIAL.
      rs_source-found   = abap_false.
      rs_source-message = 'ORIGIN_MISSING'.
      RETURN.
    ENDIF.

    rs_source-found      = abap_true.
    rs_source-lines      = lt_lines.
    rs_source-line_count = lines( lt_lines ).
    " Cùng blob + SHA1 với ZCL026_SCORT_TARGET_APPLY (concat newline + calculate_checksum)
    rs_source-text       = zcl_scort_hash_utl=>lines_to_text( lt_lines ).
    rs_source-hash       = zcl_scort_hash_utl=>calculate_checksum( rs_source-text ).
    rs_source-message    = |OK { rs_source-line_count } lines|.
  ENDMETHOD.

ENDCLASS.
