CLASS zbp_ir_scort_obj_m DEFINITION
  PUBLIC
  ABSTRACT
  FINAL
  FOR BEHAVIOR OF zir_scort_obj_m.

  "! Behavior Pool for ZIR_SCORT_OBJ_M.
  "! Contains real logic for Action: checkDiff.
  "! checkDiff: Reads source from both sides, runs CL_ABAP_DIFF, returns diff summary in $self.
  PUBLIC SECTION.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zbp_ir_scort_obj_m IMPLEMENTATION.
ENDCLASS.

"=====================================================================
"  Local Class: Handler for checkDiff Action
"  (This is the CCIMP local class in ABAPGit structure)
"=====================================================================
CLASS lhc_zir_scort_obj_m DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS check_diff FOR ACTION
      ENTITY zir_scort_obj_m~checkdiff
      IMPORTING keys FOR checkdiff result[1].
ENDCLASS.

CLASS lhc_zir_scort_obj_m IMPLEMENTATION.

  METHOD check_diff.
    "-- Process each requested key
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      "-- Step 1: Read Local source code
      DATA lt_local_lines  TYPE string_table.
      DATA lt_target_lines TYPE string_table.

      "-- Get Local source via ZCL_SCORT_L_READER
      TRY.
          DATA(ls_local) = zcl_scort_l_reader=>read_object(
            iv_object_type = <key>-%key-objecttype
            iv_object_name = <key>-%key-objectname
          ).
          SPLIT ls_local-source_code_text
            AT cl_abap_char_utilities=>newline
            INTO TABLE lt_local_lines.
        CATCH cx_parameter_invalid.
          CLEAR lt_local_lines.
      ENDTRY.

      "-- Get Target source via ZCL_SCORT_T_READER
      TRY.
          DATA(ls_target) = zcl_scort_t_reader=>read_object(
            iv_object_type = <key>-%key-objecttype
            iv_object_name = <key>-%key-objectname
          ).
          SPLIT ls_target-source_code_text
            AT cl_abap_char_utilities=>newline
            INTO TABLE lt_target_lines.
        CATCH cx_parameter_invalid.
          CLEAR lt_target_lines.
      ENDTRY.

      "-- Step 2: Run CL_ABAP_DIFF to compare
      DATA lo_diff  TYPE REF TO cl_abap_diff.
      CREATE OBJECT lo_diff.

      DATA lt_diff_result TYPE cl_abap_diff=>ty_diffs.
      TRY.
          lt_diff_result = lo_diff->diff(
            source  = lt_local_lines
            target  = lt_target_lines
          ).
        CATCH cx_parameter_invalid.
          "-- Diff failed: continue
      ENDTRY.

      "-- Step 3: Count diff lines for summary
      DATA lv_added    TYPE i.
      DATA lv_removed  TYPE i.
      DATA lv_unchanged TYPE i.
      LOOP AT lt_diff_result ASSIGNING FIELD-SYMBOL(<diff>).
        CASE <diff>-type.
          WHEN 'A'. ADD 1 TO lv_added.
          WHEN 'D'. ADD 1 TO lv_removed.
          WHEN 'E'. ADD 1 TO lv_unchanged.
        ENDCASE.
      ENDLOOP.

      "-- Step 4: Build result entity — $self (return updated fields)
      "  Result entity maps back to ZIR_SCORT_OBJ_M row
      "  We signal back the compare status via Description field or custom ext field
      "  Here we reuse the ExistenceStatus field to flag diff result
      DATA ls_result LIKE LINE OF result.
      ls_result-%key             = <key>-%key.
      ls_result-%param-pgmid          = <key>-%key-pgmid.
      ls_result-%param-objecttype     = <key>-%key-objecttype.
      ls_result-%param-objectname     = <key>-%key-objectname.
      ls_result-%param-existencestatus = COND #(
        WHEN lv_added = 0 AND lv_removed = 0
          THEN 'IDENTICAL'
          ELSE 'DIFFERENT'
      ).
      APPEND ls_result TO result.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
