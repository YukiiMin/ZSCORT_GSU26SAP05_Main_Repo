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
    ev_message = zcm_scort=>get_text_by_key(
                   is_t100_key = zcm_scort=>missing_tr_param
                   iv_attr1    = 'ReleaseRequest' ).
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
      ev_message = zcm_scort=>get_text_by_key(
                     is_t100_key = zcm_scort=>internal_error
                     iv_attr1    = CONV #( lx->get_text( ) ) ).
      RETURN.
  ENDTRY.

  ev_success = COND #( WHEN lv_ok = abap_true THEN 'X' ELSE space ).

  IF lv_msg IS NOT INITIAL.
    ev_message = lv_msg.
  ELSEIF lv_ok = abap_true.
    ev_message = zcm_scort=>get_text_by_key(
                   is_t100_key = zcm_scort=>tr_released_success
                   iv_attr1    = CONV #( iv_trkorr ) ).
  ELSE.
    ev_message = zcm_scort=>get_text_by_key(
                   is_t100_key = zcm_scort=>release_failed
                   iv_attr1    = CONV #( iv_trkorr )
                   iv_attr2    = 'Unknown error' ).
  ENDIF.

ENDFUNCTION.
