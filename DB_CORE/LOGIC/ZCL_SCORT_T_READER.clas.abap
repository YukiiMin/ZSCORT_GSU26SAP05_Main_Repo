*"*---------------------------------------------------------------------*
*"* Class: ZCL_SCORT_T_READER
*"* Read Target simulator from ZA026_SCORT_REPO (plain SOURCE_CODE).
*"* ZA026_SCORT_HIST = audit trail (REQ2) — không dùng cho Compare.
*"*---------------------------------------------------------------------*
CLASS zcl_scort_t_reader DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_string_tab TYPE zcl_scort_l_reader=>ty_string_tab.

    TYPES:
      BEGIN OF ty_source,
        object_type   TYPE trobjtype,
        object_name   TYPE sobj_name,
        server_id     TYPE c LENGTH 10,
        version_no    TYPE numc5,
        found         TYPE abap_bool,
        is_new_target TYPE abap_bool,
        decompress_ok TYPE abap_bool,
        lines         TYPE ty_string_tab,
        text          TYPE string,
        hash_stored   TYPE c LENGTH 40,
        hash_calc     TYPE c LENGTH 40,
        line_count    TYPE i,
        message       TYPE string,
        trkorr        TYPE trkorr,
        is_current    TYPE abap_bool,
      END OF ty_source,

      BEGIN OF ty_version,
        version_no TYPE versno,
        checksum   TYPE c LENGTH 40,
        author     TYPE as4user,
        trkorr     TYPE trkorr,
        descript   TYPE as4text,
        is_current TYPE abap_bool,
        src_preview TYPE c LENGTH 255,
        message    TYPE string,
      END OF ty_version,
      tt_version TYPE STANDARD TABLE OF ty_version WITH DEFAULT KEY.

    " Giữ API cũ — simulator Target không còn server_id trên bảng
    CONSTANTS c_server_tgt TYPE c LENGTH 10 VALUE 'TGT'.
    CONSTANTS c_pgmid_r3tr TYPE pgmid VALUE 'R3TR'.
    CONSTANTS c_tab_repo   TYPE tabname VALUE 'ZA026_SCORT_REPO'.
    CONSTANTS c_tab_hist   TYPE tabname VALUE 'ZA026_SCORT_HIST'.

    CLASS-METHODS read_version
      IMPORTING
        iv_object_type   TYPE trobjtype
        iv_object_name   TYPE sobj_name
        iv_server_id     TYPE c DEFAULT c_server_tgt
        iv_version_no    TYPE numc5 OPTIONAL
      RETURNING
        VALUE(rs_source) TYPE ty_source.

    CLASS-METHODS read_current
      IMPORTING
        iv_object_type   TYPE trobjtype
        iv_object_name   TYPE sobj_name
        iv_server_id     TYPE c DEFAULT c_server_tgt
      RETURNING
        VALUE(rs_source) TYPE ty_source.

    CLASS-METHODS list_versions
      IMPORTING
        iv_object_type   TYPE trobjtype
        iv_object_name   TYPE sobj_name
      RETURNING
        VALUE(rt_vers)   TYPE tt_version.

ENDCLASS.


CLASS zcl_scort_t_reader IMPLEMENTATION.

  METHOD read_current.
    DATA lv_vers TYPE numc5.

    CLEAR rs_source.
    rs_source-object_type = iv_object_type.
    rs_source-object_name = iv_object_name.
    rs_source-server_id   = COND #( WHEN iv_server_id IS INITIAL THEN c_server_tgt ELSE iv_server_id ).

    SELECT SINGLE version_no FROM za026_scort_repo
      WHERE pgmid      = @c_pgmid_r3tr
        AND object     = @iv_object_type
        AND obj_name   = @iv_object_name
        AND is_current = @abap_true
      INTO @lv_vers.

    IF sy-subrc <> 0 OR lv_vers IS INITIAL.
      " Fallback: version mới nhất nếu chưa gắn is_current
      SELECT version_no FROM za026_scort_repo
        WHERE pgmid    = @c_pgmid_r3tr
          AND object   = @iv_object_type
          AND obj_name = @iv_object_name
        ORDER BY version_no DESCENDING
        INTO @lv_vers
        UP TO 1 ROWS.
      ENDSELECT.
    ENDIF.

    IF lv_vers IS INITIAL.
      rs_source-found         = abap_false.
      rs_source-is_new_target = abap_true.
      rs_source-message       = 'NEW_AT_TARGET — chưa có bản trong ZA026_SCORT_REPO'.
      RETURN.
    ENDIF.

    rs_source = read_version(
      iv_object_type = iv_object_type
      iv_object_name = iv_object_name
      iv_server_id   = rs_source-server_id
      iv_version_no  = lv_vers ).
  ENDMETHOD.

  METHOD read_version.
    DATA lv_text   TYPE string.
    DATA lv_hash   TYPE c LENGTH 40.
    DATA lv_vers   TYPE numc5.
    DATA lv_trkorr TYPE trkorr.
    DATA lv_curr   TYPE abap_bool.
    DATA lv_prev   TYPE c LENGTH 255.

    CLEAR rs_source.
    rs_source-object_type = iv_object_type.
    rs_source-object_name = iv_object_name.
    rs_source-server_id   = COND #( WHEN iv_server_id IS INITIAL THEN c_server_tgt ELSE iv_server_id ).

    IF iv_version_no IS SUPPLIED AND iv_version_no IS NOT INITIAL.
      lv_vers = iv_version_no.
    ELSE.
      rs_source = read_current(
        iv_object_type = iv_object_type
        iv_object_name = iv_object_name
        iv_server_id   = rs_source-server_id ).
      RETURN.
    ENDIF.
    rs_source-version_no = lv_vers.

    SELECT SINGLE source_code, checksum, trkorr, is_current, src_preview
      FROM za026_scort_repo
      WHERE pgmid      = @c_pgmid_r3tr
        AND object     = @iv_object_type
        AND obj_name   = @iv_object_name
        AND version_no = @lv_vers
      INTO (@lv_text, @lv_hash, @lv_trkorr, @lv_curr, @lv_prev).

    IF sy-subrc <> 0.
      rs_source-found         = abap_false.
      rs_source-is_new_target = abap_true.
      rs_source-message       = |Version { lv_vers } không có trong ZA026_SCORT_REPO|.
      RETURN.
    ENDIF.

    rs_source-trkorr     = lv_trkorr.
    rs_source-is_current = boolc( lv_curr = abap_true OR lv_curr = 'X' ).

    IF lv_text IS INITIAL.
      rs_source-found         = abap_false.
      rs_source-is_new_target = abap_false.
      rs_source-decompress_ok = abap_false.
      rs_source-hash_stored   = lv_hash.
      rs_source-message       = |REPO source_code empty (vers { lv_vers })|.
      RETURN.
    ENDIF.

    rs_source-found         = abap_true.
    rs_source-decompress_ok = abap_true. " plain STRING — không GZIP
    rs_source-text          = lv_text.
    rs_source-lines         = zcl_scort_hash_utl=>text_to_lines( lv_text ).
    rs_source-line_count    = lines( rs_source-lines ).
    rs_source-hash_stored   = lv_hash.
    " Cùng thuật toán ZCL026_SCORT_TARGET_APPLY=>CALCULATE_CHECKSUM
    rs_source-hash_calc     = zcl_scort_hash_utl=>calculate_checksum( lv_text ).
    rs_source-message       = |OK REPO vers { lv_vers }, { rs_source-line_count } lines|.
    IF lv_prev IS NOT INITIAL AND rs_source-message IS NOT INITIAL.
      " preview chỉ metadata — không ghi đè message chính
    ENDIF.
  ENDMETHOD.

  METHOD list_versions.
    DATA:
      BEGIN OF ls_db,
        version_no  TYPE versno,
        checksum    TYPE c LENGTH 40,
        author      TYPE as4user,
        trkorr      TYPE trkorr,
        descript    TYPE as4text,
        is_current  TYPE c LENGTH 1,
        src_preview TYPE c LENGTH 255,
      END OF ls_db,
      lt_db LIKE STANDARD TABLE OF ls_db WITH DEFAULT KEY.
    DATA ls_out TYPE ty_version.
    DATA lv_label TYPE string.

    CLEAR rt_vers.

    SELECT version_no, checksum, author, trkorr, descript, is_current, src_preview
      FROM za026_scort_repo
      WHERE pgmid    = @c_pgmid_r3tr
        AND object   = @iv_object_type
        AND obj_name = @iv_object_name
      ORDER BY version_no DESCENDING
      INTO CORRESPONDING FIELDS OF TABLE @lt_db
      UP TO 200 ROWS.

    LOOP AT lt_db INTO ls_db.
      CLEAR ls_out.
      ls_out-version_no  = ls_db-version_no.
      ls_out-checksum    = ls_db-checksum.
      ls_out-author      = ls_db-author.
      ls_out-trkorr      = ls_db-trkorr.
      ls_out-descript    = ls_db-descript.
      ls_out-is_current  = boolc( ls_db-is_current = abap_true OR ls_db-is_current = 'X' ).
      ls_out-src_preview = ls_db-src_preview.
      lv_label = CONV string( ls_db-version_no ).
      SHIFT lv_label LEFT DELETING LEADING '0'.
      IF lv_label IS INITIAL.
        lv_label = '0'.
      ENDIF.
      IF ls_out-is_current = abap_true.
        ls_out-message = |{ lv_label } (current)|.
      ELSEIF ls_db-descript IS NOT INITIAL.
        ls_out-message = |{ lv_label } — { ls_db-descript }|.
      ELSE.
        ls_out-message = lv_label.
      ENDIF.
      APPEND ls_out TO rt_vers.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
