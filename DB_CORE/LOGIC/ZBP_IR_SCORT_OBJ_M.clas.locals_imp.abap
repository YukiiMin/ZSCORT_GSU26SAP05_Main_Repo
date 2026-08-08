CLASS lhc_zir_scort_obj_m DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS rba_Sourcecode FOR READ
      IMPORTING keys_rba FOR READ zir_scort_obj_m\_Sourcecode FULL result_requested RESULT result LINK association_links.

    METHODS check_diff FOR MODIFY
      IMPORTING keys FOR ACTION zir_scort_obj_m~checkdiff RESULT result.
ENDCLASS.

CLASS lhc_zir_scort_obj_m IMPLEMENTATION.
  METHOD rba_Sourcecode.
    DATA ls_src TYPE zcr_scort_obj_src.
    DATA ls_link LIKE LINE OF association_links.

    LOOP AT keys_rba INTO DATA(ls_key).
      ls_src-ServerType = 'L'. " default for matrix if not specified
      ls_src-ObjectType = ls_key-ObjectType.
      ls_src-ObjectName = ls_key-ObjectName.

      TRY.
          DATA(ls_ori) = zcl_scort_l_reader=>read_active(
                           iv_object_type = ls_key-ObjectType
                           iv_object_name = ls_key-ObjectName ).
          ls_src-VersionNo      = zcl_scort_v_reader=>c_vers_active.
          ls_src-SourceCodeText = ls_ori-text.
          ls_src-LineCount      = ls_ori-line_count.
          ls_src-SrcHash        = CONV #( ls_ori-hash ).
          ls_src-Message        = ls_ori-message.
        CATCH cx_root INTO DATA(lx).
          ls_src-Message = lx->get_text( ).
      ENDTRY.

      INSERT ls_src INTO TABLE result.

      ls_link-source-Pgmid = ls_key-Pgmid.
      ls_link-source-ObjectType = ls_key-ObjectType.
      ls_link-source-ObjectName = ls_key-ObjectName.
      ls_link-target-ServerType = ls_src-ServerType.
      ls_link-target-ObjectType = ls_src-ObjectType.
      ls_link-target-ObjectName = ls_src-ObjectName.
      INSERT ls_link INTO TABLE association_links.
    ENDLOOP.
  ENDMETHOD.

  METHOD check_diff.
    "-- Process each requested key
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      "-- Step 1: Read Local source code via ZCL_SCORT_L_READER
      DATA(ls_local) = zcl_scort_l_reader=>read_active(
        iv_object_type = <key>-%key-objecttype
        iv_object_name = <key>-%key-objectname
      ).

      "-- Step 2: Read Target source code via ZCL_SCORT_T_READER
      DATA(ls_target) = zcl_scort_t_reader=>read_current(
        iv_object_type = <key>-%key-objecttype
        iv_object_name = <key>-%key-objectname
      ).

      "-- Step 3: Compare Hashes (ABAP Cloud compliant — no CL_ABAP_DIFF needed)
      DATA lv_status TYPE string.
      IF ls_local-found = abap_false OR ls_target-found = abap_false.
        lv_status = 'SOURCE_MISSING'.
      ELSEIF ls_local-hash = ls_target-hash_stored OR ( ls_target-hash_calc IS NOT INITIAL AND ls_local-hash = ls_target-hash_calc ).
        lv_status = 'IDENTICAL'.
      ELSE.
        lv_status = 'DIFFERENT'.
      ENDIF.

      "-- Step 4: Build result entity — $self (return updated fields)
      DATA ls_result LIKE LINE OF result.
      ls_result-%key                  = <key>-%key.
      ls_result-%param-pgmid          = <key>-%key-pgmid.
      ls_result-%param-objecttype     = <key>-%key-objecttype.
      ls_result-%param-objectname     = <key>-%key-objectname.
      ls_result-%param-existencestatus = lv_status.
      APPEND ls_result TO result.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
