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
    ev_success = abap_false.

    " 1. Đọc thông tin từ bảng E070 để xác định loại Request
    SELECT SINGLE trkorr, strkorr, trstatus FROM e070
      WHERE trkorr = @iv_trkorr
      INTO @DATA(ls_e070).

    IF sy-subrc <> 0.
      ev_status  = 'UNKNOWN'.
      ev_message = zcm_scort=>get_text_by_key( is_t100_key = zcm_scort=>tr_not_found iv_attr1 = CONV #( iv_trkorr ) ).
      RETURN.
    ENDIF.

    " Tự động xác định Request Type
    ev_request_type = COND #( WHEN ls_e070-strkorr IS NOT INITIAL THEN 'TASK' ELSE 'REQUEST' ).
    ev_status       = ls_e070-trstatus.

    " 2. Kiểm tra nếu đã Released trước đó
    IF ls_e070-trstatus = 'R'.
      ev_message = zcm_scort=>get_text_by_key( is_t100_key = zcm_scort=>tr_already_released iv_attr1 = CONV #( iv_trkorr ) ).
      RETURN.
    ENDIF.

    " 3. Gọi Function Module chuẩn của SAP để Release (Không dính dáng tới Target Apply)
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
      " Đọc lại E070 — FM đôi khi trả 0 nhưng status chưa R (task còn mở, export chưa xong…)
      SELECT SINGLE trstatus FROM e070 WHERE trkorr = @iv_trkorr INTO @ev_status.
      IF ev_status = 'R'.
        ev_success = abap_true.
        IF ev_request_type = 'TASK'.
          ev_message = |Release thành công Task { iv_trkorr }. Object đã merge về TR Cha { ls_e070-strkorr }.|.
        ELSE.
          ev_message = |Release thành công Transport Request { iv_trkorr }.|.
          " Tự động Apply to Target sau khi TR Cha Release thành công
          DATA lv_apply_ok  TYPE abap_bool.
          DATA lv_apply_msg TYPE string.
          zcl026_scort_target_apply=>apply_to_target(
            EXPORTING iv_parent_trkorr = iv_trkorr
            IMPORTING ev_success       = lv_apply_ok
                      ev_message       = lv_apply_msg ).
          IF lv_apply_ok = abap_true.
            ev_message = ev_message && | (Apply to Target: OK)|.
          ELSE.
            ev_message = ev_message && | (Apply to Target LỖI: { lv_apply_msg })|.
          ENDIF.
        ENDIF.
      ELSE.
        ev_success = abap_false.
        ev_message = |Release { iv_trkorr } chưa hoàn tất (status={ ev_status }, FM subrc={ lv_fm_subrc }). Kiểm tra task còn mở / SE09.|.
      ENDIF.

    ELSE.
      ev_success = abap_false.
      " Map theo EXCEPTIONS ở CALL FUNCTION phía trên (không phải số chuẩn SAP toàn cục)
      CASE lv_fm_subrc.
        WHEN 1.
          ev_message = |Release { iv_trkorr }: CTS init failed|.
        WHEN 2.
          ev_message = |Release { iv_trkorr }: locked (enqueue) — thử lại / unlock SE03|.
        WHEN 3.
          ev_message = |Release { iv_trkorr }: no authorization|.
        WHEN 4.
          ev_message = |Release { iv_trkorr }: invalid request|.
        WHEN 5.
          ev_message = |Release { iv_trkorr }: already released|.
        WHEN 6.
          ev_message = |Release { iv_trkorr }: cannot repeat yet|.
        WHEN 7.
          ev_message = |Release { iv_trkorr }: object check error — Activate object (SE38/SE80), sửa syntax, rồi Release lại. Xem log SE09|.
        WHEN 8.
          ev_message = |Release { iv_trkorr }: object conversion error|.
        WHEN 9.
          ev_message = |Release { iv_trkorr }: model check error|.
        WHEN 10.
          " không vào đây (coi là success phía trên)
          ev_message = |Release { iv_trkorr }: released with warning|.
        WHEN 11.
          ev_message = |Release { iv_trkorr }: released with error — xem export log SE09|.
        WHEN 12.
          ev_message = |Release { iv_trkorr }: information to display (chạy SE09 Release để xem chi tiết)|.
        WHEN 13.
          ev_message = |Release { iv_trkorr }: cancelled|.
        WHEN OTHERS.
          ev_message = |Release { iv_trkorr } failed (subrc { lv_fm_subrc })|.
      ENDCASE.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
