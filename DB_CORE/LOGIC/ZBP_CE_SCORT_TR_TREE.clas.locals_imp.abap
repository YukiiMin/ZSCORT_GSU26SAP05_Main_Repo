CLASS lhc_TrTree DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR TrTree RESULT result.

    METHODS read FOR READ
      IMPORTING keys FOR READ TrTree RESULT result.

    METHODS ReleaseRequest FOR MODIFY
      IMPORTING keys FOR ACTION TrTree~ReleaseRequest RESULT result.

    METHODS ApplyToTarget FOR MODIFY
      IMPORTING keys FOR ACTION TrTree~ApplyToTarget RESULT result.
ENDCLASS.

CLASS lhc_TrTree IMPLEMENTATION.

  METHOD read.
    " Implementation for Unmanaged READ
    " For each key, extract TRKORR (first 20 chars if padded, but wait, make_node_id didn't pad).
    " Let's fetch using the query class directly.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      DATA(lv_trkorr) = CONV trkorr( <key>-NodeId(20) ). " Warning: might contain objname if not padded.
      " Fetch the TR tree for this TRKORR
      DATA(lt_nodes) = zcl_scort_tr_tree_query=>build_tree( iv_trkorr = lv_trkorr ).
      READ TABLE lt_nodes ASSIGNING FIELD-SYMBOL(<node>) WITH KEY node_id = <key>-NodeId.
      IF sy-subrc = 0.
        DATA ls_result LIKE LINE OF result.
        ls_result-NodeId = <node>-node_id.
        ls_result-NodeType = <node>-node_type.
        ls_result-TrStatus = <node>-tr_status.
        ls_result-Trkorr = <node>-trkorr.
        APPEND ls_result TO result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_instance_features.
    " Dynamic feature control (e.g., disable Release if already released)
    " Custom Entity keys are Trkorr, NodeId, etc.
    " Wait, since it's a virtual entity, we can just allow the action and do validation inside.
    READ ENTITIES OF zce_scort_tr_tree IN LOCAL MODE
      ENTITY TrTree
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_nodes).

    LOOP AT lt_nodes ASSIGNING FIELD-SYMBOL(<node>).
      DATA(lv_release_enabled) = if_abap_behv=>fc-o-enabled.
      DATA(lv_apply_enabled)   = if_abap_behv=>fc-o-enabled.

      IF <node>-NodeType = 'OBJ'.
        lv_release_enabled = if_abap_behv=>fc-o-disabled.
        lv_apply_enabled   = if_abap_behv=>fc-o-disabled.
      ELSE.
        IF <node>-TrStatus = 'R'.
          lv_release_enabled = if_abap_behv=>fc-o-disabled.
        ELSE.
          lv_apply_enabled   = if_abap_behv=>fc-o-disabled.
        ENDIF.
      ENDIF.

      APPEND VALUE #( %tky = <node>-%tky
                      %action-ReleaseRequest = lv_release_enabled
                      %action-ApplyToTarget  = lv_apply_enabled ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD ReleaseRequest.
    " Implementation for TR_RELEASE_REQUEST
    READ ENTITIES OF zce_scort_tr_tree IN LOCAL MODE
      ENTITY TrTree
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_nodes).

    LOOP AT lt_nodes ASSIGNING FIELD-SYMBOL(<node>).
      SELECT SINGLE trkorr, strkorr, trstatus FROM e070
        WHERE trkorr = @<node>-Trkorr
        INTO @DATA(ls_e070).

      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = <node>-%tky %msg = new_message( id = 'ZSCORT' number = '000' severity = if_abap_behv_message=>severity-error v1 = 'TR/Task not found' ) ) TO reported-trtree.
        CONTINUE.
      ENDIF.

      " If TR Cha, check if any Task is NOT released
      IF ls_e070-strkorr IS INITIAL.
        SELECT SINGLE trkorr FROM e070 WHERE strkorr = @ls_e070-trkorr AND trstatus <> 'R' INTO @DATA(lv_unreleased_task).
        IF sy-subrc = 0.
          APPEND VALUE #( %tky = <node>-%tky %msg = new_message( id = 'ZSCORT' number = '000' severity = if_abap_behv_message=>severity-error v1 = 'Chưa release hết Task con!' ) ) TO reported-trtree.
          CONTINUE.
        ENDIF.
      ENDIF.

      CALL FUNCTION 'TR_RELEASE_REQUEST'
        EXPORTING
          iv_trkorr                  = <node>-Trkorr
          iv_dialog                  = abap_false
          iv_display_export_log      = abap_false
        EXCEPTIONS
          OTHERS                     = 14.

      IF sy-subrc = 0 OR sy-subrc = 10.
        APPEND VALUE #( %tky = <node>-%tky %msg = new_message( id = 'ZSCORT' number = '000' severity = if_abap_behv_message=>severity-success v1 = 'Release thành công' ) ) TO reported-trtree.
      ELSE.
        APPEND VALUE #( %tky = <node>-%tky %msg = new_message( id = 'ZSCORT' number = '000' severity = if_abap_behv_message=>severity-error v1 = 'Release thất bại' ) ) TO reported-trtree.
      ENDIF.
      
      APPEND VALUE #( %tky = <node>-%tky %param = <node> ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD ApplyToTarget.
    " Implementation for ApplyToTarget (Mock logic for now, per user specs)
    READ ENTITIES OF zce_scort_tr_tree IN LOCAL MODE
      ENTITY TrTree
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_nodes).

    LOOP AT lt_nodes ASSIGNING FIELD-SYMBOL(<node>).
      " TODO: B3/B4/B5 as per whiteboard specs.
      APPEND VALUE #( %tky = <node>-%tky %msg = new_message( id = 'ZSCORT' number = '000' severity = if_abap_behv_message=>severity-success v1 = 'Applied to Target successfully' ) ) TO reported-trtree.
      APPEND VALUE #( %tky = <node>-%tky %param = <node> ) TO result.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
