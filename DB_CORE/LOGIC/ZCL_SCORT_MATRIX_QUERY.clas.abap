CLASS zcl_scort_matrix_query DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_scort_matrix_query IMPLEMENTATION.
  METHOD if_rap_query_provider~select.
    DATA: lt_result TYPE STANDARD TABLE OF zce_scort_matrix,
          ls_result LIKE LINE OF lt_result.

    DATA(lo_paging) = io_request->get_paging( ).
    DATA(lv_top)    = lo_paging->get_page_size( ).
    DATA(lv_skip)   = lo_paging->get_offset( ).

    " We bypass sadl dump by building the matrix in memory
    " 1. Fetch Local Objects
    SELECT pgmid, object AS objecttype, obj_name AS objectname, devclass AS localpackage, author AS localauthor
      FROM tadir
      WHERE pgmid = 'R3TR'
        AND obj_name LIKE 'Z%'
      INTO TABLE @DATA(lt_local).

    " 2. Fetch Target Objects
    SELECT pgmid, object AS objecttype, obj_name AS objectname, devclass AS targetpackage, author AS targetauthor
      FROM za05_scort_t
      WHERE pgmid = 'R3TR'
      INTO TABLE @DATA(lt_target).

    " 3. Merge
    SORT lt_local BY objecttype objectname.
    SORT lt_target BY objecttype objectname.

    DATA: lv_idx_l TYPE i VALUE 1,
          lv_idx_t TYPE i VALUE 1,
          lv_lines_l TYPE i,
          lv_lines_t TYPE i.

    lv_lines_l = lines( lt_local ).
    lv_lines_t = lines( lt_target ).

    WHILE lv_idx_l <= lv_lines_l OR lv_idx_t <= lv_lines_t.
      CLEAR ls_result.
      ls_result-pgmid = 'R3TR'.
      ls_result-servertype = 'L'. " or read from parameter if parameterized

      IF lv_idx_l <= lv_lines_l AND lv_idx_t <= lv_lines_t.
        DATA(ls_l) = lt_local[ lv_idx_l ].
        DATA(ls_t) = lt_target[ lv_idx_t ].

        IF ls_l-objecttype = ls_t-objecttype AND ls_l-objectname = ls_t-objectname.
          ls_result-objecttype      = ls_l-objecttype.
          ls_result-objectname      = ls_l-objectname.
          ls_result-localpackage    = ls_l-localpackage.
          ls_result-targetpackage   = ls_t-targetpackage.
          ls_result-localauthor     = ls_l-localauthor.
          ls_result-targetauthor    = ls_t-targetauthor.
          ls_result-existencestatus = 'BOTH'.
          lv_idx_l = lv_idx_l + 1.
          lv_idx_t = lv_idx_t + 1.
        ELSEIF ls_l-objecttype < ls_t-objecttype OR ( ls_l-objecttype = ls_t-objecttype AND ls_l-objectname < ls_t-objectname ).
          ls_result-objecttype      = ls_l-objecttype.
          ls_result-objectname      = ls_l-objectname.
          ls_result-localpackage    = ls_l-localpackage.
          ls_result-localauthor     = ls_l-localauthor.
          ls_result-existencestatus = 'LOCAL_ONLY'.
          lv_idx_l = lv_idx_l + 1.
        ELSE.
          ls_result-objecttype      = ls_t-objecttype.
          ls_result-objectname      = ls_t-objectname.
          ls_result-targetpackage   = ls_t-targetpackage.
          ls_result-targetauthor    = ls_t-targetauthor.
          ls_result-existencestatus = 'TARGET_ONLY'.
          lv_idx_t = lv_idx_t + 1.
        ENDIF.
      ELSEIF lv_idx_l <= lv_lines_l.
        ls_l = lt_local[ lv_idx_l ].
        ls_result-objecttype      = ls_l-objecttype.
        ls_result-objectname      = ls_l-objectname.
        ls_result-localpackage    = ls_l-localpackage.
        ls_result-localauthor     = ls_l-localauthor.
        ls_result-existencestatus = 'LOCAL_ONLY'.
        lv_idx_l = lv_idx_l + 1.
      ELSE.
        ls_t = lt_target[ lv_idx_t ].
        ls_result-objecttype      = ls_t-objecttype.
        ls_result-objectname      = ls_t-objectname.
        ls_result-targetpackage   = ls_t-targetpackage.
        ls_result-targetauthor    = ls_t-targetauthor.
        ls_result-existencestatus = 'TARGET_ONLY'.
        lv_idx_t = lv_idx_t + 1.
      ENDIF.

      APPEND ls_result TO lt_result.
    ENDWHILE.

    " 4. Apply SADL filter & sorts from request (Simulated in memory)
    " We use simple filtering based on io_request->get_filter( ) if needed.
    " For a complete robust solution, one would parse the filter tree.
    " Since ABAP 7.5x doesn't expose easy dynamic where clauses on internal tables directly,
    " we rely on standard UI5 filtering for simple fields.
    " Here we'll just implement basic filtering for ExistenceStatus, ObjectName, ObjectType, etc.
    DATA(lo_filter) = io_request->get_filter( )->get_as_ranges( ).
    LOOP AT lo_filter INTO DATA(ls_cond).
      CASE ls_cond-name.
        WHEN 'EXISTENCESTATUS'.
          DELETE lt_result WHERE existencestatus NOT IN ls_cond-range.
        WHEN 'OBJECTNAME'.
          DELETE lt_result WHERE objectname NOT IN ls_cond-range.
        WHEN 'OBJECTTYPE'.
          DELETE lt_result WHERE objecttype NOT IN ls_cond-range.
      ENDCASE.
    ENDLOOP.

    " 5. Return count
    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( lines( lt_result ) ).
    ENDIF.

    " 6. Return data
    IF io_request->is_data_requested( ).
      IF lv_skip > 0 OR lv_top > 0.
        DATA: lt_paged LIKE lt_result.
        DATA(lv_end) = lv_skip + lv_top.
        IF lv_end > lines( lt_result ) OR lv_top = 0.
          lv_end = lines( lt_result ).
        ENDIF.
        DATA(lv_start) = lv_skip + 1.
        IF lv_start <= lv_end.
          APPEND LINES OF lt_result FROM lv_start TO lv_end TO lt_paged.
        ENDIF.
        io_response->set_data( lt_paged ).
      ELSE.
        io_response->set_data( lt_result ).
      ENDIF.
    ENDIF.

  ENDMETHOD.
ENDCLASS.
