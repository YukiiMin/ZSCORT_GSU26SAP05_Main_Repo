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

    METHODS extract_trkorr
      IMPORTING iv_node_id     TYPE zde_scort_node_id
      RETURNING VALUE(rv_trkorr) TYPE e070-trkorr.

    METHODS msg
      IMPORTING
        iv_severity TYPE if_abap_behv_message=>t_severity
        iv_text     TYPE clike
      RETURNING
        VALUE(ro_msg) TYPE REF TO if_abap_behv_message.
ENDCLASS.

CLASS lhc_TrTree IMPLEMENTATION.

  METHOD extract_trkorr.
    DATA lv TYPE c LENGTH 40.
    lv = iv_node_id.
    rv_trkorr = lv(20).
    CONDENSE rv_trkorr.
  ENDMETHOD.

  METHOD msg.
    TRY.
        ro_msg = new_message_with_text( severity = iv_severity text = CONV string( iv_text ) ).
      CATCH cx_root.
        CLEAR ro_msg.
    ENDTRY.
  ENDMETHOD.

  METHOD read.
    DATA ls_result LIKE LINE OF result.
    DATA lv_trkorr TYPE e070-trkorr.
    DATA lt_nodes  TYPE zcl_scort_tr_tree_query=>tt_nodes.

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      CLEAR ls_result.
      lv_trkorr = extract_trkorr( <key>-NodeId ).
      IF lv_trkorr IS INITIAL.
        CONTINUE.
      ENDIF.

      lt_nodes = zcl_scort_tr_tree_query=>build_tree( iv_trkorr = lv_trkorr ).

      READ TABLE lt_nodes ASSIGNING FIELD-SYMBOL(<node>)
        WITH KEY node_id = <key>-NodeId.
      IF sy-subrc <> 0.
        READ TABLE lt_nodes ASSIGNING <node>
          WITH KEY node_type = 'TR' trkorr = lv_trkorr.
      ENDIF.
      IF sy-subrc <> 0.
        READ TABLE lt_nodes ASSIGNING <node>
          WITH KEY trkorr = lv_trkorr.
      ENDIF.
      IF sy-subrc <> 0.
        ls_result-NodeId   = <key>-NodeId.
        ls_result-Trkorr   = lv_trkorr.
        ls_result-NodeType = 'TR'.
        SELECT SINGLE trstatus FROM e070 WHERE trkorr = @lv_trkorr INTO @ls_result-TrStatus.
        APPEND ls_result TO result.
        CONTINUE.
      ENDIF.

      ls_result-NodeId       = <node>-node_id.
      ls_result-ParentNodeId = <node>-parent_node_id.
      ls_result-TreeLevel    = <node>-tree_level.
      ls_result-NodeType     = <node>-node_type.
      ls_result-Trkorr       = <node>-trkorr.
      ls_result-ParentTrkorr = <node>-parent_trkorr.
      ls_result-Description  = <node>-description.
      ls_result-Owner        = <node>-owner.
      ls_result-As4date      = <node>-as4date.
      ls_result-TrStatus     = <node>-tr_status.
      ls_result-ObjName      = <node>-obj_name.
      ls_result-ObjType      = <node>-obj_type.
      ls_result-Pgmid        = <node>-pgmid.
      ls_result-NodeId = <key>-NodeId.
      APPEND ls_result TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_instance_features.
    DATA lv_trkorr TYPE e070-trkorr.
    DATA lv_status TYPE trstatus.
    DATA lv_release TYPE if_abap_behv=>t_xflag.
    DATA lv_apply   TYPE if_abap_behv=>t_xflag.

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      lv_trkorr = extract_trkorr( <key>-NodeId ).
      CLEAR lv_status.
      IF lv_trkorr IS NOT INITIAL.
        SELECT SINGLE trstatus FROM e070 WHERE trkorr = @lv_trkorr INTO @lv_status.
      ENDIF.

      lv_release = if_abap_behv=>fc-o-enabled.
      lv_apply   = if_abap_behv=>fc-o-enabled.
      IF lv_status = 'R'.
        lv_release = if_abap_behv=>fc-o-disabled.
      ELSEIF lv_status IS NOT INITIAL.
        lv_apply = if_abap_behv=>fc-o-disabled.
      ENDIF.

      APPEND VALUE #( %tky = <key>-%tky
                      %action-ReleaseRequest = lv_release
                      %action-ApplyToTarget  = lv_apply ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD ReleaseRequest.
    DATA lv_trkorr  TYPE e070-trkorr.
    DATA lv_ok      TYPE abap_bool.
    DATA lv_msg     TYPE string.
    DATA lv_status  TYPE trstatus.
    DATA lv_task    TYPE e070-trkorr.
    DATA lv_str     TYPE e070-strkorr.
    DATA lv_fm_ok   TYPE c LENGTH 1.
    DATA lv_fm_msg  TYPE c LENGTH 255.

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      lv_trkorr = extract_trkorr( <key>-NodeId ).
      IF lv_trkorr IS INITIAL.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-trtree.
        APPEND VALUE #( %tky = <key>-%tky
                        %msg = msg( iv_severity = if_abap_behv_message=>severity-error
                                    iv_text = zcm_scort=>get_text_by_key(
                                                is_t100_key = zcm_scort=>missing_tr_param
                                                iv_attr1    = 'ReleaseRequest' ) ) ) TO reported-trtree.
        CONTINUE.
      ENDIF.

      CLEAR: lv_str, lv_task.
      SELECT SINGLE strkorr FROM e070 WHERE trkorr = @lv_trkorr INTO @lv_str.
      IF sy-subrc = 0 AND lv_str IS INITIAL.
        SELECT SINGLE trkorr FROM e070
          WHERE strkorr = @lv_trkorr AND trstatus <> 'R'
          INTO @lv_task.
        IF sy-subrc = 0.
          APPEND VALUE #( %tky = <key>-%tky ) TO failed-trtree.
          APPEND VALUE #( %tky = <key>-%tky
                          %msg = msg( iv_severity = if_abap_behv_message=>severity-error
                                      iv_text = zcm_scort=>get_text_by_key(
                                                  is_t100_key = zcm_scort=>release_task_first
                                                  iv_attr1    = CONV #( lv_task ) ) ) ) TO reported-trtree.
          CONTINUE.
        ENDIF.
      ENDIF.

      CLEAR: lv_ok, lv_msg, lv_status, lv_fm_ok, lv_fm_msg.
      CALL FUNCTION 'Z_SCORT_TR_RELEASE_LOCAL'
        DESTINATION 'NONE'
        EXPORTING
          iv_trkorr  = lv_trkorr
          iv_dialog  = space
        IMPORTING
          ev_success = lv_fm_ok
          ev_message = lv_fm_msg
        EXCEPTIONS
          system_failure        = 1 MESSAGE lv_fm_msg
          communication_failure = 2 MESSAGE lv_fm_msg
          OTHERS                = 3.

      IF sy-subrc <> 0.
        lv_ok = abap_false.
        IF lv_fm_msg IS INITIAL.
          lv_fm_msg = |subrc { sy-subrc }|.
        ENDIF.
        lv_msg = |Release LUW failed: { lv_fm_msg }|.
      ELSE.
        lv_ok  = xsdbool( lv_fm_ok = abap_true OR lv_fm_ok = 'X' ).
        lv_msg = CONV string( lv_fm_msg ).
      ENDIF.

      SELECT SINGLE trstatus FROM e070 WHERE trkorr = @lv_trkorr INTO @lv_status.
      IF lv_ok = abap_true AND lv_status <> 'R' AND lv_status <> 'N' AND lv_status <> 'O'.
        lv_ok = abap_false.
        IF lv_msg IS INITIAL.
          lv_msg = zcm_scort=>get_text_by_key(
                     is_t100_key = zcm_scort=>release_incomplete
                     iv_attr1    = CONV #( lv_trkorr )
                     iv_attr2    = CONV #( lv_status ) ).
        ENDIF.
      ENDIF.

      IF lv_ok = abap_true.
        APPEND VALUE #( %tky = <key>-%tky
                        %msg = msg( iv_severity = if_abap_behv_message=>severity-success
                                    iv_text = COND #( WHEN lv_msg IS NOT INITIAL THEN lv_msg
                                                     ELSE zcm_scort=>get_text_by_key(
                                                            is_t100_key = zcm_scort=>tr_released_success
                                                            iv_attr1    = CONV #( lv_trkorr ) ) ) ) ) TO reported-trtree.
        APPEND VALUE #( %tky = <key>-%tky
                        %param = VALUE #( NodeId = <key>-NodeId
                                          Trkorr = lv_trkorr
                                          NodeType = COND #( WHEN lv_str IS NOT INITIAL THEN 'TASK' ELSE 'TR' )
                                          TrStatus = lv_status ) ) TO result.
      ELSE.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-trtree.
        APPEND VALUE #( %tky = <key>-%tky
                        %msg = msg( iv_severity = if_abap_behv_message=>severity-error
                                    iv_text = COND #( WHEN lv_msg IS NOT INITIAL THEN lv_msg
                                                     ELSE zcm_scort=>get_text_by_key(
                                                            is_t100_key = zcm_scort=>release_failed
                                                            iv_attr1    = CONV #( lv_trkorr ) ) ) ) ) TO reported-trtree.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD ApplyToTarget.
    DATA lv_trkorr TYPE e070-trkorr.
    DATA lv_ok     TYPE abap_bool.
    DATA lv_msg    TYPE string.
    DATA lv_fm_ok  TYPE c LENGTH 1.
    DATA lv_fm_msg TYPE c LENGTH 255.

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      lv_trkorr = extract_trkorr( <key>-NodeId ).
      IF lv_trkorr IS INITIAL.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-trtree.
        APPEND VALUE #( %tky = <key>-%tky
                        %msg = msg( iv_severity = if_abap_behv_message=>severity-error
                                    iv_text = zcm_scort=>get_text_by_key(
                                                is_t100_key = zcm_scort=>missing_tr_param
                                                iv_attr1    = 'ApplyToTarget' ) ) ) TO reported-trtree.
        CONTINUE.
      ENDIF.

      CLEAR: lv_ok, lv_msg, lv_fm_ok, lv_fm_msg.
      CALL FUNCTION 'Z_SCORT_TR_APPLY_LOCAL'
        DESTINATION 'NONE'
        EXPORTING
          iv_trkorr  = lv_trkorr
        IMPORTING
          ev_success = lv_fm_ok
          ev_message = lv_fm_msg
        EXCEPTIONS
          system_failure        = 1 MESSAGE lv_fm_msg
          communication_failure = 2 MESSAGE lv_fm_msg
          OTHERS                = 3.

      IF sy-subrc <> 0.
        lv_ok = abap_false.
        IF lv_fm_msg IS INITIAL.
          lv_fm_msg = |subrc { sy-subrc }|.
        ENDIF.
        lv_msg = |Apply LUW failed: { lv_fm_msg }|.
      ELSE.
        lv_ok  = xsdbool( lv_fm_ok = abap_true OR lv_fm_ok = 'X' ).
        lv_msg = CONV string( lv_fm_msg ).
      ENDIF.

      IF lv_ok = abap_true.
        APPEND VALUE #( %tky = <key>-%tky
                        %msg = msg( iv_severity = if_abap_behv_message=>severity-success
                                    iv_text = COND #( WHEN lv_msg IS NOT INITIAL THEN lv_msg
                                                     ELSE zcm_scort=>get_text_by_key(
                                                            is_t100_key = zcm_scort=>target_apply_started
                                                            iv_attr1    = CONV #( lv_trkorr ) ) ) ) ) TO reported-trtree.
        APPEND VALUE #( %tky = <key>-%tky
                        %param = VALUE #( NodeId = <key>-NodeId
                                          Trkorr = lv_trkorr
                                          NodeType = 'TR'
                                          Description = CONV as4text( lv_msg ) ) ) TO result.
      ELSE.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-trtree.
        APPEND VALUE #( %tky = <key>-%tky
                        %msg = msg( iv_severity = if_abap_behv_message=>severity-error
                                    iv_text = COND #( WHEN lv_msg IS NOT INITIAL THEN lv_msg
                                                     ELSE zcm_scort=>get_text_by_key(
                                                            is_t100_key = zcm_scort=>internal_error
                                                            iv_attr1    = |Apply failed for { lv_trkorr }| ) ) ) ) TO reported-trtree.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
