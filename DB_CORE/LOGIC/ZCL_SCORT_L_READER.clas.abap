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

    CLASS-METHODS read_ddic_source_table
      IMPORTING iv_name  TYPE sobj_name
      EXPORTING et_lines TYPE ty_string_tab ev_ok TYPE abap_bool.

    CLASS-METHODS read_ddic_tabl_fallback
      IMPORTING iv_name  TYPE sobj_name
      EXPORTING et_lines TYPE ty_string_tab ev_ok TYPE abap_bool.

    CLASS-METHODS read_ddic_dtel
      IMPORTING iv_name  TYPE sobj_name
      EXPORTING et_lines TYPE ty_string_tab ev_ok TYPE abap_bool.

    CLASS-METHODS read_ddic_doma
      IMPORTING iv_name  TYPE sobj_name
      EXPORTING et_lines TYPE ty_string_tab ev_ok TYPE abap_bool.

    CLASS-METHODS read_msag
      IMPORTING iv_name  TYPE sobj_name
      EXPORTING et_lines TYPE ty_string_tab ev_ok TYPE abap_bool.

    CLASS-METHODS read_devc
      IMPORTING iv_name  TYPE sobj_name
      EXPORTING et_lines TYPE ty_string_tab ev_ok TYPE abap_bool.

    CLASS-METHODS read_dcls
      IMPORTING iv_name  TYPE sobj_name
      EXPORTING et_lines TYPE ty_string_tab ev_ok TYPE abap_bool.

    CLASS-METHODS read_ddlx
      IMPORTING iv_name  TYPE sobj_name
      EXPORTING et_lines TYPE ty_string_tab ev_ok TYPE abap_bool.

    CLASS-METHODS read_bdef
      IMPORTING iv_name  TYPE sobj_name
      EXPORTING et_lines TYPE ty_string_tab ev_ok TYPE abap_bool.

    CLASS-METHODS read_srvd
      IMPORTING iv_name  TYPE sobj_name
      EXPORTING et_lines TYPE ty_string_tab ev_ok TYPE abap_bool.

ENDCLASS.


CLASS zcl_scort_l_reader IMPLEMENTATION.

  METHOD is_supported.
    CASE iv_object_type.
      WHEN 'PROG' OR 'CLAS' OR 'INTF' OR 'FUNC' OR 'FUGR'
        OR 'DTEL' OR 'DOMA' OR 'TABL' OR 'DDLS' OR 'BDEF'
        OR 'DCLS' OR 'DDLX' OR 'SRVD' OR 'TTYP' OR 'VIEW'
        OR 'MSAG' OR 'DEVC'.
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
    DATA lv_main TYPE sobj_name.
    DATA lt_all  TYPE ty_string_tab.
    DATA lt_one  TYPE ty_string_tab.
    DATA lv_ok   TYPE abap_bool.

    CLEAR: et_lines, ev_ok.
    lv_main = |SAPL{ iv_name }|.
    read_prog( EXPORTING iv_name = lv_main
               IMPORTING et_lines = lt_one ev_ok = lv_ok ).
    IF lv_ok = abap_true.
      APPEND LINES OF lt_one TO lt_all.
    ENDIF.

    CLEAR lt_one.
    lv_main = |L{ iv_name }TOP|.
    read_prog( EXPORTING iv_name = lv_main
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
    CLEAR: et_lines, ev_ok.

    CASE iv_object.
      WHEN 'DDLS'.
        read_ddic_source_table( EXPORTING iv_name  = iv_name
                                IMPORTING et_lines = et_lines ev_ok = ev_ok ).
      WHEN 'DCLS'.
        read_dcls( EXPORTING iv_name  = iv_name
                   IMPORTING et_lines = et_lines ev_ok = ev_ok ).
      WHEN 'DDLX'.
        read_ddlx( EXPORTING iv_name  = iv_name
                   IMPORTING et_lines = et_lines ev_ok = ev_ok ).
      WHEN 'BDEF'.
        read_bdef( EXPORTING iv_name  = iv_name
                   IMPORTING et_lines = et_lines ev_ok = ev_ok ).
      WHEN 'SRVD'.
        read_srvd( EXPORTING iv_name  = iv_name
                   IMPORTING et_lines = et_lines ev_ok = ev_ok ).
      WHEN 'TABL' OR 'VIEW' OR 'TTYP'.
        read_ddic_tabl_fallback( EXPORTING iv_name  = iv_name
                                 IMPORTING et_lines = et_lines ev_ok = ev_ok ).
      WHEN 'DTEL'.
        read_ddic_dtel( EXPORTING iv_name  = iv_name
                        IMPORTING et_lines = et_lines ev_ok = ev_ok ).
      WHEN 'DOMA'.
        read_ddic_doma( EXPORTING iv_name  = iv_name
                        IMPORTING et_lines = et_lines ev_ok = ev_ok ).
    ENDCASE.
  ENDMETHOD.

  METHOD read_ddic_source_table.
    DATA lv_source  TYPE string.
    DATA lv_ddlname TYPE ddddlsrc-ddlname.

    CLEAR: et_lines, ev_ok.
    lv_ddlname = iv_name.

    SELECT SINGLE source FROM ddddlsrc
      WHERE ddlname = @lv_ddlname AND as4local = 'A'
      INTO @lv_source.

    IF sy-subrc <> 0.
      SELECT SINGLE source FROM ddddlsrc
        WHERE ddlname = @lv_ddlname
        INTO @lv_source.
    ENDIF.

    IF sy-subrc <> 0 OR lv_source IS INITIAL.
      RETURN.
    ENDIF.

    IF lv_source CS cl_abap_char_utilities=>cr_lf.
      SPLIT lv_source AT cl_abap_char_utilities=>cr_lf INTO TABLE et_lines.
    ELSEIF lv_source CS cl_abap_char_utilities=>newline.
      SPLIT lv_source AT cl_abap_char_utilities=>newline INTO TABLE et_lines.
    ELSE.
      APPEND lv_source TO et_lines.
    ENDIF.

    ev_ok = abap_true.
  ENDMETHOD.

  METHOD read_dcls.
    DATA lv_source  TYPE string.
    DATA lv_dclname TYPE c LENGTH 30.

    CLEAR: et_lines, ev_ok.
    lv_dclname = iv_name.

    TRY.
        SELECT SINGLE source FROM ('ACMDCLSRC')
          WHERE dclname = @lv_dclname AND as4local = 'A'
          INTO @lv_source.
        IF sy-subrc <> 0.
          SELECT SINGLE source FROM ('ACMDCLSRC')
            WHERE dclname = @lv_dclname
            INTO @lv_source.
        ENDIF.
      CATCH cx_root.
        CLEAR lv_source.
    ENDTRY.

    IF lv_source IS INITIAL.
      TRY.
          DATA lo_handler TYPE REF TO object.
          DATA lr_dcl     TYPE REF TO data.
          FIELD-SYMBOLS <ls_dcl> TYPE any.
          FIELD-SYMBOLS <lv_src> TYPE any.

          CALL METHOD ('CL_ACM_DCL_HANDLER_FACTORY')=>('CREATE')
            RECEIVING
              ro_handler = lo_handler.

          IF lo_handler IS BOUND.
            CREATE DATA lr_dcl TYPE ('ACM_S_DCLSRC').
            ASSIGN lr_dcl->* TO <ls_dcl>.

            CALL METHOD lo_handler->('READ')
              EXPORTING
                iv_dclname = lv_dclname
              IMPORTING
                es_dclsrc  = <ls_dcl>.

            ASSIGN COMPONENT 'SOURCE' OF STRUCTURE <ls_dcl> TO <lv_src>.
            IF sy-subrc = 0 AND <lv_src> IS NOT INITIAL.
              lv_source = <lv_src>.
            ENDIF.
          ENDIF.
        CATCH cx_root.
          CLEAR lv_source.
      ENDTRY.
    ENDIF.

    IF lv_source IS INITIAL.
      TRY.
          SELECT SINGLE source FROM ddddlsrc
            WHERE ddlname = @lv_dclname AND as4local = 'A'
            INTO @lv_source.
          IF sy-subrc <> 0.
            SELECT SINGLE source FROM ddddlsrc
              WHERE ddlname = @lv_dclname
              INTO @lv_source.
          ENDIF.
        CATCH cx_root.
          CLEAR lv_source.
      ENDTRY.
    ENDIF.

    IF lv_source IS NOT INITIAL.
      IF lv_source CS cl_abap_char_utilities=>cr_lf.
        SPLIT lv_source AT cl_abap_char_utilities=>cr_lf INTO TABLE et_lines.
      ELSEIF lv_source CS cl_abap_char_utilities=>newline.
        SPLIT lv_source AT cl_abap_char_utilities=>newline INTO TABLE et_lines.
      ELSE.
        APPEND lv_source TO et_lines.
      ENDIF.
      ev_ok = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD read_ddlx.
    DATA lv_source TYPE string.
    DATA lv_name   TYPE c LENGTH 30.

    CLEAR: et_lines, ev_ok.
    lv_name = iv_name.

    TRY.
        SELECT SINGLE source FROM ('DDLXSRC_SRC')
          WHERE ddlxname = @lv_name AND as4local = 'A'
          INTO @lv_source.
        IF sy-subrc <> 0.
          SELECT SINGLE source FROM ('DDLXSRC_SRC')
            WHERE ddlxname = @lv_name
            INTO @lv_source.
        ENDIF.
      CATCH cx_root.
        CLEAR lv_source.
    ENDTRY.

    IF lv_source IS INITIAL.
      TRY.
          SELECT SINGLE source FROM ('DDLXSRC_SRC')
            WHERE metadataname = @lv_name AND as4local = 'A'
            INTO @lv_source.
          IF sy-subrc <> 0.
            SELECT SINGLE source FROM ('DDLXSRC_SRC')
              WHERE metadataname = @lv_name
              INTO @lv_source.
          ENDIF.
        CATCH cx_root.
          CLEAR lv_source.
      ENDTRY.
    ENDIF.

    IF lv_source IS INITIAL.
      TRY.
          SELECT SINGLE source FROM ('DDLXSRC')
            WHERE ddlxname = @lv_name AND as4local = 'A'
            INTO @lv_source.
          IF sy-subrc <> 0.
            SELECT SINGLE source FROM ('DDLXSRC')
              WHERE ddlxname = @lv_name
              INTO @lv_source.
          ENDIF.
        CATCH cx_root.
          CLEAR lv_source.
      ENDTRY.
    ENDIF.

    IF lv_source IS INITIAL.
      TRY.
          DATA lo_persist TYPE REF TO object.
          DATA lo_model   TYPE REF TO object.
          DATA lr_data    TYPE REF TO data.
          FIELD-SYMBOLS <ls_data>    TYPE any.
          FIELD-SYMBOLS <ls_content> TYPE any.
          FIELD-SYMBOLS <lv_src>     TYPE any.

          CREATE OBJECT lo_persist TYPE ('CL_DDLX_ADT_OBJECT_PERSIST').
          CREATE OBJECT lo_model   TYPE ('CL_DDLX_WB_OBJECT_DATA').
          CREATE DATA lr_data TYPE ('CL_DDLX_WB_OBJECT_DATA=>TY_OBJECT_DATA').
          ASSIGN lr_data->* TO <ls_data>.

          DATA(lv_obj_key) = CONV seu_objkey( lv_name ).
          CALL METHOD lo_persist->('GET')
            EXPORTING
              p_object_key  = lv_obj_key
              p_version     = 'A'
            CHANGING
              p_object_data = lo_model.

          CALL METHOD lo_model->('GET_DATA')
            IMPORTING
              p_data = <ls_data>.

          ASSIGN COMPONENT 'CONTENT' OF STRUCTURE <ls_data> TO <ls_content>.
          IF sy-subrc = 0.
            ASSIGN COMPONENT 'SOURCE' OF STRUCTURE <ls_content> TO <lv_src>.
          ENDIF.
          IF sy-subrc <> 0 OR <lv_src> IS INITIAL.
            ASSIGN COMPONENT 'SOURCE' OF STRUCTURE <ls_data> TO <lv_src>.
          ENDIF.
          IF sy-subrc = 0 AND <lv_src> IS NOT INITIAL.
            lv_source = <lv_src>.
          ENDIF.
        CATCH cx_root.
          CLEAR lv_source.
      ENDTRY.
    ENDIF.

    IF lv_source IS INITIAL.
      TRY.
          SELECT SINGLE source FROM ddddlsrc
            WHERE ddlname = @lv_name AND as4local = 'A'
            INTO @lv_source.
          IF sy-subrc <> 0.
            SELECT SINGLE source FROM ddddlsrc
              WHERE ddlname = @lv_name
              INTO @lv_source.
          ENDIF.
        CATCH cx_root.
          CLEAR lv_source.
      ENDTRY.
    ENDIF.

    IF lv_source IS NOT INITIAL.
      IF lv_source CS cl_abap_char_utilities=>cr_lf.
        SPLIT lv_source AT cl_abap_char_utilities=>cr_lf INTO TABLE et_lines.
      ELSEIF lv_source CS cl_abap_char_utilities=>newline.
        SPLIT lv_source AT cl_abap_char_utilities=>newline INTO TABLE et_lines.
      ELSE.
        APPEND lv_source TO et_lines.
      ENDIF.
      ev_ok = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD read_bdef.
    DATA lv_source TYPE string.
    DATA lv_name   TYPE sobj_name.

    CLEAR: et_lines, ev_ok.
    lv_name = iv_name.

    TRY.
        DATA lo_persist TYPE REF TO object.
        DATA lo_model   TYPE REF TO object.
        DATA lr_data    TYPE REF TO data.
        FIELD-SYMBOLS <ls_data>    TYPE any.
        FIELD-SYMBOLS <ls_content> TYPE any.
        FIELD-SYMBOLS <lv_src>     TYPE any.

        CREATE OBJECT lo_persist TYPE ('CL_BDEF_ADT_OBJECT_PERSIST').
        CREATE OBJECT lo_model   TYPE ('CL_BDEF_WB_OBJECT_DATA').
        TRY.
            CREATE DATA lr_data TYPE ('CL_BDEF_WB_OBJECT_DATA=>TY_BDEF_OBJECT_DATA').
          CATCH cx_root.
            TRY.
                CREATE DATA lr_data TYPE ('CL_BDEF_WB_OBJECT_DATA=>TY_OBJECT_DATA').
              CATCH cx_root.
            ENDTRY.
        ENDTRY.

        IF lr_data IS BOUND.
          ASSIGN lr_data->* TO <ls_data>.

          DATA(lv_obj_key) = CONV seu_objkey( lv_name ).
          CALL METHOD lo_persist->('GET')
            EXPORTING
              p_object_key  = lv_obj_key
              p_version     = 'A'
            CHANGING
              p_object_data = lo_model.

          CALL METHOD lo_model->('GET_DATA')
            IMPORTING
              p_data = <ls_data>.

          ASSIGN COMPONENT 'CONTENT-SOURCE' OF STRUCTURE <ls_data> TO <lv_src>.
          IF sy-subrc <> 0 OR <lv_src> IS INITIAL.
            ASSIGN COMPONENT 'CONTENT' OF STRUCTURE <ls_data> TO <ls_content>.
            IF sy-subrc = 0.
              ASSIGN COMPONENT 'SOURCE' OF STRUCTURE <ls_content> TO <lv_src>.
            ENDIF.
          ENDIF.
          IF sy-subrc <> 0 OR <lv_src> IS INITIAL.
            ASSIGN COMPONENT 'SOURCE' OF STRUCTURE <ls_data> TO <lv_src>.
          ENDIF.
          IF sy-subrc = 0 AND <lv_src> IS NOT INITIAL.
            lv_source = <lv_src>.
          ENDIF.
        ENDIF.
      CATCH cx_root.
        CLEAR lv_source.
    ENDTRY.

    IF lv_source IS INITIAL.
      TRY.
          DATA ls_wb_type TYPE wbobjtype.
          DATA lo_wb_oper TYPE REF TO object.
          DATA lo_wb_data TYPE REF TO object.

          ls_wb_type-objtype_tr = 'BDEF'.
          ls_wb_type-subtype_wb = 'BDO'.

          CALL METHOD ('CL_WB_OBJECT_OPERATOR')=>('CREATE_INSTANCE')
            EXPORTING
              object_type = ls_wb_type
              object_key  = lv_name
            RECEIVING
              result      = lo_wb_oper.

          IF lo_wb_oper IS BOUND.
            TRY.
                CALL METHOD lo_wb_oper->('IF_WB_OBJECT_OPERATOR~READ')
                  EXPORTING
                    version        = 'A'
                    data_selection = 'AL'
                  IMPORTING
                    eo_object_data = lo_wb_data.
              CATCH cx_root.
                CALL METHOD lo_wb_oper->('IF_WB_OBJECT_OPERATOR~READ')
                  EXPORTING
                    version        = 'I'
                    data_selection = 'AL'
                  IMPORTING
                    eo_object_data = lo_wb_data.
            ENDTRY.

            IF lo_wb_data IS BOUND.
              CLEAR lr_data.
              TRY.
                  CREATE DATA lr_data TYPE ('CL_BDEF_WB_OBJECT_DATA=>TY_BDEF_OBJECT_DATA').
                CATCH cx_root.
                  TRY.
                      CREATE DATA lr_data TYPE ('CL_BDEF_WB_OBJECT_DATA=>TY_OBJECT_DATA').
                    CATCH cx_root.
                  ENDTRY.
              ENDTRY.

              IF lr_data IS BOUND.
                ASSIGN lr_data->* TO <ls_data>.
                CALL METHOD lo_wb_data->('GET_DATA')
                  IMPORTING
                    p_data = <ls_data>.

                ASSIGN COMPONENT 'CONTENT-SOURCE' OF STRUCTURE <ls_data> TO <lv_src>.
                IF sy-subrc <> 0 OR <lv_src> IS INITIAL.
                  ASSIGN COMPONENT 'CONTENT' OF STRUCTURE <ls_data> TO <ls_content>.
                  IF sy-subrc = 0.
                    ASSIGN COMPONENT 'SOURCE' OF STRUCTURE <ls_content> TO <lv_src>.
                  ENDIF.
                ENDIF.
                IF sy-subrc <> 0 OR <lv_src> IS INITIAL.
                  ASSIGN COMPONENT 'SOURCE' OF STRUCTURE <ls_data> TO <lv_src>.
                ENDIF.

                IF sy-subrc = 0 AND <lv_src> IS NOT INITIAL.
                  lv_source = <lv_src>.
                ENDIF.
              ENDIF.
            ENDIF.
          ENDIF.
        CATCH cx_root.
          CLEAR lv_source.
      ENDTRY.
    ENDIF.

    IF lv_source IS INITIAL.
      TRY.
          SELECT SINGLE source FROM ('RSBDEFSRC')
            WHERE name = @lv_name AND as4local = 'A'
            INTO @lv_source.
        CATCH cx_root.
      ENDTRY.
    ENDIF.

    IF lv_source IS INITIAL.
      TRY.
          SELECT SINGLE source FROM ddddlsrc
            WHERE ddlname = @lv_name AND as4local = 'A'
            INTO @lv_source.
          IF sy-subrc <> 0.
            SELECT SINGLE source FROM ddddlsrc
              WHERE ddlname = @lv_name
              INTO @lv_source.
          ENDIF.
        CATCH cx_root.
      ENDTRY.
    ENDIF.

    IF lv_source IS NOT INITIAL.
      IF lv_source CS cl_abap_char_utilities=>cr_lf.
        SPLIT lv_source AT cl_abap_char_utilities=>cr_lf INTO TABLE et_lines.
      ELSEIF lv_source CS cl_abap_char_utilities=>newline.
        SPLIT lv_source AT cl_abap_char_utilities=>newline INTO TABLE et_lines.
      ELSE.
        APPEND lv_source TO et_lines.
      ENDIF.
      ev_ok = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD read_srvd.
    DATA lv_source TYPE string.
    DATA lv_name   TYPE sobj_name.

    CLEAR: et_lines, ev_ok.
    lv_name = iv_name.

    TRY.
        DATA ls_wb_type TYPE wbobjtype.
        DATA lo_wb_oper TYPE REF TO object.
        DATA lo_wb_data TYPE REF TO object.
        DATA lr_data    TYPE REF TO data.
        FIELD-SYMBOLS <ls_data>    TYPE any.
        FIELD-SYMBOLS <ls_content> TYPE any.
        FIELD-SYMBOLS <lv_src>     TYPE any.

        ls_wb_type-objtype_tr = 'SRVD'.
        ls_wb_type-subtype_wb = 'SRV'.

        CALL METHOD ('CL_WB_OBJECT_OPERATOR')=>('CREATE_INSTANCE')
          EXPORTING
            object_type = ls_wb_type
            object_key  = lv_name
          RECEIVING
            result      = lo_wb_oper.

        IF lo_wb_oper IS BOUND.
          TRY.
              CALL METHOD lo_wb_oper->('IF_WB_OBJECT_OPERATOR~READ')
                EXPORTING
                  version        = 'A'
                  data_selection = 'AL'
                IMPORTING
                  eo_object_data = lo_wb_data.
            CATCH cx_root.
              CALL METHOD lo_wb_oper->('IF_WB_OBJECT_OPERATOR~READ')
                EXPORTING
                  version        = 'I'
                  data_selection = 'AL'
                IMPORTING
                  eo_object_data = lo_wb_data.
          ENDTRY.

          IF lo_wb_data IS BOUND.
            TRY.
                CREATE DATA lr_data TYPE ('CL_SRVD_WB_OBJECT_DATA=>TY_SRVD_OBJECT_DATA').
              CATCH cx_root.
                TRY.
                    CREATE DATA lr_data TYPE ('CL_SRVD_WB_OBJECT_DATA=>TY_OBJECT_DATA').
                  CATCH cx_root.
                ENDTRY.
            ENDTRY.

            IF lr_data IS BOUND.
              ASSIGN lr_data->* TO <ls_data>.
              CALL METHOD lo_wb_data->('GET_DATA')
                IMPORTING
                  p_data = <ls_data>.

              ASSIGN COMPONENT 'CONTENT-SOURCE' OF STRUCTURE <ls_data> TO <lv_src>.
              IF sy-subrc <> 0 OR <lv_src> IS INITIAL.
                ASSIGN COMPONENT 'CONTENT' OF STRUCTURE <ls_data> TO <ls_content>.
                IF sy-subrc = 0.
                  ASSIGN COMPONENT 'SOURCE' OF STRUCTURE <ls_content> TO <lv_src>.
                ENDIF.
              ENDIF.
              IF sy-subrc <> 0 OR <lv_src> IS INITIAL.
                ASSIGN COMPONENT 'SOURCE' OF STRUCTURE <ls_data> TO <lv_src>.
              ENDIF.

              IF sy-subrc = 0 AND <lv_src> IS NOT INITIAL.
                lv_source = <lv_src>.
              ENDIF.
            ENDIF.
          ENDIF.
        ENDIF.
      CATCH cx_root.
        CLEAR lv_source.
    ENDTRY.

    IF lv_source IS INITIAL.
      TRY.
          DATA lo_persist  TYPE REF TO object.
          DATA lo_model    TYPE REF TO object.
          DATA lr_adt_data TYPE REF TO data.
          FIELD-SYMBOLS <ls_adt_data> TYPE any.

          CREATE OBJECT lo_persist TYPE ('CL_SRVD_ADT_OBJECT_PERSIST').
          CREATE OBJECT lo_model   TYPE ('CL_SRVD_WB_OBJECT_DATA').
          TRY.
              CREATE DATA lr_adt_data TYPE ('CL_SRVD_WB_OBJECT_DATA=>TY_SRVD_OBJECT_DATA').
            CATCH cx_root.
              TRY.
                  CREATE DATA lr_adt_data TYPE ('CL_SRVD_WB_OBJECT_DATA=>TY_OBJECT_DATA').
                CATCH cx_root.
              ENDTRY.
          ENDTRY.

          IF lr_adt_data IS BOUND.
            ASSIGN lr_adt_data->* TO <ls_adt_data>.
            DATA(lv_obj_key) = CONV seu_objkey( lv_name ).
            CALL METHOD lo_persist->('GET')
              EXPORTING
                p_object_key  = lv_obj_key
                p_version     = 'A'
              CHANGING
                p_object_data = lo_model.

            CALL METHOD lo_model->('GET_DATA')
              IMPORTING
                p_data = <ls_adt_data>.

            ASSIGN COMPONENT 'CONTENT-SOURCE' OF STRUCTURE <ls_adt_data> TO <lv_src>.
            IF sy-subrc <> 0 OR <lv_src> IS INITIAL.
              ASSIGN COMPONENT 'CONTENT' OF STRUCTURE <ls_adt_data> TO <ls_content>.
              IF sy-subrc = 0.
                ASSIGN COMPONENT 'SOURCE' OF STRUCTURE <ls_content> TO <lv_src>.
              ENDIF.
            ENDIF.
            IF sy-subrc <> 0 OR <lv_src> IS INITIAL.
              ASSIGN COMPONENT 'SOURCE' OF STRUCTURE <ls_adt_data> TO <lv_src>.
            ENDIF.

            IF sy-subrc = 0 AND <lv_src> IS NOT INITIAL.
              lv_source = <lv_src>.
            ENDIF.
          ENDIF.
        CATCH cx_root.
          CLEAR lv_source.
      ENDTRY.
    ENDIF.

    IF lv_source IS INITIAL.
      TRY.
          SELECT SINGLE source FROM ('SRVD_SOURCE')
            WHERE srvd_name = @lv_name
            INTO @lv_source.
        CATCH cx_root.
      ENDTRY.
    ENDIF.

    IF lv_source IS INITIAL.
      TRY.
          SELECT SINGLE source FROM ddddlsrc
            WHERE ddlname = @lv_name AND as4local = 'A'
            INTO @lv_source.
          IF sy-subrc <> 0.
            SELECT SINGLE source FROM ddddlsrc
              WHERE ddlname = @lv_name
              INTO @lv_source.
          ENDIF.
        CATCH cx_root.
      ENDTRY.
    ENDIF.

    IF lv_source IS NOT INITIAL.
      IF lv_source CS cl_abap_char_utilities=>cr_lf.
        SPLIT lv_source AT cl_abap_char_utilities=>cr_lf INTO TABLE et_lines.
      ELSEIF lv_source CS cl_abap_char_utilities=>newline.
        SPLIT lv_source AT cl_abap_char_utilities=>newline INTO TABLE et_lines.
      ELSE.
        APPEND lv_source TO et_lines.
      ENDIF.
      ev_ok = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD read_ddic_tabl_fallback.
    DATA ls_dd02v    TYPE dd02v.
    DATA lt_dd03p    TYPE STANDARD TABLE OF dd03p WITH DEFAULT KEY.
    DATA lt_dd05m    TYPE STANDARD TABLE OF dd05m WITH DEFAULT KEY.
    DATA lt_dd08v    TYPE STANDARD TABLE OF dd08v WITH DEFAULT KEY.
    DATA lv_tabname  TYPE tabname.
    DATA lv_enhanc   TYPE string.
    DATA lv_tabcat   TYPE string.
    DATA lv_delclass TYPE string.
    DATA lv_maint    TYPE string.
    DATA lv_line     TYPE string.
    DATA lv_type     TYPE string.
    DATA lv_fnam     TYPE string.

    CLEAR: et_lines, ev_ok.
    lv_tabname = iv_name.

    CALL FUNCTION 'DDIF_TABL_GET'
      EXPORTING
        name      = lv_tabname
        langu     = sy-langu
      IMPORTING
        dd02v_wa  = ls_dd02v
      TABLES
        dd03p_tab = lt_dd03p
        dd05m_tab = lt_dd05m
        dd08v_tab = lt_dd08v
      EXCEPTIONS
        OTHERS    = 1.

    IF sy-subrc <> 0 OR ls_dd02v-tabname IS INITIAL.
      RETURN.
    ENDIF.

    CASE ls_dd02v-exclass.
      WHEN '1'.    lv_enhanc = 'NOT_CLASSIFIED'.
      WHEN '2'.    lv_enhanc = 'EXTENSIBLE_CHARACTER'.
      WHEN '3'.    lv_enhanc = 'EXTENSIBLE_CHARACTER_NUMERIC'.
      WHEN '4'.    lv_enhanc = 'EXTENSIBLE_ANY'.
      WHEN OTHERS. lv_enhanc = 'NOT_EXTENSIBLE'.
    ENDCASE.

    CASE ls_dd02v-tabclass.
      WHEN 'TRANSP'.  lv_tabcat = 'TRANSPARENT'.
      WHEN 'POOL'.    lv_tabcat = 'POOL'.
      WHEN 'CLUSTER'. lv_tabcat = 'CLUSTER'.
      WHEN 'INTTAB'.  lv_tabcat = 'STRUCTURE'.
      WHEN OTHERS.    lv_tabcat = ls_dd02v-tabclass.
    ENDCASE.

    IF ls_dd02v-contflag IS NOT INITIAL.
      lv_delclass = ls_dd02v-contflag.
    ELSE.
      lv_delclass = 'A'.
    ENDIF.

    CASE ls_dd02v-mainflag.
      WHEN 'X'.    lv_maint = 'ALLOWED'.
      WHEN 'R'.    lv_maint = 'RESTRICTED'.
      WHEN OTHERS. lv_maint = 'NOT_ALLOWED'.
    ENDCASE.

    APPEND |@EndUserText.label : '{ ls_dd02v-ddtext }'| TO et_lines.
    APPEND |@AbapCatalog.enhancement.category : #{ lv_enhanc }| TO et_lines.
    APPEND |@AbapCatalog.tableCategory : #{ lv_tabcat }| TO et_lines.
    APPEND |@AbapCatalog.deliveryClass : #{ lv_delclass }| TO et_lines.
    APPEND |@AbapCatalog.dataMaintenance : #{ lv_maint }| TO et_lines.
    APPEND |define table { to_lower( CONV string( iv_name ) ) } \{| TO et_lines.

    LOOP AT lt_dd03p INTO DATA(ls_p) WHERE fieldname IS NOT INITIAL.
      IF ls_p-fieldname(1) = '.'.
        CONTINUE.
      ENDIF.

      lv_fnam = to_lower( CONV string( ls_p-fieldname ) ).

      IF ls_p-rollname IS NOT INITIAL.
        lv_type = to_lower( CONV string( ls_p-rollname ) ).
      ELSE.
        CASE ls_p-datatype.
          WHEN 'INT8' OR 'INT4' OR 'INT2' OR 'INT1' OR 'DATS' OR 'TIMS' OR 'UTCLONG'.
            lv_type = |abap.{ to_lower( CONV string( ls_p-datatype ) ) }|.
          WHEN 'CHAR' OR 'NUMC' OR 'RAW' OR 'CLNT' OR 'LANG'.
            lv_type = |abap.{ to_lower( CONV string( ls_p-datatype ) ) }({ ls_p-leng })|.
          WHEN 'DEC' OR 'CURR' OR 'QUAN'.
            lv_type = |abap.{ to_lower( CONV string( ls_p-datatype ) ) }({ ls_p-leng }, { ls_p-decimals })|.
          WHEN OTHERS.
            lv_type = |abap.{ to_lower( CONV string( ls_p-datatype ) ) }|.
        ENDCASE.
      ENDIF.

      READ TABLE lt_dd08v INTO DATA(ls_fk)
        WITH KEY fieldname = ls_p-fieldname.
      IF sy-subrc = 0 AND ls_fk-checktable IS NOT INITIAL.
        APPEND |  @AbapCatalog.foreignKey.label : '{ ls_fk-ddtext }'| TO et_lines.
        APPEND |  @AbapCatalog.foreignKey.screenCheck : true| TO et_lines.

        IF ls_p-keyflag = 'X'.
          APPEND |  key { lv_fnam WIDTH = 30 } : { lv_type }| TO et_lines.
        ELSE.
          APPEND |  { lv_fnam WIDTH = 34 } : { lv_type }| TO et_lines.
        ENDIF.

        APPEND |    with foreign key { to_lower( CONV string( ls_fk-checktable ) ) }| TO et_lines.

        DATA(lv_first_cond) = abap_true.
        LOOP AT lt_dd05m INTO DATA(ls_m) WHERE fieldname = ls_p-fieldname.
          DATA(lv_checkf) = to_lower( CONV string( ls_m-checkfield ) ).
          DATA(lv_forkf)  = to_lower( CONV string( ls_m-forkey ) ).
          DATA(lv_tabn)   = to_lower( CONV string( iv_name ) ).

          IF lv_first_cond = abap_true.
            lv_line = |      where { lv_checkf } = { lv_tabn }.{ lv_forkf }|.
            lv_first_cond = abap_false.
          ELSE.
            lv_line = |        and { lv_checkf } = { lv_tabn }.{ lv_forkf }|.
          ENDIF.
          APPEND lv_line TO et_lines.
        ENDLOOP.

        DATA(lv_last_idx) = lines( et_lines ).
        IF lv_last_idx > 0.
          READ TABLE et_lines INTO lv_line INDEX lv_last_idx.
          lv_line = |{ lv_line };|.
          MODIFY et_lines FROM lv_line INDEX lv_last_idx.
        ENDIF.
      ELSE.
        IF ls_p-keyflag = 'X'.
          lv_line = |  key { lv_fnam WIDTH = 30 } : { lv_type } not null;|.
        ELSE.
          lv_line = |  { lv_fnam WIDTH = 34 } : { lv_type };|.
        ENDIF.
        APPEND lv_line TO et_lines.
      ENDIF.
    ENDLOOP.

    APPEND '}' TO et_lines.
    ev_ok = abap_true.
  ENDMETHOD.

  METHOD read_ddic_dtel.
    DATA ls_dd04v TYPE dd04v.
    DATA lv_name  TYPE rollname.
    DATA lv_cat   TYPE string VALUE 'DOMAIN'.
    DATA lv_log   TYPE string VALUE 'false'.
    DATA lv_hist  TYPE string VALUE 'false'.

    CLEAR: et_lines, ev_ok.
    lv_name = iv_name.

    CALL FUNCTION 'DDIF_DTEL_GET'
      EXPORTING
        name     = lv_name
        langu    = sy-langu
      IMPORTING
        dd04v_wa = ls_dd04v
      EXCEPTIONS
        OTHERS   = 1.

    IF sy-subrc <> 0 OR ls_dd04v-rollname IS INITIAL.
      RETURN.
    ENDIF.

    IF ls_dd04v-domname IS INITIAL.
      lv_cat = 'PREDEFINED_TYPE'.
    ENDIF.
    IF ls_dd04v-logflag = 'X'.
      lv_log = 'true'.
    ENDIF.
    IF ls_dd04v-actflag = 'X'.
      lv_hist = 'true'.
    ENDIF.

    APPEND |@EndUserText.label : '{ ls_dd04v-ddtext }'| TO et_lines.
    APPEND |@AbapCatalog.dataElement.category : #{ lv_cat }| TO et_lines.
    IF ls_dd04v-domname IS NOT INITIAL.
      APPEND |@AbapCatalog.dataElement.typeName : '{ to_lower( CONV string( ls_dd04v-domname ) ) }'| TO et_lines.
    ENDIF.
    APPEND |@AbapCatalog.dataElement.dataType : #{ ls_dd04v-datatype }| TO et_lines.
    APPEND |@AbapCatalog.dataElement.length : { ls_dd04v-leng }| TO et_lines.
    IF ls_dd04v-decimals > 0.
      APPEND |@AbapCatalog.dataElement.decimals : { ls_dd04v-decimals }| TO et_lines.
    ENDIF.

    APPEND |@AbapCatalog.dataElement.fieldLabel.short : \{ length : { ls_dd04v-scrlen1 }, text : '{ ls_dd04v-scrtext_s }' \}| TO et_lines.
    APPEND |@AbapCatalog.dataElement.fieldLabel.medium : \{ length : { ls_dd04v-scrlen2 }, text : '{ ls_dd04v-scrtext_m }' \}| TO et_lines.
    APPEND |@AbapCatalog.dataElement.fieldLabel.long : \{ length : { ls_dd04v-scrlen3 }, text : '{ ls_dd04v-scrtext_l }' \}| TO et_lines.
    APPEND |@AbapCatalog.dataElement.fieldLabel.heading : \{ length : { ls_dd04v-headlen }, text : '{ ls_dd04v-reptext }' \}| TO et_lines.

    IF ls_dd04v-shlpname IS NOT INITIAL.
      APPEND |@AbapCatalog.dataElement.searchHelp : \{ name : '{ ls_dd04v-shlpname }', parameter : '{ ls_dd04v-shlpfield }' \}| TO et_lines.
    ENDIF.
    IF ls_dd04v-memoryid IS NOT INITIAL.
      APPEND |@AbapCatalog.dataElement.parameterId : '{ ls_dd04v-memoryid }'| TO et_lines.
    ENDIF.
    APPEND |@AbapCatalog.dataElement.changeDocumentLogging : { lv_log }| TO et_lines.
    APPEND |@AbapCatalog.dataElement.inputHistory : { lv_hist }| TO et_lines.

    IF ls_dd04v-domname IS NOT INITIAL.
      APPEND |define data element { to_lower( CONV string( iv_name ) ) } : { to_lower( CONV string( ls_dd04v-domname ) ) };| TO et_lines.
    ELSE.
      APPEND |define data element { to_lower( CONV string( iv_name ) ) } : abap.{ to_lower( CONV string( ls_dd04v-datatype ) ) }({ ls_dd04v-leng });| TO et_lines.
    ENDIF.
    ev_ok = abap_true.
  ENDMETHOD.

  METHOD read_ddic_doma.
    DATA ls_dd01v TYPE dd01v.
    DATA lt_dd07v TYPE STANDARD TABLE OF dd07v WITH DEFAULT KEY.
    DATA lv_name  TYPE domname.
    DATA lv_case  TYPE string VALUE 'false'.

    CLEAR: et_lines, ev_ok.
    lv_name = iv_name.

    CALL FUNCTION 'DDIF_DOMA_GET'
      EXPORTING
        name      = lv_name
        langu     = sy-langu
      IMPORTING
        dd01v_wa  = ls_dd01v
      TABLES
        dd07v_tab = lt_dd07v
      EXCEPTIONS
        OTHERS    = 1.

    IF sy-subrc <> 0 OR ls_dd01v-domname IS INITIAL.
      RETURN.
    ENDIF.

    IF ls_dd01v-lowercase = 'X'.
      lv_case = 'true'.
    ENDIF.

    APPEND |@EndUserText.label : '{ ls_dd01v-ddtext }'| TO et_lines.
    APPEND |@AbapCatalog.domain.dataType : #{ ls_dd01v-datatype }| TO et_lines.
    APPEND |@AbapCatalog.domain.length : { ls_dd01v-leng }| TO et_lines.
    APPEND |@AbapCatalog.domain.outputLength : { ls_dd01v-outputlen }| TO et_lines.
    IF ls_dd01v-convexit IS NOT INITIAL.
      APPEND |@AbapCatalog.domain.conversionRoutine : '{ ls_dd01v-convexit }'| TO et_lines.
    ENDIF.
    APPEND |@AbapCatalog.domain.caseSensitive : { lv_case }| TO et_lines.
    IF ls_dd01v-entitytab IS NOT INITIAL.
      APPEND |@AbapCatalog.domain.valueTable : '{ to_lower( CONV string( ls_dd01v-entitytab ) ) }'| TO et_lines.
    ENDIF.

    APPEND |define domain { to_lower( CONV string( iv_name ) ) } as { to_lower( CONV string( ls_dd01v-datatype ) ) }({ ls_dd01v-leng }) \{| TO et_lines.
    LOOP AT lt_dd07v INTO DATA(ls_v).
      APPEND |  '{ ls_v-domvalue_l }' : '{ ls_v-ddtext }',| TO et_lines.
    ENDLOOP.
    APPEND '}' TO et_lines.
    ev_ok = abap_true.
  ENDMETHOD.

  METHOD read_msag.
    DATA lv_arbgb      TYPE t100a-arbgb.
    DATA lv_masterlang TYPE t100a-masterlang.
    DATA lv_respuser   TYPE t100a-respuser.
    DATA lv_stext      TYPE t100t-stext.

    CLEAR: et_lines, ev_ok.
    lv_arbgb = iv_name.

    SELECT SINGLE masterlang, respuser FROM t100a
      WHERE arbgb = @lv_arbgb
      INTO (@lv_masterlang, @lv_respuser).

    SELECT SINGLE stext FROM t100t
      WHERE arbgb = @lv_arbgb AND sprsl = @sy-langu
      INTO @lv_stext.

    IF lv_stext IS INITIAL.
      SELECT SINGLE stext FROM t100t
        WHERE arbgb = @lv_arbgb
        INTO @lv_stext.
    ENDIF.

    SELECT msgnr, text FROM t100
      WHERE arbgb = @lv_arbgb AND sprsl = @sy-langu
      ORDER BY msgnr
      INTO TABLE @DATA(lt_t100).

    IF lt_t100 IS INITIAL.
      SELECT msgnr, text FROM t100
        WHERE arbgb = @lv_arbgb
        ORDER BY msgnr
        INTO TABLE @lt_t100 UP TO 200 ROWS.
    ENDIF.

    IF lv_masterlang IS INITIAL AND lt_t100 IS INITIAL.
      RETURN.
    ENDIF.

    IF lv_stext IS NOT INITIAL.
      APPEND |@EndUserText.label : '{ lv_stext }'| TO et_lines.
    ENDIF.
    IF lv_masterlang IS NOT INITIAL.
      APPEND |@AbapCatalog.messageClass.masterLanguage : '{ lv_masterlang }'| TO et_lines.
    ENDIF.
    IF lv_respuser IS NOT INITIAL.
      APPEND |@AbapCatalog.messageClass.responsible : '{ lv_respuser }'| TO et_lines.
    ENDIF.

    APPEND |define message class { to_lower( CONV string( iv_name ) ) } \{| TO et_lines.
    LOOP AT lt_t100 INTO DATA(ls_m).
      DATA lv_text TYPE string.
      lv_text = ls_m-text.
      REPLACE ALL OCCURRENCES OF `'` IN lv_text WITH `''`.
      APPEND |  '{ ls_m-msgnr }' : '{ lv_text }',| TO et_lines.
    ENDLOOP.
    APPEND '}' TO et_lines.

    ev_ok = abap_true.
  ENDMETHOD.

  METHOD read_devc.
    DATA lv_devclass TYPE tdevc-devclass.
    DATA ls_tdevc    TYPE tdevc.
    DATA lv_ctext    TYPE tdevct-ctext.

    CLEAR: et_lines, ev_ok.
    lv_devclass = iv_name.

    SELECT SINGLE * FROM tdevc
      WHERE devclass = @lv_devclass
      INTO @ls_tdevc.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    SELECT SINGLE ctext FROM tdevct
      WHERE devclass = @lv_devclass AND spras = @sy-langu
      INTO @lv_ctext.

    IF lv_ctext IS INITIAL.
      SELECT SINGLE ctext FROM tdevct
        WHERE devclass = @lv_devclass
        INTO @lv_ctext.
    ENDIF.

    SELECT p~devclass, t~ctext
      FROM tdevc AS p
      LEFT OUTER JOIN tdevct AS t ON t~devclass = p~devclass AND t~spras = @sy-langu
      WHERE p~parentcl = @lv_devclass
      ORDER BY p~devclass
      INTO TABLE @DATA(lt_sub).

    DATA lv_type TYPE string.
    IF ls_tdevc-pdevclass IS NOT INITIAL.
      lv_type = 'Development'.
    ELSE.
      lv_type = 'Structure'.
    ENDIF.

    IF lv_ctext IS NOT INITIAL.
      APPEND |@EndUserText.label : '{ lv_ctext }'| TO et_lines.
    ENDIF.
    IF ls_tdevc-dlvunit IS NOT INITIAL.
      APPEND |@AbapCatalog.package.softwareComponent : '{ ls_tdevc-dlvunit }'| TO et_lines.
    ENDIF.
    IF ls_tdevc-component IS NOT INITIAL.
      APPEND |@AbapCatalog.package.applicationComponent : '{ ls_tdevc-component }'| TO et_lines.
    ENDIF.
    IF ls_tdevc-pdevclass IS NOT INITIAL.
      APPEND |@AbapCatalog.package.transportLayer : '{ ls_tdevc-pdevclass }'| TO et_lines.
    ENDIF.
    IF ls_tdevc-parentcl IS NOT INITIAL.
      APPEND |@AbapCatalog.package.superPackage : '{ ls_tdevc-parentcl }'| TO et_lines.
    ENDIF.
    IF ls_tdevc-as4user IS NOT INITIAL.
      APPEND |@AbapCatalog.package.responsible : '{ ls_tdevc-as4user }'| TO et_lines.
    ENDIF.
    APPEND |@AbapCatalog.package.packageType : '{ lv_type }'| TO et_lines.

    APPEND |define package { to_lower( CONV string( iv_name ) ) } \{| TO et_lines.

    IF lt_sub IS NOT INITIAL.
      APPEND '  /* Subpackages */' TO et_lines.
      LOOP AT lt_sub INTO DATA(ls_s).
        DATA lv_sub_desc TYPE string.
        lv_sub_desc = ls_s-ctext.
        REPLACE ALL OCCURRENCES OF `'` IN lv_sub_desc WITH `''`.
        APPEND |  subpackage { to_lower( CONV string( ls_s-devclass ) ) } : '{ lv_sub_desc }';| TO et_lines.
      ENDLOOP.
    ENDIF.

    APPEND '  /* Package Hierarchy */' TO et_lines.
    APPEND '  hierarchy {' TO et_lines.
    IF ls_tdevc-parentcl IS NOT INITIAL.
      APPEND |    level 0 : { to_lower( CONV string( ls_tdevc-parentcl ) ) };| TO et_lines.
    ENDIF.
    APPEND |    level 1 : { to_lower( CONV string( iv_name ) ) };| TO et_lines.
    LOOP AT lt_sub INTO DATA(ls_h).
      APPEND |    level 2 : { to_lower( CONV string( ls_h-devclass ) ) };| TO et_lines.
    ENDLOOP.
    APPEND '  }' TO et_lines.

    APPEND '}' TO et_lines.

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
      WHEN 'DTEL' OR 'DOMA' OR 'TABL' OR 'DDLS' OR 'BDEF'
        OR 'DCLS' OR 'DDLX' OR 'SRVD' OR 'TTYP' OR 'VIEW'.
        read_ddic_src( EXPORTING iv_object = CONV #( iv_object_type )
                                 iv_name   = CONV #( iv_object_name )
                       IMPORTING et_lines  = lt_lines ev_ok = lv_ok ).
      WHEN 'MSAG'.
        read_msag( EXPORTING iv_name  = CONV #( iv_object_name )
                   IMPORTING et_lines = lt_lines ev_ok = lv_ok ).
      WHEN 'DEVC'.
        read_devc( EXPORTING iv_name  = CONV #( iv_object_name )
                   IMPORTING et_lines = lt_lines ev_ok = lv_ok ).
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
    rs_source-text       = zcl_scort_hash_utl=>lines_to_text( lt_lines ).
    rs_source-hash       = zcl_scort_hash_utl=>calculate_checksum( rs_source-text ).
    rs_source-message    = |OK { rs_source-line_count } lines|.
  ENDMETHOD.

ENDCLASS.
