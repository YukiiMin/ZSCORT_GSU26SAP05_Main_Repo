CLASS zcl_scort_tr_tree_query DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

    TYPES:
      BEGIN OF ty_node,
        node_id        TYPE zde_scort_node_id,
        parent_node_id TYPE zde_scort_parent_node_id,
        tree_level     TYPE zde_scort_tree_level,
        node_type      TYPE c LENGTH 4,
        trkorr         TYPE e070-trkorr,
        parent_trkorr  TYPE e070-strkorr,
        description    TYPE e07t-as4text,
        owner          TYPE e070-as4user,
        as4date        TYPE e070-as4date,
        tr_status      TYPE e070-trstatus,
        obj_name       TYPE e071-obj_name,
        obj_type       TYPE e071-object,
        pgmid          TYPE e071-pgmid,
      END OF ty_node.
    TYPES tt_nodes TYPE STANDARD TABLE OF ty_node WITH DEFAULT KEY.

    CLASS-METHODS build_tree
      IMPORTING
        iv_trkorr    TYPE e070-trkorr     OPTIONAL
        iv_owner     TYPE e070-as4user    OPTIONAL
        iv_date_from TYPE d               OPTIONAL
        iv_date_to   TYPE d               OPTIONAL
        iv_trstatus  TYPE e070-trstatus   OPTIONAL
        iv_obj_name  TYPE e071-obj_name   OPTIONAL
        iv_obj_type  TYPE e071-object     OPTIONAL
      RETURNING
        VALUE(rt_nodes) TYPE tt_nodes.

    CLASS-METHODS make_node_id
      IMPORTING
        iv_trkorr    TYPE e070-trkorr
        iv_obj_name  TYPE clike OPTIONAL
        iv_suffix    TYPE clike OPTIONAL
      RETURNING
        VALUE(rv_id) TYPE zde_scort_node_id.

    CLASS-METHODS get_type_description
      IMPORTING
        iv_obj_type    TYPE e071-object
      RETURNING
        VALUE(rv_desc) TYPE as4text.

  PROTECTED SECTION.
  PRIVATE SECTION.

ENDCLASS.

CLASS zcl_scort_tr_tree_query IMPLEMENTATION.

  METHOD if_rap_query_provider~select.
    DATA lv_trkorr    TYPE e070-trkorr.
    DATA lv_owner     TYPE e070-as4user.
    DATA lv_date_from TYPE d.
    DATA lv_date_to   TYPE d.
    DATA lv_trstatus  TYPE e070-trstatus.
    DATA lv_raw       TYPE string.
    DATA lt_result TYPE STANDARD TABLE OF zce_scort_tr_tree WITH DEFAULT KEY.
    DATA lt_page   TYPE STANDARD TABLE OF zce_scort_tr_tree WITH DEFAULT KEY.
    DATA ls_result LIKE LINE OF lt_result.
    DATA lv_offset TYPE i.
    DATA lv_page   TYPE i.
    DATA lv_total  TYPE i.
    DATA lv_from   TYPE i.
    DATA lv_to     TYPE i.
    DATA lv_data   TYPE abap_bool.
    DATA lv_count  TYPE abap_bool.

    TRY.
        TRY.
            lv_data  = io_request->is_data_requested( ).
          CATCH cx_root.
            lv_data = abap_true.
        ENDTRY.
        TRY.
            lv_count = io_request->is_total_numb_of_rec_requested( ).
          CATCH cx_root.
            lv_count = abap_true.
        ENDTRY.

        lv_raw = zcl_scort_query_utl=>filter_low(
                   io_request = io_request iv_field = 'TRKORR' ).
        IF lv_raw IS INITIAL.
          lv_raw = zcl_scort_query_utl=>filter_low(
                     io_request = io_request iv_field = 'NODEID' ).
        ENDIF.
        IF lv_raw IS NOT INITIAL.
          lv_trkorr = CONV #( lv_raw ).
        ENDIF.

        lv_raw = zcl_scort_query_utl=>filter_low(
                   io_request = io_request iv_field = 'OWNER' ).
        IF lv_raw IS NOT INITIAL.
          lv_owner = CONV #( lv_raw ).
        ENDIF.

        lv_raw = zcl_scort_query_utl=>filter_low(
                   io_request = io_request iv_field = 'TRSTATUS' ).
        IF lv_raw IS NOT INITIAL.
          lv_trstatus = CONV #( lv_raw ).
        ENDIF.

        lv_raw = zcl_scort_query_utl=>filter_low(
                   io_request = io_request iv_field = 'AS4DATE' ).
        IF lv_raw IS NOT INITIAL AND strlen( lv_raw ) >= 8.
          lv_date_from = lv_raw(8).
        ENDIF.

        DATA lv_obj_name TYPE e071-obj_name.
        DATA lv_obj_type TYPE e071-object.
        lv_raw = zcl_scort_query_utl=>filter_low(
                   io_request = io_request iv_field = 'OBJNAME' ).
        IF lv_raw IS INITIAL.
          lv_raw = zcl_scort_query_utl=>filter_low(
                     io_request = io_request iv_field = 'OBJECTNAME' ).
        ENDIF.
        IF lv_raw IS NOT INITIAL.
          lv_obj_name = CONV #( lv_raw ).
        ENDIF.

        lv_raw = zcl_scort_query_utl=>filter_low(
                   io_request = io_request iv_field = 'OBJTYPE' ).
        IF lv_raw IS INITIAL.
          lv_raw = zcl_scort_query_utl=>filter_low(
                     io_request = io_request iv_field = 'OBJECTTYPE' ).
        ENDIF.
        IF lv_raw IS NOT INITIAL.
          lv_obj_type = CONV #( lv_raw ).
        ENDIF.

        DATA(lt_nodes) = build_tree(
          iv_trkorr    = lv_trkorr
          iv_owner     = lv_owner
          iv_date_from = lv_date_from
          iv_date_to   = lv_date_to
          iv_trstatus  = lv_trstatus
          iv_obj_name  = lv_obj_name
          iv_obj_type  = lv_obj_type ).

        LOOP AT lt_nodes ASSIGNING FIELD-SYMBOL(<node>).
          CLEAR ls_result.
          ls_result-NodeId        = <node>-node_id.
          ls_result-ParentNodeId  = <node>-parent_node_id.
          ls_result-TreeLevel     = <node>-tree_level.
          ls_result-NodeType      = <node>-node_type.
          ls_result-Trkorr        = <node>-trkorr.
          ls_result-ParentTrkorr  = <node>-parent_trkorr.
          ls_result-Description   = <node>-description.
          ls_result-Owner         = <node>-owner.
          ls_result-As4date       = <node>-as4date.
          ls_result-TrStatus      = <node>-tr_status.
          ls_result-ObjName       = <node>-obj_name.
          ls_result-ObjType       = <node>-obj_type.
          ls_result-Pgmid         = <node>-pgmid.
          APPEND ls_result TO lt_result.
        ENDLOOP.

        lv_total = lines( lt_result ).

        TRY.
            lv_offset = CONV i( io_request->get_paging( )->get_offset( ) ).
            DATA(lv_ps) = io_request->get_paging( )->get_page_size( ).
            IF lv_ps = if_rap_query_paging=>page_size_unlimited OR lv_ps <= 0.
              lv_page = 100.
            ELSEIF lv_ps > 500.
              lv_page = 500.
            ELSE.
              lv_page = CONV i( lv_ps ).
            ENDIF.
          CATCH cx_root.
            lv_offset = 0.
            lv_page   = 100.
        ENDTRY.

        IF lv_count = abap_true.
          io_response->set_total_number_of_records( CONV int8( lv_total ) ).
        ENDIF.

        IF lv_data = abap_true.
          lv_from = lv_offset + 1.
          lv_to   = lv_offset + lv_page.
          IF lv_from <= lv_total.
            IF lv_to > lv_total.
              lv_to = lv_total.
            ENDIF.
            LOOP AT lt_result INTO ls_result FROM lv_from TO lv_to.
              APPEND ls_result TO lt_page.
            ENDLOOP.
          ENDIF.
          io_response->set_data( lt_page ).
        ENDIF.
      CATCH cx_root.
        CLEAR lt_page.
        TRY.
            IF lv_count = abap_true OR lv_count IS INITIAL.
              io_response->set_total_number_of_records( 0 ).
            ENDIF.
            IF lv_data = abap_true OR lv_data IS INITIAL.
              io_response->set_data( lt_page ).
            ENDIF.
          CATCH cx_root.
        ENDTRY.
    ENDTRY.
  ENDMETHOD.

  METHOD build_tree.
    DATA lt_tr_parents TYPE TABLE OF e070.
    DATA lv_tr_pattern TYPE string.
    DATA lv_owner_pattern TYPE string.

    IF iv_trkorr IS NOT INITIAL.
      lv_tr_pattern = iv_trkorr.
      REPLACE ALL OCCURRENCES OF '*' IN lv_tr_pattern WITH '%'.
      REPLACE ALL OCCURRENCES OF '+' IN lv_tr_pattern WITH '_'.
      IF lv_tr_pattern NA '%'.
        lv_tr_pattern = |%{ lv_tr_pattern }%|.
      ENDIF.
    ELSE.
      lv_tr_pattern = '%'.
    ENDIF.

    IF iv_owner IS NOT INITIAL.
      lv_owner_pattern = iv_owner.
      REPLACE ALL OCCURRENCES OF '*' IN lv_owner_pattern WITH '%'.
      REPLACE ALL OCCURRENCES OF '+' IN lv_owner_pattern WITH '_'.
      IF lv_owner_pattern NA '%'.
        lv_owner_pattern = |%{ lv_owner_pattern }%|.
      ENDIF.
    ELSE.
      lv_owner_pattern = '%'.
    ENDIF.

    TYPES: BEGIN OF ty_tr_filter,
             trkorr TYPE e070-trkorr,
           END OF ty_tr_filter.
    DATA lt_matching_trkorr TYPE STANDARD TABLE OF ty_tr_filter WITH DEFAULT KEY.
    DATA lt_target_parents  TYPE STANDARD TABLE OF ty_tr_filter WITH DEFAULT KEY.
    DATA lv_obj_filtered    TYPE abap_bool VALUE abap_false.

    IF iv_obj_name IS NOT INITIAL OR iv_obj_type IS NOT INITIAL.
      lv_obj_filtered = abap_true.
      DATA lv_obj_pattern TYPE string.
      IF iv_obj_name IS NOT INITIAL.
        lv_obj_pattern = iv_obj_name.
        REPLACE ALL OCCURRENCES OF '*' IN lv_obj_pattern WITH '%'.
        REPLACE ALL OCCURRENCES OF '+' IN lv_obj_pattern WITH '_'.
        IF lv_obj_pattern NA '%'.
          lv_obj_pattern = |%{ lv_obj_pattern }%|.
        ENDIF.
      ELSE.
        lv_obj_pattern = '%'.
      ENDIF.

      IF iv_obj_type IS NOT INITIAL.
        SELECT DISTINCT trkorr FROM e071
          WHERE object = @iv_obj_type AND obj_name LIKE @lv_obj_pattern
          INTO TABLE @lt_matching_trkorr
          UP TO 500 ROWS.
      ELSE.
        SELECT DISTINCT trkorr FROM e071
          WHERE obj_name LIKE @lv_obj_pattern
          INTO TABLE @lt_matching_trkorr
          UP TO 500 ROWS.
      ENDIF.

      IF lt_matching_trkorr IS INITIAL.
        RETURN.
      ENDIF.

      SELECT trkorr, strkorr FROM e070
        FOR ALL ENTRIES IN @lt_matching_trkorr
        WHERE trkorr = @lt_matching_trkorr-trkorr
        INTO TABLE @DATA(lt_match_e070).
      LOOP AT lt_match_e070 INTO DATA(ls_m).
        IF ls_m-strkorr IS NOT INITIAL.
          APPEND VALUE #( trkorr = ls_m-strkorr ) TO lt_target_parents.
        ELSE.
          APPEND VALUE #( trkorr = ls_m-trkorr ) TO lt_target_parents.
        ENDIF.
      ENDLOOP.
      SORT lt_target_parents BY trkorr.
      DELETE ADJACENT DUPLICATES FROM lt_target_parents COMPARING trkorr.

      IF lt_target_parents IS INITIAL.
        RETURN.
      ENDIF.
    ENDIF.

    IF lv_obj_filtered = abap_true.
      SELECT trkorr, strkorr, as4user, as4date, as4time, trstatus
        FROM e070
        FOR ALL ENTRIES IN @lt_target_parents
        WHERE strkorr = @space
          AND trkorr  = @lt_target_parents-trkorr
          AND trkorr  LIKE @lv_tr_pattern
          AND as4user LIKE @lv_owner_pattern
        INTO CORRESPONDING FIELDS OF TABLE @lt_tr_parents.

      SORT lt_tr_parents BY as4date DESCENDING as4time DESCENDING.
      IF lines( lt_tr_parents ) > 200.
        DELETE lt_tr_parents FROM 201.
      ENDIF.
    ELSE.
      SELECT trkorr, strkorr, as4user, as4date, as4time, trstatus
        FROM e070
        WHERE strkorr = @space
          AND trkorr  LIKE @lv_tr_pattern
          AND as4user LIKE @lv_owner_pattern
        ORDER BY as4date DESCENDING, as4time DESCENDING
        INTO CORRESPONDING FIELDS OF TABLE @lt_tr_parents
        UP TO 200 ROWS.
    ENDIF.

    IF lt_tr_parents IS INITIAL. RETURN. ENDIF.

    IF iv_trstatus IS NOT INITIAL.
      DELETE lt_tr_parents WHERE trstatus <> iv_trstatus.
    ENDIF.
    IF iv_date_from IS NOT INITIAL.
      DELETE lt_tr_parents WHERE as4date < iv_date_from.
    ENDIF.
    IF iv_date_to IS NOT INITIAL.
      DELETE lt_tr_parents WHERE as4date > iv_date_to.
    ENDIF.

    IF lt_tr_parents IS INITIAL. RETURN. ENDIF.

    DATA lt_tr_texts TYPE TABLE OF e07t.
    SELECT trkorr, langu, as4text
      FROM e07t
      FOR ALL ENTRIES IN @lt_tr_parents
      WHERE trkorr = @lt_tr_parents-trkorr
        AND langu  = @sy-langu
      INTO CORRESPONDING FIELDS OF TABLE @lt_tr_texts.

    DATA lt_tasks TYPE TABLE OF e070.
    SELECT trkorr, strkorr, as4user, as4date, trstatus
      FROM e070
      FOR ALL ENTRIES IN @lt_tr_parents
      WHERE strkorr = @lt_tr_parents-trkorr
      INTO CORRESPONDING FIELDS OF TABLE @lt_tasks.

    TYPES: BEGIN OF ty_attr,
             trkorr    TYPE e070-trkorr,
             attribute TYPE e070a-attribute,
             reference TYPE e070a-reference,
           END OF ty_attr.
    DATA lt_e070a TYPE STANDARD TABLE OF ty_attr WITH DEFAULT KEY.

    IF lt_tr_parents IS NOT INITIAL.
      SELECT trkorr, attribute, reference
        FROM e070a
        FOR ALL ENTRIES IN @lt_tr_parents
        WHERE trkorr = @lt_tr_parents-trkorr
          AND attribute <> 'SAPCOMPONENT'
        INTO CORRESPONDING FIELDS OF TABLE @lt_e070a.
    ENDIF.

    DATA lt_tr_keys TYPE TABLE OF e070.
    lt_tr_keys = lt_tr_parents.
    APPEND LINES OF lt_tasks TO lt_tr_keys.
    SORT lt_tr_keys BY trkorr.
    DELETE ADJACENT DUPLICATES FROM lt_tr_keys COMPARING trkorr.

    TYPES: BEGIN OF ty_parsed_obj,
             trkorr    TYPE e071-trkorr,
             pgmid     TYPE e071-pgmid,
             object    TYPE e071-object,
             fold_type TYPE e071-object,
             fold_desc TYPE as4text,
             obj_name  TYPE e071-obj_name,
             desc      TYPE as4text,
             owner     TYPE e070-as4user,
             as4date   TYPE e070-as4date,
           END OF ty_parsed_obj.
    DATA lt_parsed_objs TYPE STANDARD TABLE OF ty_parsed_obj WITH DEFAULT KEY.
    DATA ls_parsed LIKE LINE OF lt_parsed_objs.
    DATA lt_e071_raw TYPE TABLE OF e071.

    IF lt_tr_keys IS NOT INITIAL.
      SELECT trkorr, pgmid, object, obj_name
        FROM e071
        FOR ALL ENTRIES IN @lt_tr_keys
        WHERE trkorr = @lt_tr_keys-trkorr
          AND ( pgmid = 'R3TR' OR pgmid = 'LIMU' OR pgmid = '*' OR object = 'RELE' )
        INTO CORRESPONDING FIELDS OF TABLE @lt_e071_raw.

      LOOP AT lt_e071_raw INTO DATA(ls_raw).
        CLEAR ls_parsed.
        ls_parsed-trkorr = ls_raw-trkorr.
        ls_parsed-pgmid  = ls_raw-pgmid.

        IF ls_raw-object = 'METH'.
          " LIMU METH: obj_name contains Class Name (first 30 chars) and Method Name
          DATA lv_cls TYPE e071-obj_name.
          DATA lv_mth TYPE as4text.
          CLEAR: lv_cls, lv_mth.
          IF strlen( ls_raw-obj_name ) > 30.
            lv_cls = ls_raw-obj_name(30).
            lv_mth = ls_raw-obj_name+30.
          ELSE.
            SPLIT ls_raw-obj_name AT space INTO lv_cls lv_mth.
          ENDIF.
          CONDENSE lv_cls.
          CONDENSE lv_mth.
          IF lv_mth IS INITIAL.
            SPLIT ls_raw-obj_name AT space INTO lv_cls lv_mth.
            CONDENSE lv_cls.
            CONDENSE lv_mth.
          ENDIF.
          ls_parsed-object    = 'METH'.
          ls_parsed-fold_type = 'METH'.
          ls_parsed-fold_desc = get_type_description( 'METH' ).
          ls_parsed-obj_name  = lv_cls.
          ls_parsed-desc      = lv_mth.
          APPEND ls_parsed TO lt_parsed_objs.

        ELSEIF ls_raw-object = 'FUNC'.
          ls_parsed-object    = 'FUNC'.
          ls_parsed-fold_type = 'FUNC'.
          ls_parsed-fold_desc = get_type_description( 'FUNC' ).
          ls_parsed-obj_name  = ls_raw-obj_name.
          ls_parsed-desc      = ''.
          APPEND ls_parsed TO lt_parsed_objs.

        ELSEIF ls_raw-object = 'CPUB' OR ls_raw-object = 'CPRI' OR ls_raw-object = 'CPRO' OR ls_raw-object = 'CLSD'.
          ls_parsed-object    = ls_raw-object.
          ls_parsed-fold_type = ls_raw-object.
          ls_parsed-fold_desc = get_type_description( ls_raw-object ).
          ls_parsed-obj_name  = ls_raw-obj_name.
          CASE ls_raw-object.
            WHEN 'CPUB'. ls_parsed-desc = 'Public Header'.
            WHEN 'CPRI'. ls_parsed-desc = 'Private Header'.
            WHEN 'CPRO'. ls_parsed-desc = 'Protected Header'.
            WHEN 'CLSD'. ls_parsed-desc = 'Class Definition'.
          ENDCASE.
          APPEND ls_parsed TO lt_parsed_objs.

        ELSEIF ls_raw-object = 'REPS' OR ls_raw-object = 'REPT'.
          " Check if this is a Function Group include (e.g. L<FUGR>UXX, L<FUGR>TOP, L<FUGR>U01...)
          DATA lv_obj_len TYPE i.
          DATA lv_off_end TYPE i.
          DATA lv_is_fg_inc TYPE abap_bool.
          DATA lv_fg_name TYPE string.

          lv_is_fg_inc = abap_false.
          CLEAR lv_fg_name.
          lv_obj_len = strlen( ls_raw-obj_name ).

          IF lv_obj_len > 4 AND ls_raw-obj_name(1) = 'L'.
            lv_off_end = lv_obj_len - 3.
            IF ls_raw-obj_name+lv_off_end(3) = 'UXX'.
              lv_is_fg_inc = abap_true.
              DATA lv_mid_len TYPE i.
              lv_mid_len = lv_off_end - 1.
              lv_fg_name = ls_raw-obj_name+1(lv_mid_len).
            ELSEIF ls_raw-obj_name+lv_off_end(3) = 'TOP'.
              lv_is_fg_inc = abap_true.
              DATA lv_mid_len_top TYPE i.
              lv_mid_len_top = lv_off_end - 1.
              lv_fg_name = ls_raw-obj_name+1(lv_mid_len_top).
            ELSEIF lv_obj_len > 4 AND ls_raw-obj_name+lv_off_end(1) = 'U'.
              lv_is_fg_inc = abap_true.
              DATA lv_mid_len_u TYPE i.
              lv_mid_len_u = lv_off_end - 1.
              lv_fg_name = ls_raw-obj_name+1(lv_mid_len_u).
            ENDIF.
          ELSEIF lv_obj_len > 4 AND ls_raw-obj_name(4) = 'SAPL'.
            lv_is_fg_inc = abap_true.
            lv_fg_name = ls_raw-obj_name+4.
          ENDIF.

          IF lv_is_fg_inc = abap_true.
            ls_parsed-object    = 'FUNC'.
            ls_parsed-fold_type = 'FUNC'.
            ls_parsed-fold_desc = 'Function Module'.
            ls_parsed-obj_name  = ls_raw-obj_name.
            ls_parsed-desc      = |Function Group Include ({ lv_fg_name })|.
          ELSE.
            ls_parsed-object    = ls_raw-object.
            ls_parsed-fold_type = ls_raw-object.
            ls_parsed-fold_desc = get_type_description( ls_raw-object ).
            ls_parsed-obj_name  = ls_raw-obj_name.
            ls_parsed-desc      = 'Report Source Code'.
          ENDIF.

          APPEND ls_parsed TO lt_parsed_objs.

        ELSEIF ls_raw-pgmid = '*' OR ls_raw-object = 'RELE'.
          " Comment Entry: Released (SE09 CTS audit log: <Task> <YYYYMMDD> <HHMMSS> <User>)
          ls_parsed-object    = ls_raw-object.
          ls_parsed-fold_type = ls_raw-object.
          IF ls_raw-object = 'RELE'.
            ls_parsed-fold_desc = 'Comment Entry: Released'.
          ELSEIF ls_raw-object = 'NOTE'.
            ls_parsed-fold_desc = 'Comment Entry: Note'.
          ELSEIF ls_raw-object = 'COMM'.
            ls_parsed-fold_desc = 'Comment Entry: Comment'.
          ELSEIF ls_raw-object IS INITIAL.
            ls_parsed-fold_desc = 'Comment Entry'.
          ELSE.
            ls_parsed-fold_desc = |Comment Entry: { ls_raw-object }|.
          ENDIF.

          DATA lt_rele_parts TYPE STANDARD TABLE OF string WITH DEFAULT KEY.
          DATA lv_rele_str TYPE string.
          DATA lv_tk TYPE string.
          DATA lv_dt TYPE string.
          DATA lv_tm TYPE string.
          DATA lv_us TYPE string.

          lv_rele_str = ls_raw-obj_name.
          CONDENSE lv_rele_str.
          SPLIT lv_rele_str AT space INTO TABLE lt_rele_parts.
          DELETE lt_rele_parts WHERE table_line IS INITIAL.

          IF lines( lt_rele_parts ) >= 4.
            READ TABLE lt_rele_parts INDEX 1 INTO lv_tk.
            READ TABLE lt_rele_parts INDEX 2 INTO lv_dt.
            READ TABLE lt_rele_parts INDEX 3 INTO lv_tm.
            READ TABLE lt_rele_parts INDEX 4 INTO lv_us.

            ls_parsed-obj_name = lv_tk.
            ls_parsed-owner    = lv_us.
            ls_parsed-as4date  = lv_dt.

            DATA lv_fdate TYPE string.
            DATA lv_ftime TYPE string.
            IF strlen( lv_dt ) = 8.
              lv_fdate = |{ lv_dt(4) }-{ lv_dt+4(2) }-{ lv_dt+6(2) }|.
            ELSE.
              lv_fdate = lv_dt.
            ENDIF.
            IF strlen( lv_tm ) = 6.
              lv_ftime = |{ lv_tm(2) }:{ lv_tm+2(2) }:{ lv_tm+4(2) }|.
            ELSE.
              lv_ftime = lv_tm.
            ENDIF.
            ls_parsed-desc = |Released: { lv_fdate } { lv_ftime }|.
          ELSE.
            ls_parsed-obj_name = ls_raw-obj_name.
            ls_parsed-desc     = ''.
          ENDIF.

          APPEND ls_parsed TO lt_parsed_objs.

        ELSE.
          ls_parsed-object    = ls_raw-object.
          ls_parsed-fold_type = ls_raw-object.
          ls_parsed-fold_desc = get_type_description( ls_raw-object ).
          ls_parsed-obj_name  = ls_raw-obj_name.
          ls_parsed-desc      = ''.
          APPEND ls_parsed TO lt_parsed_objs.
        ENDIF.
      ENDLOOP.

      SORT lt_parsed_objs BY trkorr fold_type obj_name desc.
      DELETE ADJACENT DUPLICATES FROM lt_parsed_objs COMPARING trkorr fold_type obj_name desc.
    ENDIF.

    DATA ls_node TYPE ty_node.
    DATA lv_current_type TYPE e071-object.

    LOOP AT lt_tr_parents ASSIGNING FIELD-SYMBOL(<tr>).
      CLEAR ls_node.
      ls_node-node_id        = make_node_id( <tr>-trkorr ).
      ls_node-parent_node_id = ''.
      ls_node-tree_level     = 0.
      ls_node-node_type      = 'TR'.
      ls_node-trkorr         = <tr>-trkorr.
      ls_node-parent_trkorr  = ''.
      ls_node-owner          = <tr>-as4user.
      ls_node-as4date        = <tr>-as4date.
      ls_node-tr_status      = <tr>-trstatus.
      READ TABLE lt_tr_texts ASSIGNING FIELD-SYMBOL(<txt>)
        WITH KEY trkorr = <tr>-trkorr.
      IF sy-subrc = 0. ls_node-description = <txt>-as4text. ENDIF.
      APPEND ls_node TO rt_nodes.

      LOOP AT lt_tasks ASSIGNING FIELD-SYMBOL(<task>)
          WHERE strkorr = <tr>-trkorr.
        CLEAR ls_node.
        ls_node-node_id        = make_node_id( <task>-trkorr ).
        ls_node-parent_node_id = make_node_id( <tr>-trkorr ).
        ls_node-tree_level     = 1.
        ls_node-node_type      = 'TASK'.
        ls_node-trkorr         = <task>-trkorr.
        ls_node-parent_trkorr  = <tr>-trkorr.
        ls_node-owner          = <task>-as4user.
        ls_node-as4date        = <task>-as4date.
        ls_node-tr_status      = <task>-trstatus.
        ls_node-description    = 'Development/Correction'.
        APPEND ls_node TO rt_nodes.

        CLEAR lv_current_type.

        LOOP AT lt_parsed_objs ASSIGNING FIELD-SYMBOL(<obj>)
            WHERE trkorr = <task>-trkorr.

          IF lv_current_type <> <obj>-fold_type.
            lv_current_type = <obj>-fold_type.
            CLEAR ls_node.
            ls_node-node_id        = make_node_id(
              iv_trkorr   = <task>-trkorr
              iv_obj_name = |#{ <obj>-fold_type }|
            ).
            ls_node-parent_node_id = make_node_id( <task>-trkorr ).
            ls_node-tree_level     = 2.
            ls_node-node_type      = 'FOLD'.
            ls_node-trkorr         = <task>-trkorr.
            ls_node-parent_trkorr  = <tr>-trkorr.
            ls_node-obj_type       = <obj>-fold_type.
            ls_node-obj_name       = <obj>-fold_desc.
            ls_node-description    = <obj>-fold_desc.
            APPEND ls_node TO rt_nodes.
          ENDIF.

          CLEAR ls_node.
          ls_node-node_id        = make_node_id(
            iv_trkorr   = <task>-trkorr
            iv_obj_name = <obj>-obj_name
            iv_suffix   = <obj>-desc
          ).
          ls_node-parent_node_id = make_node_id(
            iv_trkorr   = <task>-trkorr
            iv_obj_name = |#{ <obj>-fold_type }|
          ).
          ls_node-tree_level     = 3.
          IF <obj>-pgmid = '*' OR <obj>-object = 'RELE'.
            ls_node-node_type    = 'COMM'.
            ls_node-owner        = <obj>-owner.
            ls_node-as4date      = <obj>-as4date.
            ls_node-tr_status    = 'R'.
          ELSE.
            ls_node-node_type    = 'OBJ'.
            ls_node-owner        = ''.
            ls_node-as4date      = ''.
            ls_node-tr_status    = ''.
          ENDIF.
          ls_node-trkorr         = <task>-trkorr.
          ls_node-parent_trkorr  = <tr>-trkorr.
          ls_node-obj_type       = <obj>-object.
          ls_node-obj_name       = <obj>-obj_name.
          ls_node-pgmid          = <obj>-pgmid.
          ls_node-description    = <obj>-desc.
          APPEND ls_node TO rt_nodes.
        ENDLOOP.
      ENDLOOP.

      CLEAR lv_current_type.
      DATA lv_has_tr_obj TYPE abap_bool.
      lv_has_tr_obj = abap_false.
      LOOP AT lt_parsed_objs ASSIGNING FIELD-SYMBOL(<chk_tr_obj>)
          WHERE trkorr = <tr>-trkorr.
        lv_has_tr_obj = abap_true.
        EXIT.
      ENDLOOP.

      IF lv_has_tr_obj = abap_true.
        CLEAR ls_node.
        ls_node-node_id        = make_node_id( iv_trkorr = <tr>-trkorr iv_obj_name = '#OBJ_LIST' ).
        ls_node-parent_node_id = make_node_id( <tr>-trkorr ).
        ls_node-tree_level     = 1.
        ls_node-node_type      = 'FOLD'.
        ls_node-trkorr         = <tr>-trkorr.
        ls_node-parent_trkorr  = <tr>-trkorr.
        ls_node-obj_type       = 'LIST'.
        ls_node-obj_name       = 'Object List of Request'.
        ls_node-description    = 'Object List of Request'.
        APPEND ls_node TO rt_nodes.

        LOOP AT lt_parsed_objs ASSIGNING FIELD-SYMBOL(<obj2>)
            WHERE trkorr = <tr>-trkorr.

          IF lv_current_type <> <obj2>-fold_type.
            lv_current_type = <obj2>-fold_type.
            CLEAR ls_node.
            ls_node-node_id        = make_node_id(
              iv_trkorr   = <tr>-trkorr
              iv_obj_name = |#TR_FLD_{ <obj2>-fold_type }|
            ).
            ls_node-parent_node_id = make_node_id( iv_trkorr = <tr>-trkorr iv_obj_name = '#OBJ_LIST' ).
            ls_node-tree_level     = 2.
            ls_node-node_type      = 'FOLD'.
            ls_node-trkorr         = <tr>-trkorr.
            ls_node-parent_trkorr  = <tr>-trkorr.
            ls_node-obj_type       = <obj2>-fold_type.
            ls_node-obj_name       = <obj2>-fold_desc.
            ls_node-description    = <obj2>-fold_desc.
            APPEND ls_node TO rt_nodes.
          ENDIF.

          CLEAR ls_node.
          ls_node-node_id        = make_node_id(
            iv_trkorr   = <tr>-trkorr
            iv_obj_name = <obj2>-obj_name
            iv_suffix   = <obj2>-desc
          ).
          ls_node-parent_node_id = make_node_id(
            iv_trkorr   = <tr>-trkorr
            iv_obj_name = |#TR_FLD_{ <obj2>-fold_type }|
          ).
          ls_node-tree_level     = 3.
          IF <obj2>-pgmid = '*' OR <obj2>-object = 'RELE'.
            ls_node-node_type    = 'COMM'.
            ls_node-owner        = <obj2>-owner.
            ls_node-as4date      = <obj2>-as4date.
            ls_node-tr_status    = 'R'.
          ELSE.
            ls_node-node_type    = 'OBJ'.
            ls_node-owner        = ''.
            ls_node-as4date      = ''.
            ls_node-tr_status    = ''.
          ENDIF.
          ls_node-trkorr         = <tr>-trkorr.
          ls_node-parent_trkorr  = <tr>-trkorr.
          ls_node-obj_name       = <obj2>-obj_name.
          ls_node-obj_type       = <obj2>-object.
          ls_node-pgmid          = <obj2>-pgmid.
          ls_node-description    = <obj2>-desc.
          APPEND ls_node TO rt_nodes.
        ENDLOOP.
      ENDIF.

      DATA lv_has_attr TYPE abap_bool.
      lv_has_attr = abap_false.
      LOOP AT lt_e070a ASSIGNING FIELD-SYMBOL(<chk_attr>)
          WHERE trkorr = <tr>-trkorr.
        lv_has_attr = abap_true.
        EXIT.
      ENDLOOP.

      IF lv_has_attr = abap_true.
        CLEAR ls_node.
        ls_node-node_id        = make_node_id( iv_trkorr = <tr>-trkorr iv_obj_name = '#REQ_ATTR' ).
        ls_node-parent_node_id = make_node_id( <tr>-trkorr ).
        ls_node-tree_level     = 1.
        ls_node-node_type      = 'ATTR'.
        ls_node-trkorr         = <tr>-trkorr.
        ls_node-parent_trkorr  = <tr>-trkorr.
        ls_node-obj_type       = 'ATTR'.
        ls_node-obj_name       = 'Request Attributes'.
        ls_node-description    = ''.
        APPEND ls_node TO rt_nodes.

        LOOP AT lt_e070a ASSIGNING FIELD-SYMBOL(<attr>)
            WHERE trkorr = <tr>-trkorr.
          CLEAR ls_node.
          ls_node-node_id        = make_node_id(
            iv_trkorr   = <tr>-trkorr
            iv_obj_name = |#ATTR_{ <attr>-attribute }|
          ).
          ls_node-parent_node_id = make_node_id( iv_trkorr = <tr>-trkorr iv_obj_name = '#REQ_ATTR' ).
          ls_node-tree_level     = 2.
          ls_node-node_type      = 'ATTR'.
          ls_node-trkorr         = <tr>-trkorr.
          ls_node-parent_trkorr  = <tr>-trkorr.
          ls_node-obj_type       = 'ATTR'.
          ls_node-obj_name       = <attr>-attribute.
          ls_node-description    = ''.
          APPEND ls_node TO rt_nodes.

          CLEAR ls_node.
          ls_node-node_id        = make_node_id(
            iv_trkorr   = <tr>-trkorr
            iv_obj_name = |#VAL_{ <attr>-attribute }|
            iv_suffix   = <attr>-reference
          ).
          ls_node-parent_node_id = make_node_id(
            iv_trkorr   = <tr>-trkorr
            iv_obj_name = |#ATTR_{ <attr>-attribute }|
          ).
          ls_node-tree_level     = 3.
          ls_node-node_type      = 'ATTR'.
          ls_node-trkorr         = <tr>-trkorr.
          ls_node-parent_trkorr  = <tr>-trkorr.
          ls_node-obj_type       = 'VAL'.
          ls_node-obj_name       = <attr>-reference.

          DATA lv_ref_val TYPE string.
          lv_ref_val = <attr>-reference.
          CONDENSE lv_ref_val.
          IF strlen( lv_ref_val ) = 14.
            ls_node-description = |{ lv_ref_val(4) }-{ lv_ref_val+4(2) }-{ lv_ref_val+6(2) } { lv_ref_val+8(2) }:{ lv_ref_val+10(2) }:{ lv_ref_val+12(2) }|.
          ELSE.
            ls_node-description = ''.
          ENDIF.
          APPEND ls_node TO rt_nodes.
        ENDLOOP.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

  METHOD make_node_id.
    DATA lv TYPE string.
    IF iv_obj_name IS INITIAL.
      lv = CONV string( iv_trkorr ).
    ELSEIF iv_suffix IS NOT INITIAL.
      lv = |{ CONV string( iv_trkorr ) }_{ CONV string( iv_obj_name ) }_{ CONV string( iv_suffix ) }|.
    ELSE.
      lv = |{ CONV string( iv_trkorr ) }_{ CONV string( iv_obj_name ) }|.
    ENDIF.
    CONDENSE lv.
    IF strlen( lv ) > 40.
      DATA lv_off TYPE i.
      DATA lv_tail TYPE string.
      lv_off = strlen( lv ) - 14.
      lv_tail = lv+lv_off(14).
      lv = |{ lv(25) }~{ lv_tail }|.
    ENDIF.
    rv_id = lv.
  ENDMETHOD.

  METHOD get_type_description.
    CASE iv_obj_type.
      WHEN 'RELE'. rv_desc = 'Comment Entry: Released'.
      WHEN 'NOTE'. rv_desc = 'Comment Entry: Note'.
      WHEN 'COMM'. rv_desc = 'Comment Entry: Comment'.
      WHEN 'METH'. rv_desc = 'Method (ABAP Objects)'.
      WHEN 'CLAS'. rv_desc = 'Class (ABAP Objects)'.
      WHEN 'CLSD'. rv_desc = 'Class Definition (ABAP Objects)'.
      WHEN 'CPUB'. rv_desc = 'Public Header (ABAP Objects)'.
      WHEN 'CPRI'. rv_desc = 'Private Header (ABAP Objects)'.
      WHEN 'CPRO'. rv_desc = 'Protected Header (ABAP Objects)'.
      WHEN 'CINC'. rv_desc = 'Class Includes (ABAP Objects)'.
      WHEN 'FUNC'. rv_desc = 'Function Module'.
      WHEN 'FUGR'. rv_desc = 'Function Group'.
      WHEN 'PROG'. rv_desc = 'Program / Report'.
      WHEN 'REPS'. rv_desc = 'Report Source Code'.
      WHEN 'REPT'. rv_desc = 'Report Text Elements'.
      WHEN 'TABL'. rv_desc = 'Database Table'.
      WHEN 'DTEL'. rv_desc = 'Data Element'.
      WHEN 'DOMA'. rv_desc = 'Domain'.
      WHEN 'DDLS'. rv_desc = 'CDS View Entity'.
      WHEN 'BDEF'. rv_desc = 'Behavior Definition'.
      WHEN 'TRAN'. rv_desc = 'Transaction'.
      WHEN 'DEVC'. rv_desc = 'Package'.
      WHEN 'MSAG'. rv_desc = 'Message Class'.
      WHEN 'INTF'. rv_desc = 'Interface (ABAP Objects)'.
      WHEN OTHERS. rv_desc = iv_obj_type.
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
