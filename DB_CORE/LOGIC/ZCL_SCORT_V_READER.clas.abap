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
      IMPORTING
        iv_object_type     TYPE csequence
        iv_object_name     TYPE csequence OPTIONAL
      RETURNING
        VALUE(rv_vrs_type) TYPE vrsd-objtype.

    CLASS-METHODS list_versions
      IMPORTING
        iv_object_type TYPE csequence
        iv_object_name TYPE csequence
        iv_component   TYPE csequence OPTIONAL
      RETURNING
        VALUE(rt_list) TYPE tt_version.

    CLASS-METHODS read_version
      IMPORTING
        iv_object_type TYPE csequence
        iv_object_name TYPE csequence
        iv_version_no  TYPE versno
        iv_component   TYPE csequence OPTIONAL
      RETURNING
        VALUE(rs_source) TYPE ty_source.

    CLASS-METHODS display_versions
      IMPORTING
        iv_object_type TYPE csequence
        iv_object_name TYPE csequence.

    CLASS-METHODS read_clas_components_version
      IMPORTING
        iv_classname  TYPE csequence
        iv_version_no TYPE versno
      EXPORTING
        ev_json       TYPE string
        ev_ok         TYPE abap_bool.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_incl,
        name TYPE programm,
        kind TYPE c LENGTH 10,
      END OF ty_incl,
      tt_incl TYPE STANDARD TABLE OF ty_incl WITH DEFAULT KEY,
      tt_vrsd TYPE STANDARD TABLE OF vrsd WITH DEFAULT KEY,
      BEGIN OF ty_tr_hist,
        trkorr  TYPE e070-trkorr,
        as4user TYPE e070-as4user,
        as4date TYPE e070-as4date,
        as4time TYPE e070-as4time,
      END OF ty_tr_hist,
      tt_tr_hist TYPE STANDARD TABLE OF ty_tr_hist WITH DEFAULT KEY.

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
      IMPORTING
        iv_object_name TYPE csequence
        iv_component   TYPE csequence OPTIONAL
      RETURNING
        VALUE(rt_vrsd) TYPE tt_vrsd.

    CLASS-METHODS read_version_directory
      IMPORTING
        iv_vrs_type    TYPE vrsd-objtype
        iv_object_name TYPE csequence
      RETURNING
        VALUE(rt_vrsd) TYPE tt_vrsd.

    CLASS-METHODS extract_text_from_any
      IMPORTING is_any   TYPE any
      CHANGING  ct_lines TYPE ty_string_tab.

    CLASS-METHODS reconstruct_clas_source
      IMPORTING
        is_object       TYPE svrs2_versionable_object
        iv_classname    TYPE csequence
      RETURNING
        VALUE(rt_lines) TYPE ty_string_tab.

ENDCLASS.


CLASS zcl_scort_v_reader IMPLEMENTATION.

  METHOD map_vrs_objtype.
    CASE iv_object_type.
      WHEN 'PROG'.
        rv_vrs_type = 'REPS'.
      WHEN 'CLAS'.
        IF iv_object_name IS NOT INITIAL AND iv_object_name CS '='.
          rv_vrs_type = 'REPS'.
        ELSE.
          rv_vrs_type = 'CLAS'.
        ENDIF.
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
    lv_vrs_type = map_vrs_objtype(
                    iv_object_type = iv_object_type
                    iv_object_name = iv_object_name ).
    lv_objname  = CONV vrsd-objname( iv_object_name ).

    IF iv_object_type = 'CLAS'.
      lt_vrsd = list_clas_versions( iv_object_name = iv_object_name iv_component = iv_component ).
    ELSE.
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
    ENDIF.

    IF lt_vrsd IS INITIAL AND iv_object_type = 'INTF'.
      TRY.
          lv_objname = cl_oo_classname_service=>get_interfacepool_name( CONV seoclsname( iv_object_name ) ).
        CATCH cx_root.
          lv_objname = |{ iv_object_name WIDTH = 30 PAD = '=' }IP|.
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

    TYPES: BEGIN OF ty_tr_fae,
             trkorr TYPE e07t-trkorr,
           END OF ty_tr_fae.
    DATA lt_tr_fae TYPE STANDARD TABLE OF ty_tr_fae WITH DEFAULT KEY.
    DATA ls_tr_fae TYPE ty_tr_fae.

    TYPES: BEGIN OF ty_e07t_cache,
             trkorr  TYPE e07t-trkorr,
             langu   TYPE e07t-langu,
             as4text TYPE e07t-as4text,
           END OF ty_e07t_cache.
    DATA lt_e07t_db TYPE STANDARD TABLE OF ty_e07t_cache WITH DEFAULT KEY.

    LOOP AT lt_vrsd INTO DATA(ls_v_fae).
      IF ls_v_fae-korrnum IS NOT INITIAL.
        ls_tr_fae-trkorr = CONV #( ls_v_fae-korrnum ).
        COLLECT ls_tr_fae INTO lt_tr_fae.
      ENDIF.
    ENDLOOP.

    IF lt_tr_fae IS NOT INITIAL.
      SELECT trkorr, langu, as4text
        FROM e07t
        FOR ALL ENTRIES IN @lt_tr_fae
        WHERE trkorr = @lt_tr_fae-trkorr
        INTO CORRESPONDING FIELDS OF TABLE @lt_e07t_db.

      SORT lt_e07t_db BY trkorr langu.
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
        DATA(lv_tr_text) = VALUE e07t-as4text( ).
        READ TABLE lt_e07t_db INTO DATA(ls_t1) WITH KEY trkorr = ls_vrsd-korrnum langu = sy-langu BINARY SEARCH.
        IF sy-subrc = 0 AND ls_t1-as4text IS NOT INITIAL.
          lv_tr_text = ls_t1-as4text.
        ELSE.
          READ TABLE lt_e07t_db INTO DATA(ls_t2) WITH KEY trkorr = ls_vrsd-korrnum langu = 'E' BINARY SEARCH.
          IF sy-subrc = 0 AND ls_t2-as4text IS NOT INITIAL.
            lv_tr_text = ls_t2-as4text.
          ELSE.
            READ TABLE lt_e07t_db INTO DATA(ls_t3) WITH KEY trkorr = ls_vrsd-korrnum BINARY SEARCH.
            IF sy-subrc = 0.
              lv_tr_text = ls_t3-as4text.
            ENDIF.
          ENDIF.
        ENDIF.

        IF lv_tr_text IS NOT INITIAL.
          ls_row-message = lv_tr_text.
        ELSE.
          ls_row-message = |{ lv_label } — { ls_vrsd-korrnum }|.
        ENDIF.
      ELSE.
        ls_row-message = lv_label.
      ENDIF.
      APPEND ls_row TO rt_list.
    ENDLOOP.

    SORT rt_list BY version_no DESCENDING.

    CLEAR ls_row.
    ls_row-object_type = iv_object_type.
    ls_row-object_name = iv_object_name.
    ls_row-version_no  = c_vers_active.
    ls_row-author      = sy-uname.
    ls_row-datum       = sy-datum.
    ls_row-uzeit       = sy-uzeit.
    ls_row-is_active   = abap_true.

    DATA lv_clean_cname TYPE trobj_name.
    lv_clean_cname = CONV #( iv_object_name ).
    IF iv_object_type = 'CLAS' AND lv_clean_cname CS '='.
      SPLIT lv_clean_cname AT '=' INTO lv_clean_cname DATA(lv_dummy_c).
    ENDIF.
    CONDENSE lv_clean_cname.

    DATA lv_act_tr     TYPE trkorr.
    DATA lv_act_str    TYPE trkorr.
    DATA lv_act_user   TYPE as4user.
    DATA lv_act_date   TYPE as4date.
    DATA lv_act_time   TYPE as4time.
    DATA lv_act_text   TYPE as4text.

    SELECT h~trkorr, h~strkorr, h~as4user, h~as4date, h~as4time
      FROM e071 AS o
      INNER JOIN e070 AS h ON h~trkorr = o~trkorr
      WHERE ( o~pgmid = 'R3TR' OR o~pgmid = 'LIMU' )
        AND o~object   = @iv_object_type
        AND ( o~obj_name = @iv_object_name OR o~obj_name = @lv_clean_cname )
        AND ( h~trstatus = 'D' OR h~trstatus = 'L' )
      ORDER BY h~as4date DESCENDING, h~as4time DESCENDING
      INTO (@lv_act_tr, @lv_act_str, @lv_act_user, @lv_act_date, @lv_act_time)
      UP TO 1 ROWS.
    ENDSELECT.

    IF lv_act_tr IS NOT INITIAL.
      DATA(lv_target_tr) = COND trkorr( WHEN lv_act_str IS NOT INITIAL THEN lv_act_str ELSE lv_act_tr ).
      ls_row-korrnum = lv_target_tr.
      ls_row-author  = lv_act_user.
      ls_row-datum   = lv_act_date.
      ls_row-uzeit   = lv_act_time.

      SELECT SINGLE as4text FROM e07t
        WHERE trkorr = @lv_target_tr
          AND ( langu = @sy-langu OR langu = 'E' )
        INTO @lv_act_text.
      IF lv_act_text IS NOT INITIAL.
        ls_row-message = lv_act_text.
      ENDIF.
    ENDIF.

    IF ls_row-message IS INITIAL.
      IF iv_object_type = 'CLAS'.
        DATA lv_c_json TYPE string.
        DATA lv_c_ok   TYPE abap_bool.
        DATA lv_tgt_comp TYPE string.
        lv_tgt_comp = to_upper( iv_component ).
        IF lv_tgt_comp IS INITIAL.
          lv_tgt_comp = 'CP'.
        ENDIF.
        zcl_scort_l_reader=>read_clas_components(
          EXPORTING iv_classname = iv_object_name
          IMPORTING ev_json      = lv_c_json
                    ev_ok        = lv_c_ok ).
        IF lv_c_ok = abap_true AND lv_c_json CS |"id":"{ lv_tgt_comp }"|.
          ls_row-message = |Active ({ lv_tgt_comp })|.
        ELSE.
          ls_row-message = |Active ({ lv_tgt_comp } empty)|.
        ENDIF.
      ELSE.
        ls_active = zcl_scort_l_reader=>read_active(
                      iv_object_type = iv_object_type
                      iv_object_name = iv_object_name ).
        IF ls_active-found = abap_true.
          ls_row-message = |Active ({ ls_active-line_count } lines)|.
        ELSE.
          ls_row-message = 'Active missing'.
        ENDIF.
      ENDIF.
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
    DATA ls_keep        TYPE vrsd.
    DATA lt_raw         TYPE tt_vrsd.
    DATA lv_clean_cname TYPE seoclsname.
    DATA lv_cp_name     TYPE sobj_name.
    DATA lv_pattern_eq  TYPE vrsd-objname.
    DATA lv_pattern_sp  TYPE vrsd-objname.
    DATA lt_seen        TYPE SORTED TABLE OF versno WITH UNIQUE KEY table_line.

    DATA lt_tr_hist TYPE tt_tr_hist.
    DATA lv_syn_v   TYPE i.

    CLEAR rt_vrsd.
    lv_clean_cname = to_upper( iv_object_name ).
    IF lv_clean_cname CS '='.
      SPLIT lv_clean_cname AT '=' INTO lv_clean_cname DATA(lv_dummy_cl).
    ENDIF.
    CONDENSE lv_clean_cname.

    lv_pattern_eq = |{ lv_clean_cname }=%|.
    lv_pattern_sp = |{ lv_clean_cname } %|.

    SELECT objtype, objname, versno, author, datum, zeit, korrnum
      FROM vrsd
      WHERE objname = @lv_clean_cname
         OR objname LIKE @lv_pattern_eq
         OR objname LIKE @lv_pattern_sp
      INTO CORRESPONDING FIELDS OF TABLE @lt_raw.

    DELETE lt_raw WHERE versno IS INITIAL OR versno = '00000'.

    IF lt_raw IS INITIAL.
      lt_raw = read_version_directory(
                 iv_vrs_type    = 'CLAS'
                 iv_object_name = lv_clean_cname ).
      DELETE lt_raw WHERE versno IS INITIAL OR versno = '00000'.
      IF lt_raw IS INITIAL.
        TRY.
            lv_cp_name = cl_oo_classname_service=>get_classpool_name( lv_clean_cname ).
          CATCH cx_root.
            lv_cp_name = |{ lv_clean_cname WIDTH = 30 PAD = '=' }CP|.
        ENDTRY.
        lt_raw = read_version_directory(
                   iv_vrs_type    = 'REPS'
                   iv_object_name = lv_cp_name ).
        DELETE lt_raw WHERE versno IS INITIAL OR versno = '00000'.
      ENDIF.
    ENDIF.

    IF lt_raw IS INITIAL.
      SELECT DISTINCT h~trkorr, h~as4user, h~as4date, h~as4time
        FROM e071 AS o
        INNER JOIN e070 AS h ON h~trkorr = o~trkorr
        WHERE ( o~pgmid = 'R3TR' OR o~pgmid = 'LIMU' )
          AND ( o~obj_name = @lv_clean_cname OR o~obj_name LIKE @lv_pattern_eq OR o~obj_name LIKE @lv_pattern_sp )
          AND h~trstatus = 'R'
        INTO CORRESPONDING FIELDS OF TABLE @lt_tr_hist.

      SORT lt_tr_hist BY as4date DESCENDING as4time DESCENDING.

      lv_syn_v = lines( lt_tr_hist ).
      LOOP AT lt_tr_hist INTO DATA(ls_trh).
        APPEND VALUE #(
          objtype = 'CLAS'
          objname = lv_clean_cname
          versno  = |{ lv_syn_v WIDTH = 5 PAD = '0' ALIGN = RIGHT }|
          author  = ls_trh-as4user
          datum   = ls_trh-as4date
          zeit    = ls_trh-as4time
          korrnum = ls_trh-trkorr
        ) TO lt_raw.
        lv_syn_v = lv_syn_v - 1.
      ENDLOOP.
    ENDIF.

    SORT lt_raw BY versno DESCENDING korrnum DESCENDING datum DESCENDING zeit DESCENDING.
    LOOP AT lt_raw INTO ls_keep.
      IF ls_keep-versno IS INITIAL OR ls_keep-versno = '00000'.
        CONTINUE.
      ENDIF.
      INSERT ls_keep-versno INTO TABLE lt_seen.
      IF sy-subrc = 0.
        APPEND ls_keep TO rt_vrsd.
      ENDIF.
    ENDLOOP.

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

    DATA lv_actual_name TYPE sobj_name.
    DATA lv_cname       TYPE seoclsname.
    DATA lv_comp        TYPE string.
    DATA lv_pat_vrs     TYPE vrsd-objname.
    DATA lt_vrsd_hits   TYPE STANDARD TABLE OF vrsd WITH DEFAULT KEY.
    DATA ls_vrsd_chosen TYPE vrsd.
    DATA lv_dummy_split TYPE string.
    DATA lv_nlen        TYPE i.

    lv_actual_name = CONV #( iv_object_name ).

    IF iv_object_type = 'CLAS'.
      lv_cname = to_upper( iv_object_name ).
      IF lv_cname CS '='.
        SPLIT lv_cname AT '=' INTO lv_cname lv_dummy_split.
      ENDIF.
      CONDENSE lv_cname.

      lv_comp = to_upper( iv_component ).
      IF lv_comp IS INITIAL AND iv_object_name CS '='.
        lv_nlen = strlen( iv_object_name ).
        IF lv_nlen >= 5 AND substring( val = iv_object_name off = lv_nlen - 5 len = 5 ) = 'CCDEF'.
          lv_comp = 'CCDEF'.
        ELSEIF lv_nlen >= 5 AND substring( val = iv_object_name off = lv_nlen - 5 len = 5 ) = 'CCIMP'.
          lv_comp = 'CCIMP'.
        ELSEIF lv_nlen >= 5 AND substring( val = iv_object_name off = lv_nlen - 5 len = 5 ) = 'CCMAC'.
          lv_comp = 'CCMAC'.
        ELSEIF lv_nlen >= 4 AND substring( val = iv_object_name off = lv_nlen - 4 len = 4 ) = 'CCAU'.
          lv_comp = 'CCAU'.
        ELSE.
          lv_comp = 'CP'.
        ENDIF.
      ELSEIF lv_comp IS INITIAL.
        lv_comp = 'CP'.
      ENDIF.

      TRY.
          CASE lv_comp.
            WHEN 'CP'.
              lv_actual_name = lv_cname.
            WHEN 'CCDEF'.
              lv_actual_name = cl_oo_classname_service=>get_ccdef_name( lv_cname ).
            WHEN 'CCIMP'.
              lv_actual_name = cl_oo_classname_service=>get_ccimp_name( lv_cname ).
            WHEN 'CCAU'.
              lv_actual_name = cl_oo_classname_service=>get_ccau_name( lv_cname ).
            WHEN 'CCMAC'.
              lv_actual_name = cl_oo_classname_service=>get_ccmac_name( lv_cname ).
            WHEN OTHERS.
              lv_actual_name = |{ lv_cname WIDTH = 30 PAD = '=' }{ lv_comp }|.
          ENDCASE.
        CATCH cx_root.
          IF lv_comp = 'CP'.
            lv_actual_name = lv_cname.
          ELSE.
            lv_actual_name = |{ lv_cname WIDTH = 30 PAD = '=' }{ lv_comp }|.
          ENDIF.
      ENDTRY.

      DATA lv_pat_eq TYPE vrsd-objname.
      DATA lv_pat_sp TYPE vrsd-objname.
      lv_pat_eq = |{ lv_cname }=%|.
      lv_pat_sp = |{ lv_cname } %|.

      DATA lv_vers_pad TYPE versno.
      lv_vers_pad = iv_version_no.
      CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
        EXPORTING
          input  = iv_version_no
        IMPORTING
          output = lv_vers_pad.

      SELECT objtype, objname, versno, author, datum, zeit, korrnum
        FROM vrsd
        WHERE ( versno = @iv_version_no OR versno = @lv_vers_pad )
          AND ( objname = @lv_actual_name
             OR objname = @iv_object_name
             OR objname = @lv_cname
             OR objname LIKE @lv_pat_eq
             OR objname LIKE @lv_pat_sp )
        INTO CORRESPONDING FIELDS OF TABLE @lt_vrsd_hits.

      IF lt_vrsd_hits IS INITIAL.
        DATA lt_fb_tr TYPE tt_tr_hist.
        SELECT DISTINCT h~trkorr, h~as4user, h~as4date, h~as4time
          FROM e071 AS o
          INNER JOIN e070 AS h ON h~trkorr = o~trkorr
          WHERE ( o~pgmid = 'R3TR' OR o~pgmid = 'LIMU' )
            AND ( o~obj_name = @lv_cname OR o~obj_name LIKE @lv_pat_eq OR o~obj_name LIKE @lv_pat_sp )
            AND h~trstatus = 'R'
          INTO CORRESPONDING FIELDS OF TABLE @lt_fb_tr.

        SORT lt_fb_tr BY as4date ASCENDING as4time ASCENDING.
        DATA lv_idx_fb TYPE i.
        DATA ls_chosen_tr TYPE ty_tr_hist.
        lv_idx_fb = CONV i( lv_vers_pad ).
        IF lv_idx_fb > 0 AND lv_idx_fb <= lines( lt_fb_tr ).
          ls_chosen_tr = lt_fb_tr[ lv_idx_fb ].
          SELECT objtype, objname, versno, author, datum, zeit, korrnum
            FROM vrsd
            WHERE korrnum = @ls_chosen_tr-trkorr
              AND ( objname = @lv_actual_name
                 OR objname = @iv_object_name
                 OR objname = @lv_cname
                 OR objname LIKE @lv_pat_eq
                 OR objname LIKE @lv_pat_sp )
            INTO CORRESPONDING FIELDS OF TABLE @lt_vrsd_hits.
        ENDIF.
      ENDIF.

      IF ls_chosen_tr-trkorr IS NOT INITIAL AND lt_vrsd_hits IS INITIAL.
        rs_source-found   = abap_false.
        rs_source-message = |Version { iv_version_no } (TR { ls_chosen_tr-trkorr }): No snapshot archived in VRSD.|.
        RETURN.
      ENDIF.

      IF lt_vrsd_hits IS NOT INITIAL.
        LOOP AT lt_vrsd_hits INTO DATA(ls_hit).
          CASE lv_comp.
            WHEN 'CP'.
              IF ls_hit-objtype = 'CLAS'.
                ls_vrsd_chosen = ls_hit.
                EXIT.
              ENDIF.
            WHEN 'CCDEF'.
              IF ls_hit-objname CS 'CCDEF'.
                ls_vrsd_chosen = ls_hit.
                EXIT.
              ENDIF.
            WHEN 'CCIMP'.
              IF ls_hit-objname CS 'CCIMP'.
                ls_vrsd_chosen = ls_hit.
                EXIT.
              ENDIF.
            WHEN 'CCAU'.
              IF ls_hit-objname CS 'CCAU'.
                ls_vrsd_chosen = ls_hit.
                EXIT.
              ENDIF.
            WHEN 'CCMAC'.
              IF ls_hit-objname CS 'CCMAC'.
                ls_vrsd_chosen = ls_hit.
                EXIT.
              ENDIF.
          ENDCASE.
        ENDLOOP.

        IF ls_vrsd_chosen-objtype IS INITIAL.
          LOOP AT lt_vrsd_hits INTO ls_hit.
            IF lv_comp = 'CP' AND ls_hit-objtype = 'CLAS'.
              ls_vrsd_chosen = ls_hit.
              EXIT.
            ELSEIF lv_comp <> 'CP' AND ls_hit-objname CS lv_comp.
              ls_vrsd_chosen = ls_hit.
              EXIT.
            ENDIF.
          ENDLOOP.
        ENDIF.

        IF ls_vrsd_chosen-objtype IS INITIAL.
          IF lv_comp = 'CP'.
            ls_vrsd_chosen-objtype = 'CLAS'.
            ls_vrsd_chosen-objname = lv_cname.
            ls_vrsd_chosen-versno  = lt_vrsd_hits[ 1 ]-versno.
          ELSE.
            ls_vrsd_chosen = lt_vrsd_hits[ 1 ].
          ENDIF.
        ENDIF.

        lv_vrs_type    = ls_vrsd_chosen-objtype.
        lv_actual_name = ls_vrsd_chosen-objname.
      ELSE.
        IF lv_comp = 'CP'.
          lv_vrs_type    = 'CLAS'.
          lv_actual_name = lv_cname.
        ELSE.
          lv_vrs_type = 'REPS'.
        ENDIF.
      ENDIF.
    ELSE.
      lv_vrs_type = map_vrs_objtype(
                      iv_object_type = iv_object_type
                      iv_object_name = lv_actual_name ).
    ENDIF.

    DATA lv_final_versno TYPE versno.
    lv_final_versno = iv_version_no.
    IF ls_vrsd_chosen-versno IS NOT INITIAL.
      lv_final_versno = ls_vrsd_chosen-versno.
    ENDIF.

    read_version_content(
      EXPORTING
        iv_object_type = iv_object_type
        iv_vrs_type    = lv_vrs_type
        iv_object_name = lv_actual_name
        iv_version_no  = lv_final_versno
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

    IF iv_object_type = 'DDLS' OR iv_object_type = 'DDLX' OR iv_object_type = 'BDEF' OR iv_object_type = 'DCLS'.
      DATA lv_internal_found TYPE abap_bool.
      DATA lt_clean_lines    TYPE ty_string_tab.
      DATA lv_curr_line      TYPE string.
      lv_internal_found = abap_false.
      CLEAR lt_clean_lines.
      LOOP AT lt_lines INTO lv_curr_line.
        IF lv_curr_line CS '/*+[internal]'.
          lv_internal_found = abap_true.
          EXIT.
        ENDIF.
        APPEND lv_curr_line TO lt_clean_lines.
      ENDLOOP.
      IF lv_internal_found = abap_true.
        lt_lines = lt_clean_lines.
      ENDIF.
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

    IF sy-subrc <> 0 AND ls_object-objtype = 'REPS' AND ls_object-objname CS '='.
      ls_object-objtype = 'CINC'.
      CALL FUNCTION 'SVRS_GET_VERSION'
        CHANGING
          object = ls_object
        EXCEPTIONS
          no_version         = 1
          version_unreadable = 2
          OTHERS             = 3.
    ENDIF.

    IF sy-subrc <> 0 AND iv_object_type = 'CLAS'.
      ls_object-objtype = 'CLAS'.
      ls_object-objname = CONV #( iv_object_name ).
      IF ls_object-objname CS '='.
        SPLIT ls_object-objname AT '=' INTO ls_object-objname DATA(lv_dummy_cls).
        CONDENSE ls_object-objname.
      ENDIF.
      CALL FUNCTION 'SVRS_GET_VERSION'
        CHANGING
          object = ls_object
        EXCEPTIONS
          no_version         = 1
          version_unreadable = 2
          OTHERS             = 3.
    ENDIF.

    IF sy-subrc <> 0.
      ev_ok = abap_false.
      ev_message = |SVRS_GET_VERSION failed for { iv_object_name } vers { iv_version_no } (Subrc: { sy-subrc })|.
      RETURN.
    ENDIF.

    ev_ok = abap_true.

    CASE iv_vrs_type.
      WHEN 'CLAS'.
        et_lines = reconstruct_clas_source( is_object = ls_object iv_classname = iv_object_name ).
        IF et_lines IS INITIAL.
          ASSIGN COMPONENT 'REPS' OF STRUCTURE ls_object TO <ls_sub>.
          IF sy-subrc = 0 AND <ls_sub> IS ASSIGNED.
            extract_text_from_any( EXPORTING is_any = <ls_sub> CHANGING ct_lines = et_lines ).
          ENDIF.
        ENDIF.
        IF et_lines IS INITIAL.
          ASSIGN COMPONENT 'CPUB' OF STRUCTURE ls_object TO <ls_sub>.
          IF sy-subrc = 0 AND <ls_sub> IS ASSIGNED.
            extract_text_from_any( EXPORTING is_any = <ls_sub> CHANGING ct_lines = et_lines ).
          ENDIF.
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

      WHEN OTHERS.
        ASSIGN COMPONENT 'REPS' OF STRUCTURE ls_object TO <ls_sub>.
        IF sy-subrc = 0 AND <ls_sub> IS ASSIGNED.
          extract_text_from_any( EXPORTING is_any = <ls_sub> CHANGING ct_lines = et_lines ).
        ENDIF.
        IF et_lines IS INITIAL.
          ASSIGN COMPONENT 'CINC' OF STRUCTURE ls_object TO <ls_sub>.
          IF sy-subrc = 0 AND <ls_sub> IS ASSIGNED.
            extract_text_from_any( EXPORTING is_any = <ls_sub> CHANGING ct_lines = et_lines ).
          ENDIF.
        ENDIF.
        ev_message = |{ ls_object-objtype } via SVRS_GET_VERSION ({ lines( et_lines ) } lines)|.
    ENDCASE.

    IF et_lines IS INITIAL.
      DATA lt_cand_comps TYPE STANDARD TABLE OF string WITH DEFAULT KEY.
      APPEND 'REPS' TO lt_cand_comps.
      APPEND 'CINC' TO lt_cand_comps.
      APPEND 'CLAS' TO lt_cand_comps.
      APPEND 'INTF' TO lt_cand_comps.
      APPEND 'FUNC' TO lt_cand_comps.
      APPEND 'CPUB' TO lt_cand_comps.
      APPEND 'CPRO' TO lt_cand_comps.
      APPEND 'CPRI' TO lt_cand_comps.
      APPEND 'CLSD' TO lt_cand_comps.
      APPEND 'METH' TO lt_cand_comps.
      IF ls_object-objtype IS NOT INITIAL.
        APPEND CONV string( ls_object-objtype ) TO lt_cand_comps.
      ENDIF.

      LOOP AT lt_cand_comps INTO DATA(lv_cand).
        ASSIGN COMPONENT lv_cand OF STRUCTURE ls_object TO <ls_sub>.
        IF sy-subrc = 0 AND <ls_sub> IS ASSIGNED.
          extract_text_from_any( EXPORTING is_any = <ls_sub> CHANGING ct_lines = et_lines ).
          IF et_lines IS NOT INITIAL.
            ev_message = |{ lv_cand } via SVRS generic ({ lines( et_lines ) } lines)|.
            EXIT.
          ENDIF.
        ENDIF.
      ENDLOOP.
    ENDIF.

    et_lines = zcl_scort_hash_utl=>normalize_lines( et_lines ).
  ENDMETHOD.

  METHOD extract_text_from_any.
    DATA lo_type        TYPE REF TO cl_abap_typedescr.
    DATA lo_row_descr   TYPE REF TO cl_abap_typedescr.
    DATA lo_comp_descr  TYPE REF TO cl_abap_typedescr.
    DATA lo_struct      TYPE REF TO cl_abap_structdescr.
    DATA lt_comp_names  TYPE STANDARD TABLE OF string WITH DEFAULT KEY.
    DATA lt_split       TYPE STANDARD TABLE OF string WITH DEFAULT KEY.
    DATA lv_str         TYPE string.
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
                ASSIGN COMPONENT 'ABAPTXT' OF STRUCTURE <ls_row> TO <lv_val>.
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

  METHOD read_clas_components_version.
    TYPES: BEGIN OF ty_clas_comp,
             id          TYPE string,
             title       TYPE string,
             kind        TYPE string,
             include     TYPE string,
             line_count  TYPE i,
             has_content TYPE abap_bool,
             source      TYPE string,
           END OF ty_clas_comp,
           tt_clas_comp TYPE STANDARD TABLE OF ty_clas_comp WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_inc_def,
             id    TYPE string,
             title TYPE string,
             kind  TYPE string,
           END OF ty_inc_def.

    DATA lt_comps    TYPE tt_clas_comp.
    DATA ls_comp     TYPE ty_clas_comp.
    DATA ls_ver      TYPE ty_source.
    DATA lv_cname    TYPE seoclsname.
    DATA lv_inc      TYPE programm.
    DATA lt_inc_defs TYPE STANDARD TABLE OF ty_inc_def WITH DEFAULT KEY.

    CLEAR: ev_json, ev_ok.
    lv_cname = to_upper( iv_classname ).
    IF lv_cname CS '='.
      SPLIT lv_cname AT '=' INTO lv_cname DATA(lv_dummy_split).
    ENDIF.
    CONDENSE lv_cname.

    DATA lv_vers_pad     TYPE versno.
    DATA lv_snap_korrnum TYPE trkorr.
    DATA lv_snap_datum   TYPE datum.
    DATA lv_snap_zeit    TYPE uzeit.
    DATA lv_pat_eq       TYPE vrsd-objname.
    DATA lv_pat_sp       TYPE vrsd-objname.

    lv_vers_pad = iv_version_no.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = iv_version_no
      IMPORTING
        output = lv_vers_pad.

    lv_pat_eq = |{ lv_cname }=%|.
    lv_pat_sp = |{ lv_cname } %|.

    SELECT SINGLE korrnum, datum, zeit FROM vrsd
      WHERE ( versno = @iv_version_no OR versno = @lv_vers_pad )
        AND ( objname = @lv_cname
           OR objname LIKE @lv_pat_eq
           OR objname LIKE @lv_pat_sp )
      INTO (@lv_snap_korrnum, @lv_snap_datum, @lv_snap_zeit). "#EC CI_BUFFJOIN

    IF lv_snap_korrnum IS INITIAL.
      DATA lt_snap_tr TYPE tt_tr_hist.
      SELECT DISTINCT h~trkorr, h~as4user, h~as4date, h~as4time
        FROM e071 AS o
        INNER JOIN e070 AS h ON h~trkorr = o~trkorr
        WHERE ( o~pgmid = 'R3TR' OR o~pgmid = 'LIMU' )
          AND ( o~obj_name = @lv_cname OR o~obj_name LIKE @lv_pat_eq OR o~obj_name LIKE @lv_pat_sp )
          AND h~trstatus = 'R'
        INTO CORRESPONDING FIELDS OF TABLE @lt_snap_tr.

      SORT lt_snap_tr BY as4date ASCENDING as4time ASCENDING.
      DATA lv_idx_snap TYPE i.
      lv_idx_snap = CONV i( lv_vers_pad ).
      IF lv_idx_snap > 0 AND lv_idx_snap <= lines( lt_snap_tr ).
        DATA ls_snap_chosen TYPE ty_tr_hist.
        ls_snap_chosen  = lt_snap_tr[ lv_idx_snap ].
        lv_snap_korrnum = ls_snap_chosen-trkorr.
        lv_snap_datum   = ls_snap_chosen-as4date.
        lv_snap_zeit    = ls_snap_chosen-as4time.
      ENDIF.
    ENDIF.

    DATA lv_ccdef_name TYPE sobj_name.
    DATA lv_ccimp_name TYPE sobj_name.
    DATA lv_ccau_name  TYPE sobj_name.
    DATA lv_ccmac_name TYPE sobj_name.

    TRY.
        lv_ccdef_name = cl_oo_classname_service=>get_ccdef_name( lv_cname ).
      CATCH cx_root.
        lv_ccdef_name = |{ lv_cname WIDTH = 30 PAD = '=' }CCDEF|.
    ENDTRY.
    TRY.
        lv_ccimp_name = cl_oo_classname_service=>get_ccimp_name( lv_cname ).
      CATCH cx_root.
        lv_ccimp_name = |{ lv_cname WIDTH = 30 PAD = '=' }CCIMP|.
    ENDTRY.
    TRY.
        lv_ccau_name = cl_oo_classname_service=>get_ccau_name( lv_cname ).
      CATCH cx_root.
        lv_ccau_name = |{ lv_cname WIDTH = 30 PAD = '=' }CCAU|.
    ENDTRY.
    TRY.
        lv_ccmac_name = cl_oo_classname_service=>get_ccmac_name( lv_cname ).
      CATCH cx_root.
        lv_ccmac_name = |{ lv_cname WIDTH = 30 PAD = '=' }CCMAC|.
    ENDTRY.

    DATA lv_ccdef_vno TYPE versno.
    DATA lv_ccimp_vno TYPE versno.

    IF lv_snap_korrnum IS NOT INITIAL.
      SELECT SINGLE versno FROM vrsd
        WHERE objname = @lv_ccdef_name AND korrnum = @lv_snap_korrnum
        INTO @lv_ccdef_vno. "#EC CI_SGLSELECT
      SELECT SINGLE versno FROM vrsd
        WHERE objname = @lv_ccimp_name AND korrnum = @lv_snap_korrnum
        INTO @lv_ccimp_vno. "#EC CI_SGLSELECT
    ENDIF.

    IF lv_ccdef_vno IS INITIAL AND lv_snap_datum IS NOT INITIAL.
      SELECT versno FROM vrsd
        WHERE objname = @lv_ccdef_name
          AND ( datum < @lv_snap_datum
             OR ( datum = @lv_snap_datum AND zeit <= @lv_snap_zeit ) )
        ORDER BY datum DESCENDING, zeit DESCENDING
        INTO @lv_ccdef_vno
        UP TO 1 ROWS.
      ENDSELECT.
    ENDIF.

    IF lv_ccimp_vno IS INITIAL AND lv_snap_datum IS NOT INITIAL.
      SELECT versno FROM vrsd
        WHERE objname = @lv_ccimp_name
          AND ( datum < @lv_snap_datum
             OR ( datum = @lv_snap_datum AND zeit <= @lv_snap_zeit ) )
        ORDER BY datum DESCENDING, zeit DESCENDING
        INTO @lv_ccimp_vno
        UP TO 1 ROWS.
      ENDSELECT.
    ENDIF.

    DATA ls_ccdef_ver TYPE ty_source.
    DATA ls_ccimp_ver TYPE ty_source.

    IF lv_ccdef_vno IS NOT INITIAL.
      ls_ccdef_ver = read_version(
                       iv_object_type = 'CLAS'
                       iv_object_name = lv_cname
                       iv_version_no  = lv_ccdef_vno
                       iv_component   = 'CCDEF' ).
    ENDIF.

    IF lv_ccimp_vno IS NOT INITIAL.
      ls_ccimp_ver = read_version(
                       iv_object_type = 'CLAS'
                       iv_object_name = lv_cname
                       iv_version_no  = lv_ccimp_vno
                       iv_component   = 'CCIMP' ).
    ENDIF.

    DATA lv_clas_vno TYPE versno.
    DATA lt_cp_lines TYPE ty_string_tab.
    DATA lv_cp_ok    TYPE abap_bool.
    DATA lv_cp_msg   TYPE string.
    DATA lv_cp_text  TYPE string.

    IF lv_snap_korrnum IS NOT INITIAL.
      SELECT SINGLE versno FROM vrsd
        WHERE objtype = 'CLAS' AND objname = @lv_cname AND korrnum = @lv_snap_korrnum
        INTO @lv_clas_vno. "#EC CI_SGLSELECT
    ENDIF.

    IF lv_clas_vno IS INITIAL.
      SELECT SINGLE versno FROM vrsd
        WHERE objtype = 'CLAS' AND objname = @lv_cname
          AND ( versno = @iv_version_no OR versno = @lv_vers_pad )
        INTO @lv_clas_vno. "#EC CI_SGLSELECT
    ENDIF.

    IF lv_clas_vno IS INITIAL AND lv_snap_datum IS NOT INITIAL.
      SELECT versno FROM vrsd
        WHERE objtype = 'CLAS' AND objname = @lv_cname
          AND ( datum < @lv_snap_datum
             OR ( datum = @lv_snap_datum AND zeit <= @lv_snap_zeit ) )
        ORDER BY datum DESCENDING, zeit DESCENDING
        INTO @lv_clas_vno
        UP TO 1 ROWS.
      ENDSELECT.
    ENDIF.

    IF lv_clas_vno IS INITIAL.
      lv_clas_vno = iv_version_no.
    ENDIF.

    read_version_content(
      EXPORTING
        iv_object_type = 'CLAS'
        iv_vrs_type    = 'CLAS'
        iv_object_name = lv_cname
        iv_version_no  = lv_clas_vno
      IMPORTING
        et_lines       = lt_cp_lines
        ev_ok          = lv_cp_ok
        ev_message     = lv_cp_msg ).

    IF lv_cp_ok = abap_true AND lt_cp_lines IS NOT INITIAL.
      lv_cp_text = zcl_scort_hash_utl=>lines_to_text( lt_cp_lines ).
    ELSE.
      DATA ls_cp_fb TYPE ty_source.
      ls_cp_fb = read_version(
                   iv_object_type = 'CLAS'
                   iv_object_name = lv_cname
                   iv_version_no  = iv_version_no
                   iv_component   = 'CP' ).
      lv_cp_text = ls_cp_fb-text.
    ENDIF.

    CLEAR ls_comp.
    ls_comp-id          = 'CP'.
    ls_comp-title       = 'Global Class'.
    ls_comp-kind        = 'CLAS'.
    ls_comp-include     = |{ lv_cname WIDTH = 30 PAD = '=' }CP|.
    ls_comp-line_count  = lines( zcl_scort_hash_utl=>text_to_lines( lv_cp_text ) ).
    ls_comp-has_content = boolc( lv_cp_text IS NOT INITIAL ).
    ls_comp-source      = lv_cp_text.
    APPEND ls_comp TO lt_comps.

    lt_inc_defs = VALUE #(
      ( id = 'CCDEF' title = 'Class-relevant Local Types' kind = 'CCDEF' )
      ( id = 'CCIMP' title = 'Local Types' kind = 'CCIMP' )
      ( id = 'CCAU'  title = 'Test Classes' kind = 'CCAU' )
      ( id = 'CCMAC' title = 'Macros' kind = 'CCMAC' )
    ).

    LOOP AT lt_inc_defs INTO DATA(ls_def).
      CLEAR: ls_comp, ls_ver, lv_inc.
      ls_comp-id    = ls_def-id.
      ls_comp-title = ls_def-title.
      ls_comp-kind  = ls_def-kind.

      CASE ls_def-id.
        WHEN 'CCDEF'.
          lv_inc = lv_ccdef_name.
        WHEN 'CCIMP'.
          lv_inc = lv_ccimp_name.
        WHEN 'CCAU'.
          lv_inc = lv_ccau_name.
        WHEN 'CCMAC'.
          lv_inc = lv_ccmac_name.
      ENDCASE.
      ls_comp-include = lv_inc.

      DATA lv_comp_vno TYPE versno.
      CLEAR lv_comp_vno.

      IF lv_snap_korrnum IS NOT INITIAL.
        SELECT SINGLE versno FROM vrsd
          WHERE objname = @lv_inc AND korrnum = @lv_snap_korrnum
          INTO @lv_comp_vno. "#EC CI_SGLSELECT
      ENDIF.

      IF lv_comp_vno IS INITIAL AND lv_snap_datum IS NOT INITIAL.
        SELECT versno FROM vrsd
          WHERE objname = @lv_inc
            AND ( datum < @lv_snap_datum
               OR ( datum = @lv_snap_datum AND zeit <= @lv_snap_zeit ) )
          ORDER BY datum DESCENDING, zeit DESCENDING
          INTO @lv_comp_vno
          UP TO 1 ROWS.
        ENDSELECT.
      ENDIF.

      DATA lv_read_vno TYPE versno.
      lv_read_vno = COND versno( WHEN lv_comp_vno IS NOT INITIAL
                                 THEN lv_comp_vno
                                 ELSE iv_version_no ).

      ls_ver = read_version(
                 iv_object_type = 'CLAS'
                 iv_object_name = lv_cname
                 iv_version_no  = lv_read_vno
                 iv_component   = ls_def-id ).

      ls_comp-line_count  = ls_ver-line_count.
      ls_comp-has_content = boolc( ls_ver-found = abap_true AND ls_ver-text IS NOT INITIAL ).
      ls_comp-source      = ls_ver-text.
      APPEND ls_comp TO lt_comps.
    ENDLOOP.

    ev_json = /ui2/cl_json=>serialize(
                data        = lt_comps
                pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).
    ev_ok = abap_true.
  ENDMETHOD.

  METHOD reconstruct_clas_source.
    FIELD-SYMBOLS <ls_part>   TYPE any.
    FIELD-SYMBOLS <lt_tab>    TYPE ANY TABLE.
    FIELD-SYMBOLS <ls_meth>   TYPE any.
    FIELD-SYMBOLS <lv_mname>  TYPE any.
    DATA lt_part_lines  TYPE ty_string_tab.
    DATA lv_mname_str   TYPE string.
    DATA lv_clean_cname TYPE string.

    CLEAR rt_lines.
    lv_clean_cname = iv_classname.
    IF lv_clean_cname CS '='.
      SPLIT lv_clean_cname AT '=' INTO lv_clean_cname DATA(lv_dummy_rc).
    ENDIF.
    CONDENSE lv_clean_cname.

    ASSIGN COMPONENT 'REPS' OF STRUCTURE is_object TO <ls_part>.
    IF sy-subrc = 0 AND <ls_part> IS ASSIGNED AND <ls_part> IS NOT INITIAL.
      extract_text_from_any( EXPORTING is_any = <ls_part> CHANGING ct_lines = rt_lines ).
      IF lines( rt_lines ) > 10.
        DATA lv_first_block TYPE string.
        CLEAR lv_first_block.
        LOOP AT rt_lines INTO DATA(lv_rline).
          lv_first_block = |{ lv_first_block }{ lv_rline }\n|.
          IF sy-tabix > 30.
            EXIT.
          ENDIF.
        ENDLOOP.
        IF to_upper( lv_first_block ) CS 'CLASS'
           AND to_upper( lv_first_block ) CS 'DEFINITION'
           AND NOT ( to_upper( lv_first_block ) CS 'CLASS-POOL' )
           AND NOT ( to_upper( lv_first_block ) CS 'INCLUDE' ).
          RETURN.
        ENDIF.
      ENDIF.
      CLEAR rt_lines.
    ENDIF.

    CLEAR lt_part_lines.
    ASSIGN COMPONENT 'CPUB' OF STRUCTURE is_object TO <ls_part>.
    IF sy-subrc = 0 AND <ls_part> IS ASSIGNED.
      extract_text_from_any( EXPORTING is_any = <ls_part> CHANGING ct_lines = lt_part_lines ).
    ENDIF.

    DATA(lv_has_class_def) = abap_false.
    LOOP AT lt_part_lines INTO DATA(lv_cpub_line).
      IF to_upper( lv_cpub_line ) CS 'CLASS' AND to_upper( lv_cpub_line ) CS 'DEFINITION'.
        lv_has_class_def = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    IF lv_has_class_def = abap_true.
      APPEND LINES OF lt_part_lines TO rt_lines.
    ELSE.
      APPEND |CLASS { lv_clean_cname } DEFINITION PUBLIC.| TO rt_lines.
      APPEND |  PUBLIC SECTION.| TO rt_lines.
      LOOP AT lt_part_lines INTO DATA(lv_pub_l).
        IF lv_pub_l IS NOT INITIAL AND lv_pub_l(1) <> '*'.
          APPEND |    { lv_pub_l }| TO rt_lines.
        ENDIF.
      ENDLOOP.
    ENDIF.

    CLEAR lt_part_lines.
    ASSIGN COMPONENT 'CPRO' OF STRUCTURE is_object TO <ls_part>.
    IF sy-subrc = 0 AND <ls_part> IS ASSIGNED.
      extract_text_from_any( EXPORTING is_any = <ls_part> CHANGING ct_lines = lt_part_lines ).
      IF lt_part_lines IS NOT INITIAL.
        APPEND |  PROTECTED SECTION.| TO rt_lines.
        LOOP AT lt_part_lines INTO DATA(lv_pro_l).
          IF lv_pro_l IS NOT INITIAL AND lv_pro_l(1) <> '*'.
            APPEND |    { lv_pro_l }| TO rt_lines.
          ENDIF.
        ENDLOOP.
      ENDIF.
    ENDIF.

    CLEAR lt_part_lines.
    ASSIGN COMPONENT 'CPRI' OF STRUCTURE is_object TO <ls_part>.
    IF sy-subrc = 0 AND <ls_part> IS ASSIGNED.
      extract_text_from_any( EXPORTING is_any = <ls_part> CHANGING ct_lines = lt_part_lines ).
      IF lt_part_lines IS NOT INITIAL.
        APPEND |  PRIVATE SECTION.| TO rt_lines.
        LOOP AT lt_part_lines INTO DATA(lv_pri_l).
          IF lv_pri_l IS NOT INITIAL AND lv_pri_l(1) <> '*'.
            APPEND |    { lv_pri_l }| TO rt_lines.
          ENDIF.
        ENDLOOP.
      ENDIF.
    ENDIF.

    APPEND |ENDCLASS.| TO rt_lines.
    APPEND || TO rt_lines.

    APPEND |CLASS { lv_clean_cname } IMPLEMENTATION.| TO rt_lines.
    ASSIGN COMPONENT 'METH' OF STRUCTURE is_object TO <ls_part>.
    IF sy-subrc = 0 AND <ls_part> IS ASSIGNED.
      ASSIGN <ls_part> TO <lt_tab>.
      IF sy-subrc = 0 AND <lt_tab> IS ASSIGNED.
        LOOP AT <lt_tab> ASSIGNING <ls_meth>.
          CLEAR: lv_mname_str, lt_part_lines.
          ASSIGN COMPONENT 'CPDNAME' OF STRUCTURE <ls_meth> TO <lv_mname>.
          IF sy-subrc <> 0.
            ASSIGN COMPONENT 'METHNAME' OF STRUCTURE <ls_meth> TO <lv_mname>.
          ENDIF.
          IF sy-subrc <> 0.
            ASSIGN COMPONENT 'OBJNAME' OF STRUCTURE <ls_meth> TO <lv_mname>.
          ENDIF.
          IF sy-subrc = 0 AND <lv_mname> IS ASSIGNED.
            lv_mname_str = CONV string( <lv_mname> ).
          ENDIF.

          extract_text_from_any( EXPORTING is_any = <ls_meth> CHANGING ct_lines = lt_part_lines ).

          IF lv_mname_str IS NOT INITIAL.
            APPEND || TO rt_lines.
            APPEND |  METHOD { lv_mname_str }.| TO rt_lines.
            LOOP AT lt_part_lines INTO DATA(lv_ml).
              IF to_upper( condense( lv_ml ) ) <> |METHOD { to_upper( lv_mname_str ) }.|
                 AND to_upper( condense( lv_ml ) ) <> 'ENDMETHOD.'.
                APPEND |    { lv_ml }| TO rt_lines.
              ENDIF.
            ENDLOOP.
            APPEND |  ENDMETHOD.| TO rt_lines.
          ELSEIF lt_part_lines IS NOT INITIAL.
            APPEND LINES OF lt_part_lines TO rt_lines.
          ENDIF.
        ENDLOOP.
      ENDIF.
    ENDIF.

    APPEND |ENDCLASS.| TO rt_lines.
  ENDMETHOD.

ENDCLASS.
