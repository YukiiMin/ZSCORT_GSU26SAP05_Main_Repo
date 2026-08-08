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
    " FE gửi TrTree('S40K…') — NodeId ≈ Trkorr (có thể pad space do CHAR40).
    DATA lv TYPE c LENGTH 40.
    lv = iv_node_id.
    rv_trkorr = lv(20).
    CONDENSE rv_trkorr.
  ENDMETHOD.

  METHOD msg.
    " Không dùng message class ZSCORT/000 (thường không tồn tại → dump).
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

      " 1) Exact NodeId
      READ TABLE lt_nodes ASSIGNING FIELD-SYMBOL(<node>)
        WITH KEY node_id = <key>-NodeId.
      " 2) Fallback: TR header của Trkorr
      IF sy-subrc <> 0.
        READ TABLE lt_nodes ASSIGNING <node>
          WITH KEY node_type = 'TR' trkorr = lv_trkorr.
      ENDIF.
      " 3) Fallback: bất kỳ node cùng Trkorr
      IF sy-subrc <> 0.
        READ TABLE lt_nodes ASSIGNING <node>
          WITH KEY trkorr = lv_trkorr.
      ENDIF.
      IF sy-subrc <> 0.
        " Synthesize minimal row so action key resolution does not dump
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
      " Trả đúng key FE gửi để %tky khớp
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
        " Chưa Release → chưa Apply
        lv_apply = if_abap_behv=>fc-o-disabled.
      ENDIF.

      APPEND VALUE #( %tky = <key>-%tky
                      %action-ReleaseRequest = lv_release
                      %action-ApplyToTarget  = lv_apply ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD ReleaseRequest.
    " Logic Release = ZCL026_SCORT_RELEASE_SERVICE (trong FM LOCAL).
    " Không gọi class trực tiếp từ RAP — CTS/AUTH RAISE/COMMIT → dump
    " BEHAVIOR_ILLEGAL_STATEMENT. FM + DESTINATION 'NONE' = LUW riêng.
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
                                    iv_text = 'Missing TR number' ) ) TO reported-trtree.
        CONTINUE.
      ENDIF.

      " TR cha: bắt release hết task trước (SAP + UI rule)
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
                                      iv_text = |Release task { lv_task } first| ) ) TO reported-trtree.
          CONTINUE.
        ENDIF.
      ENDIF.

      CLEAR: lv_ok, lv_msg, lv_status, lv_fm_ok, lv_fm_msg.
      " MESSAGE = text từ system_failure (FM thiếu / chưa RFC / dump trong FM)
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
        " 1 = system_failure: thường FM chưa có / chưa Remote-Enabled / dump ST22 trong FM
        lv_msg = |Release LUW failed: { lv_fm_msg }. SE37: Z_SCORT_TR_RELEASE_LOCAL → Attributes → Remote-Enabled + Activate. ST22 nếu dump|.
      ELSE.
        lv_ok  = xsdbool( lv_fm_ok = abap_true OR lv_fm_ok = 'X' ).
        lv_msg = CONV string( lv_fm_msg ).
      ENDIF.

      SELECT SINGLE trstatus FROM e070 WHERE trkorr = @lv_trkorr INTO @lv_status.
      " R/N = xong; O = đang export (vẫn coi release đã nhận — không downgrade thành fail)
      IF lv_ok = abap_true AND lv_status <> 'R' AND lv_status <> 'N' AND lv_status <> 'O'.
        lv_ok = abap_false.
        IF lv_msg IS INITIAL.
          lv_msg = |Release did not complete (status still { lv_status })|.
        ENDIF.
      ENDIF.

      IF lv_ok = abap_true.
        APPEND VALUE #( %tky = <key>-%tky
                        %msg = msg( iv_severity = if_abap_behv_message=>severity-success
                                    iv_text = COND #( WHEN lv_msg IS NOT INITIAL THEN lv_msg
                                                     ELSE |Released { lv_trkorr }| ) ) ) TO reported-trtree.
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
                                                     ELSE |Release failed: { lv_trkorr }| ) ) ) TO reported-trtree.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD ApplyToTarget.
    " Logic = ZCL026_SCORT_TARGET_APPLY (có COMMIT WORK).
    " Không gọi class trực tiếp từ BDEF → dump BEHAVIOR_ILLEGAL_STATEMENT.
    " FM Z_SCORT_TR_APPLY_LOCAL DESTINATION 'NONE' = LUW riêng.
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
                                    iv_text = 'Missing TR for ApplyToTarget' ) ) TO reported-trtree.
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
        lv_msg = |Apply LUW failed: { lv_fm_msg }. SE37: Z_SCORT_TR_APPLY_LOCAL Remote-Enabled + Activate|.
      ELSE.
        lv_ok  = xsdbool( lv_fm_ok = abap_true OR lv_fm_ok = 'X' ).
        lv_msg = CONV string( lv_fm_msg ).
      ENDIF.

      IF lv_ok = abap_true.
        APPEND VALUE #( %tky = <key>-%tky
                        %msg = msg( iv_severity = if_abap_behv_message=>severity-success
                                    iv_text = COND #( WHEN lv_msg IS NOT INITIAL THEN lv_msg
                                                     ELSE |Apply OK { lv_trkorr }| ) ) ) TO reported-trtree.
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
                                                     ELSE |Apply failed for { lv_trkorr }| ) ) ) TO reported-trtree.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
