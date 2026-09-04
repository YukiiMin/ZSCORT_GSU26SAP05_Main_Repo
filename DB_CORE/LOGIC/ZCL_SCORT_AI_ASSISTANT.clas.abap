CLASS zcl_scort_ai_assistant DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES:
      tv_mode TYPE c LENGTH 1,
      BEGIN OF ty_syntax_finding,
        type            TYPE string,
        line_or_snippet TYPE string,
        message         TYPE string,
        suggestion      TYPE string,
      END OF ty_syntax_finding,
      tt_syntax_finding TYPE STANDARD TABLE OF ty_syntax_finding WITH EMPTY KEY,

      BEGIN OF ty_syntax_result,
        syntax_status      TYPE string,
        syntax_score       TYPE string,
        clean_abap_verdict TYPE string,
        summary            TYPE string,
        findings           TYPE tt_syntax_finding,
      END OF ty_syntax_result,

      BEGIN OF ty_transport_result,
        summary        TYPE string,
        risks          TYPE string_table,
        recommendation TYPE string,
        reason         TYPE string,
        impact_level   TYPE string,
      END OF ty_transport_result.

    CONSTANTS:
      c_mode_gemini_direct TYPE tv_mode VALUE 'G',
      c_mode_sap_ai_core   TYPE tv_mode VALUE 'S'.

    CLASS-METHODS:
      class_constructor,

      check_syntax_and_quality
        IMPORTING
          iv_obj_type      TYPE csequence
          iv_obj_name      TYPE csequence
          iv_local_code    TYPE string
          iv_target_code   TYPE string OPTIONAL
          iv_lang          TYPE string DEFAULT space  " space = auto-detect from sy-langu
          iv_mode          TYPE tv_mode DEFAULT c_mode_gemini_direct
          iv_model         TYPE string OPTIONAL
        RETURNING
          VALUE(rv_json)   TYPE string
        RAISING
          cx_static_check,

      review_transport
        IMPORTING
          iv_obj_type      TYPE csequence
          iv_obj_name      TYPE csequence
          iv_local_code    TYPE string
          iv_target_code   TYPE string OPTIONAL
          iv_lang          TYPE string DEFAULT space  " space = auto-detect from sy-langu
          iv_mode          TYPE tv_mode DEFAULT c_mode_gemini_direct
          iv_model         TYPE string OPTIONAL
        RETURNING
          VALUE(rv_json)   TYPE string
        RAISING
          cx_static_check.

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_api_key_entry,
        key_val TYPE string,
      END OF ty_api_key_entry,
      tt_api_keys TYPE STANDARD TABLE OF ty_api_key_entry WITH EMPTY KEY.

    CLASS-DATA:
      gt_api_keys        TYPE tt_api_keys,
      gv_current_key_idx TYPE i VALUE 1,
      gt_models          TYPE string_table.

    CLASS-METHODS:
      get_next_api_key
        RETURNING
          VALUE(rv_key) TYPE string,

      call_gemini_with_failover
        IMPORTING
          iv_prompt      TYPE string
          iv_model       TYPE string OPTIONAL
        RETURNING
          VALUE(rv_json) TYPE string
        RAISING
          cx_static_check,

      call_sap_ai_core
        IMPORTING
          iv_prompt           TYPE string
          iv_destination_name TYPE rfcdest DEFAULT 'SAP_AI_CORE_DEST'
        RETURNING
          VALUE(rv_json)      TYPE string
        RAISING
          cx_static_check,

      build_syntax_prompt
        IMPORTING
          iv_obj_type      TYPE csequence
          iv_obj_name      TYPE csequence
          iv_local_code    TYPE string
          iv_target_code   TYPE string
          iv_lang          TYPE string
        RETURNING
          VALUE(rv_prompt) TYPE string,

      build_transport_prompt
        IMPORTING
          iv_obj_type      TYPE csequence
          iv_obj_name      TYPE csequence
          iv_local_code    TYPE string
          iv_target_code   TYPE string
          iv_lang          TYPE string
        RETURNING
          VALUE(rv_prompt) TYPE string,

      """ Resolve user language to AI prompt instruction.
      """ Priority: 1) iv_lang passed explicitly, 2) sy-langu of current SAP session.
      resolve_language
        IMPORTING
          iv_lang          TYPE string DEFAULT space
        RETURNING
          VALUE(rv_lang_text) TYPE string,

      escape_json_string
        IMPORTING
          iv_raw         TYPE string
        RETURNING
          VALUE(rv_clean) TYPE string,

      add_line_numbers
        IMPORTING
          iv_code        TYPE string
        RETURNING
          VALUE(rv_code) TYPE string.

ENDCLASS.



CLASS zcl_scort_ai_assistant IMPLEMENTATION.

  METHOD class_constructor.
    CLEAR gt_api_keys.
    DATA(lt_b64) = VALUE string_table(
      ( `QUl6YVN5QnFDNG9lZDBTOC02MFpDREd4cmFhWVBqVGo1SHgwS3BB` )
      ( `QVEuQWI4Uk42S2JiQmZCaHpEWlE0dHl0MDN4cWlaX3h4Tl9iSDRENjFvZTBaQWpfVnptVUE=` )
      ( `QVEuQWI4Uk42THdFZ0dpUHJ5RlBJODVkR2VSb21idTFpb2t3R0JqYUtaLUNnRjFJQTRHRVE=` )
      ( `QVEuQWI4Uk42THRSbXdaaWdwT05aNTUyQ1hCQlVTcG5tVmNqY1JrSzZEbldCekF1RlpOc2c=` )
      ( `QVEuQWI4Uk42S1ZHaUdQWXhDZGJUTWhoYm9ydDhRU25jZHRvbDhabTRHR0U2bk40NFZ1M3c=` )
      ( `QVEuQWI4Uk42TGhQeFo2blFHcVJkdnpUQVlaNjByUVVVamhPSDU4Ymxld2UzbkVTU05Kc0E=` )
      ( `QVEuQWI4Uk42SU14MXM3akdJMUpIc1pNZjQ5QkxDd1ZjcEJibFpOSFBHSHpfVmQ1aVJYQ0E=` )
      ( `QVEuQWI4Uk42TG9xcl9MQkdoR3poeG90V3N0VTVlbFpnenVWd2tubi1XTXB3dzdxeUQtTHc=` )
      ( `QUl6YVN5QjFzRjJRdGlTLVRSalFQVGxMdHVYMlc0RkkxQ3NObWYw` )
    ).
    LOOP AT lt_b64 INTO DATA(lv_b64).
      APPEND VALUE #( key_val = cl_http_utility=>decode_base64( lv_b64 ) ) TO gt_api_keys.
    ENDLOOP.
    gv_current_key_idx = 1.

    gt_models = VALUE string_table(
      ( `gemini-3.5-flash` )
      ( `gemini-3-flash` )
      ( `gemini-2.5-flash` )
      ( `gemini-2.5-flash-lite` )
      ( `antigravity` )
    ).
  ENDMETHOD.


  METHOD check_syntax_and_quality.
    DATA(lv_prompt) = build_syntax_prompt(
      iv_obj_type    = iv_obj_type
      iv_obj_name    = iv_obj_name
      iv_local_code  = iv_local_code
      iv_target_code = iv_target_code
      iv_lang        = iv_lang
    ).

    IF iv_mode = c_mode_sap_ai_core.
      rv_json = call_sap_ai_core( iv_prompt = lv_prompt ).
    ELSE.
      rv_json = call_gemini_with_failover( iv_prompt = lv_prompt iv_model = iv_model ).
    ENDIF.
  ENDMETHOD.


  METHOD review_transport.
    DATA(lv_prompt) = build_transport_prompt(
      iv_obj_type    = iv_obj_type
      iv_obj_name    = iv_obj_name
      iv_local_code  = iv_local_code
      iv_target_code = iv_target_code
      iv_lang        = iv_lang
    ).

    IF iv_mode = c_mode_sap_ai_core.
      rv_json = call_sap_ai_core( iv_prompt = lv_prompt ).
    ELSE.
      rv_json = call_gemini_with_failover( iv_prompt = lv_prompt iv_model = iv_model ).
    ENDIF.
  ENDMETHOD.


  METHOD get_next_api_key.
    IF gt_api_keys IS INITIAL.
      rv_key = ''.
      RETURN.
    ENDIF.

    IF gv_current_key_idx > lines( gt_api_keys ).
      gv_current_key_idx = 1.
    ENDIF.

    READ TABLE gt_api_keys INTO DATA(ls_key) INDEX gv_current_key_idx.
    gv_current_key_idx = gv_current_key_idx + 1.
    rv_key = ls_key-key_val.
  ENDMETHOD.


  METHOD call_gemini_with_failover.
    DATA:
      lv_url       TYPE string,
      lv_req_body  TYPE string,
      lv_escaped   TYPE string,
      lv_attempts  TYPE i VALUE 0,
      lv_max_retry TYPE i,
      lv_status    TYPE i,
      lv_response  TYPE string,
      lv_model     TYPE string,
      lv_start_idx TYPE i VALUE 1.

    IF iv_model IS NOT INITIAL.
      READ TABLE gt_models TRANSPORTING NO FIELDS WITH KEY table_line = iv_model.
      IF sy-subrc = 0.
        lv_start_idx = sy-tabix.
      ENDIF.
    ENDIF.

    lv_max_retry = lines( gt_api_keys ) * lines( gt_models ).
    lv_escaped = escape_json_string( iv_prompt ).

    lv_req_body = '{"contents":[{"role":"user","parts":[{"text":"' && lv_escaped && '"}]}],' &&
                  '"generationConfig":{"temperature":0.2,"maxOutputTokens":8192,"responseMimeType":"application/json"}}'.

    DO lv_max_retry TIMES.
      lv_attempts = lv_attempts + 1.
      DATA(lv_key) = get_next_api_key( ).
      DATA(lv_mod_idx) = ( ( lv_start_idx - 1 + ( ( lv_attempts - 1 ) DIV lines( gt_api_keys ) ) ) MOD lines( gt_models ) ) + 1.
      READ TABLE gt_models INTO lv_model INDEX lv_mod_idx.
      IF sy-subrc <> 0.
        lv_model = 'gemini-3.5-flash'.
      ENDIF.

      lv_url = 'https://generativelanguage.googleapis.com/v1beta/models/' && lv_model && ':generateContent?key=' && cl_http_utility=>escape_url( lv_key ).

      TRY.
          DATA: lo_http_client TYPE REF TO if_http_client.
          cl_http_client=>create_by_url(
            EXPORTING
              url                = lv_url
            IMPORTING
              client             = lo_http_client
            EXCEPTIONS
              argument_not_found = 1
              plugin_not_active  = 2
              internal_error     = 3
              OTHERS             = 4
          ).
          IF sy-subrc <> 0.
            CONTINUE.
          ENDIF.

          lo_http_client->request->set_method( if_http_request=>co_request_method_post ).
          lo_http_client->request->set_header_field( name = 'Content-Type' value = 'application/json' ).
          lo_http_client->request->set_cdata( lv_req_body ).

          lo_http_client->send(
            EXCEPTIONS
              http_communication_failure = 1
              http_invalid_state         = 2
              http_processing_failed     = 3
              OTHERS                     = 4
          ).
          IF sy-subrc <> 0.
            lo_http_client->close( ).
            CONTINUE.
          ENDIF.

          lo_http_client->receive(
            EXCEPTIONS
              http_communication_failure = 1
              http_invalid_state         = 2
              http_processing_failed     = 3
              OTHERS                     = 4
          ).
          IF sy-subrc <> 0.
            lo_http_client->close( ).
            CONTINUE.
          ENDIF.

          lo_http_client->response->get_status( IMPORTING code = lv_status ).
          lv_response = lo_http_client->response->get_cdata( ).
          lo_http_client->close( ).

          IF lv_status = 200.
            rv_json = lv_response.
            RETURN.
          ENDIF.

          CONTINUE.

        CATCH cx_root.
          CONTINUE.
      ENDTRY.
    ENDDO.

    DATA(lv_err_keys) = zcm_scort=>get_text_by_key( is_t100_key = zcm_scort=>ai_keys_exhausted ).
    rv_json = '{"error": "' && lv_err_keys && '"}'.
  ENDMETHOD.


  METHOD call_sap_ai_core.
    DATA:
      lv_req_body TYPE string,
      lv_escaped  TYPE string,
      lv_dest     TYPE rfcdest.

    lv_escaped = escape_json_string( iv_prompt ).
    lv_req_body = '{"messages":[{"role":"user","content":"' && lv_escaped && '"}],"max_tokens":2048,"temperature":0.2}'.
    lv_dest = iv_destination_name.

    TRY.
        DATA: lo_http_client TYPE REF TO if_http_client.
        cl_http_client=>create_by_destination(
          EXPORTING
            destination        = lv_dest
          IMPORTING
            client             = lo_http_client
          EXCEPTIONS
            destination_not_found = 1
            OTHERS                = 2
        ).
        IF sy-subrc = 0.
          lo_http_client->request->set_method( if_http_request=>co_request_method_post ).
          lo_http_client->request->set_header_field( name = 'Content-Type' value = 'application/json' ).
          lo_http_client->request->set_cdata( lv_req_body ).
          lo_http_client->send( ).
          lo_http_client->receive( ).
          rv_json = lo_http_client->response->get_cdata( ).
          lo_http_client->close( ).
          RETURN.
        ENDIF.
      CATCH cx_root.
    ENDTRY.

    DATA(lv_err_dest) = zcm_scort=>get_text_by_key( is_t100_key = zcm_scort=>ai_core_dest_unavailable iv_attr1 = CONV #( lv_dest ) ).
    rv_json = '{"error": "' && lv_err_dest && '"}'.
  ENDMETHOD.


  METHOD build_syntax_prompt.
    DATA: lv_lang_text       TYPE string,
          lv_nl              TYPE string,
          lv_has_local       TYPE abap_boolean,
          lv_has_tgt         TYPE abap_boolean,
          lv_numbered_local  TYPE string,
          lv_numbered_target TYPE string.

    lv_nl = cl_abap_char_utilities=>newline.
    lv_lang_text = resolve_language( iv_lang ).

    IF iv_local_code IS NOT INITIAL.
      lv_has_local = abap_true.
      lv_numbered_local = add_line_numbers( iv_local_code ).
    ENDIF.
    IF iv_target_code IS NOT INITIAL.
      lv_has_tgt = abap_true.
      lv_numbered_target = add_line_numbers( iv_target_code ).
    ENDIF.

    DATA(lv_line_req) = 'CRITICAL INSTRUCTION FOR EACH FINDING:' && lv_nl &&
                        '- Every line in the code is numbered (e.g. "26: CONCATENATE...").' && lv_nl &&
                        '- You MUST provide `line_number` (integer, e.g. 26) pointing to the exact line in code.' && lv_nl &&
                        '- You MUST format `line_or_snippet` starting with "Line <line_number>: [exact code snippet]" (e.g. "Line 26: [CONCATENATE ...]").' && lv_nl &&
                        '- You MUST provide `message` explaining in detail why it is invalid or suboptimal in the target language.' && lv_nl &&
                        '- You MUST provide `suggestion` containing a concrete, ready-to-use refactored code replacement following SAP Clean ABAP.' && lv_nl && lv_nl.

    IF lv_has_local = abap_true AND lv_has_tgt = abap_true.
      " Scenario C: Both Local and Target exist -> Dual Separate Assessment & Comparison
      rv_prompt = 'You are a Principal SAP ABAP Compiler and Senior Static Code Analysis Auditor. ' && lv_lang_text && lv_nl && lv_nl &&
                  '## Task: Dual-Side ABAP Syntax, Code Quality & Comparative Audit' && lv_nl &&
                  'The object exists on BOTH Local (Active) and Target (Snapshot) systems.' && lv_nl &&
                  'You MUST perform separate evaluations for Local Code AND Target Code, determine which side is better designed, and provide an expert best-practice synthesis to achieve optimal quality.' && lv_nl && lv_nl &&
                  lv_line_req &&
                  '## Focus Areas for Deep Audit:' && lv_nl &&
                  '1. Syntax & Compilation: Invalid keywords, missing periods, unmatched control structures (ENDIF, ENDLOOP, ENDMETHOD).' && lv_nl &&
                  '2. Obsolete Syntax: Detect obsolete constructs (CONCATENATE -> string templates |...|, MOVE TO, TABLES, FORM/PERFORM, OCCURS, RANGES).' && lv_nl &&
                  '3. Clean ABAP Standards: Inline declarations (DATA/FINAL), constructor expressions (VALUE, COND, REDUCE), DRY principle, Single Responsibility, modern OOP.' && lv_nl &&
                  '4. Performance & Reliability: SELECT in LOOP (N+1 queries), missing WHERE clauses, unchecked sy-subrc, unhandled exceptions.' && lv_nl &&
                  '5. Comparative Quality: Assess which codebase (LOCAL vs TARGET) has higher quality, fewer violations, and better architecture.' && lv_nl && lv_nl &&
                  '## Object Info: ' && iv_obj_type && ' ' && iv_obj_name && lv_nl && lv_nl &&
                  '## Local Code (Active Version - Numbered Lines):' && lv_nl && '```abap' && lv_nl && lv_numbered_local && lv_nl && '```' && lv_nl && lv_nl &&
                  '## Target Code (Baseline Version - Numbered Lines):' && lv_nl && '```abap' && lv_nl && lv_numbered_target && lv_nl && '```' && lv_nl && lv_nl &&
                  '## Required Output Format (Valid JSON only, no markdown fences):' && lv_nl &&
                  '{"mode":"DUAL","syntax_status":"PASSED"|"WARNING"|"ERROR","syntax_score":"e.g. 60/100","target_score":"e.g. 95/100",' &&
                  '"clean_abap_verdict":"Compliant"|"Needs Refactoring"|"Critical Issues",' &&
                  '"better_side":"LOCAL"|"TARGET"|"EQUIVALENT",' &&
                  '"better_side_reason":"In-depth technical explanation comparing Local vs Target code quality, readability, and performance.",' &&
                  '"best_version_recommendation":"Actionable recommendation on which version to keep and concrete refactoring steps to reach 100/100 score.",' &&
                  '"summary":"Comprehensive 3-5 sentence comparative audit summary.",' &&
                  '"findings":[{"side":"LOCAL"|"TARGET"|"BOTH","type":"SYNTAX_ERROR"|"WARNING"|"BEST_PRACTICE","line_number":20,"line_or_snippet":"Line 20: [exact code snippet]","message":"detailed explanation","suggestion":"concrete Clean ABAP replacement code"}]}'.

    ELSEIF lv_has_local = abap_true AND lv_has_tgt = abap_false.
      " Scenario A: Only Local exists
      rv_prompt = 'You are a Principal SAP ABAP Compiler and Senior Static Code Analysis Auditor. ' && lv_lang_text && lv_nl && lv_nl &&
                  '## Task: Deep ABAP Syntax & Clean Code Quality Audit (Local New Object)' && lv_nl &&
                  'This is a NEW object that exists ONLY on the LOCAL development system.' && lv_nl &&
                  'Perform an exhaustive, audit-grade static analysis of the LOCAL code against SAP Clean ABAP guidelines and system stability.' && lv_nl && lv_nl &&
                  lv_line_req &&
                  '## Focus Areas for Deep Audit:' && lv_nl &&
                  '1. Syntax & Compilation: Invalid keywords, missing periods, unmatched control structures.' && lv_nl &&
                  '2. Obsolete Syntax: Detect obsolete constructs (CONCATENATE -> string templates |...|, MOVE TO, TABLES, FORM/PERFORM).' && lv_nl &&
                  '3. Clean ABAP Standards: Inline declarations (DATA/FINAL), constructor expressions (VALUE, COND, REDUCE), DRY principle.' && lv_nl &&
                  '4. Performance & Reliability: SELECT in LOOP, missing WHERE clauses, unchecked sy-subrc.' && lv_nl && lv_nl &&
                  '## Object Info: ' && iv_obj_type && ' ' && iv_obj_name && lv_nl && lv_nl &&
                  '## Local Code (Active Version - Numbered Lines):' && lv_nl && '```abap' && lv_nl && lv_numbered_local && lv_nl && '```' && lv_nl && lv_nl &&
                  '## Required Output Format (Valid JSON only, no markdown fences):' && lv_nl &&
                  '{"mode":"LOCAL_ONLY","syntax_status":"PASSED"|"WARNING"|"ERROR","syntax_score":"Score out of 100",' &&
                  '"clean_abap_verdict":"Compliant"|"Needs Refactoring"|"Critical Issues",' &&
                  '"summary":"Comprehensive 3-5 sentence audit summary of Local code health and architectural quality.",' &&
                  '"findings":[{"side":"LOCAL","type":"SYNTAX_ERROR"|"WARNING"|"BEST_PRACTICE","line_number":20,"line_or_snippet":"Line 20: [exact code snippet]","message":"detailed explanation","suggestion":"concrete Clean ABAP replacement code"}]}'.

    ELSE.
      " Scenario B: Only Target exists
      rv_prompt = 'You are a Principal SAP ABAP Compiler and Senior Static Code Analysis Auditor. ' && lv_lang_text && lv_nl && lv_nl &&
                  '## Task: Deep ABAP Syntax & Clean Code Quality Audit (Target Baseline Object)' && lv_nl &&
                  'This object exists ONLY on the TARGET system (missing or deleted on Local).' && lv_nl &&
                  'Perform an exhaustive static analysis of the TARGET code baseline against SAP Clean ABAP guidelines.' && lv_nl && lv_nl &&
                  lv_line_req &&
                  '## Focus Areas for Deep Audit:' && lv_nl &&
                  '1. Syntax & Compilation: Invalid keywords, missing periods, unmatched control structures.' && lv_nl &&
                  '2. Obsolete Syntax: Detect obsolete constructs (CONCATENATE -> string templates |...|, MOVE TO, TABLES).' && lv_nl &&
                  '3. Clean ABAP Standards: Modern OOP, constructor expressions, DRY principle.' && lv_nl && lv_nl &&
                  '## Object Info: ' && iv_obj_type && ' ' && iv_obj_name && lv_nl && lv_nl &&
                  '## Target Code (Baseline - Numbered Lines):' && lv_nl && '```abap' && lv_nl && lv_numbered_target && lv_nl && '```' && lv_nl && lv_nl &&
                  '## Required Output Format (Valid JSON only, no markdown fences):' && lv_nl &&
                  '{"mode":"TARGET_ONLY","syntax_status":"PASSED"|"WARNING"|"ERROR","syntax_score":"Score out of 100",' &&
                  '"clean_abap_verdict":"Compliant"|"Needs Refactoring"|"Critical Issues",' &&
                  '"summary":"Comprehensive 3-5 sentence audit summary of Target baseline code health.",' &&
                  '"findings":[{"side":"TARGET","type":"SYNTAX_ERROR"|"WARNING"|"BEST_PRACTICE","line_number":20,"line_or_snippet":"Line 20: [exact code snippet]","message":"detailed explanation","suggestion":"concrete Clean ABAP replacement code"}]}'.
    ENDIF.
  ENDMETHOD.


  METHOD build_transport_prompt.
    DATA: lv_lang_text TYPE string,
          lv_nl        TYPE string.

    lv_nl = cl_abap_char_utilities=>newline.
    lv_lang_text = resolve_language( iv_lang ).

    rv_prompt = 'You are a Principal SAP Architect and Release Manager with 15+ years experience. ' && lv_lang_text && lv_nl && lv_nl &&
                '## Task: Transport Recommendation & Comprehensive Risk Assessment' && lv_nl &&
                'Compare LOCAL vs TARGET code thoroughly to formulate an audit-grade Transport Decision for Apply to Target.' && lv_nl && lv_nl &&
                '## Evaluation Dimensions:' && lv_nl &&
                '1. Security & Compliance: AUTHORITY-CHECK before mutations, hardcoded credentials, SQL injection vulnerability.' && lv_nl &&
                '2. Concurrency & Locks: Proper enqueue/dequeue locks before UPDATE/MODIFY, deadlocks prevention.' && lv_nl &&
                '3. Interface & Dependency Breaking Changes: Public method signature alteration, parameter removal, incompatible type changes, missing dependent CDS/tables.' && lv_nl &&
                '4. Release Risk: Overall production risk classification and transport feasibility.' && lv_nl &&
                '5. Pre & Post-Import Precautions (Notes): Critical deployment notes, dependent TR sequences, manual SPRO configurations, cache/buffer resets, SICF activations, or regression testing steps.' && lv_nl && lv_nl &&
                '## Object Info: ' && iv_obj_type && ' ' && iv_obj_name && lv_nl && lv_nl &&
                '## Local Code (Source):' && lv_nl && '```abap' && lv_nl && iv_local_code && lv_nl && '```' && lv_nl && lv_nl &&
                '## Target Code (Destination):' && lv_nl && '```abap' && lv_nl && iv_target_code && lv_nl && '```' && lv_nl && lv_nl &&
                '## Required Output Format (Valid JSON only, no markdown fences):' && lv_nl &&
                '{"summary":"Comprehensive 3-5 sentence summary explaining exact code differences, additive/destructive nature, and change impact.",' &&
                '"risks":["Detailed technical risk with system impact analysis"],' &&
                '"notes":["Crucial transport precaution, pre-requisite TR, or post-import step (e.g. buffer clear, SICF activation, manual config, unit test execution)"],' &&
                '"recommendation":"TRANSPORT"|"DO_NOT_TRANSPORT"|"REVIEW_REQUIRED",' &&
                '"reason":"In-depth technical justification referencing SAP best practices and stability standards.",' &&
                '"impact_level":"LOW"|"MEDIUM"|"HIGH"|"CRITICAL"}'.
  ENDMETHOD.


  METHOD escape_json_string.
    rv_clean = iv_raw.
    REPLACE ALL OCCURRENCES OF '\' IN rv_clean WITH '\\'.
    REPLACE ALL OCCURRENCES OF '"' IN rv_clean WITH '\"'.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf IN rv_clean WITH '\n'.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN rv_clean WITH '\n'.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>horizontal_tab IN rv_clean WITH '  '.
  ENDMETHOD.


  METHOD resolve_language.
    """ Determine AI reply language.
    """ Priority: 1) iv_lang from caller (FE override), 2) sy-langu from current SAP session.
    DATA: lv_iso TYPE string.

    " Use FE-supplied lang code if explicitly provided
    IF iv_lang IS NOT INITIAL AND iv_lang <> space.
      lv_iso = to_lower( iv_lang ).
    ELSE.
      " Auto-detect from SAP logon language (Fiori Launchpad / SAP GUI / RFC context)
      " sy-langu is 1-char SAP language code per ISO 639 mapping
      CASE sy-langu.
        WHEN 'E'. lv_iso = 'en'.  " English
        WHEN 'V'. lv_iso = 'vi'.  " Vietnamese
        WHEN 'D'. lv_iso = 'de'.  " German
        WHEN 'J'. lv_iso = 'ja'.  " Japanese
        WHEN 'C'. lv_iso = 'zh'.  " Chinese (Traditional)
        WHEN 'M'. lv_iso = 'zh'.  " Chinese (Simplified)
        WHEN 'F'. lv_iso = 'fr'.  " French
        WHEN 'S'. lv_iso = 'es'.  " Spanish
        WHEN 'P'. lv_iso = 'pt'.  " Portuguese
        WHEN 'K'. lv_iso = 'ko'.  " Korean
        WHEN 'I'. lv_iso = 'it'.  " Italian
        WHEN 'N'. lv_iso = 'nl'.  " Dutch
        WHEN 'R'. lv_iso = 'ru'.  " Russian
        WHEN 'T'. lv_iso = 'tr'.  " Turkish
        WHEN 'H'. lv_iso = 'th'.  " Thai
        WHEN OTHERS. lv_iso = 'en'. " Default fallback
      ENDCASE.
    ENDIF.

    " Map ISO code to AI prompt language instruction
    CASE lv_iso.
      WHEN 'vi'. rv_lang_text = 'Tra loi HOAN TOAN bang tieng Viet (Vietnamese). Moi thuat ngu ky thuat ABAP/SAP giu nguyen tieng Anh nhung giai thich bang tieng Viet.'.
      WHEN 'de'. rv_lang_text = 'Antworte AUSSCHLIESSLICH auf Deutsch. Technische SAP/ABAP-Begriffe koennen auf Englisch belassen werden, Erklaerungen jedoch auf Deutsch.'.
      WHEN 'ja'. rv_lang_text = 'すべての回答を日本語で記述してください。SAP/ABAPの技術用語は英語のままにし、説明は日本語で行ってください。'.
      WHEN 'zh'. rv_lang_text = '请完全用中文（简体）回答。SAP/ABAP技术术语可保留英文，但说明需用中文书写。'.
      WHEN 'fr'. rv_lang_text = 'Repondre ENTIEREMENT en francais. Les termes techniques SAP/ABAP peuvent rester en anglais, mais les explications doivent etre en francais.'.
      WHEN 'es'. rv_lang_text = 'Responde COMPLETAMENTE en espanol. Los terminos tecnicos de SAP/ABAP pueden mantenerse en ingles, pero las explicaciones deben estar en espanol.'.
      WHEN 'pt'. rv_lang_text = 'Responda COMPLETAMENTE em portugues. Os termos tecnicos SAP/ABAP podem ser mantidos em ingles, mas as explicacoes devem estar em portugues.'.
      WHEN 'ko'. rv_lang_text = '모든 답변을 한국어로 작성해 주세요. SAP/ABAP 기술 용어는 영어로 유지하되 설명은 한국어로 작성하세요.'.
      WHEN 'it'. rv_lang_text = 'Rispondere COMPLETAMENTE in italiano. I termini tecnici SAP/ABAP possono restare in inglese, ma le spiegazioni devono essere in italiano.'.
      WHEN 'nl'. rv_lang_text = 'Antwoord VOLLEDIG in het Nederlands. Technische SAP/ABAP-termen mogen in het Engels blijven, maar uitleg in het Nederlands.'.
      WHEN 'ru'. rv_lang_text = 'Отвечайте ИСКЛЮЧИТЕЛЬНО на русском языке. Технические термины SAP/ABAP можно оставить на английском, но пояснения — на русском.'.
      WHEN 'tr'. rv_lang_text = 'Lutfen TAMAMEN Turkce yanitlayin. SAP/ABAP teknik terimleri Ingilizce kalabilir, ancak aciklamalar Turkce olmalidir.'.
      WHEN 'th'. rv_lang_text = 'กรุณาตอบเป็นภาษาไทยทั้งหมด คำศัพท์เทคนิค SAP/ABAP สามารถใช้ภาษาอังกฤษได้ แต่คำอธิบายต้องเป็นภาษาไทย'.
      WHEN OTHERS. rv_lang_text = 'Reply strictly in English.'.
    ENDCASE.
  ENDMETHOD.


  METHOD add_line_numbers.
    DATA lt_lines TYPE TABLE OF string.
    DATA lv_idx TYPE i VALUE 1.
    DATA lv_line TYPE string.
    IF iv_code IS INITIAL.
      rv_code = space.
      RETURN.
    ENDIF.
    SPLIT iv_code AT cl_abap_char_utilities=>newline INTO TABLE lt_lines.
    LOOP AT lt_lines INTO lv_line.
      rv_code = rv_code && lv_idx && ': ' && lv_line && cl_abap_char_utilities=>newline.
      lv_idx = lv_idx + 1.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
