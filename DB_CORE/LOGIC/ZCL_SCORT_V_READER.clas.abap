*"*---------------------------------------------------------------------*
*"* Class: ZCL_SCORT_V_READER
*"* TH2 — Version History (read-only)
*"* UI   : SVRS_DISPLAY_VERSION (giống SE80 Version Management)
*"* List : VRSD only for CLAS (CPUB/METH…) — no GET_VERSION_LIST
*"* Read :
*"*   PROG/REPS     → SVRS_GET_REPS_FROM_OBJECT / SVRS_GET_VERSION_REPS
*"*   CLAS          → =====CS else ghép CU/CO/CI + locals + CMxxx
*"*   INTF          → INTF / =====IP / INTFSEC
*"*   FUNC          → SVRS_GET_VERSION_FUNC
*"*   FUGR          → SVRS_GET_REPS_FROM_OBJECT
*"*---------------------------------------------------------------------*
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
      IMPORTING iv_object_type     TYPE trobjtype
      RETURNING VALUE(rv_vrs_type) TYPE vrsd-objtype.

    CLASS-METHODS list_versions
      IMPORTING
        iv_object_type TYPE trobjtype
        iv_object_name TYPE sobj_name
      RETURNING
        VALUE(rt_list) TYPE tt_version.

    CLASS-METHODS read_version
      IMPORTING
        iv_object_type TYPE trobjtype
        iv_object_name TYPE sobj_name
        iv_version_no  TYPE versno
      RETURNING
        VALUE(rs_source) TYPE ty_source.

    " Mở màn hình Version Management chuẩn SAP (click chọn version)
    CLASS-METHODS display_versions
      IMPORTING
        iv_object_type TYPE trobjtype
        iv_object_name TYPE sobj_name.

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
        iv_object_type TYPE trobjtype
        iv_vrs_type    TYPE vrsd-objtype
        iv_object_name TYPE sobj_name
        iv_version_no  TYPE versno
      EXPORTING
        et_lines       TYPE ty_string_tab
        ev_ok          TYPE abap_bool
        ev_message     TYPE string.

    CLASS-METHODS read_reps_generic
      IMPORTING
        iv_vrs_type    TYPE vrsd-objtype
        iv_object_name TYPE sobj_name
        iv_version_no  TYPE versno
      EXPORTING
        et_lines       TYPE ty_string_tab
        ev_ok          TYPE abap_bool.

    CLASS-METHODS read_func_version
      IMPORTING
        iv_object_name TYPE sobj_name
        iv_version_no  TYPE versno
      EXPORTING
        et_lines       TYPE ty_string_tab
        ev_ok          TYPE abap_bool.

    CLASS-METHODS read_clas_version
      IMPORTING
        iv_object_name TYPE sobj_name
        iv_version_no  TYPE versno
      EXPORTING
        et_lines       TYPE ty_string_tab
        ev_ok          TYPE abap_bool
        ev_message     TYPE string.

    CLASS-METHODS read_intf_version
      IMPORTING
        iv_object_name TYPE sobj_name
        iv_version_no  TYPE versno
      EXPORTING
        et_lines       TYPE ty_string_tab
        ev_ok          TYPE abap_bool
        ev_message     TYPE string.

    CLASS-METHODS collect_clas_form_includes
      IMPORTING iv_clsname TYPE seoclsname
      RETURNING VALUE(rt_incl) TYPE tt_incl.

    CLASS-METHODS append_include_source
      IMPORTING
        iv_include    TYPE programm
        iv_kind       TYPE csequence
        iv_version_no TYPE versno
      CHANGING
        ct_lines      TYPE ty_string_tab
        cv_any_ok     TYPE abap_bool.

    CLASS-METHODS resolve_include_versno
      IMPORTING
        iv_include    TYPE programm
        iv_version_no TYPE versno
      RETURNING
        VALUE(rv_vers) TYPE versno.

    CLASS-METHODS list_clas_versions
      IMPORTING iv_object_name TYPE sobj_name
      RETURNING VALUE(rt_vrsd) TYPE tt_vrsd.

    "! List giống Version Management (SVRS_GET_VERSION_DIRECTORY_46)
    CLASS-METHODS read_version_directory
      IMPORTING
        iv_vrs_type    TYPE vrsd-objtype
        iv_object_name TYPE sobj_name
      RETURNING
        VALUE(rt_vrsd) TYPE tt_vrsd.

    CLASS-METHODS append_text_table
      IMPORTING it_any   TYPE ANY TABLE
      CHANGING  ct_lines TYPE ty_string_tab.

    CLASS-METHODS add_unique_incl
      IMPORTING
        iv_name TYPE programm
        iv_kind TYPE csequence
      CHANGING
        ct_incl TYPE tt_incl.

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

    IF iv_object_type = 'CLAS'.
      lt_vrsd = list_clas_versions( iv_object_name ).
    ELSE.
      " Ưu tiên FM directory (cùng nguồn list Version Management / ADT)
      lt_vrsd = read_version_directory(
                  iv_vrs_type   = lv_vrs_type
                  iv_object_name = CONV sobj_name( lv_objname ) ).

      IF lt_vrsd IS INITIAL.
        SELECT objtype, objname, versno, author, datum, zeit, korrnum
          FROM vrsd
          WHERE objtype = @lv_vrs_type
            AND objname = @lv_objname
          ORDER BY versno DESCENDING
          INTO CORRESPONDING FIELDS OF TABLE @lt_vrsd.
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
    ENDIF.

    " Dedup theo VERSNO (FM / SELECT có thể trùng)
    DATA lt_seen TYPE SORTED TABLE OF versno WITH UNIQUE KEY table_line.
    DATA lv_label TYPE string.
    LOOP AT lt_vrsd INTO DATA(ls_vrsd).
      IF ls_vrsd-versno IS INITIAL OR ls_vrsd-versno = '00000'.
        CONTINUE. " kỹ thuật — SE80 không đếm là version 1…
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
    " Cùng FM mà SE80 / Version Management dùng (ảnh 4)
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

    " Cùng directory mà Version Management dùng (đủ VERSNO hơn SELECT VRSD thuần)
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
    " Only VRSD — no GET_VERSION_LIST / SVRS_VERSIONABLE_OBJECTS (type conflict on S40).
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
    CLEAR: et_lines, ev_ok, ev_message.

    CASE iv_object_type.
      WHEN 'FUNC'.
        read_func_version(
          EXPORTING iv_object_name = iv_object_name iv_version_no = iv_version_no
          IMPORTING et_lines = et_lines ev_ok = ev_ok ).
        IF ev_ok = abap_false.
          ev_message = |SVRS_GET_VERSION_FUNC failed for { iv_object_name } vers { iv_version_no }|.
        ENDIF.

      WHEN 'CLAS'.
        read_clas_version(
          EXPORTING iv_object_name = iv_object_name iv_version_no = iv_version_no
          IMPORTING et_lines = et_lines ev_ok = ev_ok ev_message = ev_message ).

      WHEN 'INTF'.
        read_intf_version(
          EXPORTING iv_object_name = iv_object_name iv_version_no = iv_version_no
          IMPORTING et_lines = et_lines ev_ok = ev_ok ev_message = ev_message ).

      WHEN OTHERS.
        " PROG / FUGR / ...
        read_reps_generic(
          EXPORTING
            iv_vrs_type    = iv_vrs_type
            iv_object_name = iv_object_name
            iv_version_no  = iv_version_no
          IMPORTING et_lines = et_lines ev_ok = ev_ok ).
        IF ev_ok = abap_false.
          ev_message = |SVRS_GET_REPS_FROM_OBJECT failed type={ iv_vrs_type } vers={ iv_version_no }|.
        ENDIF.
    ENDCASE.
  ENDMETHOD.

  METHOD read_clas_version.
    DATA lv_cls   TYPE seoclsname.
    DATA lv_cs    TYPE programm.
    DATA lt_cs    TYPE ty_string_tab.
    DATA lv_ok    TYPE abap_bool.
    DATA lt_incl  TYPE tt_incl.
    DATA ls_incl  TYPE ty_incl.
    DATA lv_any   TYPE abap_bool.

    CLEAR: et_lines, ev_ok, ev_message.
    lv_cls = CONV seoclsname( iv_object_name ).

    " 1) Source-based include =====CS — khớp Active (CL_OO_FACTORY)
    TRY.
        lv_cs = cl_oo_classname_service=>get_cs_name( lv_cls ).
      CATCH cx_root.
        CLEAR lv_cs.
    ENDTRY.
    IF lv_cs IS NOT INITIAL.
      append_include_source(
        EXPORTING iv_include = lv_cs iv_kind = 'CS' iv_version_no = iv_version_no
        CHANGING  ct_lines = lt_cs cv_any_ok = lv_ok ).
      IF lv_ok = abap_true AND lines( lt_cs ) > 5.
        et_lines = lt_cs.
        ev_ok = abap_true.
        ev_message = |CLAS via CS ({ lines( et_lines ) } lines)|.
        RETURN.
      ENDIF.
    ENDIF.

    " 2) Ghép form-based: CU/CO/CI + locals + methods + test
    CLEAR: et_lines, lv_any.
    lt_incl = collect_clas_form_includes( lv_cls ).
    LOOP AT lt_incl INTO ls_incl.
      append_include_source(
        EXPORTING
          iv_include    = ls_incl-name
          iv_kind       = ls_incl-kind
          iv_version_no = iv_version_no
        CHANGING
          ct_lines  = et_lines
          cv_any_ok = lv_any ).
    ENDLOOP.
    IF lv_any = abap_true AND et_lines IS NOT INITIAL.
      ev_ok = abap_true.
      ev_message = |CLAS assembled { lines( lt_incl ) } includes, { lines( et_lines ) } lines|.
      RETURN.
    ENDIF.

    " 3) Fallback: object type CLAS / class pool CP
    CLEAR et_lines.
    read_reps_generic(
      EXPORTING iv_vrs_type = 'CLAS' iv_object_name = iv_object_name iv_version_no = iv_version_no
      IMPORTING et_lines = et_lines ev_ok = ev_ok ).
    IF ev_ok = abap_true.
      ev_message = |CLAS via SVRS type CLAS|.
      RETURN.
    ENDIF.

    TRY.
        DATA(lv_pool) = cl_oo_classname_service=>get_classpool_name( lv_cls ).
      CATCH cx_root.
        lv_pool = |{ iv_object_name WIDTH = 30 PAD = '=' }CP|.
    ENDTRY.
    CLEAR et_lines.
    read_reps_generic(
      EXPORTING
        iv_vrs_type    = 'REPS'
        iv_object_name = CONV sobj_name( lv_pool )
        iv_version_no  = iv_version_no
      IMPORTING et_lines = et_lines ev_ok = ev_ok ).
    IF ev_ok = abap_true.
      ev_message = |CLAS via CP only (incomplete)|.
    ELSE.
      ev_message = |CLAS version { iv_version_no }: no CS/sections/methods/CP|.
    ENDIF.
  ENDMETHOD.

  METHOD collect_clas_form_includes.
    DATA lv_name TYPE programm.
    DATA lt_meth TYPE seop_methods_w_include.
    DATA ls_meth LIKE LINE OF lt_meth.

    CLEAR rt_incl.

    " Sections
    TRY.
        lv_name = cl_oo_classname_service=>get_pubsec_name( iv_clsname ).
        add_unique_incl( EXPORTING iv_name = lv_name iv_kind = 'CU' CHANGING ct_incl = rt_incl ).
      CATCH cx_root.
        CLEAR lv_name.
    ENDTRY.
    TRY.
        lv_name = cl_oo_classname_service=>get_prosec_name( iv_clsname ).
        add_unique_incl( EXPORTING iv_name = lv_name iv_kind = 'CO' CHANGING ct_incl = rt_incl ).
      CATCH cx_root.
        CLEAR lv_name.
    ENDTRY.
    TRY.
        lv_name = cl_oo_classname_service=>get_prisec_name( iv_clsname ).
        add_unique_incl( EXPORTING iv_name = lv_name iv_kind = 'CI' CHANGING ct_incl = rt_incl ).
      CATCH cx_root.
        CLEAR lv_name.
    ENDTRY.

    " Local definitions / macros / implementations / tests
    TRY.
        lv_name = cl_oo_classname_service=>get_ccdef_name( iv_clsname ).
        add_unique_incl( EXPORTING iv_name = lv_name iv_kind = 'CCDEF' CHANGING ct_incl = rt_incl ).
      CATCH cx_root.
        CLEAR lv_name.
    ENDTRY.
    TRY.
        lv_name = cl_oo_classname_service=>get_ccmac_name( iv_clsname ).
        add_unique_incl( EXPORTING iv_name = lv_name iv_kind = 'CCMAC' CHANGING ct_incl = rt_incl ).
      CATCH cx_root.
        CLEAR lv_name.
    ENDTRY.

    " Methods (sorted by method name)
    TRY.
        lt_meth = cl_oo_classname_service=>get_all_method_includes( clsname = iv_clsname ).
        SORT lt_meth BY cpdkey-cpdname.
        LOOP AT lt_meth INTO ls_meth.
          add_unique_incl(
            EXPORTING iv_name = ls_meth-incname iv_kind = 'CM'
            CHANGING  ct_incl = rt_incl ).
        ENDLOOP.
      CATCH cx_root.
        CLEAR lt_meth.
    ENDTRY.

    TRY.
        lv_name = cl_oo_classname_service=>get_ccimp_name( iv_clsname ).
        add_unique_incl( EXPORTING iv_name = lv_name iv_kind = 'CCIMP' CHANGING ct_incl = rt_incl ).
      CATCH cx_root.
        CLEAR lv_name.
    ENDTRY.
    TRY.
        lv_name = cl_oo_classname_service=>get_ccau_name( iv_clsname ).
        add_unique_incl( EXPORTING iv_name = lv_name iv_kind = 'CCAU' CHANGING ct_incl = rt_incl ).
      CATCH cx_root.
        CLEAR lv_name.
    ENDTRY.
    " Không thêm CP — chỉ INCLUDE list, trùng nội dung
  ENDMETHOD.

  METHOD add_unique_incl.
    DATA ls TYPE ty_incl.
    CHECK iv_name IS NOT INITIAL.
    READ TABLE ct_incl WITH KEY name = iv_name TRANSPORTING NO FIELDS.
    IF sy-subrc = 0.
      RETURN.
    ENDIF.
    ls-name = iv_name.
    ls-kind = iv_kind.
    APPEND ls TO ct_incl.
  ENDMETHOD.

  METHOD append_include_source.
    DATA lv_vers  TYPE versno.
    DATA lt_part  TYPE ty_string_tab.
    DATA lv_ok    TYPE abap_bool.
    DATA lv_hdr   TYPE string.
    DATA lv_line  TYPE string.

    lv_vers = resolve_include_versno(
                iv_include    = iv_include
                iv_version_no = iv_version_no ).
    IF lv_vers IS INITIAL.
      RETURN.
    ENDIF.

    read_reps_generic(
      EXPORTING
        iv_vrs_type    = 'REPS'
        iv_object_name = CONV sobj_name( iv_include )
        iv_version_no  = lv_vers
      IMPORTING et_lines = lt_part ev_ok = lv_ok ).

    IF lv_ok = abap_false OR lt_part IS INITIAL.
      RETURN.
    ENDIF.

    cv_any_ok = abap_true.
    lv_hdr = |*"*--- [{ iv_kind }] { iv_include } vers { lv_vers } ---*|.
    APPEND lv_hdr TO ct_lines.
    LOOP AT lt_part INTO lv_line.
      APPEND lv_line TO ct_lines.
    ENDLOOP.
    APPEND '' TO ct_lines.
  ENDMETHOD.

  METHOD resolve_include_versno.
    DATA lv_name TYPE vrsd-objname.
    DATA lv_max  TYPE versno.

    CLEAR rv_vers.
    lv_name = CONV vrsd-objname( iv_include ).

    SELECT SINGLE versno
      FROM vrsd
      WHERE objtype = 'REPS'
        AND objname = @lv_name
        AND versno  = @iv_version_no
      INTO @rv_vers.
    IF sy-subrc = 0.
      RETURN.
    ENDIF.

    " Fallback: version gần nhất ≤ requested (include có thể lệch versno)
    SELECT MAX( versno )
      FROM vrsd
      WHERE objtype = 'REPS'
        AND objname = @lv_name
        AND versno  <= @iv_version_no
      INTO @lv_max.
    IF lv_max IS NOT INITIAL.
      rv_vers = lv_max.
    ENDIF.
  ENDMETHOD.

  METHOD read_intf_version.
    DATA lv_intf TYPE seoclsname.
    DATA lv_pool TYPE programm.
    DATA lv_sec  TYPE programm.
    DATA lv_any  TYPE abap_bool.

    CLEAR: et_lines, ev_ok, ev_message.
    lv_intf = CONV seoclsname( iv_object_name ).

    read_reps_generic(
      EXPORTING iv_vrs_type = 'INTF' iv_object_name = iv_object_name iv_version_no = iv_version_no
      IMPORTING et_lines = et_lines ev_ok = ev_ok ).
    IF ev_ok = abap_true.
      ev_message = |INTF via SVRS type INTF|.
      RETURN.
    ENDIF.

    TRY.
        lv_sec = cl_oo_classname_service=>get_intfsec_name( lv_intf ).
      CATCH cx_root.
        CLEAR lv_sec.
    ENDTRY.
    IF lv_sec IS NOT INITIAL.
      append_include_source(
        EXPORTING iv_include = lv_sec iv_kind = 'INTFSEC' iv_version_no = iv_version_no
        CHANGING  ct_lines = et_lines cv_any_ok = lv_any ).
    ENDIF.

    TRY.
        lv_pool = cl_oo_classname_service=>get_interfacepool_name( lv_intf ).
      CATCH cx_root.
        lv_pool = |{ iv_object_name WIDTH = 30 PAD = '=' }IP|.
    ENDTRY.
    IF lv_any = abap_false.
      append_include_source(
        EXPORTING iv_include = lv_pool iv_kind = 'IP' iv_version_no = iv_version_no
        CHANGING  ct_lines = et_lines cv_any_ok = lv_any ).
    ENDIF.

    IF lv_any = abap_true AND et_lines IS NOT INITIAL.
      ev_ok = abap_true.
      ev_message = |INTF assembled|.
    ELSE.
      ev_message = |INTF version { iv_version_no } unreadable|.
    ENDIF.
  ENDMETHOD.

  METHOD read_reps_generic.
    DATA lv_name  TYPE vrsd-objname.
    DATA lt_repos TYPE STANDARD TABLE OF abaptxt255 WITH DEFAULT KEY.
    DATA lt_trdir TYPE STANDARD TABLE OF trdir WITH DEFAULT KEY.
    DATA lt_modi  TYPE STANDARD TABLE OF smodisrc WITH DEFAULT KEY.
    DATA lt_log   TYPE STANDARD TABLE OF smodilog WITH DEFAULT KEY.

    CLEAR: et_lines, ev_ok.
    lv_name = CONV vrsd-objname( iv_object_name ).

    " Bọc TRY — trên S40 TABLES type lệch → CX_SY_DYN_CALL_ILLEGAL_TYPE (VER_VS_VER).
    TRY.
        CALL FUNCTION 'SVRS_GET_REPS_FROM_OBJECT'
          EXPORTING
            object_name = lv_name
            object_type = iv_vrs_type
            versno      = iv_version_no
          TABLES
            repos_tab   = lt_repos
            trdir_tab   = lt_trdir
            vsmodisrc   = lt_modi
            vsmodilog   = lt_log
          EXCEPTIONS
            no_version  = 1
            OTHERS      = 2.

        IF sy-subrc = 0 AND lt_repos IS NOT INITIAL.
          append_text_table( EXPORTING it_any = lt_repos CHANGING ct_lines = et_lines ).
          IF et_lines IS NOT INITIAL.
            ev_ok = abap_true.
            RETURN.
          ENDIF.
        ENDIF.
      CATCH cx_sy_dyn_call_illegal_type cx_sy_dyn_call_param_not_found cx_root.
        CLEAR et_lines.
    ENDTRY.

    IF iv_vrs_type = 'REPS'.
      DATA lt_abap TYPE STANDARD TABLE OF abaptext WITH DEFAULT KEY.
      DATA lt_tdir TYPE STANDARD TABLE OF trdir WITH DEFAULT KEY.
      TRY.
          CALL FUNCTION 'SVRS_GET_VERSION_REPS'
            EXPORTING
              object_name = lv_name
              versno      = iv_version_no
            TABLES
              repos_tab   = lt_abap
              trdir_tab   = lt_tdir
            EXCEPTIONS
              no_version  = 1
              OTHERS      = 2.
          IF sy-subrc = 0 AND lt_abap IS NOT INITIAL.
            append_text_table( EXPORTING it_any = lt_abap CHANGING ct_lines = et_lines ).
            IF et_lines IS NOT INITIAL.
              ev_ok = abap_true.
            ENDIF.
          ENDIF.
        CATCH cx_sy_dyn_call_illegal_type cx_sy_dyn_call_param_not_found cx_root.
          CLEAR et_lines.
      ENDTRY.
    ENDIF.
  ENDMETHOD.

  METHOD read_func_version.
    " TABLES của SVRS_GET_VERSION_FUNC trên nhiều hệ dùng *_OLD
    DATA lv_name  TYPE vrsd-objname.
    DATA lt_tfdir TYPE STANDARD TABLE OF tfdir_old WITH DEFAULT KEY.
    DATA lt_tftit TYPE STANDARD TABLE OF tftit WITH DEFAULT KEY.
    DATA lt_funct TYPE STANDARD TABLE OF funct WITH DEFAULT KEY.
    DATA lt_enlfd TYPE STANDARD TABLE OF enlfd_old WITH DEFAULT KEY.
    DATA lt_trdir TYPE STANDARD TABLE OF trdir WITH DEFAULT KEY.
    DATA lt_uincl TYPE STANDARD TABLE OF abaptext WITH DEFAULT KEY.
    DATA lt_dincl TYPE STANDARD TABLE OF abaptext WITH DEFAULT KEY.

    CLEAR: et_lines, ev_ok.
    lv_name = CONV vrsd-objname( iv_object_name ).

    CALL FUNCTION 'SVRS_GET_VERSION_FUNC'
      EXPORTING
        object_name = lv_name
        versno      = iv_version_no
      TABLES
        tfdir_tab   = lt_tfdir
        tftit_tab   = lt_tftit
        funct_tab   = lt_funct
        enlfd_tab   = lt_enlfd
        trdir_tab   = lt_trdir
        uincl_tab   = lt_uincl
        dincl_tab   = lt_dincl
      EXCEPTIONS
        no_version  = 1
        OTHERS      = 2.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    append_text_table( EXPORTING it_any = lt_uincl CHANGING ct_lines = et_lines ).
    IF et_lines IS INITIAL.
      append_text_table( EXPORTING it_any = lt_dincl CHANGING ct_lines = et_lines ).
    ENDIF.
    IF et_lines IS NOT INITIAL.
      ev_ok = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD append_text_table.
    DATA lv_line TYPE string.
    FIELD-SYMBOLS <ls> TYPE any.
    FIELD-SYMBOLS <lv> TYPE any.

    LOOP AT it_any ASSIGNING <ls>.
      CLEAR lv_line.
      ASSIGN COMPONENT 'LINE' OF STRUCTURE <ls> TO <lv>.
      IF sy-subrc = 0.
        lv_line = CONV string( <lv> ).
      ELSE.
        lv_line = CONV string( <ls> ).
      ENDIF.
      APPEND lv_line TO ct_lines.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
