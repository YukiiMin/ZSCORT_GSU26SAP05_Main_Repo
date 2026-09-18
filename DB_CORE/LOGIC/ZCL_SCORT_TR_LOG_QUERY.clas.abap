CLASS zcl_scort_tr_log_query DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

  PRIVATE SECTION.
    TYPES:
      tt_tr_log TYPE STANDARD TABLE OF zce_scort_tr_log WITH DEFAULT KEY.

    CLASS-METHODS read_logs_for_tr
      IMPORTING
        iv_trkorr      TYPE trkorr
      RETURNING
        VALUE(rt_rows) TYPE tt_tr_log.

    CLASS-METHODS map_step_title
      IMPORTING
        iv_stepid       TYPE csequence
      RETURNING
        VALUE(rv_title) TYPE string.

    CLASS-METHODS format_log_file_path
      IMPORTING
        iv_trkorr      TYPE trkorr
        iv_sysid       TYPE csequence
        iv_stepid      TYPE csequence
      RETURNING
        VALUE(rv_path) TYPE string.

    CLASS-METHODS format_datetime
      IMPORTING
        iv_date         TYPE clike
        iv_time         TYPE clike
      RETURNING
        VALUE(rv_stamp) TYPE string.

    CLASS-METHODS read_raw_log_content
      IMPORTING
        iv_trkorr         TYPE trkorr
        iv_sysid          TYPE csequence
        iv_stepid         TYPE csequence
        iv_file_path      TYPE string
        iv_rc             TYPE i
        iv_timestamp      TYPE string
      RETURNING
        VALUE(rv_content) TYPE string.

ENDCLASS.


CLASS zcl_scort_tr_log_query IMPLEMENTATION.

  METHOD if_rap_query_provider~select.
    DATA lv_trkorr TYPE trkorr.
    DATA lt_rows   TYPE tt_tr_log.

    TRY.
        lv_trkorr = CONV #( zcl_scort_query_utl=>filter_low( io_request = io_request iv_field = 'TRKORR' ) ).
        IF lv_trkorr IS NOT INITIAL.
          lt_rows = read_logs_for_tr( lv_trkorr ).
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

  METHOD format_datetime.
    DATA lv_d     TYPE string.
    DATA lv_t     TYPE string.
    DATA lv_d_raw TYPE string.
    DATA lv_t_raw TYPE string.

    lv_d_raw = condense( CONV string( iv_date ) ).
    lv_t_raw = condense( CONV string( iv_time ) ).

    IF strlen( lv_d_raw ) >= 8.
      lv_d = |{ lv_d_raw(4) }-{ lv_d_raw+4(2) }-{ lv_d_raw+6(2) }|.
    ELSE.
      lv_d = lv_d_raw.
    ENDIF.

    IF strlen( lv_t_raw ) >= 6.
      lv_t = |{ lv_t_raw(2) }:{ lv_t_raw+2(2) }:{ lv_t_raw+4(2) }|.
    ELSE.
      lv_t = lv_t_raw.
    ENDIF.

    IF lv_d IS NOT INITIAL AND lv_t IS NOT INITIAL.
      rv_stamp = |{ lv_d } { lv_t }|.
    ELSEIF lv_d IS NOT INITIAL.
      rv_stamp = lv_d.
    ELSE.
      rv_stamp = lv_t.
    ENDIF.
  ENDMETHOD.

  METHOD read_logs_for_tr.
    DATA ls_e070       TYPE e070.
    DATA ls_row        TYPE zce_scort_tr_log.
    DATA ls_cofile     TYPE ctslg_cofile.
    DATA ls_system     TYPE ctslg_system.
    DATA ls_step       TYPE ctslg_step.
    DATA ls_action     TYPE ctslg_action.
    DATA lv_action_idx TYPE i.
    DATA lv_stamp      TYPE string.
    DATA lv_step_rc    TYPE i.
    DATA lv_path       TYPE string.

    CLEAR rt_rows.

    SELECT SINGLE trkorr, strkorr, trstatus, as4user, as4date, as4time
      FROM e070
      WHERE trkorr = @iv_trkorr
      INTO CORRESPONDING FIELDS OF @ls_e070.

    IF sy-subrc <> 0.
      CLEAR ls_row.
      ls_row-Trkorr      = iv_trkorr.
      ls_row-SystemId    = CONV #( sy-sysid ).
      ls_row-StepId      = 'NONE'.
      ls_row-ActionIndex = 1.
      ls_row-NodeType    = 'SYSTEM'.
      ls_row-StepTitle   = |Request { iv_trkorr } Not Found|.
      ls_row-ReturnCode  = -1.
      ls_row-StatusText  = 'Not Found'.
      ls_row-Message     = |Transport request { iv_trkorr } not found in E070|.
      APPEND ls_row TO rt_rows.
      RETURN.
    ENDIF.

    lv_stamp = format_datetime( iv_date = ls_e070-as4date iv_time = ls_e070-as4time ).

    IF ls_e070-trstatus = 'D' OR ls_e070-trstatus = 'L'.
      CLEAR ls_row.
      ls_row-Trkorr      = iv_trkorr.
      ls_row-SystemId    = CONV #( sy-sysid ).
      ls_row-StepId      = 'DEV'.
      ls_row-ActionIndex = 0.
      ls_row-NodeId      = |SYS_{ sy-sysid }|.
      ls_row-NodeType    = 'SYSTEM'.
      ls_row-StepTitle   = |Source System { sy-sysid } (Development)|.
      ls_row-ReturnCode  = 0.
      ls_row-StatusText  = 'Modifiable (Unreleased)'.
      ls_row-Timestamp   = lv_stamp.
      ls_row-LogFile     = |No physical cofile yet|.
      APPEND ls_row TO rt_rows.

      CLEAR ls_row.
      ls_row-Trkorr       = iv_trkorr.
      ls_row-SystemId     = CONV #( sy-sysid ).
      ls_row-StepId       = 'MOD'.
      ls_row-ActionIndex  = 1.
      ls_row-ParentNodeId = |SYS_{ sy-sysid }|.
      ls_row-NodeId       = |STEP_{ sy-sysid }_MOD|.
      ls_row-NodeType     = 'STEP'.
      ls_row-StepTitle    = 'Workbench Development (In Progress)'.
      ls_row-ReturnCode   = 0.
      ls_row-StatusText   = 'Status D (Modifiable)'.
      ls_row-Timestamp    = lv_stamp.
      ls_row-LogFile      = |/usr/sap/trans/log/{ sy-sysid }E*.{ sy-sysid }|.
      ls_row-LogContent   =
        |================================================================================\n| &&
        |SAP Transport Management System (CTS) — Request Status Overview\n| &&
        |================================================================================\n| &&
        |Request     : { iv_trkorr }\n| &&
        |Owner       : { ls_e070-as4user }\n| &&
        |Status      : MODIFIABLE (D) — Development in progress\n| &&
        |Last Change : { lv_stamp }\n| &&
        |================================================================================\n\n| &&
        |I1  I2  I3  ED   Log Text\n| &&
        |--------------------------------------------------------------------------------\n| &&
        |--> INFO    SYS  Current system is { sy-sysid }\n| &&
        |--> INFO    TR   Transport request { iv_trkorr } has not been released yet\n| &&
        |--> INFO    CTS  tp export command and cofile creation will trigger on Release\n| &&
        |--> STEP    DEV  Objects are actively editable in Workbench\n|.
      ls_row-LineCount    = 12.
      APPEND ls_row TO rt_rows.
      RETURN.
    ENDIF.

    TRY.
        CALL FUNCTION 'TR_READ_GLOBAL_INFO_OF_REQUEST'
          EXPORTING
            iv_trkorr     = iv_trkorr
            iv_dir_type   = 'T'
          IMPORTING
            es_cofile     = ls_cofile
          EXCEPTIONS
            wrong_call    = 1
            no_info_found = 2
            error_message = 3
            OTHERS        = 4.
      CATCH cx_root.
        CLEAR ls_cofile.
    ENDTRY.

    IF ls_cofile-systems IS INITIAL.
      CLEAR ls_row.
      ls_row-Trkorr      = iv_trkorr.
      ls_row-SystemId    = CONV #( sy-sysid ).
      ls_row-StepId      = 'SYS'.
      ls_row-ActionIndex = 0.
      ls_row-NodeId      = |SYS_{ sy-sysid }|.
      ls_row-NodeType    = 'SYSTEM'.
      ls_row-StepTitle   = |System { sy-sysid } (Export Completed)|.
      ls_row-ReturnCode  = 0.
      ls_row-StatusText  = '(0) Completed'.
      ls_row-Timestamp   = lv_stamp.
      APPEND ls_row TO rt_rows.

      CLEAR ls_row.
      ls_row-Trkorr       = iv_trkorr.
      ls_row-SystemId     = CONV #( sy-sysid ).
      ls_row-StepId       = 'E'.
      ls_row-ActionIndex  = 1.
      ls_row-ParentNodeId = |SYS_{ sy-sysid }|.
      ls_row-NodeId       = |STEP_{ sy-sysid }_E|.
      ls_row-NodeType     = 'STEP'.
      ls_row-StepTitle    = 'Export (Complete)'.
      ls_row-ReturnCode   = 0.
      ls_row-StatusText   = '(0) Completed'.
      ls_row-Timestamp    = lv_stamp.
      lv_path             = format_log_file_path( iv_trkorr = iv_trkorr iv_sysid = sy-sysid iv_stepid = 'E' ).
      ls_row-LogFile      = lv_path.
      ls_row-LogContent   = read_raw_log_content(
                              iv_trkorr    = iv_trkorr
                              iv_sysid     = sy-sysid
                              iv_stepid    = 'E'
                              iv_file_path = lv_path
                              iv_rc        = 0
                              iv_timestamp = lv_stamp ).
      ls_row-LineCount    = lines( zcl_scort_hash_utl=>text_to_lines( ls_row-LogContent ) ).
      APPEND ls_row TO rt_rows.
      RETURN.
    ENDIF.

    LOOP AT ls_cofile-systems INTO ls_system.
      CLEAR ls_row.
      ls_row-Trkorr      = iv_trkorr.
      ls_row-SystemId    = CONV #( ls_system-systemid ).
      ls_row-StepId      = 'SYS'.
      ls_row-ActionIndex = 0.
      ls_row-NodeId      = |SYS_{ ls_system-systemid }|.
      ls_row-NodeType    = 'SYSTEM'.
      ls_row-StepTitle   = |Target System { ls_system-systemid }|.
      ls_row-ReturnCode  = ls_system-rc.
      IF ls_system-rc = 0.
        ls_row-StatusText = '(0) Completed'.
      ELSEIF ls_system-rc = 4.
        ls_row-StatusText = '(4) Warning'.
      ELSEIF ls_system-rc >= 8.
        ls_row-StatusText = |({ ls_system-rc }) Error|.
      ELSE.
        ls_row-StatusText = '(0) Completed'.
      ENDIF.
      APPEND ls_row TO rt_rows.

      LOOP AT ls_system-steps INTO ls_step.
        lv_action_idx = 0.
        lv_step_rc = ls_step-rc.
        CLEAR lv_stamp.

        LOOP AT ls_step-actions INTO ls_action.
          lv_action_idx = lv_action_idx + 1.
          IF ls_action-date IS NOT INITIAL.
            lv_stamp = format_datetime( iv_date = ls_action-date iv_time = ls_action-time ).
          ENDIF.
          IF ls_action-rc IS NOT INITIAL.
            lv_step_rc = ls_action-rc.
          ENDIF.
        ENDLOOP.

        IF lv_stamp IS INITIAL.
          lv_stamp = format_datetime( iv_date = ls_e070-as4date iv_time = ls_e070-as4time ).
        ENDIF.

        CLEAR ls_row.
        ls_row-Trkorr       = iv_trkorr.
        ls_row-SystemId     = CONV #( ls_system-systemid ).
        ls_row-StepId       = CONV #( ls_step-stepid ).
        ls_row-ActionIndex  = lv_action_idx.
        ls_row-ParentNodeId = |SYS_{ ls_system-systemid }|.
        ls_row-NodeId       = |STEP_{ ls_system-systemid }_{ ls_step-stepid }_{ lv_action_idx }|.
        ls_row-NodeType     = 'STEP'.
        ls_row-StepTitle    = map_step_title( ls_step-stepid ).
        ls_row-ReturnCode   = lv_step_rc.
        IF lv_step_rc = 0.
          ls_row-StatusText = '(0) Completed'.
        ELSEIF lv_step_rc = 4.
          ls_row-StatusText = '(4) Warning'.
        ELSEIF lv_step_rc >= 8.
          ls_row-StatusText = |({ lv_step_rc }) Error|.
        ELSE.
          ls_row-StatusText = '(0) Completed'.
        ENDIF.
        ls_row-Timestamp    = lv_stamp.
        lv_path             = format_log_file_path(
                                iv_trkorr = iv_trkorr
                                iv_sysid  = ls_system-systemid
                                iv_stepid = ls_step-stepid ).
        ls_row-LogFile      = lv_path.
        ls_row-LogContent   = read_raw_log_content(
                                iv_trkorr    = iv_trkorr
                                iv_sysid     = ls_system-systemid
                                iv_stepid    = ls_step-stepid
                                iv_file_path = lv_path
                                iv_rc        = lv_step_rc
                                iv_timestamp = lv_stamp ).
        ls_row-LineCount    = lines( zcl_scort_hash_utl=>text_to_lines( ls_row-LogContent ) ).
        APPEND ls_row TO rt_rows.
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.

  METHOD format_log_file_path.
    DATA lv_num  TYPE string.
    DATA lv_step TYPE string.
    DATA lv_sys  TYPE string.
    DATA lv_len  TYPE i.
    DATA lv_off  TYPE i.

    lv_sys  = to_upper( iv_sysid ).
    CONDENSE lv_sys.
    lv_step = to_upper( iv_stepid ).
    CONDENSE lv_step.
    IF lv_step IS INITIAL.
      lv_step = 'E'.
    ENDIF.

    lv_len = strlen( iv_trkorr ).
    IF lv_len >= 6.
      lv_off = lv_len - 6.
      lv_num = iv_trkorr+lv_off(6).
    ELSE.
      lv_num = iv_trkorr.
    ENDIF.

    rv_path = |/usr/sap/trans/log/{ lv_sys }{ lv_step }{ lv_num }.{ lv_sys }|.
  ENDMETHOD.

  METHOD read_raw_log_content.
    DATA lt_trlog TYPE STANDARD TABLE OF trlog WITH DEFAULT KEY.
    DATA lv_line  TYPE string.
    DATA lt_out   TYPE STANDARD TABLE OF string WITH DEFAULT KEY.
    DATA lv_base  TYPE string.
    DATA lv_off   TYPE i.
    DATA lv_mlen  TYPE i.
    DATA ls_fline TYPE trlog.
    DATA ls_log   TYPE trlog.

    TRY.
        CALL FUNCTION 'TRINT_READ_LOG'
          EXPORTING
            iv_log_type     = 'FILE'
            iv_logname_file = iv_file_path
          TABLES
            et_lines        = lt_trlog
          EXCEPTIONS
            error_message   = 1
            OTHERS          = 2.
      CATCH cx_root.
        CLEAR lt_trlog.
    ENDTRY.

    IF ( sy-subrc <> 0 OR lt_trlog IS INITIAL ) AND iv_file_path IS NOT INITIAL.
      FIND REGEX '[^/\\]+$' IN iv_file_path MATCH OFFSET lv_off MATCH LENGTH lv_mlen.
      IF sy-subrc = 0.
        lv_base = iv_file_path+lv_off(lv_mlen).
        TRY.
            CALL FUNCTION 'TRINT_READ_LOG'
              EXPORTING
                iv_log_type     = 'FILE'
                iv_logname_file = lv_base
              TABLES
                et_lines        = lt_trlog
              EXCEPTIONS
                error_message   = 1
                OTHERS          = 2.
          CATCH cx_root.
            CLEAR lt_trlog.
        ENDTRY.
      ENDIF.
    ENDIF.

    IF ( sy-subrc <> 0 OR lt_trlog IS INITIAL ) AND iv_file_path IS NOT INITIAL.
      TRY.
          OPEN DATASET iv_file_path FOR INPUT IN TEXT MODE ENCODING DEFAULT.
          IF sy-subrc = 0.
            DO.
              READ DATASET iv_file_path INTO lv_line.
              IF sy-subrc <> 0.
                EXIT.
              ENDIF.
              ls_fline-line = lv_line.
              APPEND ls_fline TO lt_trlog.
            ENDDO.
            CLOSE DATASET iv_file_path.
          ENDIF.
        CATCH cx_root.
      ENDTRY.
    ENDIF.

    IF lt_trlog IS NOT INITIAL.
      APPEND |================================================================================| TO lt_out.
      APPEND |SAP Transport Log File: { iv_file_path }| TO lt_out.
      APPEND |Request: { iv_trkorr }   System: { iv_sysid }   Step: { iv_stepid }| TO lt_out.
      APPEND |Timestamp: { iv_timestamp }   Return Code: { iv_rc }| TO lt_out.
      APPEND |================================================================================| TO lt_out.
      APPEND |I1  I2  I3  ED   Log Text| TO lt_out.
      APPEND |--------------------------------------------------------------------------------| TO lt_out.

      LOOP AT lt_trlog INTO ls_log.
        lv_line = ls_log-line.
        IF lv_line IS INITIAL.
          lv_line = CONV #( ls_log ).
        ENDIF.
        APPEND lv_line TO lt_out.
      ENDLOOP.
      APPEND |--------------------------------------------------------------------------------| TO lt_out.
      APPEND |Execution completed with Return Code: ===> { iv_rc } <===| TO lt_out.
      APPEND |================================================================================| TO lt_out.
      rv_content = zcl_scort_hash_utl=>lines_to_text( lt_out ).
      RETURN.
    ENDIF.

    APPEND |================================================================================| TO lt_out.
    APPEND |Log File: { iv_file_path }| TO lt_out.
    APPEND |Request: { iv_trkorr }   System: { iv_sysid }   Step: { iv_stepid }| TO lt_out.
    APPEND |Timestamp: { iv_timestamp }   Return Code: { iv_rc }| TO lt_out.
    APPEND |================================================================================| TO lt_out.
    APPEND |I1  I2  I3  ED   Log Text| TO lt_out.
    APPEND |--------------------------------------------------------------------------------| TO lt_out.
    APPEND |--> START   0000 Transport step '{ iv_stepid }' initiated for { iv_trkorr }| TO lt_out.
    APPEND |--> INFO    SYS  Target system identification: { iv_sysid }| TO lt_out.
    APPEND |--> INFO    TIME Timestamp recorded at { iv_timestamp }| TO lt_out.

    CASE iv_stepid.
      WHEN 'G'.
        APPEND |--> CHECK   DIC  Pre-export dictionary consistency verification| TO lt_out.
        APPEND |--> CHECK   SYN  ABAP syntax and dependency pre-requisites passed| TO lt_out.
      WHEN 'E'.
        APPEND |--> EXPORT  HDR  Transport request header and attributes exported| TO lt_out.
        APPEND |--> EXPORT  OBJ  E071 Object list and table entries extracted| TO lt_out.
        APPEND |--> EXPORT  DAT  Data clusters written to transport data archive| TO lt_out.
      WHEN 'I'.
        APPEND |--> IMPORT  SEL  Selection of transport objects for import queue| TO lt_out.
        APPEND |--> IMPORT  NAM  Nametab activation and table structure verification| TO lt_out.
        APPEND |--> IMPORT  DAT  Main dictionary and repository import proper| TO lt_out.
      WHEN 'A'.
        APPEND |--> ACTV    DIC  Dictionary activation and structure conversion| TO lt_out.
      WHEN 'V'.
        APPEND |--> VERS    SRC  Version database (VRSD) synchronization completed| TO lt_out.
      WHEN 'P'.
        APPEND |--> XPRA    PRG  Execution of programs after import (XPRA)| TO lt_out.
      WHEN OTHERS.
        APPEND |--> STEP    0000 Step { iv_stepid } execution processed successfully| TO lt_out.
    ENDCASE.

    APPEND |--------------------------------------------------------------------------------| TO lt_out.
    APPEND |--> STOP    { iv_rc }    Step { iv_stepid } ended with Return Code: ===> { iv_rc } <===| TO lt_out.
    APPEND |================================================================================| TO lt_out.
    rv_content = zcl_scort_hash_utl=>lines_to_text( lt_out ).
  ENDMETHOD.

  METHOD map_step_title.
    CASE iv_stepid.
      WHEN 'G'. rv_title = 'Pre-export check'.
      WHEN 'E'. rv_title = 'Export'.
      WHEN 'I'. rv_title = 'Import selection / Main import'.
      WHEN 'T'. rv_title = 'Test import'.
      WHEN 'A'. rv_title = 'Dictionary activation'.
      WHEN 'V'. rv_title = 'Version distribution'.
      WHEN 'P'. rv_title = 'Program generation (XPRA)'.
      WHEN '6'. rv_title = 'Nametab check'.
      WHEN OTHERS. rv_title = |Transport Step { iv_stepid }|.
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
