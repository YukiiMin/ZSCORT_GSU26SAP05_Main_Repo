CLASS zcl_scort_ai_http_handler DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_http_extension .
  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_request_payload,
        action      TYPE string,
        objectType  TYPE string,
        objectName  TYPE string,
        localCode   TYPE string,
        targetCode  TYPE string,
        language    TYPE string,
        mode        TYPE zcl_scort_ai_assistant=>tv_mode,
      END OF ty_request_payload.
ENDCLASS.



CLASS zcl_scort_ai_http_handler IMPLEMENTATION.

  METHOD if_http_extension~handle_request.
    DATA:
      lv_method    TYPE string,
      lv_body      TYPE string,
      ls_req       TYPE ty_request_payload,
      lv_resp_json TYPE string.

    lv_method = server->request->get_header_field( name = '~request_method' ).

    IF lv_method = 'OPTIONS'.
      server->response->set_header_field( name = 'Access-Control-Allow-Origin'  value = '*' ).
      server->response->set_header_field( name = 'Access-Control-Allow-Methods' value = 'GET, POST, OPTIONS' ).
      server->response->set_header_field( name = 'Access-Control-Allow-Headers' value = 'Content-Type, Authorization, X-Requested-With' ).
      server->response->set_status( code = 200 reason = 'OK' ).
      RETURN.
    ENDIF.

    server->response->set_header_field( name = 'Access-Control-Allow-Origin' value = '*' ).
    server->response->set_header_field( name = 'Content-Type' value = 'application/json; charset=utf-8' ).

    IF lv_method <> 'POST'.
      server->response->set_status( code = 405 reason = 'Method Not Allowed' ).
      DATA(lv_err_method) = zcm_scort=>get_text_by_key( is_t100_key = zcm_scort=>http_method_not_allowed iv_attr1 = lv_method ).
      server->response->set_cdata( '{"error": "' && lv_err_method && '"}' ).
      RETURN.
    ENDIF.

    lv_body = server->request->get_cdata( ).
    IF lv_body IS INITIAL.
      server->response->set_status( code = 400 reason = 'Bad Request' ).
      DATA(lv_err_empty) = zcm_scort=>get_text_by_key( is_t100_key = zcm_scort=>request_body_empty ).
      server->response->set_cdata( '{"error": "' && lv_err_empty && '"}' ).
      RETURN.
    ENDIF.

    /ui2/cl_json=>deserialize(
      EXPORTING
        json = lv_body
        pretty_name = /ui2/cl_json=>pretty_mode-camel_case
      CHANGING
        data = ls_req
    ).

    IF ls_req-mode IS INITIAL.
      ls_req-mode = zcl_scort_ai_assistant=>c_mode_gemini_direct.
    ENDIF.
    IF ls_req-language IS INITIAL.
      ls_req-language = 'en'.
    ENDIF.

    TRY.
        IF ls_req-action = 'SYNTAX'.
          lv_resp_json = zcl_scort_ai_assistant=>check_syntax_and_quality(
            iv_obj_type    = ls_req-objecttype
            iv_obj_name    = ls_req-objectname
            iv_local_code  = ls_req-localcode
            iv_target_code = ls_req-targetcode
            iv_lang        = ls_req-language
            iv_mode        = ls_req-mode
          ).
        ELSEIF ls_req-action = 'TRANSPORT'.
          lv_resp_json = zcl_scort_ai_assistant=>review_transport(
            iv_obj_type    = ls_req-objecttype
            iv_obj_name    = ls_req-objectname
            iv_local_code  = ls_req-localcode
            iv_target_code = ls_req-targetcode
            iv_lang        = ls_req-language
            iv_mode        = ls_req-mode
          ).
        ELSE.
          server->response->set_status( code = 400 reason = 'Invalid Action' ).
          DATA(lv_err_act) = zcm_scort=>get_text_by_key( is_t100_key = zcm_scort=>ai_invalid_action iv_attr1 = ls_req-action ).
          server->response->set_cdata( '{"error": "' && lv_err_act && '"}' ).
          RETURN.
        ENDIF.

        server->response->set_status( code = 200 reason = 'OK' ).
        server->response->set_cdata( lv_resp_json ).

      CATCH cx_root INTO DATA(lx_err).
        server->response->set_status( code = 500 reason = 'Internal Server Error' ).
        server->response->set_cdata( '{"error": "' && lx_err->get_text( ) && '"}' ).
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
