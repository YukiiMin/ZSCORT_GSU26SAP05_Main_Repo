*"======================================================================
*" Z_SCORT_TR_RELEASE_LOCAL | Function Group: ZSCORT_FG_LOCAL
*"
*" Wrapper LUW → ZCL026_SCORT_RELEASE_SERVICE=>PROCESS_RELEASE
*"
*" Nếu ADT vẫn báo Field unknown: mở FM → tab Parameters → Add thủ công
*"   IV_TRKORR  Import  TYPE TRKORR     Pass Value
*"   IV_DIALOG  Import  TYPE CHAR1      Pass Value  Optional
*"   EV_SUCCESS Export  TYPE CHAR1      Pass Value
*"   EV_MESSAGE Export  TYPE CHAR255    Pass Value
*" rồi Attributes → Remote-Enabled → Activate.
*"======================================================================

FUNCTION z_scort_tr_release_local
  IMPORTING
    VALUE(iv_trkorr) TYPE trkorr
    VALUE(iv_dialog) TYPE char1 OPTIONAL
  EXPORTING
    VALUE(ev_success) TYPE char1
    VALUE(ev_message) TYPE char255.

  DATA:
    lv_ok     TYPE abap_bool,
    lv_msg    TYPE string,
    lv_status TYPE trstatus,
    lv_dialog TYPE abap_bool.

  CLEAR: ev_success, ev_message.

  IF iv_trkorr IS INITIAL.
    ev_success = space.
    ev_message = 'Trkorr is initial'.
    RETURN.
  ENDIF.

  lv_dialog = boolc( iv_dialog IS NOT INITIAL ).

  TRY.
      zcl026_scort_release_service=>process_release(
        EXPORTING
          iv_trkorr  = iv_trkorr
          iv_dialog  = lv_dialog
        IMPORTING
          ev_success = lv_ok
          ev_status  = lv_status
          ev_message = lv_msg ).
    CATCH cx_root INTO DATA(lx).
      ev_success = space.
      ev_message = |ZCL026: { lx->get_text( ) }|.
      RETURN.
  ENDTRY.

  ev_success = COND #( WHEN lv_ok = abap_true THEN 'X' ELSE space ).

  IF lv_msg IS NOT INITIAL.
    ev_message = lv_msg.
  ELSEIF lv_ok = abap_true.
    ev_message = |Released { iv_trkorr } (status={ lv_status })|.
  ELSE.
    ev_message = |Release failed { iv_trkorr }|.
  ENDIF.

ENDFUNCTION.
