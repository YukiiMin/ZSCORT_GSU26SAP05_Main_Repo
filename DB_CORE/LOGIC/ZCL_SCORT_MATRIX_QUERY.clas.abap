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
    TYPES: BEGIN OF ty_obj_local,
             pgmid        TYPE pgmid,
             objecttype   TYPE trobjtype,
             objectname   TYPE trobj_name,
             localpackage TYPE devclass,
             localauthor  TYPE as4user,
           END OF ty_obj_local,

           BEGIN OF ty_obj_target,
             pgmid         TYPE pgmid,
             objecttype    TYPE trobjtype,
             objectname    TYPE trobj_name,
             targetpackage TYPE devclass,
             targetauthor  TYPE as4user,
           END OF ty_obj_target,

           ty_status TYPE c LENGTH 15.

    DATA: lt_local         TYPE STANDARD TABLE OF ty_obj_local WITH DEFAULT KEY,
          lt_target        TYPE STANDARD TABLE OF ty_obj_target WITH DEFAULT KEY,
          lt_result        TYPE STANDARD TABLE OF zce_scort_matrix,
          ls_result        LIKE LINE OF lt_result,
          lr_pgmid         TYPE RANGE OF pgmid,
          lr_obj_type      TYPE RANGE OF trobjtype,
          lr_obj_name      TYPE RANGE OF sobj_name,
          lr_local_pkg     TYPE RANGE OF devclass,
          lr_local_author  TYPE RANGE OF as4user,
          lr_target_pkg    TYPE RANGE OF devclass,
          lr_target_author TYPE RANGE OF as4user,
          lr_status        TYPE RANGE OF ty_status.

    DATA(lo_paging) = io_request->get_paging( ).
    DATA(lv_top)    = lo_paging->get_page_size( ).
    DATA(lv_skip)   = lo_paging->get_offset( ).

    TRY.
        DATA(lt_ranges) = io_request->get_filter( )->get_as_ranges( ).
        LOOP AT lt_ranges INTO DATA(ls_filter).
          CASE to_upper( CONDENSE( ls_filter-name ) ).
            WHEN 'PGMID'.
              LOOP AT ls_filter-range INTO DATA(ls_r_pgmid).
                APPEND VALUE #( sign = ls_r_pgmid-sign option = ls_r_pgmid-option low = ls_r_pgmid-low high = ls_r_pgmid-high ) TO lr_pgmid.
              ENDLOOP.
            WHEN 'OBJECTTYPE'.
              LOOP AT ls_filter-range INTO DATA(ls_r_otype).
                APPEND VALUE #( sign = ls_r_otype-sign option = ls_r_otype-option low = ls_r_otype-low high = ls_r_otype-high ) TO lr_obj_type.
              ENDLOOP.
            WHEN 'OBJECTNAME'.
              LOOP AT ls_filter-range INTO DATA(ls_r_oname).
                APPEND VALUE #( sign = ls_r_oname-sign option = ls_r_oname-option low = ls_r_oname-low high = ls_r_oname-high ) TO lr_obj_name.
              ENDLOOP.
            WHEN 'LOCALPACKAGE'.
              LOOP AT ls_filter-range INTO DATA(ls_r_lpkg).
                APPEND VALUE #( sign = ls_r_lpkg-sign option = ls_r_lpkg-option low = ls_r_lpkg-low high = ls_r_lpkg-high ) TO lr_local_pkg.
              ENDLOOP.
            WHEN 'LOCALAUTHOR'.
              LOOP AT ls_filter-range INTO DATA(ls_r_lauth).
                APPEND VALUE #( sign = ls_r_lauth-sign option = ls_r_lauth-option low = ls_r_lauth-low high = ls_r_lauth-high ) TO lr_local_author.
              ENDLOOP.
            WHEN 'TARGETPACKAGE'.
              LOOP AT ls_filter-range INTO DATA(ls_r_tpkg).
                APPEND VALUE #( sign = ls_r_tpkg-sign option = ls_r_tpkg-option low = ls_r_tpkg-low high = ls_r_tpkg-high ) TO lr_target_pkg.
              ENDLOOP.
            WHEN 'TARGETAUTHOR'.
              LOOP AT ls_filter-range INTO DATA(ls_r_tauth).
                APPEND VALUE #( sign = ls_r_tauth-sign option = ls_r_tauth-option low = ls_r_tauth-low high = ls_r_tauth-high ) TO lr_target_author.
              ENDLOOP.
            WHEN 'EXISTENCESTATUS'.
              LOOP AT ls_filter-range INTO DATA(ls_r_stat).
                APPEND VALUE #( sign = ls_r_stat-sign option = ls_r_stat-option low = ls_r_stat-low high = ls_r_stat-high ) TO lr_status.
              ENDLOOP.
          ENDCASE.
        ENDLOOP.
      CATCH cx_root.
    ENDTRY.

    IF lr_obj_type IS INITIAL.
      lr_obj_type = VALUE #(
        ( sign = 'I' option = 'EQ' low = 'PROG' )
        ( sign = 'I' option = 'EQ' low = 'CLAS' )
        ( sign = 'I' option = 'EQ' low = 'INTF' )
        ( sign = 'I' option = 'EQ' low = 'FUGR' )
        ( sign = 'I' option = 'EQ' low = 'FUNC' )
        ( sign = 'I' option = 'EQ' low = 'DDLS' )
        ( sign = 'I' option = 'EQ' low = 'BDEF' )
        ( sign = 'I' option = 'EQ' low = 'DCLS' )
        ( sign = 'I' option = 'EQ' low = 'DDLX' )
        ( sign = 'I' option = 'EQ' low = 'SRVD' )
        ( sign = 'I' option = 'EQ' low = 'TABL' )
        ( sign = 'I' option = 'EQ' low = 'DTEL' )
        ( sign = 'I' option = 'EQ' low = 'DOMA' )
        ( sign = 'I' option = 'EQ' low = 'TTYP' )
        ( sign = 'I' option = 'EQ' low = 'VIEW' )
        ( sign = 'I' option = 'EQ' low = 'MSAG' )
        ( sign = 'I' option = 'EQ' low = 'DEVC' )
        ( sign = 'I' option = 'EQ' low = 'TRAN' )
        ( sign = 'I' option = 'EQ' low = 'NROB' )
        ( sign = 'I' option = 'EQ' low = 'WAPA' )
        ( sign = 'I' option = 'EQ' low = 'SSFO' )
        ( sign = 'I' option = 'EQ' low = 'SHLP' )
      ).
    ENDIF.

    DATA(lv_fetch_r3tr) = abap_true.
    IF lr_pgmid IS NOT INITIAL AND 'R3TR' NOT IN lr_pgmid.
      lv_fetch_r3tr = abap_false.
    ENDIF.

    IF lv_fetch_r3tr = abap_true.
      IF lr_obj_name IS NOT INITIAL OR lr_local_pkg IS NOT INITIAL.
        SELECT pgmid, object AS objecttype, obj_name AS objectname, devclass AS localpackage, author AS localauthor
          FROM tadir
          WHERE pgmid     = 'R3TR'
            AND object    IN @lr_obj_type
            AND obj_name  IN @lr_obj_name
            AND devclass  IN @lr_local_pkg
            AND author    IN @lr_local_author
            AND ( delflag IS NULL OR delflag = ' ' OR delflag = '' )
          INTO TABLE @lt_local. "#EC CI_SGLSELECT
      ELSE.
        SELECT pgmid, object AS objecttype, obj_name AS objectname, devclass AS localpackage, author AS localauthor
          FROM tadir
          WHERE pgmid     = 'R3TR'
            AND object    IN @lr_obj_type
            AND obj_name  LIKE 'Z%'
            AND author    IN @lr_local_author
            AND ( delflag IS NULL OR delflag = ' ' OR delflag = '' )
          INTO TABLE @lt_local. "#EC CI_SGLSELECT
      ENDIF.
    ENDIF.

    DATA(lv_fetch_func) = abap_true.
    IF lr_pgmid IS NOT INITIAL AND 'LIMU' NOT IN lr_pgmid.
      lv_fetch_func = abap_false.
    ENDIF.
    IF lr_obj_type IS NOT INITIAL AND 'FUNC' NOT IN lr_obj_type.
      lv_fetch_func = abap_false.
    ENDIF.

    IF lv_fetch_func = abap_true.
      IF lr_obj_name IS NOT INITIAL OR lr_local_pkg IS NOT INITIAL.
        SELECT 'LIMU'     AS pgmid,
               'FUNC'     AS objecttype,
               f~funcname AS objectname,
               t~devclass AS localpackage,
               t~author   AS localauthor
          FROM enlfdir AS f
          INNER JOIN tadir AS t
            ON t~pgmid = 'R3TR' AND t~object = 'FUGR' AND t~obj_name = f~area
            AND ( t~delflag IS NULL OR t~delflag = ' ' OR t~delflag = '' )
          WHERE f~funcname IN @lr_obj_name
            AND t~devclass IN @lr_local_pkg
            AND t~author   IN @lr_local_author
            AND f~active   = 'X'
          APPENDING CORRESPONDING FIELDS OF TABLE @lt_local. "#EC CI_BUFFJOIN
      ELSE.
        SELECT 'LIMU'     AS pgmid,
               'FUNC'     AS objecttype,
               f~funcname AS objectname,
               t~devclass AS localpackage,
               t~author   AS localauthor
          FROM enlfdir AS f
          INNER JOIN tadir AS t
            ON t~pgmid = 'R3TR' AND t~object = 'FUGR' AND t~obj_name = f~area
            AND ( t~delflag IS NULL OR t~delflag = ' ' OR t~delflag = '' )
          WHERE f~funcname LIKE 'Z%'
            AND t~author   IN @lr_local_author
            AND f~active   = 'X'
          APPENDING CORRESPONDING FIELDS OF TABLE @lt_local. "#EC CI_BUFFJOIN
      ENDIF.
    ENDIF.

    IF lr_obj_name IS NOT INITIAL OR lr_target_pkg IS NOT INITIAL.
      SELECT pgmid, object AS objecttype, obj_name AS objectname, devclass AS targetpackage, author AS targetauthor
        FROM za05_scort_t
        WHERE pgmid    IN @lr_pgmid
          AND ( pgmid = 'R3TR' OR pgmid = 'LIMU' )
          AND object   IN @lr_obj_type
          AND obj_name IN @lr_obj_name
          AND devclass IN @lr_target_pkg
          AND author   IN @lr_target_author
        INTO TABLE @lt_target.
    ELSE.
      SELECT pgmid, object AS objecttype, obj_name AS objectname, devclass AS targetpackage, author AS targetauthor
        FROM za05_scort_t
        WHERE pgmid    IN @lr_pgmid
          AND ( pgmid = 'R3TR' OR pgmid = 'LIMU' )
          AND object   IN @lr_obj_type
          AND obj_name LIKE 'Z%'
          AND author   IN @lr_target_author
        INTO TABLE @lt_target.
    ENDIF.

    SORT lt_local BY pgmid objecttype objectname.
    SORT lt_target BY pgmid objecttype objectname.

    DATA: lv_idx_l   TYPE i VALUE 1,
          lv_idx_t   TYPE i VALUE 1,
          lv_lines_l TYPE i,
          lv_lines_t TYPE i.

    lv_lines_l = lines( lt_local ).
    lv_lines_t = lines( lt_target ).

    WHILE lv_idx_l <= lv_lines_l OR lv_idx_t <= lv_lines_t.
      CLEAR ls_result.
      ls_result-servertype = 'L'.

      IF lv_idx_l <= lv_lines_l AND lv_idx_t <= lv_lines_t.
        DATA(ls_l) = lt_local[ lv_idx_l ].
        DATA(ls_t) = lt_target[ lv_idx_t ].

        IF ls_l-pgmid = ls_t-pgmid AND ls_l-objecttype = ls_t-objecttype AND ls_l-objectname = ls_t-objectname.
          ls_result-pgmid           = ls_l-pgmid.
          ls_result-objecttype      = ls_l-objecttype.
          ls_result-objectname      = ls_l-objectname.
          ls_result-localpackage    = ls_l-localpackage.
          ls_result-targetpackage   = ls_t-targetpackage.
          ls_result-localauthor     = ls_l-localauthor.
          ls_result-targetauthor    = ls_t-targetauthor.
          ls_result-existencestatus = 'BOTH'.
          lv_idx_l = lv_idx_l + 1.
          lv_idx_t = lv_idx_t + 1.
        ELSEIF ls_l-pgmid < ls_t-pgmid
            OR ( ls_l-pgmid = ls_t-pgmid AND ls_l-objecttype < ls_t-objecttype )
            OR ( ls_l-pgmid = ls_t-pgmid AND ls_l-objecttype = ls_t-objecttype AND ls_l-objectname < ls_t-objectname ).
          ls_result-pgmid           = ls_l-pgmid.
          ls_result-objecttype      = ls_l-objecttype.
          ls_result-objectname      = ls_l-objectname.
          ls_result-localpackage    = ls_l-localpackage.
          ls_result-localauthor     = ls_l-localauthor.
          ls_result-existencestatus = 'LOCAL_ONLY'.
          lv_idx_l = lv_idx_l + 1.
        ELSE.
          ls_result-pgmid           = ls_t-pgmid.
          ls_result-objecttype      = ls_t-objecttype.
          ls_result-objectname      = ls_t-objectname.
          ls_result-targetpackage   = ls_t-targetpackage.
          ls_result-targetauthor    = ls_t-targetauthor.
          ls_result-existencestatus = 'TARGET_ONLY'.
          lv_idx_t = lv_idx_t + 1.
        ENDIF.
      ELSEIF lv_idx_l <= lv_lines_l.
        ls_l = lt_local[ lv_idx_l ].
        ls_result-pgmid           = ls_l-pgmid.
        ls_result-objecttype      = ls_l-objecttype.
        ls_result-objectname      = ls_l-objectname.
        ls_result-localpackage    = ls_l-localpackage.
        ls_result-localauthor     = ls_l-localauthor.
        ls_result-existencestatus = 'LOCAL_ONLY'.
        lv_idx_l = lv_idx_l + 1.
      ELSE.
        ls_t = lt_target[ lv_idx_t ].
        ls_result-pgmid           = ls_t-pgmid.
        ls_result-objecttype      = ls_t-objecttype.
        ls_result-objectname      = ls_t-objectname.
        ls_result-targetpackage   = ls_t-targetpackage.
        ls_result-targetauthor    = ls_t-targetauthor.
        ls_result-existencestatus = 'TARGET_ONLY'.
        lv_idx_t = lv_idx_t + 1.
      ENDIF.

      APPEND ls_result TO lt_result.
    ENDWHILE.

    IF lr_status IS NOT INITIAL.
      DELETE lt_result WHERE existencestatus NOT IN lr_status.
    ENDIF.
    IF lr_local_pkg IS NOT INITIAL.
      DELETE lt_result WHERE localpackage NOT IN lr_local_pkg.
    ENDIF.
    IF lr_local_author IS NOT INITIAL.
      DELETE lt_result WHERE localauthor NOT IN lr_local_author.
    ENDIF.
    IF lr_target_pkg IS NOT INITIAL.
      DELETE lt_result WHERE targetpackage NOT IN lr_target_pkg.
    ENDIF.
    IF lr_target_author IS NOT INITIAL.
      DELETE lt_result WHERE targetauthor NOT IN lr_target_author.
    ENDIF.

    DATA: lt_sort_criteria TYPE abap_sortorder_tab,
          ls_sort_criteria TYPE abap_sortorder.

    TRY.
        DATA(lt_req_sort) = io_request->get_sort_elements( ).
        IF lt_req_sort IS NOT INITIAL.
          LOOP AT lt_req_sort INTO DATA(ls_req_sort).
            CLEAR ls_sort_criteria.
            ls_sort_criteria-name       = to_upper( CONDENSE( ls_req_sort-element_name ) ).
            ls_sort_criteria-descending = ls_req_sort-descending.
            APPEND ls_sort_criteria TO lt_sort_criteria.
          ENDLOOP.
          SORT lt_result BY (lt_sort_criteria).
        ELSE.
          SORT lt_result BY pgmid ASCENDING objecttype ASCENDING objectname ASCENDING.
        ENDIF.
      CATCH cx_root.
        SORT lt_result BY pgmid ASCENDING objecttype ASCENDING objectname ASCENDING.
    ENDTRY.

    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( lines( lt_result ) ).
    ENDIF.

    IF io_request->is_data_requested( ).
      IF lv_skip > 0 OR lv_top > 0.
        DATA: lt_paged LIKE lt_result.
        DATA(lv_total_lines) = lines( lt_result ).
        DATA(lv_start)       = lv_skip + 1.
        DATA(lv_end)         = lv_skip + lv_top.

        IF lv_top = 0 OR lv_end > lv_total_lines.
          lv_end = lv_total_lines.
        ENDIF.

        IF lv_start <= lv_total_lines.
          APPEND LINES OF lt_result FROM lv_start TO lv_end TO lt_paged.
        ENDIF.
        io_response->set_data( lt_paged ).
      ELSE.
        io_response->set_data( lt_result ).
      ENDIF.
    ENDIF.

  ENDMETHOD.
ENDCLASS.
