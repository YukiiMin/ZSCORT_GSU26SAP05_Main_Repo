CLASS zcl026_scort_release_service DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_inactive_obj,
             object   TYPE dwinactiv-object,
             obj_name TYPE dwinactiv-obj_name,
             uname    TYPE dwinactiv-uname,
           END OF ty_inactive_obj,
           tt_inactive_objs TYPE STANDARD TABLE OF ty_inactive_obj WITH DEFAULT KEY.

    CLASS-METHODS check_inactive_objects
      IMPORTING
        iv_trkorr          TYPE trkorr
      RETURNING
        VALUE(rt_inactive) TYPE tt_inactive_objs.

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

  METHOD check_inactive_objects.
    CLEAR rt_inactive.

    SELECT pgmid, object, obj_name
      FROM e071
      WHERE trkorr = @iv_trkorr
         OR trkorr IN ( SELECT trkorr FROM e070 WHERE strkorr = @iv_trkorr )
      INTO TABLE @DATA(lt_e071_objs).

    IF lt_e071_objs IS INITIAL.
      RETURN.
    ENDIF.

    SELECT DISTINCT object, obj_name, uname
      FROM dwinactiv
      FOR ALL ENTRIES IN @lt_e071_objs
      WHERE obj_name = @lt_e071_objs-obj_name
      INTO TABLE @rt_inactive.

    LOOP AT lt_e071_objs INTO DATA(ls_obj) WHERE object = 'CLAS' OR object = 'FUGR' OR object = 'PROG'.
      DATA(lv_prefix) = |{ ls_obj-obj_name }%|.
      SELECT DISTINCT object, obj_name, uname
        FROM dwinactiv
        WHERE obj_name LIKE @lv_prefix
        APPENDING TABLE @rt_inactive.
    ENDLOOP.

    SORT rt_inactive BY object obj_name uname.
    DELETE ADJACENT DUPLICATES FROM rt_inactive COMPARING object obj_name uname.
  ENDMETHOD.

  METHOD process_release.
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

    DATA(lt_inactive) = check_inactive_objects( iv_trkorr ).
    IF lt_inactive IS NOT INITIAL.
      ev_success = abap_false.
      DATA(lv_inact_count) = lines( lt_inactive ).
      DATA lv_inact_list TYPE string.
      LOOP AT lt_inactive INTO DATA(ls_inact).
        IF lv_inact_list IS INITIAL.
          lv_inact_list = |{ ls_inact-object } { ls_inact-obj_name } ({ ls_inact-uname })|.
        ELSE.
          lv_inact_list = |{ lv_inact_list }, { ls_inact-object } { ls_inact-obj_name } ({ ls_inact-uname })|.
        ENDIF.
      ENDLOOP.

      ev_message = zcm_scort=>get_text_by_key(
                     is_t100_key = zcm_scort=>tr_has_inactive_objects
                     iv_attr1    = CONV #( iv_trkorr )
                     iv_attr2    = CONV #( lv_inact_count ) ).
      ev_message = |{ ev_message } [{ lv_inact_list }]|.
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
        object_check_error         = 6
        OTHERS                     = 7.

    DATA(lv_fm_subrc) = sy-subrc.
    IF lv_fm_subrc = 0.
      SELECT SINGLE trstatus FROM e070 WHERE trkorr = @iv_trkorr INTO @ev_status.
      IF ev_status = 'O'.
        DO 10 TIMES.
          WAIT UP TO 1 SECONDS.
          SELECT SINGLE trstatus FROM e070 WHERE trkorr = @iv_trkorr INTO @ev_status.
          IF ev_status = 'R' OR ev_status = 'N'.
            EXIT.
          ENDIF.
        ENDDO.
      ENDIF.

      IF ev_status = 'R' OR ev_status = 'N'.
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
        ENDIF.
      ELSEIF ev_status = 'O'.
        ev_success = abap_true.
        ev_message = zcm_scort=>get_text_by_key(
                       is_t100_key = zcm_scort=>release_started_bg
                       iv_attr1    = CONV #( iv_trkorr ) ).
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
        WHEN 1.
          ev_message = zcm_scort=>get_text_by_key( is_t100_key = zcm_scort=>cts_init_failed ).
        WHEN 2.
          ev_message = zcm_scort=>get_text_by_key( is_t100_key = zcm_scort=>object_locked ).
        WHEN 3.
          ev_message = zcm_scort=>get_text_by_key(
                         is_t100_key = zcm_scort=>no_release_auth
                         iv_attr1    = CONV #( iv_trkorr ) ).
        WHEN 4.
          ev_message = zcm_scort=>get_text_by_key(
                         is_t100_key = zcm_scort=>invalid_request
                         iv_attr1    = CONV #( iv_trkorr ) ).
        WHEN 5.
          ev_message = zcm_scort=>get_text_by_key(
                         is_t100_key = zcm_scort=>tr_already_released
                         iv_attr1    = CONV #( iv_trkorr ) ).
        WHEN 6.
          lt_inactive = check_inactive_objects( iv_trkorr ).
          IF lt_inactive IS NOT INITIAL.
            DATA(lv_cnt) = lines( lt_inactive ).
            DATA lv_details TYPE string.
            LOOP AT lt_inactive INTO DATA(ls_in).
              IF lv_details IS INITIAL.
                lv_details = |{ ls_in-object } { ls_in-obj_name } ({ ls_in-uname })|.
              ELSE.
                lv_details = |{ lv_details }, { ls_in-object } { ls_in-obj_name } ({ ls_in-uname })|.
              ENDIF.
            ENDLOOP.
            ev_message = zcm_scort=>get_text_by_key(
                           is_t100_key = zcm_scort=>release_check_inactive
                           iv_attr1    = CONV #( iv_trkorr )
                           iv_attr2    = CONV #( lv_cnt ) ).
            ev_message = |{ ev_message } [{ lv_details }]|.
          ELSE.
            ev_message = zcm_scort=>get_text_by_key(
                           is_t100_key = zcm_scort=>object_check_error
                           iv_attr1    = CONV #( iv_trkorr ) ).
          ENDIF.
        WHEN OTHERS.
          ev_message = zcm_scort=>get_text_by_key(
                         is_t100_key = zcm_scort=>release_failed
                         iv_attr1    = CONV #( iv_trkorr )
                         iv_attr2    = CONV #( lv_fm_subrc ) ).
      ENDCASE.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
