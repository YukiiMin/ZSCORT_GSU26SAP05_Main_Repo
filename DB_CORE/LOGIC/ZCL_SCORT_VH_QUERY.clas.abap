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
    TYPES: BEGIN OF ty_tadir_sub,
             object   TYPE tadir-object,
             obj_name TYPE tadir-obj_name,
             devclass TYPE tadir-devclass,
             author   TYPE tadir-author,
           END OF ty_tadir_sub.
    DATA lt_tadir  TYPE STANDARD TABLE OF ty_tadir_sub WITH DEFAULT KEY.

    TRY.
        lv_entity = to_upper( io_request->get_entity_id( ) ).
      CATCH cx_root.
        CLEAR lv_entity.
    ENDTRY.

    lv_sql = zcl_scort_query_utl=>get_filter_sql( io_request ).

    IF lv_entity CS 'VH_TRKORR' OR lv_entity CS 'VHTRKORR'.
      DATA lt_trkorr TYPE STANDARD TABLE OF zc_scort_vh_trkorr WITH DEFAULT KEY.
      DATA ls_trkorr TYPE zc_scort_vh_trkorr.
      DATA lt_e070 TYPE STANDARD TABLE OF e070 WITH DEFAULT KEY.

      lv_pat = zcl_scort_query_utl=>filter_low( io_request = io_request iv_field = 'TRKORR' ).
      IF lv_pat IS INITIAL.
        lv_pat = zcl_scort_query_utl=>value_of( iv_sql = lv_sql iv_field = 'TRKORR' ).
      ENDIF.

      IF lv_pat IS NOT INITIAL.
        SELECT trkorr, trstatus, trfunction, as4user, as4date, strkorr
          FROM e070
          WHERE trkorr = @lv_pat
          INTO CORRESPONDING FIELDS OF TABLE @lt_e070
          UP TO 5 ROWS.

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

    IF lv_entity CS 'VH_OBJ_TYPE' OR lv_entity CS 'VHOBJTYPE'.
      DATA lt_otype TYPE STANDARD TABLE OF zc_scort_vh_obj_type WITH DEFAULT KEY.
      lt_otype = VALUE #(
        ( ObjectType = 'PROG' Description = 'Program / Report' )
        ( ObjectType = 'CLAS' Description = 'Class' )
        ( ObjectType = 'INTF' Description = 'Interface' )
        ( ObjectType = 'FUNC' Description = 'Function Module' )
        ( ObjectType = 'FUGR' Description = 'Function Group' )
        ( ObjectType = 'DDLS' Description = 'CDS View Entity' )
        ( ObjectType = 'BDEF' Description = 'Behavior Definition' )
        ( ObjectType = 'DCLS' Description = 'Access Control (CDS Role)' )
        ( ObjectType = 'DDLX' Description = 'Metadata Extension' )
        ( ObjectType = 'SRVD' Description = 'Service Definition' )
        ( ObjectType = 'TABL' Description = 'Database Table / Structure' )
        ( ObjectType = 'DTEL' Description = 'Data Element' )
        ( ObjectType = 'DOMA' Description = 'Domain' )
        ( ObjectType = 'TTYP' Description = 'Table Type' )
        ( ObjectType = 'VIEW' Description = 'Database View' )
        ( ObjectType = 'MSAG' Description = 'Message Class' )
        ( ObjectType = 'DEVC' Description = 'Package' )
        ( ObjectType = 'TRAN' Description = 'Transaction Code' )
        ( ObjectType = 'NROB' Description = 'Number Range Object' )
        ( ObjectType = 'WAPA' Description = 'BSP / Web Dynpro Application' )
        ( ObjectType = 'SSFO' Description = 'Smart Form' )
        ( ObjectType = 'SHLP' Description = 'Search Help' )
      ).
      respond_typed( EXPORTING io_request = io_request io_response = io_response
                     CHANGING  ct_data = lt_otype ).
      RETURN.
    ENDIF.

    IF lv_entity CS 'VH_OBJ_NAME' OR lv_entity CS 'VHOBJNAME'.
      DATA lt_oname TYPE STANDARD TABLE OF zc_scort_vh_obj_name WITH DEFAULT KEY.
      DATA ls_oname TYPE zc_scort_vh_obj_name.
      DATA lt_types TYPE RANGE OF trobjtype.

      lv_type = zcl_scort_query_utl=>filter_low( io_request = io_request iv_field = 'OBJECTTYPE' ).
      lv_name = zcl_scort_query_utl=>filter_low( io_request = io_request iv_field = 'OBJECTNAME' ).

      lt_types = VALUE #(
        ( sign = 'I' option = 'EQ' low = 'PROG' )
        ( sign = 'I' option = 'EQ' low = 'CLAS' )
        ( sign = 'I' option = 'EQ' low = 'INTF' )
        ( sign = 'I' option = 'EQ' low = 'FUGR' )
        ( sign = 'I' option = 'EQ' low = 'DTEL' )
        ( sign = 'I' option = 'EQ' low = 'DOMA' )
        ( sign = 'I' option = 'EQ' low = 'TABL' )
        ( sign = 'I' option = 'EQ' low = 'DDLS' )
        ( sign = 'I' option = 'EQ' low = 'BDEF' )
        ( sign = 'I' option = 'EQ' low = 'DCLS' )
        ( sign = 'I' option = 'EQ' low = 'DDLX' )
        ( sign = 'I' option = 'EQ' low = 'SRVD' )
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

      IF lv_type = 'FUNC'.
        IF lv_name IS NOT INITIAL.
          SELECT f~funcname AS obj_name, t~devclass, t~author
            FROM enlfdir AS f
            INNER JOIN tadir AS t
              ON t~pgmid = 'R3TR' AND t~object = 'FUGR' AND t~obj_name = f~area
              AND ( t~delflag IS NULL OR t~delflag = ' ' OR t~delflag = '' )
            WHERE f~funcname = @lv_name AND f~active = 'X'
            INTO TABLE @DATA(lt_funcs_exact)
            UP TO 5 ROWS. "#EC CI_BUFFJOIN
          LOOP AT lt_funcs_exact INTO DATA(ls_fe).
            CLEAR ls_oname.
            ls_oname-ObjectType = 'FUNC'.
            ls_oname-ObjectName = ls_fe-obj_name.
            ls_oname-Devclass   = ls_fe-devclass.
            ls_oname-Author     = ls_fe-author.
            APPEND ls_oname TO lt_oname.
          ENDLOOP.

          IF lt_oname IS INITIAL AND strlen( lv_name ) >= 2.
            lv_like = |{ lv_name }%|.
            SELECT f~funcname AS obj_name, t~devclass, t~author
              FROM enlfdir AS f
              INNER JOIN tadir AS t
                ON t~pgmid = 'R3TR' AND t~object = 'FUGR' AND t~obj_name = f~area
                AND ( t~delflag IS NULL OR t~delflag = ' ' OR t~delflag = '' )
              WHERE f~funcname LIKE @lv_like AND f~active = 'X'
              ORDER BY f~funcname
              INTO TABLE @DATA(lt_funcs_like)
              UP TO 100 ROWS. "#EC CI_BUFFJOIN
            LOOP AT lt_funcs_like INTO DATA(ls_fl).
              CLEAR ls_oname.
              ls_oname-ObjectType = 'FUNC'.
              ls_oname-ObjectName = ls_fl-obj_name.
              ls_oname-Devclass   = ls_fl-devclass.
              ls_oname-Author     = ls_fl-author.
              APPEND ls_oname TO lt_oname.
            ENDLOOP.
          ENDIF.
        ELSE.
          SELECT f~funcname AS obj_name, t~devclass, t~author
            FROM enlfdir AS f
            INNER JOIN tadir AS t
              ON t~pgmid = 'R3TR' AND t~object = 'FUGR' AND t~obj_name = f~area
              AND ( t~delflag IS NULL OR t~delflag = ' ' OR t~delflag = '' )
            WHERE ( f~funcname LIKE 'Z%' OR f~funcname LIKE 'Y%' ) AND f~active = 'X'
            ORDER BY f~funcname
            INTO TABLE @DATA(lt_funcs_browse)
            UP TO 100 ROWS. "#EC CI_BUFFJOIN
          LOOP AT lt_funcs_browse INTO DATA(ls_fb).
            CLEAR ls_oname.
            ls_oname-ObjectType = 'FUNC'.
            ls_oname-ObjectName = ls_fb-obj_name.
            ls_oname-Devclass   = ls_fb-devclass.
            ls_oname-Author     = ls_fb-author.
            APPEND ls_oname TO lt_oname.
          ENDLOOP.
        ENDIF.

        respond_typed( EXPORTING io_request = io_request io_response = io_response
                       CHANGING  ct_data = lt_oname ).
        RETURN.
      ENDIF.

      IF lv_name IS NOT INITIAL.
        IF lv_type IS NOT INITIAL.
          SELECT object, obj_name, devclass, author FROM tadir
            WHERE pgmid = 'R3TR' AND object = @lv_type AND obj_name = @lv_name
            INTO TABLE @lt_tadir
            UP TO 5 ROWS. "#EC CI_SGLSELECT
        ELSE.
          SELECT object, obj_name, devclass, author FROM tadir
            WHERE pgmid = 'R3TR' AND object IN @lt_types AND obj_name = @lv_name
            INTO TABLE @lt_tadir
            UP TO 5 ROWS. "#EC CI_SGLSELECT
        ENDIF.

        IF lt_tadir IS INITIAL AND strlen( lv_name ) >= 2.
          lv_like = |{ lv_name }%|.
          IF lv_type IS NOT INITIAL.
            SELECT object, obj_name, devclass, author FROM tadir
              WHERE pgmid = 'R3TR' AND object = @lv_type AND obj_name LIKE @lv_like
              ORDER BY obj_name
              INTO TABLE @lt_tadir
              UP TO 100 ROWS. "#EC CI_SGLSELECT
          ELSE.
            SELECT object, obj_name, devclass, author FROM tadir
              WHERE pgmid = 'R3TR' AND object IN @lt_types AND obj_name LIKE @lv_like
              ORDER BY obj_name
              INTO TABLE @lt_tadir
              UP TO 100 ROWS. "#EC CI_SGLSELECT
          ENDIF.
        ENDIF.
      ELSEIF lv_type IS NOT INITIAL.
        SELECT object, obj_name, devclass, author FROM tadir
          WHERE pgmid = 'R3TR'
            AND object = @lv_type
            AND ( obj_name LIKE 'Z%' OR obj_name LIKE 'Y%' )
          ORDER BY obj_name
          INTO TABLE @lt_tadir
          UP TO 100 ROWS. "#EC CI_SGLSELECT
      ENDIF.

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

    IF lv_entity CS 'VH_USER' OR lv_entity CS 'VHUSER'.
      DATA lt_user TYPE STANDARD TABLE OF zc_scort_vh_user WITH DEFAULT KEY.
      DATA ls_user TYPE zc_scort_vh_user.
      DATA lt_usr02 TYPE STANDARD TABLE OF usr02 WITH DEFAULT KEY.

      lv_pat = zcl_scort_query_utl=>filter_low( io_request = io_request iv_field = 'USERID' ).
      IF lv_pat IS INITIAL.
        lv_pat = zcl_scort_query_utl=>value_of( iv_sql = lv_sql iv_field = 'USERID' ).
      ENDIF.

      IF lv_pat IS NOT INITIAL.
        SELECT bname FROM usr02 WHERE bname = @lv_pat INTO TABLE @DATA(lt_usr_exact) UP TO 5 ROWS.
        IF lt_usr_exact IS INITIAL AND strlen( lv_pat ) >= 2.
          lv_like = |{ lv_pat }%|.
          SELECT bname FROM usr02 WHERE bname LIKE @lv_like ORDER BY bname
            INTO TABLE @DATA(lt_usr_like) UP TO 100 ROWS. "#EC CI_SGLSELECT
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
        SELECT bname FROM usr02 WHERE gltgv <= @sy-datum
          ORDER BY bname INTO TABLE @DATA(lt_usr_browse) UP TO 100 ROWS. "#EC CI_SGLSELECT
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

    IF lv_entity CS 'VH_PACKAGE' OR lv_entity CS 'VHPACKAGE'.
      DATA lt_pkg TYPE STANDARD TABLE OF zc_scort_vh_package WITH DEFAULT KEY.
      DATA ls_pkg TYPE zc_scort_vh_package.
      DATA lt_devc TYPE STANDARD TABLE OF tdevc-devclass WITH DEFAULT KEY.

      lv_pat = zcl_scort_query_utl=>filter_low( io_request = io_request iv_field = 'PACKAGENAME' ).
      IF lv_pat IS INITIAL.
        lv_pat = zcl_scort_query_utl=>value_of( iv_sql = lv_sql iv_field = 'PACKAGENAME' ).
      ENDIF.

      IF lv_pat IS NOT INITIAL.
        SELECT devclass FROM tdevc
          WHERE devclass = @lv_pat
          INTO TABLE @lt_devc UP TO 5 ROWS. "#EC CI_SGLSELECT

        IF lt_devc IS INITIAL AND strlen( lv_pat ) >= 2.
          lv_like = |{ lv_pat }%|.
          SELECT devclass FROM tdevc
            WHERE devclass LIKE @lv_like
            ORDER BY devclass
            INTO TABLE @lt_devc UP TO 100 ROWS. "#EC CI_SGLSELECT
        ENDIF.
      ELSE.
        SELECT devclass FROM tdevc
          WHERE ( devclass LIKE 'Z%' OR devclass LIKE 'Y%' )
          ORDER BY devclass
          INTO TABLE @lt_devc UP TO 100 ROWS. "#EC CI_SGLSELECT
      ENDIF.

      LOOP AT lt_devc INTO DATA(lv_devclass).
        CLEAR ls_pkg.
        ls_pkg-PackageName = lv_devclass.
        SELECT SINGLE ctext FROM tdevct
          WHERE spras = @sy-langu AND devclass = @lv_devclass
          INTO @ls_pkg-Description.
        IF ls_pkg-Description IS INITIAL.
          SELECT SINGLE ctext FROM tdevct
            WHERE spras = 'E' AND devclass = @lv_devclass
            INTO @ls_pkg-Description.
        ENDIF.
        APPEND ls_pkg TO lt_pkg.
      ENDLOOP.

      respond_typed( EXPORTING io_request = io_request io_response = io_response
                     CHANGING  ct_data = lt_pkg ).
      RETURN.
    ENDIF.

    DATA lt_fallback TYPE STANDARD TABLE OF zc_scort_vh_obj_type WITH DEFAULT KEY.
    respond_typed( EXPORTING io_request = io_request io_response = io_response
                   CHANGING  ct_data = lt_fallback ).
  ENDMETHOD.

  METHOD respond_typed.
    zcl_scort_query_utl=>respond(
      EXPORTING
        io_request  = io_request
        io_response = io_response
      CHANGING
        ct_data     = ct_data ).
  ENDMETHOD.

ENDCLASS.
