FUNCTION z_scort_tr_apply_local
  IMPORTING
    VALUE(iv_trkorr) TYPE trkorr
    VALUE(iv_objects_json) TYPE string OPTIONAL
  EXPORTING
    VALUE(ev_success) TYPE char1
    VALUE(ev_message) TYPE char255.



  DATA:
    lv_ok  TYPE abap_bool,
    lv_msg TYPE string.

  CLEAR: ev_success, ev_message.

  IF iv_trkorr IS INITIAL.
    ev_success = space.
    ev_message = zcm_scort=>get_text_by_key(
                   is_t100_key = zcm_scort=>missing_tr_param
                   iv_attr1    = 'ApplyToTarget' ).
    RETURN.
  ENDIF.

  DATA lt_selected TYPE zcl026_scort_target_apply=>tt_selected_objs.
  IF iv_objects_json IS NOT INITIAL.
    IF iv_objects_json CS '{' OR iv_objects_json CS '['.
      /ui2/cl_json=>deserialize(
        EXPORTING json = iv_objects_json
        CHANGING  data = lt_selected ).
    ELSE.
      SPLIT iv_objects_json AT ',' INTO TABLE DATA(lt_tokens).
      LOOP AT lt_tokens INTO DATA(lv_tok).
        SPLIT lv_tok AT ':' INTO DATA(lv_type) DATA(lv_name).
        IF lv_name IS NOT INITIAL.
          APPEND VALUE #( object = lv_type obj_name = lv_name ) TO lt_selected.
        ENDIF.
      ENDLOOP.
    ENDIF.
  ENDIF.

  TRY.
      zcl026_scort_target_apply=>apply_to_target(
        EXPORTING
          iv_parent_trkorr    = iv_trkorr
          it_selected_objects = lt_selected
        IMPORTING
          ev_success          = lv_ok
          ev_message          = lv_msg ).
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
                   is_t100_key = zcm_scort=>target_apply_success
                   iv_attr1    = CONV #( iv_trkorr )
                   iv_attr2    = '0' ).
  ELSE.
    ev_message = zcm_scort=>get_text_by_key(
                   is_t100_key = zcm_scort=>internal_error
                   iv_attr1    = CONV #( iv_trkorr ) ).
  ENDIF.

ENDFUNCTION.
