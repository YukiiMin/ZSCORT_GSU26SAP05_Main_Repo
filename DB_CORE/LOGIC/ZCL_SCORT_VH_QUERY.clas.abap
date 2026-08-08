*"*---------------------------------------------------------------------*
*"* Class: ZCL_SCORT_VH_QUERY
*"* Value Help (F4). Cover đầy đủ: data + count + sort + paging
*"* → tránh "Query not fully covered" khi Preview Compare bấm Go.
*"*---------------------------------------------------------------------*
CLASS zcl_scort_vh_query DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

  PRIVATE SECTION.
    METHODS select_dispatch
      IMPORTING
        io_request  TYPE REF TO if_rap_query_request
        io_response TYPE REF TO if_rap_query_response.

    METHODS respond_typed
      IMPORTING
        io_request  TYPE REF TO if_rap_query_request
        io_response TYPE REF TO if_rap_query_response
      CHANGING
        ct_data     TYPE STANDARD TABLE.

ENDCLASS.


CLASS zcl_scort_vh_query IMPLEMENTATION.

  METHOD if_rap_query_provider~select.
    TRY.
        select_dispatch( io_request = io_request io_response = io_response ).
      CATCH cx_root.
        " Không set_data type sai (entity khác nhau) — chỉ cover count.
        TRY.
            io_response->set_total_number_of_records( 0 ).
          CATCH cx_root.
        ENDTRY.
    ENDTRY.
  ENDMETHOD.

  METHOD select_dispatch.
    DATA lv_entity TYPE string.
    DATA lv_sql    TYPE string.
    DATA lv_pat    TYPE string.
    DATA lv_type   TYPE trobjtype.
    DATA lv_name   TYPE string.
    DATA lv_like   TYPE string.
    DATA lv_tab    TYPE tabname.
    DATA lt_tadir  TYPE STANDARD TABLE OF tadir WITH DEFAULT KEY.
    DATA lt_id     TYPE STANDARD TABLE OF char10 WITH DEFAULT KEY.

    TRY.
        lv_entity = to_upper( CONV string( io_request->get_entity_id( ) ) ).
      CATCH cx_root.
        CLEAR lv_entity.
    ENDTRY.

    lv_sql = zcl_scort_query_utl=>get_filter_sql( io_request ).

    "===== VH Trkorr =====
    " Exact / LIKE trước — tránh FE "Value does not exist" khi TR ngoài top 200.
    IF lv_entity CS 'VH_TRKORR' OR lv_entity CS 'VHTRKORR'.
      DATA lt_trkorr TYPE STANDARD TABLE OF zc_scort_vh_trkorr WITH DEFAULT KEY.
      DATA ls_trkorr TYPE zc_scort_vh_trkorr.
      DATA lt_e070 TYPE STANDARD TABLE OF e070 WITH DEFAULT KEY.

      lv_pat = zcl_scort_query_utl=>filter_low( io_request = io_request iv_field = 'TRKORR' ).
      IF lv_pat IS INITIAL.
        lv_pat = zcl_scort_query_utl=>value_of( iv_sql = lv_sql iv_field = 'TRKORR' ).
      ENDIF.

      IF lv_pat IS NOT INITIAL.
        " 1) Exact — cả request header lẫn task
        SELECT trkorr, trstatus, trfunction, as4user, as4date, strkorr
          FROM e070
          WHERE trkorr = @lv_pat
          INTO CORRESPONDING FIELDS OF TABLE @lt_e070
          UP TO 5 ROWS.

        " 2) Prefix search trên header
        IF lt_e070 IS INITIAL AND strlen( lv_pat ) >= 3.
          lv_like = |{ lv_pat }%|.
          SELECT trkorr, trstatus, trfunction, as4user, as4date, strkorr
            FROM e070
            WHERE strkorr = @space
              AND trkorr LIKE @lv_like
            ORDER BY as4date DESCENDING, trkorr DESCENDING
            INTO CORRESPONDING FIELDS OF TABLE @lt_e070
            UP TO 100 ROWS.
        ENDIF.
      ELSE.
        " Browse: 100 TR header gần nhất
        SELECT trkorr, trstatus, trfunction, as4user, as4date, strkorr
          FROM e070
          WHERE strkorr = @space
            AND ( trfunction = 'K' OR trfunction = 'W'
               OR trfunction = 'T' OR trfunction = 'C' )
          ORDER BY as4date DESCENDING, trkorr DESCENDING
          INTO CORRESPONDING FIELDS OF TABLE @lt_e070
          UP TO 100 ROWS.
      ENDIF.

      LOOP AT lt_e070 INTO DATA(ls_e070).
        CLEAR ls_trkorr.
        ls_trkorr-Trkorr     = ls_e070-trkorr.
        ls_trkorr-TrStatus   = ls_e070-trstatus.
        ls_trkorr-TrFunction = ls_e070-trfunction.
        ls_trkorr-As4user    = ls_e070-as4user.
        ls_trkorr-As4date    = ls_e070-as4date.
        CASE ls_e070-trstatus.
          WHEN 'R'. ls_trkorr-Description = 'Released'.
          WHEN 'D'. ls_trkorr-Description = 'Modifiable'.
          WHEN 'N'. ls_trkorr-Description = 'Released (protected)'.
          WHEN OTHERS. ls_trkorr-Description = |Status { ls_e070-trstatus }|.
        ENDCASE.
        IF ls_e070-strkorr IS NOT INITIAL.
          ls_trkorr-Description = |{ ls_trkorr-Description } / task of { ls_e070-strkorr }|.
        ENDIF.
        APPEND ls_trkorr TO lt_trkorr.
      ENDLOOP.

      respond_typed( EXPORTING io_request = io_request io_response = io_response
                     CHANGING  ct_data = lt_trkorr ).
      RETURN.
    ENDIF.

    "===== VH Object Type =====
    IF lv_entity CS 'VH_OBJ_TYPE' OR lv_entity CS 'VHOBJTYPE'.
      DATA lt_otype TYPE STANDARD TABLE OF zc_scort_vh_obj_type WITH DEFAULT KEY.
      lt_otype = VALUE #(
        ( ObjectType = 'PROG' Description = 'Program / Report' )
        ( ObjectType = 'CLAS' Description = 'Class' )
        ( ObjectType = 'INTF' Description = 'Interface' )
        ( ObjectType = 'FUNC' Description = 'Function Module' )
        ( ObjectType = 'FUGR' Description = 'Function Group' )
      ).
      respond_typed( EXPORTING io_request = io_request io_response = io_response
                     CHANGING  ct_data = lt_otype ).
      RETURN.
    ENDIF.

    "===== VH Object Name =====
    " Exact trước → LIKE prefix (giống VH Trkorr). Browse Z*/Y* khi chỉ có Type.
    IF lv_entity CS 'VH_OBJ_NAME' OR lv_entity CS 'VHOBJNAME'.
      DATA lt_oname TYPE STANDARD TABLE OF zc_scort_vh_obj_name WITH DEFAULT KEY.
      DATA ls_oname TYPE zc_scort_vh_obj_name.
      DATA lt_types TYPE RANGE OF trobjtype.

      lv_type = CONV trobjtype(
        zcl_scort_query_utl=>filter_low( io_request = io_request iv_field = 'OBJECTTYPE' ) ).
      lv_name = zcl_scort_query_utl=>filter_low( io_request = io_request iv_field = 'OBJECTNAME' ).

      lt_types = VALUE #(
        ( sign = 'I' option = 'EQ' low = 'PROG' )
        ( sign = 'I' option = 'EQ' low = 'CLAS' )
        ( sign = 'I' option = 'EQ' low = 'INTF' )
        ( sign = 'I' option = 'EQ' low = 'FUGR' )
      ).

      IF lv_name IS NOT INITIAL.
        " 1) Exact — ưu tiên khi FE validate / gõ đủ tên
        IF lv_type IS NOT INITIAL.
          SELECT * FROM tadir
            WHERE pgmid = 'R3TR' AND object = @lv_type AND obj_name = @lv_name
            INTO TABLE @lt_tadir
            UP TO 5 ROWS.
        ELSE.
          SELECT * FROM tadir
            WHERE pgmid = 'R3TR' AND object IN @lt_types AND obj_name = @lv_name
            INTO TABLE @lt_tadir
            UP TO 5 ROWS.
        ENDIF.

        " 2) LIKE prefix nếu chưa có exact
        IF lt_tadir IS INITIAL AND strlen( lv_name ) >= 2.
          lv_like = |{ lv_name }%|.
          IF lv_type IS NOT INITIAL.
            SELECT * FROM tadir
              WHERE pgmid = 'R3TR' AND object = @lv_type AND obj_name LIKE @lv_like
              ORDER BY obj_name
              INTO TABLE @lt_tadir
              UP TO 100 ROWS.
          ELSE.
            SELECT * FROM tadir
              WHERE pgmid = 'R3TR' AND object IN @lt_types AND obj_name LIKE @lv_like
              ORDER BY obj_name
              INTO TABLE @lt_tadir
              UP TO 100 ROWS.
          ENDIF.
        ENDIF.
      ELSEIF lv_type IS NOT INITIAL.
        " Browse theo Type — chỉ Z*/Y*
        SELECT * FROM tadir
          WHERE pgmid = 'R3TR'
            AND object = @lv_type
            AND ( obj_name LIKE 'Z%' OR obj_name LIKE 'Y%' )
          ORDER BY obj_name
          INTO TABLE @lt_tadir
          UP TO 100 ROWS.
      ENDIF.
      " Không Type + không tên → rỗng

      LOOP AT lt_tadir INTO DATA(ls_t).
        CLEAR ls_oname.
        ls_oname-ObjectType = ls_t-object.
        ls_oname-ObjectName = ls_t-obj_name.
        ls_oname-Devclass   = ls_t-devclass.
        ls_oname-Author     = ls_t-author.
        APPEND ls_oname TO lt_oname.
      ENDLOOP.

      respond_typed( EXPORTING io_request = io_request io_response = io_response
                     CHANGING  ct_data = lt_oname ).
      RETURN.
    ENDIF.

    "===== VH Compare Mode =====
    IF lv_entity CS 'VH_COMPARE_MODE' OR lv_entity CS 'VHCOMPAREMODE'
        OR ( lv_entity CS 'COMPAREMODE' AND lv_entity CS 'VH' ).
      DATA lt_mode TYPE STANDARD TABLE OF zc_scort_vh_compare_mode WITH DEFAULT KEY.
      lt_mode = VALUE #(
        ( CompareMode = 'L_VS_T' Description = 'REPO Target version vs Local Active' )
        ( CompareMode = 'VER_VS_VER' Description = 'Local VRSD vs Local VRSD' )
        ( CompareMode = 'ACTIVE_VS_VER' Description = 'Local Version vs Local Active' )
      ).
      respond_typed( EXPORTING io_request = io_request io_response = io_response
                     CHANGING  ct_data = lt_mode ).
      RETURN.
    ENDIF.

    "===== VH Compare Status =====
    IF lv_entity CS 'VH_COMPARE_STATUS' OR lv_entity CS 'VHCOMPARESTATUS'
        OR ( lv_entity CS 'COMPARESTATUS' AND lv_entity CS 'VH' ).
      DATA lt_status TYPE STANDARD TABLE OF zc_scort_vh_compare_status WITH DEFAULT KEY.
      lt_status = VALUE #(
        ( CompareStatus = 'IDENTICAL' Description = 'Hashes match' )
        ( CompareStatus = 'DIFFERENT' Description = 'Hashes differ' )
        ( CompareStatus = 'NEW_AT_TARGET' Description = 'No row in ZA026_SCORT_REPO' )
        ( CompareStatus = 'NOT_SUPPORTED' Description = 'Type out of scope' )
        ( CompareStatus = 'SOURCE_MISSING' Description = 'Active source missing' )
        ( CompareStatus = 'BAD_HEX' Description = 'REPO source_code empty' )
      ).
      respond_typed( EXPORTING io_request = io_request io_response = io_response
                     CHANGING  ct_data = lt_status ).
      RETURN.
    ENDIF.

    "===== VH Server Type =====
    IF lv_entity CS 'VH_SERVER_TYPE' OR lv_entity CS 'VHSERVERTYPE'
        OR ( lv_entity CS 'SERVERTYPE' AND lv_entity CS 'VH' ).
      DATA lt_stype TYPE STANDARD TABLE OF zc_scort_vh_server_type WITH DEFAULT KEY.
      lt_stype = VALUE #(
        ( ServerType = 'L' Description = 'Local / Origin' )
        ( ServerType = 'T' Description = 'Target REPO (ZA026_SCORT_REPO)' )
      ).
      respond_typed( EXPORTING io_request = io_request io_response = io_response
                     CHANGING  ct_data = lt_stype ).
      RETURN.
    ENDIF.

    "===== VH Server Id =====
    IF lv_entity CS 'VH_SERVER_ID' OR lv_entity CS 'VHSERVERID'
        OR ( lv_entity CS 'SERVERID' AND lv_entity CS 'VH' ).
      DATA lt_sid TYPE STANDARD TABLE OF zc_scort_vh_server_id WITH DEFAULT KEY.
      DATA ls_sid TYPE zc_scort_vh_server_id.

      ls_sid-ServerId = 'TGT'.
      ls_sid-Description = 'Target simulator (ZA026_SCORT_REPO)'.
      APPEND ls_sid TO lt_sid.

      respond_typed( EXPORTING io_request = io_request io_response = io_response
                     CHANGING  ct_data = lt_sid ).
      RETURN.
    ENDIF.

    "===== VH User / Person Responsible =====
    IF lv_entity CS 'VH_USER' OR lv_entity CS 'VHUSER'.
      DATA lt_user TYPE STANDARD TABLE OF zc_scort_vh_user WITH DEFAULT KEY.
      DATA ls_user TYPE zc_scort_vh_user.
      DATA lt_usr02 TYPE STANDARD TABLE OF usr02 WITH DEFAULT KEY.

      lv_pat = zcl_scort_query_utl=>filter_low( io_request = io_request iv_field = 'USERID' ).
      IF lv_pat IS INITIAL.
        lv_pat = zcl_scort_query_utl=>value_of( iv_sql = lv_sql iv_field = 'USERID' ).
      ENDIF.

      IF lv_pat IS NOT INITIAL.
        " Exact
        SELECT bname FROM usr02 WHERE bname = @lv_pat INTO TABLE @DATA(lt_usr_exact) UP TO 5 ROWS.
        IF lt_usr_exact IS INITIAL AND strlen( lv_pat ) >= 2.
          lv_like = |{ lv_pat }%|.
          SELECT bname FROM usr02 WHERE bname LIKE @lv_like ORDER BY bname
            INTO TABLE @DATA(lt_usr_like) UP TO 100 ROWS.
          LOOP AT lt_usr_like INTO DATA(lv_bname_like).
            CLEAR ls_user.
            ls_user-UserId = lv_bname_like.
            APPEND ls_user TO lt_user.
          ENDLOOP.
        ELSE.
          LOOP AT lt_usr_exact INTO DATA(lv_bname_ex).
            CLEAR ls_user.
            ls_user-UserId = lv_bname_ex.
            APPEND ls_user TO lt_user.
          ENDLOOP.
        ENDIF.
      ELSE.
        " Browse: 100 users gần nhất (active)
        SELECT bname FROM usr02 WHERE gltgv <= @sy-datum
          ORDER BY bname INTO TABLE @DATA(lt_usr_browse) UP TO 100 ROWS.
        LOOP AT lt_usr_browse INTO DATA(lv_bname_br).
          CLEAR ls_user.
          ls_user-UserId = lv_bname_br.
          APPEND ls_user TO lt_user.
        ENDLOOP.
      ENDIF.

      respond_typed( EXPORTING io_request = io_request io_response = io_response
                     CHANGING  ct_data = lt_user ).
      RETURN.
    ENDIF.

    "===== VH Package / Development Class =====
    IF lv_entity CS 'VH_PACKAGE' OR lv_entity CS 'VHPACKAGE'.
      DATA lt_pkg TYPE STANDARD TABLE OF zc_scort_vh_package WITH DEFAULT KEY.
      DATA ls_pkg TYPE zc_scort_vh_package.

      lv_pat = zcl_scort_query_utl=>filter_low( io_request = io_request iv_field = 'PACKAGENAME' ).
      IF lv_pat IS INITIAL.
        lv_pat = zcl_scort_query_utl=>value_of( iv_sql = lv_sql iv_field = 'PACKAGENAME' ).
      ENDIF.

      IF lv_pat IS NOT INITIAL.
        " Exact
        SELECT devclass, ctext FROM tdevc AS p
          LEFT OUTER JOIN tdevct AS t ON t~devclass = p~devclass AND t~spras = @sy-langu
          WHERE p~devclass = @lv_pat
          INTO TABLE @DATA(lt_pkg_exact) UP TO 5 ROWS.
        IF lt_pkg_exact IS INITIAL AND strlen( lv_pat ) >= 2.
          lv_like = |{ lv_pat }%|.
          SELECT devclass, ctext FROM tdevc AS p
            LEFT OUTER JOIN tdevct AS t ON t~devclass = p~devclass AND t~spras = @sy-langu
            WHERE p~devclass LIKE @lv_like ORDER BY p~devclass
            INTO TABLE @DATA(lt_pkg_like) UP TO 100 ROWS.
          LOOP AT lt_pkg_like INTO DATA(ls_pkg_row).
            CLEAR ls_pkg.
            ls_pkg-PackageName  = ls_pkg_row-devclass.
            ls_pkg-Description  = ls_pkg_row-ctext.
            APPEND ls_pkg TO lt_pkg.
          ENDLOOP.
        ELSE.
          LOOP AT lt_pkg_exact INTO DATA(ls_pkg_ex).
            CLEAR ls_pkg.
            ls_pkg-PackageName  = ls_pkg_ex-devclass.
            ls_pkg-Description  = ls_pkg_ex-ctext.
            APPEND ls_pkg TO lt_pkg.
          ENDLOOP.
        ENDIF.
      ELSE.
        " Browse: chỉ Z*/Y* package
        SELECT devclass, ctext FROM tdevc AS p
          LEFT OUTER JOIN tdevct AS t ON t~devclass = p~devclass AND t~spras = @sy-langu
          WHERE ( p~devclass LIKE 'Z%' OR p~devclass LIKE 'Y%' )
          ORDER BY p~devclass
          INTO TABLE @DATA(lt_pkg_browse) UP TO 100 ROWS.
        LOOP AT lt_pkg_browse INTO DATA(ls_pkg_br).
          CLEAR ls_pkg.
          ls_pkg-PackageName  = ls_pkg_br-devclass.
          ls_pkg-Description  = ls_pkg_br-ctext.
          APPEND ls_pkg TO lt_pkg.
        ENDLOOP.
      ENDIF.

      respond_typed( EXPORTING io_request = io_request io_response = io_response
                     CHANGING  ct_data = lt_pkg ).
      RETURN.
    ENDIF.

    "===== Unknown entity — vẫn cover =====
    DATA lt_fallback TYPE STANDARD TABLE OF zc_scort_vh_obj_type WITH DEFAULT KEY.
    respond_typed( EXPORTING io_request = io_request io_response = io_response
                   CHANGING  ct_data = lt_fallback ).
  ENDMETHOD.

  METHOD respond_typed.
    DATA lv_skip TYPE i.
    DATA lv_top  TYPE i.
    DATA lv_from TYPE i.
    DATA lv_to   TYPE i.
    DATA lt_sort TYPE if_rap_query_request=>tt_sort_elements.
    DATA lt_page TYPE REF TO data.
    DATA lv_field TYPE string.
    DATA lv_data_req TYPE abap_bool.
    DATA lv_count_req TYPE abap_bool.
    FIELD-SYMBOLS <lt_all>  TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lt_page> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <ls>      TYPE any.

    ASSIGN ct_data TO <lt_all>.

    " Cover $orderby (best-effort — không dump nếu field lạ)
    TRY.
        lt_sort = io_request->get_sort_elements( ).
      CATCH cx_root.
        CLEAR lt_sort.
    ENDTRY.
    IF lines( lt_sort ) > 0 AND lines( <lt_all> ) > 0.
      READ TABLE lt_sort INTO DATA(ls_sort) INDEX 1.
      IF sy-subrc = 0.
        lv_field = to_upper( CONV string( ls_sort-element_name ) ).
        TRY.
            IF ls_sort-descending = abap_true.
              SORT <lt_all> BY (lv_field) DESCENDING.
            ELSE.
              SORT <lt_all> BY (lv_field) ASCENDING.
            ENDIF.
          CATCH cx_root.
        ENDTRY.
      ENDIF.
    ENDIF.

    " Cover paging ($skip / $top) — top <= 0 hoặc unlimited → trả hết
    TRY.
        lv_skip = CONV i( io_request->get_paging( )->get_offset( ) ).
      CATCH cx_root.
        lv_skip = 0.
    ENDTRY.
    TRY.
        lv_top = CONV i( io_request->get_paging( )->get_page_size( ) ).
      CATCH cx_root.
        lv_top = 0.
    ENDTRY.

    CREATE DATA lt_page LIKE <lt_all>.
    ASSIGN lt_page->* TO <lt_page>.

    IF lv_top <= 0 OR lv_top >= 2147483647.
      <lt_page> = <lt_all>.
    ELSE.
      lv_from = lv_skip + 1.
      lv_to   = lv_skip + lv_top.
      LOOP AT <lt_all> ASSIGNING <ls> FROM lv_from TO lv_to.
        APPEND <ls> TO <lt_page>.
      ENDLOOP.
    ENDIF.

    " Cover data + count — FE Preview thường xin cả hai
    TRY.
        lv_data_req = io_request->is_data_requested( ).
      CATCH cx_root.
        lv_data_req = abap_true.
    ENDTRY.
    TRY.
        lv_count_req = io_request->is_total_numb_of_rec_requested( ).
      CATCH cx_root.
        lv_count_req = abap_true.
    ENDTRY.

    IF lv_data_req = abap_true.
      io_response->set_data( <lt_page> ).
    ENDIF.
    IF lv_count_req = abap_true.
      io_response->set_total_number_of_records( CONV int8( lines( <lt_all> ) ) ).
    ENDIF.

    " Một số request FE không set flag rõ — vẫn cover để tránh "not fully covered"
    IF lv_data_req = abap_false AND lv_count_req = abap_false.
      io_response->set_data( <lt_page> ).
      io_response->set_total_number_of_records( CONV int8( lines( <lt_all> ) ) ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
