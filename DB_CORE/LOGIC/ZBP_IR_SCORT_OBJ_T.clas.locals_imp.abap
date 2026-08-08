CLASS lhc_TargetObject DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS read FOR READ
      IMPORTING keys FOR READ zir_scort_obj_t RESULT result.

    METHODS rba_Sourcecode FOR READ
      IMPORTING keys_rba FOR READ zir_scort_obj_t\_Sourcecode FULL result_requested RESULT result LINK association_links.
ENDCLASS.

CLASS lhc_TargetObject IMPLEMENTATION.
  METHOD read.
    IF keys IS NOT INITIAL.
      SELECT * FROM zir_scort_obj_t
        FOR ALL ENTRIES IN @keys
        WHERE ServerId = @keys-ServerId
          AND ObjectType = @keys-ObjectType
          AND ObjectName = @keys-ObjectName
        INTO CORRESPONDING FIELDS OF TABLE @result.
    ENDIF.
  ENDMETHOD.

  METHOD rba_Sourcecode.
    DATA ls_src TYPE zcr_scort_obj_src.
    DATA ls_link LIKE LINE OF association_links.

    LOOP AT keys_rba INTO DATA(ls_key).
      ls_src-ServerType = 'T'.
      ls_src-ObjectType = ls_key-ObjectType.
      ls_src-ObjectName = ls_key-ObjectName.

      TRY.
          DATA(ls_tgt) = zcl_scort_t_reader=>read_current(
                           iv_object_type = ls_key-ObjectType
                           iv_object_name = ls_key-ObjectName ).
          ls_src-VersionNo      = ls_tgt-version_no.
          ls_src-SourceCodeText = ls_tgt-text.
          ls_src-LineCount      = ls_tgt-line_count.
          ls_src-SrcHash        = CONV #( ls_tgt-hash_stored ).
          IF ls_src-SrcHash IS INITIAL.
            ls_src-SrcHash = CONV #( ls_tgt-hash_calc ).
          ENDIF.
          ls_src-Message        = ls_tgt-message.
        CATCH cx_root INTO DATA(lx).
          ls_src-Message = lx->get_text( ).
      ENDTRY.

      INSERT ls_src INTO TABLE result.

      ls_link-source-ServerId = ls_key-ServerId.
      ls_link-source-ObjectType = ls_key-ObjectType.
      ls_link-source-ObjectName = ls_key-ObjectName.
      ls_link-target-ServerType = ls_src-ServerType.
      ls_link-target-ObjectType = ls_src-ObjectType.
      ls_link-target-ObjectName = ls_src-ObjectName.
      INSERT ls_link INTO TABLE association_links.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
