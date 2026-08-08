CLASS zcl_scort_tr_tree_query DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  "! Query Provider for Custom Entity ZCE_SCORT_TR_TREE.
  "! Builds a 3-level virtual hierarchy tree from E070/E07T/E071:
  "!   Level 0 (NodeType=TR)   : TR Request (E070 where strkorr IS INITIAL)
  "!   Level 1 (NodeType=TASK) : TR Task    (E070 where strkorr = parent Trkorr)
  "!   Level 2 (NodeType=OBJ)  : Objects    (E071 for each Task/TR)
  "! NodeID = left-padded Trkorr+ObjName (max CHAR40, unique).
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
      RETURNING
        VALUE(rt_nodes) TYPE tt_nodes.

    CLASS-METHODS make_node_id
      IMPORTING
        iv_trkorr    TYPE e070-trkorr
        iv_obj_name  TYPE e071-obj_name  OPTIONAL
      RETURNING
        VALUE(rv_id) TYPE zde_scort_node_id.

  PROTECTED SECTION.
  PRIVATE SECTION.

ENDCLASS.

CLASS zcl_scort_tr_tree_query IMPLEMENTATION.

  METHOD if_rap_query_provider~select.
    "-- Custom entity: MUST respect $top/$skip or SADL raises
    "-- CX_RAP_QUERY_PAGE_SIZE_OVERRUN → CX_SADL_DUMP_APPL_MODEL_ERROR (ST22).
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

        DATA(lt_nodes) = build_tree(
          iv_trkorr    = lv_trkorr
          iv_owner     = lv_owner
          iv_date_from = lv_date_from
          iv_date_to   = lv_date_to
          iv_trstatus  = lv_trstatus ).

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

        " Paging — default cap 100 khi unlimited (tránh PAGE_SIZE_OVERRUN)
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
    "-- B1: SELECT TR Parents (strkorr IS INITIAL = root TR)
    DATA lt_tr_parents TYPE TABLE OF e070.
    DATA lv_tr_pattern TYPE string.
    DATA lv_owner_pattern TYPE string.

    " OData Contains gửi *…* — ABAP LIKE cần %…%. filter_low đã strip */% → bọc lại.
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

    " Chỉ SELECT field dùng — ORDER BY as4time mà không select → dump trên nhiều hệ.
    SELECT trkorr, strkorr, as4user, as4date, as4time, trstatus
      FROM e070
      WHERE strkorr = @space
        AND trkorr  LIKE @lv_tr_pattern
        AND as4user LIKE @lv_owner_pattern
      ORDER BY as4date DESCENDING, as4time DESCENDING
      INTO CORRESPONDING FIELDS OF TABLE @lt_tr_parents
      UP TO 200 ROWS.

    IF lt_tr_parents IS INITIAL. RETURN. ENDIF.

    "-- Filter status & dates if requested
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

    "-- B1b: Get descriptions from E07T for all selected TRs
    DATA lt_tr_texts TYPE TABLE OF e07t.
    SELECT trkorr, langu, as4text
      FROM e07t
      FOR ALL ENTRIES IN @lt_tr_parents
      WHERE trkorr = @lt_tr_parents-trkorr
        AND langu  = @sy-langu
      INTO CORRESPONDING FIELDS OF TABLE @lt_tr_texts.

    "-- B2: SELECT Tasks (strkorr = parent TR)
    DATA lt_tasks TYPE TABLE OF e070.
    SELECT trkorr, strkorr, as4user, as4date, trstatus
      FROM e070
      FOR ALL ENTRIES IN @lt_tr_parents
      WHERE strkorr = @lt_tr_parents-trkorr
      INTO CORRESPONDING FIELDS OF TABLE @lt_tasks.

    "-- B3: SELECT Objects for all TRs and Tasks
    DATA lt_tr_keys TYPE TABLE OF e070.
    lt_tr_keys = lt_tr_parents.
    APPEND LINES OF lt_tasks TO lt_tr_keys.
    SORT lt_tr_keys BY trkorr.
    DELETE ADJACENT DUPLICATES FROM lt_tr_keys COMPARING trkorr.

    " R3TR + LIMU — TR Modifiable (D) thường chỉ có LIMU trên E071 (SE09 vẫn hiện object).
    DATA lt_objects TYPE TABLE OF e071.
    DATA lt_e071_raw TYPE TABLE OF e071.
    DATA ls_e071_out TYPE e071.
    DATA lv_pg TYPE e071-pgmid.
    DATA lv_ob TYPE e071-object.
    IF lt_tr_keys IS NOT INITIAL.
      SELECT trkorr, pgmid, object, obj_name
        FROM e071
        FOR ALL ENTRIES IN @lt_tr_keys
        WHERE trkorr = @lt_tr_keys-trkorr
          AND ( pgmid = 'R3TR' OR pgmid = 'LIMU' )
        INTO CORRESPONDING FIELDS OF TABLE @lt_e071_raw.

      LOOP AT lt_e071_raw INTO DATA(ls_e071_raw).
        CLEAR ls_e071_out.
        ls_e071_out = ls_e071_raw.
        IF ls_e071_raw-pgmid = 'LIMU'.
          lv_pg = 'R3TR'.
          CASE ls_e071_raw-object.
            WHEN 'REPS' OR 'REPT'.
              lv_ob = 'PROG'.
            WHEN 'FUNC'.
              lv_ob = 'FUGR'.
            WHEN 'CPUB' OR 'CPRI' OR 'CPRO' OR 'CLSD' OR 'METH' OR 'CINC'.
              lv_ob = 'CLAS'.
            WHEN OTHERS.
              CONTINUE.
          ENDCASE.
          ls_e071_out-pgmid  = lv_pg.
          ls_e071_out-object = lv_ob.
        ENDIF.
        APPEND ls_e071_out TO lt_objects.
      ENDLOOP.

      SORT lt_objects BY trkorr object obj_name.
      DELETE ADJACENT DUPLICATES FROM lt_objects COMPARING trkorr object obj_name.
    ENDIF.

    "-- B4: Build hierarchy
    DATA ls_node TYPE ty_node.
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

      "-- Level 1: Tasks under this TR
      LOOP AT lt_tasks ASSIGNING FIELD-SYMBOL(<task>)
          WHERE strkorr = <tr>-trkorr.
        ls_node-node_id        = make_node_id( <task>-trkorr ).
        ls_node-parent_node_id = make_node_id( <tr>-trkorr ).
        ls_node-tree_level     = 1.
        ls_node-node_type      = 'TASK'.
        ls_node-trkorr         = <task>-trkorr.
        ls_node-parent_trkorr  = <tr>-trkorr.
        ls_node-owner          = <task>-as4user.
        ls_node-as4date        = <task>-as4date.
        ls_node-tr_status      = <task>-trstatus.
        APPEND ls_node TO rt_nodes.
        CLEAR ls_node.

        "-- Level 2: Virtual Folders for Object Types, Level 3: Objects
        DATA lv_current_type TYPE e071-object.
        CLEAR lv_current_type.

        LOOP AT lt_objects ASSIGNING FIELD-SYMBOL(<obj>)
            WHERE trkorr = <task>-trkorr.

          IF lv_current_type <> <obj>-object.
            lv_current_type = <obj>-object.
            " Create FOLD node
            ls_node-node_id        = make_node_id(
              iv_trkorr   = <task>-trkorr
              iv_obj_name = |#{ <obj>-object }|
            ).
            ls_node-parent_node_id = make_node_id( <task>-trkorr ).
            ls_node-tree_level     = 2.
            ls_node-node_type      = 'FOLD'.
            ls_node-trkorr         = <task>-trkorr.
            ls_node-parent_trkorr  = <tr>-trkorr.
            ls_node-owner          = ''.
            ls_node-tr_status      = ''.
            ls_node-obj_type       = <obj>-object.
            ls_node-obj_name       = <obj>-object. " Fallback
            ls_node-description    = <obj>-object. " Folder label
            APPEND ls_node TO rt_nodes.
          ENDIF.

          " Create OBJ node
          ls_node-node_id        = make_node_id(
            iv_trkorr   = <task>-trkorr
            iv_obj_name = <obj>-obj_name
          ).
          ls_node-parent_node_id = make_node_id(
            iv_trkorr   = <task>-trkorr
            iv_obj_name = |#{ <obj>-object }|
          ).
          ls_node-tree_level     = 3.
          ls_node-node_type      = 'OBJ'.
          ls_node-trkorr         = <task>-trkorr.
          ls_node-parent_trkorr  = <tr>-trkorr.
          ls_node-owner          = ''.
          ls_node-tr_status      = ''.
          ls_node-obj_type       = <obj>-object.
          ls_node-obj_name       = <obj>-obj_name.
          ls_node-pgmid          = <obj>-pgmid.
          ls_node-description    = ''. " We can leave blank or use standard text
          APPEND ls_node TO rt_nodes.
          CLEAR ls_node.
        ENDLOOP.
      ENDLOOP.

      "-- Objects directly under TR (no task assignment, strkorr=TR)
      LOOP AT lt_objects ASSIGNING FIELD-SYMBOL(<obj2>)
          WHERE trkorr = <tr>-trkorr.
        ls_node-node_id        = make_node_id(
          iv_trkorr   = <tr>-trkorr
          iv_obj_name = <obj2>-obj_name
        ).
        ls_node-parent_node_id = make_node_id( <tr>-trkorr ).
        ls_node-tree_level     = 1.
        ls_node-node_type      = 'OBJ'.
        ls_node-trkorr         = <tr>-trkorr.
        ls_node-parent_trkorr  = <tr>-trkorr.
        ls_node-obj_name       = <obj2>-obj_name.
        ls_node-obj_type       = <obj2>-object.
        ls_node-pgmid          = <obj2>-pgmid.
        APPEND ls_node TO rt_nodes.
        CLEAR ls_node.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD make_node_id.
    "-- TR/TASK: NodeId = Trkorr (khớp FE ApplyToTarget key TrTree('S40K…')).
    "-- OBJ: Trkorr + '_' + ObjName (cắt 40).
    DATA lv TYPE string.
    IF iv_obj_name IS INITIAL.
      lv = CONV string( iv_trkorr ).
    ELSE.
      lv = |{ CONV string( iv_trkorr ) }_{ CONV string( iv_obj_name ) }|.
    ENDIF.
    CONDENSE lv.
    IF strlen( lv ) > 40.
      lv = lv(40).
    ENDIF.
    rv_id = lv.
  ENDMETHOD.

ENDCLASS.
