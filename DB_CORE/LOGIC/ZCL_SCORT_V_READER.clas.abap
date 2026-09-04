CLASS zcl_scort_v_reader DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_string_tab TYPE zcl_scort_l_reader=>ty_string_tab.

    TYPES:
      BEGIN OF ty_version_row,
        object_type TYPE trobjtype,
        object_name TYPE sobj_name,
        version_no  TYPE versno,
        author      TYPE syuname,
        datum       TYPE datum,
        uzeit       TYPE uzeit,
        korrnum     TYPE trkorr,
        is_active   TYPE abap_bool,
        message     TYPE string,
      END OF ty_version_row,
      tt_version TYPE STANDARD TABLE OF ty_version_row WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_source,
        object_type TYPE trobjtype,
        object_name TYPE sobj_name,
        version_no  TYPE versno,
        found       TYPE abap_bool,
        lines       TYPE ty_string_tab,
        text        TYPE string,
        hash        TYPE hash160,
        line_count  TYPE i,
        message     TYPE string,
      END OF ty_source.

    CONSTANTS c_vers_active TYPE versno VALUE '99998'.

    CLASS-METHODS map_vrs_objtype
      IMPORTING iv_object_type     TYPE csequence
      RETURNING VALUE(rv_vrs_type) TYPE vrsd-objtype.

    CLASS-METHODS list_versions
      IMPORTING
        iv_object_type TYPE csequence
        iv_object_name TYPE csequence
      RETURNING
        VALUE(rt_list) TYPE tt_version.

    CLASS-METHODS read_version
      IMPORTING
        iv_object_type TYPE csequence
        iv_object_name TYPE csequence
        iv_version_no  TYPE versno
      RETURNING
        VALUE(rs_source) TYPE ty_source.

    CLASS-METHODS display_versions
      IMPORTING
        iv_object_type TYPE csequence
        iv_object_name TYPE csequence.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_incl,
        name TYPE programm,
        kind TYPE c LENGTH 10,
      END OF ty_incl,
      tt_incl TYPE STANDARD TABLE OF ty_incl WITH DEFAULT KEY,
      tt_vrsd TYPE STANDARD TABLE OF vrsd WITH DEFAULT KEY.

    CLASS-METHODS read_version_content
      IMPORTING
        iv_object_type TYPE csequence
        iv_vrs_type    TYPE vrsd-objtype
        iv_object_name TYPE csequence
        iv_version_no  TYPE versno
      EXPORTING
        et_lines       TYPE ty_string_tab
        ev_ok          TYPE abap_bool
        ev_message     TYPE string.

    CLASS-METHODS list_clas_versions
      IMPORTING iv_object_name TYPE csequence
      RETURNING VALUE(rt_vrsd) TYPE tt_vrsd.

    CLASS-METHODS read_version_directory
      IMPORTING
        iv_vrs_type    TYPE vrsd-objtype
        iv_object_name TYPE csequence
      RETURNING
        VALUE(rt_vrsd) TYPE tt_vrsd.

    CLASS-METHODS extract_text_from_any
      IMPORTING is_any   TYPE any
      CHANGING  ct_lines TYPE ty_string_tab.

ENDCLASS.


CLASS zcl_scort_v_reader IMPLEMENTATION.

  METHOD map_vrs_objtype.
    CASE iv_object_type.
      WHEN 'PROG'.
        rv_vrs_type = 'REPS'.
      WHEN 'CLAS'.
        rv_vrs_type = 'CLAS'.
      WHEN 'INTF'.
        rv_vrs_type = 'INTF'.
      WHEN 'FUNC'.
        rv_vrs_type = 'FUNC'.
      WHEN 'FUGR'.
        rv_vrs_type = 'FUGR'.
      WHEN OTHERS.
        rv_vrs_type = CONV vrsd-objtype( iv_object_type ).
    ENDCASE.
  ENDMETHOD.

  METHOD list_versions.
    DATA lv_vrs_type TYPE vrsd-objtype.
    DATA lv_objname  TYPE vrsd-objname.
    DATA lt_vrsd     TYPE tt_vrsd.
    DATA ls_row      TYPE ty_version_row.
    DATA ls_active   TYPE zcl_scort_l_reader=>ty_source.

    CLEAR rt_list.
    lv_vrs_type = map_vrs_objtype( iv_object_type ).
    lv_objname  = CONV vrsd-objname( iv_object_name ).

    lt_vrsd = read_version_directory(
                iv_vrs_type   = lv_vrs_type
                iv_object_name = CONV sobj_name( lv_objname ) ).

    IF lt_vrsd IS INITIAL.
      IF iv_object_type = 'CLAS'.
        lt_vrsd = list_clas_versions( iv_object_name ).
      ELSE.
        SELECT objtype, objname, versno, author, datum, zeit, korrnum
          FROM vrsd
          WHERE objtype = @lv_vrs_type
            AND objname = @lv_objname
          ORDER BY versno DESCENDING
          INTO CORRESPONDING FIELDS OF TABLE @lt_vrsd.
      ENDIF.
    ENDIF.

    IF lt_vrsd IS INITIAL AND iv_object_type = 'INTF'.
      TRY.
          lv_objname = CONV vrsd-objname(
            cl_oo_classname_service=>get_interfacepool_name( CONV seoclsname( iv_object_name ) ) ).
        CATCH cx_root.
          lv_objname = CONV vrsd-objname( |{ iv_object_name WIDTH = 30 PAD = '=' }IP| ).
      ENDTRY.
      lt_vrsd = read_version_directory(
                  iv_vrs_type    = 'REPS'
                  iv_object_name = CONV sobj_name( lv_objname ) ).
      IF lt_vrsd IS INITIAL.
        SELECT objtype, objname, versno, author, datum, zeit, korrnum
          FROM vrsd
          WHERE objtype = 'REPS'
            AND objname = @lv_objname
          ORDER BY versno DESCENDING
          INTO CORRESPONDING FIELDS OF TABLE @lt_vrsd.
      ENDIF.
    ENDIF.

    DATA lt_seen TYPE SORTED TABLE OF versno WITH UNIQUE KEY table_line.
    DATA lv_label TYPE string.
    LOOP AT lt_vrsd INTO DATA(ls_vrsd).
      IF ls_vrsd-versno IS INITIAL OR ls_vrsd-versno = '00000'.
        CONTINUE.
      ENDIF.
      INSERT ls_vrsd-versno INTO TABLE lt_seen.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      CLEAR ls_row.
      ls_row-object_type = iv_object_type.
      ls_row-object_name = iv_object_name.
      ls_row-version_no  = ls_vrsd-versno.
      ls_row-author      = ls_vrsd-author.
      ls_row-datum       = ls_vrsd-datum.
      ls_row-uzeit       = ls_vrsd-zeit.
      ls_row-korrnum     = ls_vrsd-korrnum.
      ls_row-is_active   = abap_false.
      lv_label = CONV string( ls_vrsd-versno ).
      SHIFT lv_label LEFT DELETING LEADING '0'.
      IF lv_label IS INITIAL.
        CONTINUE.
      ENDIF.
      IF ls_vrsd-korrnum IS NOT INITIAL.
        ls_row-message = |{ lv_label } — { ls_vrsd-korrnum }|.
      ELSE.
        ls_row-message = lv_label.
      ENDIF.
      APPEND ls_row TO rt_list.
    ENDLOOP.

    SORT rt_list BY version_no DESCENDING.

    ls_active = zcl_scort_l_reader=>read_active(
                  iv_object_type = iv_object_type
                  iv_object_name = iv_object_name ).
    CLEAR ls_row.
    ls_row-object_type = iv_object_type.
    ls_row-object_name = iv_object_name.
    ls_row-version_no  = c_vers_active.
    ls_row-author      = sy-uname.
    ls_row-datum       = sy-datum.
    ls_row-uzeit       = sy-uzeit.
    ls_row-is_active   = abap_true.
    IF ls_active-found = abap_true.
      ls_row-message = |Active ({ ls_active-line_count } lines)|.
    ELSE.
      ls_row-message = 'Active missing'.
    ENDIF.
    INSERT ls_row INTO rt_list INDEX 1.
  ENDMETHOD.

  METHOD display_versions.
    DATA lv_pgmid  TYPE e071-pgmid.
    DATA lv_object TYPE e071-object.
    DATA lv_name   TYPE e071-obj_name.

    lv_object = iv_object_type.
    lv_name   = CONV e071-obj_name( iv_object_name ).

    CASE iv_object_type.
      WHEN 'FUNC'.
        lv_pgmid = 'LIMU'.
      WHEN OTHERS.
        lv_pgmid = 'R3TR'.
    ENDCASE.

    CALL FUNCTION 'SVRS_DISPLAY_VERSION'
      EXPORTING
        pgmid    = lv_pgmid
        object   = lv_object
        obj_name = lv_name.
  ENDMETHOD.

  METHOD read_version_directory.
    DATA lv_objname TYPE vrsd-objname.
    DATA lt_vrsn    TYPE STANDARD TABLE OF vrsn WITH DEFAULT KEY.
    DATA lt_list    TYPE tt_vrsd.

    CLEAR rt_vrsd.
    lv_objname = CONV vrsd-objname( iv_object_name ).

    TRY.
        CALL FUNCTION 'SVRS_GET_VERSION_DIRECTORY_46'
          EXPORTING
            destination  = space
            objname      = lv_objname
            objtype      = iv_vrs_type
          TABLES
            lversno_list = lt_vrsn
            version_list = lt_list
          EXCEPTIONS
            no_entry              = 1
            communication_failure = 2
            system_failure        = 3
            OTHERS                = 4.
        IF sy-subrc = 0 AND lt_list IS NOT INITIAL.
          rt_vrsd = lt_list.
        ENDIF.
      CATCH cx_sy_dyn_call_illegal_type
            cx_sy_dyn_call_param_missing
            cx_sy_dyn_call_param_not_found
            cx_root.
        CLEAR rt_vrsd.
    ENDTRY.
  ENDMETHOD.

  METHOD list_clas_versions.
    DATA ls_keep    TYPE vrsd.
    DATA lt_raw     TYPE tt_vrsd.
    DATA lv_pattern TYPE vrsd-objname.
    DATA lv_methpat TYPE vrsd-objname.
    DATA lt_seen    TYPE SORTED TABLE OF versno WITH UNIQUE KEY table_line.

    CLEAR rt_vrsd.

    lv_pattern = CONV vrsd-objname( |{ iv_object_name WIDTH = 30 PAD = '=' }%| ).
    lv_methpat = CONV vrsd-objname( |{ iv_object_name } %| ).

    SELECT objtype, objname, versno, author, datum, zeit, korrnum
      FROM vrsd
      WHERE ( objtype = 'CPUB' OR objtype = 'CPRI' OR objtype = 'CPRO'
           OR objtype = 'CINC' OR objtype = 'CLSD' OR objtype = 'METH'
           OR objtype = 'CLAS' OR objtype = 'REPS' )
        AND ( objname = @iv_object_name
           OR objname LIKE @lv_pattern
           OR objname LIKE @lv_methpat )
      INTO CORRESPONDING FIELDS OF TABLE @lt_raw.

    LOOP AT lt_raw INTO ls_keep WHERE objtype = 'CPUB'.
      INSERT ls_keep-versno INTO TABLE lt_seen.
      IF sy-subrc = 0.
        APPEND ls_keep TO rt_vrsd.
      ENDIF.
    ENDLOOP.

    IF rt_vrsd IS INITIAL.
      SORT lt_raw BY versno DESCENDING objtype.
      LOOP AT lt_raw INTO ls_keep.
        INSERT ls_keep-versno INTO TABLE lt_seen.
        IF sy-subrc = 0.
          APPEND ls_keep TO rt_vrsd.
        ENDIF.
      ENDLOOP.
    ENDIF.

    SORT rt_vrsd BY versno DESCENDING.
  ENDMETHOD.
  METHOD read_version.
    DATA lv_vrs_type TYPE vrsd-objtype.
    DATA lt_lines    TYPE ty_string_tab.
    DATA lv_ok       TYPE abap_bool.
    DATA lv_msg      TYPE string.
    DATA ls_active   TYPE zcl_scort_l_reader=>ty_source.

    CLEAR rs_source.
    rs_source-object_type = iv_object_type.
    rs_source-object_name = iv_object_name.
    rs_source-version_no  = iv_version_no.

    IF iv_version_no = c_vers_active OR iv_version_no IS INITIAL.
      ls_active = zcl_scort_l_reader=>read_active(
                    iv_object_type = iv_object_type
                    iv_object_name = iv_object_name ).
      rs_source-found      = ls_active-found.
      rs_source-lines      = ls_active-lines.
      rs_source-text       = ls_active-text.
      rs_source-hash       = ls_active-hash.
      rs_source-line_count = ls_active-line_count.
      rs_source-message    = ls_active-message.
      rs_source-version_no = c_vers_active.
      RETURN.
    ENDIF.

    lv_vrs_type = map_vrs_objtype( iv_object_type ).
    read_version_content(
      EXPORTING
        iv_object_type = iv_object_type
        iv_vrs_type    = lv_vrs_type
        iv_object_name = iv_object_name
        iv_version_no  = iv_version_no
      IMPORTING
        et_lines       = lt_lines
        ev_ok          = lv_ok
        ev_message     = lv_msg ).

    IF lv_ok = abap_false OR lt_lines IS INITIAL.
      rs_source-found   = abap_false.
      rs_source-message = lv_msg.
      IF rs_source-message IS INITIAL.
        rs_source-message = |Version { iv_version_no } unreadable|.
      ENDIF.
      RETURN.
    ENDIF.

    rs_source-found      = abap_true.
    rs_source-lines      = lt_lines.
    rs_source-line_count = lines( lt_lines ).
    rs_source-text       = zcl_scort_hash_utl=>lines_to_text( lt_lines ).
    rs_source-hash       = zcl_scort_hash_utl=>calculate_checksum( rs_source-text ).
    rs_source-message    = |OK { iv_object_type } vers { iv_version_no }, { rs_source-line_count } lines|.
  ENDMETHOD.

  METHOD read_version_content.
    DATA ls_object TYPE svrs2_versionable_object.
    FIELD-SYMBOLS <ls_sub> TYPE any.

    CLEAR: et_lines, ev_ok, ev_message.

    ls_object-objtype = iv_vrs_type.
    ls_object-objname = CONV #( iv_object_name ).
    ls_object-versno  = iv_version_no.

    CALL FUNCTION 'SVRS_GET_VERSION'
      CHANGING
        object = ls_object
      EXCEPTIONS
        no_version         = 1
        version_unreadable = 2
        OTHERS             = 3.

    IF sy-subrc <> 0.
      IF iv_object_type = 'PROG' OR iv_vrs_type = 'REPS'.
        DATA lt_fallback_reps TYPE STANDARD TABLE OF abaptxt WITH DEFAULT KEY.
        DATA lv_pname TYPE programm.
        lv_pname = CONV #( iv_object_name ).
        TRY.
            CALL FUNCTION 'SVRS_GET_VERSION_REPS'
              EXPORTING
                progname = lv_pname
                versno   = iv_version_no
              TABLES
                texttab  = lt_fallback_reps
              EXCEPTIONS
                OTHERS   = 1.
            IF sy-subrc = 0 AND lt_fallback_reps IS NOT INITIAL.
              extract_text_from_any( EXPORTING is_any = lt_fallback_reps CHANGING ct_lines = et_lines ).
              IF et_lines IS NOT INITIAL.
                ev_ok = abap_true.
                ev_message = |PROG via SVRS_GET_VERSION_REPS ({ lines( et_lines ) } lines)|.
                et_lines = zcl_scort_hash_utl=>normalize_lines( et_lines ).
                RETURN.
              ENDIF.
            ENDIF.
          CATCH cx_root.
        ENDTRY.
      ENDIF.

      ev_ok = abap_false.
      ev_message = |SVRS_GET_VERSION failed for { iv_object_name } vers { iv_version_no } (Subrc: { sy-subrc })|.
      RETURN.
    ENDIF.

    ev_ok = abap_true.

    CASE iv_vrs_type.
      WHEN 'CLAS'.
        ASSIGN COMPONENT 'CPUB' OF STRUCTURE ls_object TO <ls_sub>.
        IF sy-subrc = 0 AND <ls_sub> IS ASSIGNED.
          APPEND '*"*--- Public Section ---*' TO et_lines.
          extract_text_from_any( EXPORTING is_any = <ls_sub> CHANGING ct_lines = et_lines ).
          APPEND '' TO et_lines.
        ENDIF.

        ASSIGN COMPONENT 'CPRO' OF STRUCTURE ls_object TO <ls_sub>.
        IF sy-subrc = 0 AND <ls_sub> IS ASSIGNED.
          APPEND '*"*--- Protected Section ---*' TO et_lines.
          extract_text_from_any( EXPORTING is_any = <ls_sub> CHANGING ct_lines = et_lines ).
          APPEND '' TO et_lines.
        ENDIF.

        ASSIGN COMPONENT 'CPRI' OF STRUCTURE ls_object TO <ls_sub>.
        IF sy-subrc = 0 AND <ls_sub> IS ASSIGNED.
          APPEND '*"*--- Private Section ---*' TO et_lines.
          extract_text_from_any( EXPORTING is_any = <ls_sub> CHANGING ct_lines = et_lines ).
        ENDIF.

        ev_message = |CLAS via SVRS_GET_VERSION ({ lines( et_lines ) } lines)|.

      WHEN 'INTF'.
        ASSIGN COMPONENT 'INTF' OF STRUCTURE ls_object TO <ls_sub>.
        IF sy-subrc = 0 AND <ls_sub> IS ASSIGNED.
          extract_text_from_any( EXPORTING is_any = <ls_sub> CHANGING ct_lines = et_lines ).
        ENDIF.
        ev_message = |INTF via SVRS_GET_VERSION ({ lines( et_lines ) } lines)|.

      WHEN 'FUNC'.
        ASSIGN COMPONENT 'FUNC' OF STRUCTURE ls_object TO <ls_sub>.
        IF sy-subrc = 0 AND <ls_sub> IS ASSIGNED.
          extract_text_from_any( EXPORTING is_any = <ls_sub> CHANGING ct_lines = et_lines ).
        ENDIF.
        ev_message = |FUNC via SVRS_GET_VERSION ({ lines( et_lines ) } lines)|.

      WHEN 'METH'.
        ASSIGN COMPONENT 'METH' OF STRUCTURE ls_object TO <ls_sub>.
        IF sy-subrc = 0 AND <ls_sub> IS ASSIGNED.
          extract_text_from_any( EXPORTING is_any = <ls_sub> CHANGING ct_lines = et_lines ).
        ENDIF.
        ev_message = |METH via SVRS_GET_VERSION ({ lines( et_lines ) } lines)|.

      WHEN OTHERS.
        ASSIGN COMPONENT 'REPS' OF STRUCTURE ls_object TO <ls_sub>.
        IF sy-subrc = 0 AND <ls_sub> IS ASSIGNED.
          extract_text_from_any( EXPORTING is_any = <ls_sub> CHANGING ct_lines = et_lines ).
        ENDIF.
        ev_message = |{ iv_vrs_type } via SVRS_GET_VERSION ({ lines( et_lines ) } lines)|.
    ENDCASE.

    IF et_lines IS INITIAL.
      ASSIGN COMPONENT 'REPS' OF STRUCTURE ls_object TO <ls_sub>.
      IF sy-subrc = 0 AND <ls_sub> IS ASSIGNED.
        extract_text_from_any( EXPORTING is_any = <ls_sub> CHANGING ct_lines = et_lines ).
      ENDIF.
    ENDIF.

    IF et_lines IS INITIAL AND ( iv_object_type = 'PROG' OR iv_vrs_type = 'REPS' ).
      DATA lt_repotext TYPE STANDARD TABLE OF abaptxt WITH DEFAULT KEY.
      TRY.
          CALL FUNCTION 'SVRS_GET_REPS_FROM_OBJECT'
            EXPORTING
              object   = ls_object
            TABLES
              repotext = lt_repotext
            EXCEPTIONS
              OTHERS   = 1.
          IF sy-subrc = 0 AND lt_repotext IS NOT INITIAL.
            extract_text_from_any( EXPORTING is_any = lt_repotext CHANGING ct_lines = et_lines ).
          ENDIF.
        CATCH cx_root.
      ENDTRY.
    ENDIF.

    IF et_lines IS INITIAL AND ( iv_object_type = 'PROG' OR iv_vrs_type = 'REPS' ).
      DATA lt_vrs_reps2 TYPE STANDARD TABLE OF abaptxt WITH DEFAULT KEY.
      DATA lv_progname2 TYPE programm.
      lv_progname2 = CONV #( iv_object_name ).
      TRY.
          CALL FUNCTION 'SVRS_GET_VERSION_REPS'
            EXPORTING
              progname = lv_progname2
              versno   = iv_version_no
            TABLES
              texttab  = lt_vrs_reps2
            EXCEPTIONS
              OTHERS   = 1.
          IF sy-subrc = 0 AND lt_vrs_reps2 IS NOT INITIAL.
            extract_text_from_any( EXPORTING is_any = lt_vrs_reps2 CHANGING ct_lines = et_lines ).
          ENDIF.
        CATCH cx_root.
      ENDTRY.
    ENDIF.

    IF et_lines IS INITIAL AND iv_vrs_type = 'FUNC'.
      DATA lt_vrs_func TYPE STANDARD TABLE OF abaptxt WITH DEFAULT KEY.
      TRY.
          CALL FUNCTION 'SVRS_GET_VERSION_FUNC'
            EXPORTING
              funcname = CONV rs38l_fnam( iv_object_name )
              versno   = iv_version_no
            TABLES
              texttab  = lt_vrs_func
            EXCEPTIONS
              OTHERS   = 1.
          IF sy-subrc = 0 AND lt_vrs_func IS NOT INITIAL.
            extract_text_from_any( EXPORTING is_any = lt_vrs_func CHANGING ct_lines = et_lines ).
          ENDIF.
        CATCH cx_root.
      ENDTRY.
    ENDIF.

    et_lines = zcl_scort_hash_utl=>normalize_lines( et_lines ).
  ENDMETHOD.

  METHOD extract_text_from_any.
    DATA lo_type       TYPE REF TO cl_abap_typedescr.
    DATA lo_struct     TYPE REF TO cl_abap_structdescr.
    DATA lo_comp_descr TYPE REF TO cl_abap_typedescr.
    DATA lo_row_descr  TYPE REF TO cl_abap_typedescr.
    DATA lt_comp_names TYPE string_table.
    DATA lv_str        TYPE string.
    DATA lt_split      TYPE string_table.
    FIELD-SYMBOLS <lt_table> TYPE ANY TABLE.
    FIELD-SYMBOLS <ls_row>   TYPE any.
    FIELD-SYMBOLS <lv_val>   TYPE any.
    FIELD-SYMBOLS <lv_comp>  TYPE any.

    IF is_any IS INITIAL.
      RETURN.
    ENDIF.

    lo_type = cl_abap_typedescr=>describe_by_data( is_any ).

    CASE lo_type->kind.
      WHEN cl_abap_typedescr=>kind_table.
        ASSIGN is_any TO <lt_table>.
        IF sy-subrc = 0 AND <lt_table> IS ASSIGNED.
          LOOP AT <lt_table> ASSIGNING <ls_row>.
            lo_row_descr = cl_abap_typedescr=>describe_by_data( <ls_row> ).
            IF lo_row_descr->kind = cl_abap_typedescr=>kind_struct.
              ASSIGN COMPONENT 'LINE' OF STRUCTURE <ls_row> TO <lv_val>.
              IF sy-subrc <> 0.
                ASSIGN COMPONENT 'TEXT' OF STRUCTURE <ls_row> TO <lv_val>.
              ENDIF.
              IF sy-subrc <> 0.
                ASSIGN COMPONENT 1 OF STRUCTURE <ls_row> TO <lv_val>.
              ENDIF.
              IF sy-subrc = 0 AND <lv_val> IS ASSIGNED.
                APPEND CONV string( <lv_val> ) TO ct_lines.
              ENDIF.
            ELSE.
              APPEND CONV string( <ls_row> ) TO ct_lines.
            ENDIF.
          ENDLOOP.
        ENDIF.

      WHEN cl_abap_typedescr=>kind_struct.
        lo_struct = CAST cl_abap_structdescr( lo_type ).
        lt_comp_names = VALUE #( ( `SOURCE` ) ( `ABAPTEXT` ) ( `ABAPTXT` ) ( `TEXT` ) ( `LINES` ) ( `DELTA` ) ).
        LOOP AT lt_comp_names INTO DATA(lv_cname).
          ASSIGN COMPONENT lv_cname OF STRUCTURE is_any TO <lv_comp>.
          IF sy-subrc = 0 AND <lv_comp> IS ASSIGNED AND <lv_comp> IS NOT INITIAL.
            lo_comp_descr = cl_abap_typedescr=>describe_by_data( <lv_comp> ).
            IF lo_comp_descr->kind = cl_abap_typedescr=>kind_table.
              extract_text_from_any( EXPORTING is_any = <lv_comp> CHANGING ct_lines = ct_lines ).
              IF ct_lines IS NOT INITIAL.
                RETURN.
              ENDIF.
            ENDIF.
          ENDIF.
        ENDLOOP.

        LOOP AT lo_struct->components INTO DATA(ls_comp).
          ASSIGN COMPONENT ls_comp-name OF STRUCTURE is_any TO <lv_comp>.
          IF sy-subrc = 0 AND <lv_comp> IS ASSIGNED AND <lv_comp> IS NOT INITIAL.
            lo_comp_descr = cl_abap_typedescr=>describe_by_data( <lv_comp> ).
            IF lo_comp_descr->kind = cl_abap_typedescr=>kind_table.
              extract_text_from_any( EXPORTING is_any = <lv_comp> CHANGING ct_lines = ct_lines ).
              IF ct_lines IS NOT INITIAL.
                RETURN.
              ENDIF.
            ENDIF.
          ENDIF.
        ENDLOOP.

      WHEN cl_abap_typedescr=>kind_elem.
        lv_str = CONV string( is_any ).
        IF lv_str CS cl_abap_char_utilities=>cr_lf.
          SPLIT lv_str AT cl_abap_char_utilities=>cr_lf INTO TABLE lt_split.
        ELSEIF lv_str CS cl_abap_char_utilities=>newline.
          SPLIT lv_str AT cl_abap_char_utilities=>newline INTO TABLE lt_split.
        ELSE.
          APPEND lv_str TO ct_lines.
          RETURN.
        ENDIF.
        LOOP AT lt_split INTO DATA(lv_sline).
          APPEND lv_sline TO ct_lines.
        ENDLOOP.

      WHEN OTHERS.
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
