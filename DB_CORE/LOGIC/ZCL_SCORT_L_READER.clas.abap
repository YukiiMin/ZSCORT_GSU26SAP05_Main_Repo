*"*---------------------------------------------------------------------*
*"* Class: ZCL_SCORT_L_READER
*"* Read Active Source on Origin (DEV)
*"*   PROG / CLAS / INTF / FUNC / FUGR
*"*   DTEL / DOMA / TABL / DDLS / BDEF  (via cl_wb_object)
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
        iv_object_type   TYPE csequence
        iv_object_name   TYPE csequence
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

    CLASS-METHODS read_ddic_src
      IMPORTING
        iv_object TYPE trobjtype
        iv_name   TYPE sobj_name
      EXPORTING
        et_lines  TYPE ty_string_tab
        ev_ok     TYPE abap_bool.

    CLASS-METHODS read_ddic_tabl_fallback
      IMPORTING iv_name  TYPE sobj_name
      EXPORTING et_lines TYPE ty_string_tab ev_ok TYPE abap_bool.

ENDCLASS.


CLASS zcl_scort_l_reader IMPLEMENTATION.

  METHOD is_supported.
    CASE iv_object_type.
      WHEN 'PROG' OR 'CLAS' OR 'INTF' OR 'FUNC' OR 'FUGR'
        OR 'DTEL' OR 'DOMA' OR 'TABL' OR 'DDLS' OR 'BDEF'.
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
    DATA lv_fname   TYPE rs38l-name.
    DATA lv_group   TYPE rs38l-area.
    DATA lv_include TYPE programm.
    DATA lt_fm      TYPE STANDARD TABLE OF rssource WITH DEFAULT KEY.
    DATA lv_line    TYPE rssource.

    CLEAR: et_lines, ev_ok.
    lv_fname = iv_name.

    TRY.
        CALL FUNCTION 'FUNCTION_INCLUDE_INFO'
          CHANGING
            funcname            = lv_fname
            group               = lv_group
            include             = lv_include
          EXCEPTIONS
            function_not_exists = 1
            include_not_exists  = 2
            group_not_exists    = 3
            no_selections       = 4
            no_function_include = 5
            OTHERS              = 6.
        IF sy-subrc = 0 AND lv_include IS NOT INITIAL.
          READ REPORT lv_include INTO et_lines.
          IF sy-subrc = 0 AND et_lines IS NOT INITIAL.
            ev_ok = abap_true.
            RETURN.
          ENDIF.
        ENDIF.
      CATCH cx_root.
    ENDTRY.

    SELECT SINGLE pname, include FROM tfdir
      WHERE funcname = @lv_fname
      INTO (@DATA(lv_pname), @DATA(lv_inc_num)).
    IF sy-subrc = 0 AND lv_pname IS NOT INITIAL.
      DATA(lv_inc_str) = |{ lv_inc_num ALPHA = IN }|.
      IF strlen( lv_inc_str ) = 1.
        lv_inc_str = |0{ lv_inc_str }|.
      ENDIF.
      IF lv_pname(4) = 'SAPL'.
        lv_include = |L{ lv_pname+4 }U{ lv_inc_str }|.
      ELSE.
        lv_include = |{ lv_pname }U{ lv_inc_str }|.
      ENDIF.
      READ REPORT lv_include INTO et_lines.
      IF sy-subrc = 0 AND et_lines IS NOT INITIAL.
        ev_ok = abap_true.
        RETURN.
      ENDIF.
    ENDIF.

    CLEAR et_lines.
    TRY.
        CALL FUNCTION 'RPY_FUNCTIONMODULE_READ'
          EXPORTING
            functionname  = lv_fname
          TABLES
            source        = lt_fm
          EXCEPTIONS
            error_message = 1
            OTHERS        = 2.
        IF sy-subrc = 0 AND lt_fm IS NOT INITIAL.
          LOOP AT lt_fm INTO lv_line.
            APPEND CONV string( lv_line ) TO et_lines.
          ENDLOOP.
          ev_ok = abap_true.
        ENDIF.
      CATCH cx_root.
    ENDTRY.
  ENDMETHOD.

  METHOD read_fugr.
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

  METHOD read_ddic_src.
    DATA lo_obj  TYPE REF TO cl_wb_object.
    DATA lt_src  TYPE rswsourcet.
    DATA lv_line TYPE string.

    CLEAR: et_lines, ev_ok.

    TRY.
        lo_obj = cl_wb_object=>create_from_transport_key(
                   p_object   = CONV seu_objt( iv_object )
                   p_obj_name = CONV seu_name( iv_name ) ).
        lo_obj->if_wb_object_operator~get_source(
          IMPORTING p_source = lt_src ).
        LOOP AT lt_src INTO lv_line.
          APPEND CONV string( lv_line ) TO et_lines.
        ENDLOOP.
        IF et_lines IS NOT INITIAL.
          ev_ok = abap_true.
          RETURN.
        ENDIF.
      CATCH cx_root.
        CLEAR et_lines.
    ENDTRY.

    IF iv_object = 'TABL'.
      read_ddic_tabl_fallback( EXPORTING iv_name  = iv_name
                               IMPORTING et_lines = et_lines ev_ok = ev_ok ).
    ENDIF.
  ENDMETHOD.

  METHOD read_ddic_tabl_fallback.
    DATA lt_dfies  TYPE STANDARD TABLE OF dfies WITH DEFAULT KEY.
    DATA lv_line   TYPE string.
    DATA lv_tabcat TYPE string.

    CLEAR: et_lines, ev_ok.

    CALL FUNCTION 'DDIF_FIELDINFO_GET'
      EXPORTING
        tabname   = iv_name
        fieldname = space
        langu     = sy-langu
      IMPORTING
        x030l_wa  = DATA(ls_x030)
      TABLES
        dfies_tab = lt_dfies
      EXCEPTIONS
        not_found = 1
        OTHERS    = 2.

    IF sy-subrc <> 0 OR lt_dfies IS INITIAL.
      RETURN.
    ENDIF.

    SELECT SINGLE ddtext FROM dd02t
      WHERE tabname = @iv_name AND ddlanguage = @sy-langu
      INTO @DATA(lv_ddtext).

    IF lv_ddtext IS INITIAL.
      SELECT SINGLE ddtext FROM dd02t
        WHERE tabname = @iv_name
        INTO @lv_ddtext.
    ENDIF.

    CASE ls_x030-tabclass.
      WHEN 'TRANSP'. lv_tabcat = 'TRANSPARENT'.
      WHEN 'POOL'.   lv_tabcat = 'POOL'.
      WHEN 'CLUSTER'. lv_tabcat = 'CLUSTER'.
      WHEN 'INTTAB'. lv_tabcat = 'STRUCTURE'.
      WHEN OTHERS.   lv_tabcat = ls_x030-tabclass.
    ENDCASE.

    APPEND |@EndUserText.label : '{ lv_ddtext }'| TO et_lines.
    APPEND |@AbapCatalog.tableCategory : #{ lv_tabcat }| TO et_lines.
    APPEND |define table { to_lower( CONV string( iv_name ) ) } \{| TO et_lines.

    LOOP AT lt_dfies INTO DATA(ls_f).
      DATA(lv_fnam)  = to_lower( CONV string( ls_f-fieldname ) ).
      DATA(lv_rnam)  = to_lower( CONV string( ls_f-rollname ) ).
      IF ls_f-keyflag = 'X'.
        IF ls_f-notnull = 'X'.
          lv_line = |  key { lv_fnam }{ REPEAT val = space occ = 30 - strlen( lv_fnam ) } : { lv_rnam } not null;|.
        ELSE.
          lv_line = |  key { lv_fnam }{ REPEAT val = space occ = 30 - strlen( lv_fnam ) } : { lv_rnam };|.
        ENDIF.
      ELSE.
        lv_line = |  { lv_fnam }{ REPEAT val = space occ = 34 - strlen( lv_fnam ) } : { lv_rnam };|.
      ENDIF.
      APPEND lv_line TO et_lines.
    ENDLOOP.

    APPEND |}| TO et_lines.
    ev_ok = abap_true.
  ENDMETHOD.

  METHOD read_active.
    DATA lt_lines TYPE ty_string_tab.
    DATA lv_ok    TYPE abap_bool.

    CLEAR rs_source.
    rs_source-object_type = CONV #( iv_object_type ).
    rs_source-object_name = CONV #( iv_object_name ).

    IF is_supported( CONV #( iv_object_type ) ) = abap_false.
      rs_source-supported = abap_false.
      rs_source-message   = 'NOT_SUPPORTED'.
      RETURN.
    ENDIF.
    rs_source-supported = abap_true.

    CASE iv_object_type.
      WHEN 'PROG'.
        read_prog( EXPORTING iv_name = CONV #( iv_object_name )
                   IMPORTING et_lines = lt_lines ev_ok = lv_ok ).
      WHEN 'CLAS'.
        read_oo( EXPORTING iv_name = CONV #( iv_object_name ) iv_is_intf = abap_false
                 IMPORTING et_lines = lt_lines ev_ok = lv_ok ).
      WHEN 'INTF'.
        read_oo( EXPORTING iv_name = CONV #( iv_object_name ) iv_is_intf = abap_true
                 IMPORTING et_lines = lt_lines ev_ok = lv_ok ).
      WHEN 'FUNC'.
        read_func( EXPORTING iv_name = CONV #( iv_object_name )
                   IMPORTING et_lines = lt_lines ev_ok = lv_ok ).
      WHEN 'FUGR'.
        read_fugr( EXPORTING iv_name = CONV #( iv_object_name )
                   IMPORTING et_lines = lt_lines ev_ok = lv_ok ).
      WHEN 'DTEL' OR 'DOMA' OR 'TABL' OR 'DDLS' OR 'BDEF'.
        read_ddic_src( EXPORTING iv_object = CONV #( iv_object_type )
                                 iv_name   = CONV #( iv_object_name )
                       IMPORTING et_lines  = lt_lines ev_ok = lv_ok ).
    ENDCASE.

    IF lv_ok = abap_false OR lt_lines IS INITIAL.
      rs_source-found   = abap_false.
      rs_source-message = zcm_scort=>get_text_by_key(
                            is_t100_key = zcm_scort=>source_missing
                            iv_attr1    = CONV #( iv_object_type )
                            iv_attr2    = CONV #( iv_object_name )
                            iv_attr3    = 'Local' ).
      RETURN.
    ENDIF.

    rs_source-found      = abap_true.
    rs_source-lines      = lt_lines.
    rs_source-line_count = lines( lt_lines ).
    " Aligned SHA1 hash calculation with ZCL026_SCORT_TARGET_APPLY
    rs_source-text       = zcl_scort_hash_utl=>lines_to_text( lt_lines ).
    rs_source-hash       = zcl_scort_hash_utl=>calculate_checksum( rs_source-text ).
    rs_source-message    = |OK { rs_source-line_count } lines|.
  ENDMETHOD.

ENDCLASS.
