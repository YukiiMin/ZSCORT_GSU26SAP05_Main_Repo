*"======================================================================
*" Z_SCORT_TR_APPLY_LOCAL | Function Group: ZSCORT_FG_LOCAL
*"
*" Wrapper LUW → ZCL026_SCORT_TARGET_APPLY=>APPLY_TO_TARGET
*" (class có COMMIT WORK — cấm gọi trực tiếp từ RAP BDEF)
*"
*" SE37: Remote-Enabled + Pass Value. Nếu Field unknown → tab Parameters:
*"   IV_TRKORR   Import TYPE TRKORR   Pass Value
*"   EV_SUCCESS  Export TYPE CHAR1    Pass Value
*"   EV_MESSAGE  Export TYPE CHAR255  Pass Value
*"======================================================================

FUNCTION z_scort_tr_apply_local
  IMPORTING
    VALUE(iv_trkorr) TYPE trkorr
  EXPORTING
    VALUE(ev_success) TYPE char1
    VALUE(ev_message) TYPE char255.

  DATA:
    lv_ok  TYPE abap_bool,
    lv_msg TYPE string.

  CLEAR: ev_success, ev_message.

  IF iv_trkorr IS INITIAL.
    ev_success = space.
    ev_message = 'Trkorr is initial'.
    RETURN.
  ENDIF.

  TRY.
      zcl026_scort_target_apply=>apply_to_target(
        EXPORTING
          iv_parent_trkorr = iv_trkorr
        IMPORTING
          ev_success       = lv_ok
          ev_message       = lv_msg ).
    CATCH cx_root INTO DATA(lx).
      ev_success = space.
      ev_message = |ZCL026_TARGET_APPLY: { lx->get_text( ) }|.
      RETURN.
  ENDTRY.

  ev_success = COND #( WHEN lv_ok = abap_true THEN 'X' ELSE space ).

  IF lv_msg IS NOT INITIAL.
    ev_message = lv_msg.
  ELSEIF lv_ok = abap_true.
    ev_message = |Apply OK { iv_trkorr }|.
  ELSE.
    ev_message = |Apply failed { iv_trkorr }|.
  ENDIF.

ENDFUNCTION.
