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

  PROTECTED SECTION.
  PRIVATE SECTION.
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
ENDCLASS.

CLASS zcl_scort_tr_tree_query IMPLEMENTATION.

  METHOD if_rap_query_provider~select.
    "-- Step 1: Extract filter parameters from request
    DATA(lo_filter) = io_request->get_filter( ).
    DATA(lt_ranges) = lo_filter->get_as_ranges( ).

    DATA lv_trkorr    TYPE e070-trkorr.
    DATA lv_owner     TYPE e070-as4user.
    DATA lv_date_from TYPE d.
    DATA lv_date_to   TYPE d.
    DATA lv_trstatus  TYPE e070-trstatus.

    LOOP AT lt_ranges ASSIGNING FIELD-SYMBOL(<range>).
      CASE <range>-name.
        WHEN 'TRKORR'.
          READ TABLE <range>-range INDEX 1 ASSIGNING FIELD-SYMBOL(<r1>).
          IF sy-subrc = 0. lv_trkorr = <r1>-low. ENDIF.
        WHEN 'OWNER'.
          READ TABLE <range>-range INDEX 1 ASSIGNING FIELD-SYMBOL(<r2>).
          IF sy-subrc = 0. lv_owner = <r2>-low. ENDIF.
        WHEN 'AS4DATE'.
          READ TABLE <range>-range INDEX 1 ASSIGNING FIELD-SYMBOL(<r3>).
          IF sy-subrc = 0. lv_date_from = <r3>-low. lv_date_to = <r3>-high. ENDIF.
        WHEN 'TRSTATUS'.
          READ TABLE <range>-range INDEX 1 ASSIGNING FIELD-SYMBOL(<r4>).
          IF sy-subrc = 0. lv_trstatus = <r4>-low. ENDIF.
      ENDCASE.
    ENDLOOP.

    "-- Step 2: Build tree
    DATA(lt_nodes) = build_tree(
      iv_trkorr    = lv_trkorr
      iv_owner     = lv_owner
      iv_date_from = lv_date_from
      iv_date_to   = lv_date_to
      iv_trstatus  = lv_trstatus
    ).

    "-- Step 3: Convert to Custom Entity result structure (matching CDS CamelCase)
    DATA lt_result TYPE STANDARD TABLE OF zce_scort_tr_tree WITH DEFAULT KEY.
    DATA ls_result LIKE LINE OF lt_result.

    LOOP AT lt_nodes ASSIGNING FIELD-SYMBOL(<node>).
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
      CLEAR ls_result.
    ENDLOOP.

    "-- Step 4: Apply paging from request
    DATA(lv_offset) = io_request->get_paging( )->get_offset( ).
    DATA(lv_rows)   = io_request->get_paging( )->get_page_size( ).
    DATA(lv_total)  = lines( lt_result ).

    IF lv_rows > 0.
      DELETE lt_result FROM 1 TO lv_offset.
      IF lines( lt_result ) > lv_rows.
        DELETE lt_result FROM lv_rows + 1.
      ENDIF.
    ENDIF.

    io_response->set_total_number_of_records( CONV int8( lv_total ) ).
    io_response->set_data( lt_result ).
  ENDMETHOD.

  METHOD build_tree.
    "-- B1: SELECT TR Parents (strkorr IS INITIAL = root TR)
    DATA lt_tr_parents TYPE TABLE OF e070.
    DATA lv_tr_pattern TYPE string.
    DATA lv_owner_pattern TYPE string.

    IF iv_trkorr IS NOT INITIAL.
      lv_tr_pattern = iv_trkorr.
    ELSE.
      lv_tr_pattern = '%'.
    ENDIF.

    IF iv_owner IS NOT INITIAL.
      lv_owner_pattern = iv_owner.
    ELSE.
      lv_owner_pattern = '%'.
    ENDIF.

    SELECT trkorr, strkorr, as4user, as4date, trstatus
      FROM e070
      WHERE strkorr = ''
        AND trkorr  LIKE @lv_tr_pattern
        AND as4user LIKE @lv_owner_pattern
      INTO CORRESPONDING FIELDS OF TABLE @lt_tr_parents.

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

    DATA lt_objects TYPE TABLE OF e071.
    IF lt_tr_keys IS NOT INITIAL.
      SELECT trkorr, pgmid, object, obj_name, activity
        FROM e071
        FOR ALL ENTRIES IN @lt_tr_keys
        WHERE trkorr = @lt_tr_keys-trkorr
          AND pgmid  = 'R3TR'
        INTO CORRESPONDING FIELDS OF TABLE @lt_objects.
    ENDIF.

    "-- B4: Build hierarchy
    "-- Level 0: TR Parents
    LOOP AT lt_tr_parents ASSIGNING FIELD-SYMBOL(<tr>).
      DATA ls_node LIKE LINE OF rt_nodes.
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
      CLEAR ls_node.

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

        "-- Level 2: Objects under this Task
        LOOP AT lt_objects ASSIGNING FIELD-SYMBOL(<obj>)
            WHERE trkorr = <task>-trkorr.
          ls_node-node_id        = make_node_id(
            iv_trkorr   = <task>-trkorr
            iv_obj_name = <obj>-obj_name
          ).
          ls_node-parent_node_id = make_node_id( <task>-trkorr ).
          ls_node-tree_level     = 2.
          ls_node-node_type      = 'OBJ'.
          ls_node-trkorr         = <task>-trkorr.
          ls_node-parent_trkorr  = <task>-trkorr.
          ls_node-obj_name       = <obj>-obj_name.
          ls_node-obj_type       = <obj>-object.
          ls_node-pgmid          = <obj>-pgmid.
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
    "-- Build unique CHAR40 NodeID: Trkorr(20) + ObjName(20)
    rv_id = |{ iv_trkorr }{ iv_obj_name }|.
    rv_id = rv_id(40).
  ENDMETHOD.

ENDCLASS.
