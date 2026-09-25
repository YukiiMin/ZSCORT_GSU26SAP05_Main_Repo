CLASS zcl_scort_release_service DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_inactive_obj,
             trkorr   TYPE e070-trkorr,
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
CLASS zcl_scort_release_service IMPLEMENTATION.

  METHOD check_inactive_objects.
    CLEAR rt_inactive.

    TYPES: BEGIN OF ty_e071_obj,
             trkorr   TYPE e070-trkorr,
             pgmid    TYPE e071-pgmid,
             object   TYPE e071-object,
             obj_name TYPE e071-obj_name,
           END OF ty_e071_obj,
           BEGIN OF ty_dwinactiv_fae,
             obj_name TYPE dwinactiv-obj_name,
           END OF ty_dwinactiv_fae.

    DATA lt_e071_objs TYPE STANDARD TABLE OF ty_e071_obj WITH DEFAULT KEY.
    DATA lt_fae_objs  TYPE STANDARD TABLE OF ty_dwinactiv_fae WITH DEFAULT KEY.
    DATA lt_inact_raw TYPE STANDARD TABLE OF ty_inactive_obj WITH DEFAULT KEY.

    SELECT trkorr, pgmid, object, obj_name
      FROM e071
      WHERE trkorr = @iv_trkorr
         OR trkorr IN ( SELECT trkorr FROM e070 WHERE strkorr = @iv_trkorr )
      INTO TABLE @lt_e071_objs.

    IF lt_e071_objs IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_e071_objs INTO DATA(ls_e071).
      DATA(lv_fae_name) = CONV dwinactiv-obj_name( ls_e071-obj_name ).
      CONDENSE lv_fae_name.
      IF lv_fae_name IS NOT INITIAL.
        APPEND VALUE #( obj_name = lv_fae_name ) TO lt_fae_objs.
      ENDIF.
    ENDLOOP.

    SORT lt_fae_objs BY obj_name.
    DELETE ADJACENT DUPLICATES FROM lt_fae_objs COMPARING obj_name.

    IF lt_fae_objs IS NOT INITIAL.
      SELECT DISTINCT object, obj_name, uname
        FROM dwinactiv
        FOR ALL ENTRIES IN @lt_fae_objs
        WHERE obj_name = @lt_fae_objs-obj_name
        INTO CORRESPONDING FIELDS OF TABLE @lt_inact_raw.
    ENDIF.

    LOOP AT lt_e071_objs INTO ls_e071 WHERE object = 'CLAS' OR object = 'FUGR' OR object = 'PROG'.
      DATA lv_name_clean TYPE dwinactiv-obj_name.
      lv_name_clean = ls_e071-obj_name.
      CONDENSE lv_name_clean.
      IF lv_name_clean IS NOT INITIAL.
        DATA(lv_prefix) = |{ lv_name_clean }%|.
        SELECT DISTINCT object, obj_name, uname
          FROM dwinactiv
          WHERE obj_name LIKE @lv_prefix
          APPENDING CORRESPONDING FIELDS OF TABLE @lt_inact_raw.
      ENDIF.
    ENDLOOP.

    SORT lt_inact_raw BY object obj_name uname.
    DELETE ADJACENT DUPLICATES FROM lt_inact_raw COMPARING object obj_name uname.

    LOOP AT lt_inact_raw INTO DATA(ls_raw).
      DATA lv_matched_trkorr TYPE e070-trkorr.
      CLEAR lv_matched_trkorr.
      READ TABLE lt_e071_objs INTO ls_e071 WITH KEY obj_name = ls_raw-obj_name.
      IF sy-subrc = 0.
        lv_matched_trkorr = ls_e071-trkorr.
      ELSE.
        LOOP AT lt_e071_objs INTO ls_e071 WHERE object = 'CLAS' OR object = 'FUGR' OR object = 'PROG'.
          lv_name_clean = ls_e071-obj_name.
          CONDENSE lv_name_clean.
          IF lv_name_clean IS NOT INITIAL AND ls_raw-obj_name CP |{ lv_name_clean }*|.
            lv_matched_trkorr = ls_e071-trkorr.
            EXIT.
          ENDIF.
        ENDLOOP.
      ENDIF.

      IF lv_matched_trkorr IS INITIAL.
        lv_matched_trkorr = iv_trkorr.
      ENDIF.

      APPEND VALUE #( trkorr   = lv_matched_trkorr
                      object   = ls_raw-object
                      obj_name = ls_raw-obj_name
                      uname    = ls_raw-uname ) TO rt_inactive.
    ENDLOOP.

    SORT rt_inactive BY trkorr object obj_name uname.
    DELETE ADJACENT DUPLICATES FROM rt_inactive COMPARING trkorr object obj_name uname.
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
          lv_inact_list = |{ ls_inact-object } { ls_inact-obj_name } ({ ls_inact-uname } @ { ls_inact-trkorr })|.
        ELSE.
          lv_inact_list = |{ lv_inact_list }, { ls_inact-object } { ls_inact-obj_name } ({ ls_inact-uname } @ { ls_inact-trkorr })|.
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
                lv_details = |{ ls_in-object } { ls_in-obj_name } ({ ls_in-uname } @ { ls_in-trkorr })|.
              ELSE.
                lv_details = |{ lv_details }, { ls_in-object } { ls_in-obj_name } ({ ls_in-uname } @ { ls_in-trkorr })|.
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
