CLASS lhc_LocalObject DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS read FOR READ
      IMPORTING keys FOR READ zir_scort_obj_l RESULT result.

    METHODS rba_Sourcecode FOR READ
      IMPORTING keys_rba FOR READ zir_scort_obj_l\_Sourcecode FULL result_requested RESULT result LINK association_links.
ENDCLASS.

CLASS lhc_LocalObject IMPLEMENTATION.
  METHOD read.
    IF keys IS NOT INITIAL.
      SELECT * FROM zir_scort_obj_l
        FOR ALL ENTRIES IN @keys
        WHERE Pgmid = @keys-Pgmid
          AND ObjectType = @keys-ObjectType
          AND ObjectName = @keys-ObjectName
        INTO CORRESPONDING FIELDS OF TABLE @result.
    ENDIF.
  ENDMETHOD.

  METHOD rba_Sourcecode.
    DATA ls_src TYPE zcr_scort_obj_src.
    DATA ls_link LIKE LINE OF association_links.

    LOOP AT keys_rba INTO DATA(ls_key).
      ls_src-ServerType = 'L'.
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
ENDCLASS.
