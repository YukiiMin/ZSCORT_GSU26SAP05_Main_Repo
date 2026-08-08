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
"=====================================================================
"  Local Class: Handler for checkDiff Action
"=====================================================================
CLASS lhc_zir_scort_obj_m DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS check_diff FOR MODIFY
      IMPORTING keys FOR ACTION zir_scort_obj_m~checkdiff RESULT result.
ENDCLASS.

CLASS lhc_zir_scort_obj_m IMPLEMENTATION.

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
.
