CLASS zcl_scort_inactive_query DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

    TYPES:
      tt_inactive TYPE STANDARD TABLE OF zce_scort_inactive_objs WITH DEFAULT KEY.

    CLASS-METHODS query_inactive_objects
      IMPORTING
        iv_trkorr      TYPE trkorr
      RETURNING
        VALUE(rt_rows) TYPE tt_inactive.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


CLASS zcl_scort_inactive_query IMPLEMENTATION.

  METHOD if_rap_query_provider~select.
    DATA lv_trkorr TYPE trkorr.
    DATA lt_rows   TYPE tt_inactive.

    TRY.
        lv_trkorr = CONV #( zcl_scort_query_utl=>filter_low( io_request = io_request iv_field = 'TRKORR' ) ).
        IF lv_trkorr IS INITIAL.
          lv_trkorr = CONV #( zcl_scort_query_utl=>filter_low( io_request = io_request iv_field = 'PARENTTRKORR' ) ).
        ENDIF.

        IF lv_trkorr IS NOT INITIAL.
          lt_rows = query_inactive_objects( lv_trkorr ).
        ENDIF.

        zcl_scort_query_utl=>respond(
          EXPORTING io_request  = io_request
                    io_response = io_response
          CHANGING  ct_data     = lt_rows ).

      CATCH cx_root.
        CLEAR lt_rows.
        zcl_scort_query_utl=>respond(
          EXPORTING io_request  = io_request
                    io_response = io_response
          CHANGING  ct_data     = lt_rows ).
    ENDTRY.
  ENDMETHOD.

  METHOD query_inactive_objects.
    DATA lt_inactive TYPE zcl_scort_release_service=>tt_inactive_objs.
    DATA ls_row      TYPE zce_scort_inactive_objs.

    CLEAR rt_rows.
    IF iv_trkorr IS INITIAL.
      RETURN.
    ENDIF.

    lt_inactive = zcl_scort_release_service=>check_inactive_objects( iv_trkorr ).
    IF lt_inactive IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_inactive INTO DATA(ls_inact).
      CLEAR ls_row.

      ls_row-trkorr       = ls_inact-trkorr.
      ls_row-parenttrkorr = iv_trkorr.
      ls_row-objectname   = ls_inact-obj_name.
      ls_row-objecttype   = ls_inact-object.
      ls_row-uname        = ls_inact-uname.
      ls_row-status       = 'INACTIVE'.
      ls_row-shorttext    = zcm_scort=>get_text_by_key(
                              is_t100_key = zcm_scort=>inactive_object_found
                              iv_attr1    = CONV #( ls_inact-object )
                              iv_attr2    = CONV #( ls_inact-obj_name )
                              iv_attr3    = CONV #( ls_inact-uname ) ).

      APPEND ls_row TO rt_rows.
    ENDLOOP.

    SORT rt_rows BY objecttype objectname.
  ENDMETHOD.

ENDCLASS.
