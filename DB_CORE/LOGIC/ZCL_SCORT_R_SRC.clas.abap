CLASS zcl_scort_r_src DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  "! Query Provider for Custom Entity ZCR_SCORT_OBJ_SRC.
  "! Gateway class: reads ServerType from filter, routes to
  "! ZCL_SCORT_L_READER (ServerType='L') or ZCL_SCORT_T_READER (ServerType='T').
  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_scort_r_src IMPLEMENTATION.

  METHOD if_rap_query_provider~select.
    DATA lt_result      TYPE STANDARD TABLE OF zcr_scort_obj_src.
    DATA ls_result      LIKE LINE OF lt_result.
    DATA lt_filter_cond TYPE if_rap_query_provider=>tt_name_value_pair.

    "-- Step 1: Extract filter conditions from the request
    DATA(lo_filter) = io_request->get_filter( ).
    DATA(lt_ranges) = lo_filter->get_as_ranges( ).

    DATA lv_server_type TYPE c LENGTH 1.
    DATA lv_object_type TYPE tadir-object.
    DATA lv_object_name TYPE tadir-obj_name.

    "-- Parse filter values for key fields
    LOOP AT lt_ranges ASSIGNING FIELD-SYMBOL(<range>).
      CASE <range>-name.
        WHEN 'SERVERTYPE'.
          IF <range>-t_range IS NOT INITIAL.
            READ TABLE <range>-t_range INDEX 1 ASSIGNING FIELD-SYMBOL(<r>).
            IF sy-subrc = 0.
              lv_server_type = <r>-low.
            ENDIF.
          ENDIF.
        WHEN 'OBJECTTYPE'.
          IF <range>-t_range IS NOT INITIAL.
            READ TABLE <range>-t_range INDEX 1 ASSIGNING FIELD-SYMBOL(<rt>).
            IF sy-subrc = 0.
              lv_object_type = <rt>-low.
            ENDIF.
          ENDIF.
        WHEN 'OBJECTNAME'.
          IF <range>-t_range IS NOT INITIAL.
            READ TABLE <range>-t_range INDEX 1 ASSIGNING FIELD-SYMBOL(<rn>).
            IF sy-subrc = 0.
              lv_object_name = <rn>-low.
            ENDIF.
          ENDIF.
      ENDCASE.
    ENDLOOP.

    "-- Guard: key fields required
    IF lv_object_type IS INITIAL OR lv_object_name IS INITIAL.
      io_response->set_total_number_of_records( 0 ).
      RETURN.
    ENDIF.

    "-- Step 2: Branch by ServerType
    ls_result-server_type   = lv_server_type.
    ls_result-object_type   = lv_object_type.
    ls_result-object_name   = lv_object_name.

    CASE lv_server_type.
      WHEN 'L'.
        "-- Delegate to Local reader
        TRY.
            DATA(ls_l) = zcl_scort_l_reader=>read_object(
              iv_object_type = lv_object_type
              iv_object_name = lv_object_name
            ).
            ls_result-source_code_text = ls_l-source_code_text.
            ls_result-metadata_text    = ls_l-metadata_text.
            ls_result-package_name     = ls_l-package_name.
            ls_result-author           = ls_l-author.
            ls_result-description      = ls_l-description.
          CATCH cx_parameter_invalid.
            ls_result-source_code_text = `[Error reading Local source]`.
        ENDTRY.

      WHEN 'T'.
        "-- Delegate to Target reader
        TRY.
            DATA(ls_t) = zcl_scort_t_reader=>read_object(
              iv_object_type = lv_object_type
              iv_object_name = lv_object_name
            ).
            ls_result-source_code_text = ls_t-source_code_text.
            ls_result-metadata_text    = ls_t-metadata_text.
            ls_result-package_name     = ls_t-package_name.
            ls_result-author           = ls_t-author.
            ls_result-description      = ls_t-description.
          CATCH cx_parameter_invalid.
            ls_result-source_code_text = `[Error reading Target source]`.
        ENDTRY.

      WHEN OTHERS.
        ls_result-source_code_text = `[Invalid ServerType. Use L or T]`.
    ENDCASE.

    "-- Step 3: Return result set
    APPEND ls_result TO lt_result.
    io_response->set_total_number_of_records( 1 ).
    io_response->set_data( lt_result ).
  ENDMETHOD.

ENDCLASS.
