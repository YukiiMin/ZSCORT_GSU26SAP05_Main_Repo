CLASS zcl026_scort_release_service DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    CLASS-METHODS process_release
      IMPORTING
        iv_trkorr       TYPE trkorr
        iv_dialog       TYPE abap_bool DEFAULT abap_false
      EXPORTING
        ev_success      TYPE abap_bool
        ev_request_type TYPE string
        ev_status       TYPE trstatus
        ev_message      TYPE string.
ENDCLASS.
CLASS zcl026_scort_release_service IMPLEMENTATION.

  METHOD process_release.
    DATA lv_apply_ok  TYPE abap_bool.
    DATA lv_apply_msg TYPE string.
    DATA lv_reason    TYPE string.

    ev_success = abap_false.

    SELECT SINGLE trkorr, strkorr, trstatus FROM e070
      WHERE trkorr = @iv_trkorr
      INTO @DATA(ls_e070).

    IF sy-subrc <> 0.
      ev_status  = 'UNKNOWN'.
      ev_message = zcm_scort=>get_text_by_key( is_t100_key = zcm_scort=>tr_not_found iv_attr1 = CONV #( iv_trkorr ) ).
      RETURN.
    ENDIF.

    ev_request_type = COND #( WHEN ls_e070-strkorr IS NOT INITIAL THEN 'TASK' ELSE 'REQUEST' ).
    ev_status       = ls_e070-trstatus.

    IF ls_e070-trstatus = 'R'.
      ev_message = zcm_scort=>get_text_by_key( is_t100_key = zcm_scort=>tr_already_released iv_attr1 = CONV #( iv_trkorr ) ).
      RETURN.
    ENDIF.

    CALL FUNCTION 'TR_RELEASE_REQUEST'
      EXPORTING
        iv_trkorr                  = iv_trkorr
        iv_dialog                  = iv_dialog
        iv_display_export_log      = abap_false
      EXCEPTIONS
        cts_initialization_failure = 1
        enqueue_failed             = 2
        no_authorization           = 3
        invalid_request            = 4
        request_already_released   = 5
        repeat_unable              = 6
        object_check_error         = 7
        object_conversion_error    = 8
        model_check_error          = 9
        released_with_warning      = 10
        released_with_error        = 11
        information_to_display     = 12
        cancelled                  = 13
        OTHERS                     = 14.

    DATA(lv_fm_subrc) = sy-subrc.
    IF lv_fm_subrc = 0 OR lv_fm_subrc = 10.
      SELECT SINGLE trstatus FROM e070 WHERE trkorr = @iv_trkorr INTO @ev_status.
      IF ev_status = 'R'.
        ev_success = abap_true.
        IF ev_request_type = 'TASK'.
          ev_message = zcm_scort=>get_text_by_key(
                         is_t100_key = zcm_scort=>task_released_success
                         iv_attr1    = CONV #( iv_trkorr )
                         iv_attr2    = CONV #( ls_e070-strkorr ) ).
        ELSE.
          ev_message = zcm_scort=>get_text_by_key(
                         is_t100_key = zcm_scort=>tr_released_success
                         iv_attr1    = CONV #( iv_trkorr ) ).
          zcl026_scort_target_apply=>apply_to_target(
            EXPORTING iv_parent_trkorr = iv_trkorr
            IMPORTING ev_success       = lv_apply_ok
                      ev_message       = lv_apply_msg ).
          IF lv_apply_ok = abap_true.
            ev_message = |{ ev_message } (Target Apply: OK)|.
          ELSE.
            ev_message = |{ ev_message } (Target Apply: { lv_apply_msg })|.
          ENDIF.
        ENDIF.
      ELSE.
        ev_success = abap_false.
        ev_message = zcm_scort=>get_text_by_key(
                       is_t100_key = zcm_scort=>release_incomplete
                       iv_attr1    = CONV #( iv_trkorr )
                       iv_attr2    = CONV #( ev_status )
                       iv_attr3    = CONV #( lv_fm_subrc ) ).
      ENDIF.
    ELSE.
      ev_success = abap_false.
      CASE lv_fm_subrc.
        WHEN 1.  lv_reason = 'CTS init failed'.
        WHEN 2.  lv_reason = 'Object locked (enqueue)'.
        WHEN 3.  lv_reason = 'No authorization'.
        WHEN 4.  lv_reason = 'Invalid request'.
        WHEN 5.  lv_reason = 'Already released'.
        WHEN 6.  lv_reason = 'Cannot repeat yet'.
        WHEN 7.  lv_reason = 'Object check error'.
        WHEN 8.  lv_reason = 'Object conversion error'.
        WHEN 9.  lv_reason = 'Model check error'.
        WHEN 11. lv_reason = 'Released with error'.
        WHEN 12. lv_reason = 'Information to display'.
        WHEN 13. lv_reason = 'Cancelled'.
        WHEN OTHERS. lv_reason = |Subrc { lv_fm_subrc }|.
      ENDCASE.
      ev_message = zcm_scort=>get_text_by_key(
                     is_t100_key = zcm_scort=>release_failed
                     iv_attr1    = CONV #( iv_trkorr )
                     iv_attr2    = lv_reason ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
