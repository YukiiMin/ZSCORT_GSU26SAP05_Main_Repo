*"*---------------------------------------------------------------------*
*"* Class: ZCL_SCORT_T_READER
*"* Read Target from ZA05_SCORT_T (header) + ZA05_SCORT_T_SRC (GZIP).
*"* current_version trên header; SOURCE_HEX + SRC_HASH trên T_SRC.
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
        version_no  TYPE versno,
        checksum    TYPE c LENGTH 40,
        author      TYPE as4user,
        trkorr      TYPE trkorr,
        descript    TYPE as4text,
        is_current  TYPE abap_bool,
        src_preview TYPE c LENGTH 255,
        message     TYPE string,
      END OF ty_version,
      tt_version TYPE STANDARD TABLE OF ty_version WITH DEFAULT KEY.


    CONSTANTS c_pgmid_r3tr TYPE pgmid VALUE 'R3TR'.

    CLASS-METHODS read_version
      IMPORTING
        iv_object_type   TYPE trobjtype
        iv_object_name   TYPE sobj_name

        iv_version_no    TYPE numc5 OPTIONAL
      RETURNING
        VALUE(rs_source) TYPE ty_source.

    CLASS-METHODS read_current
      IMPORTING
        iv_object_type   TYPE trobjtype
        iv_object_name   TYPE sobj_name

      RETURNING
        VALUE(rs_source) TYPE ty_source.

    CLASS-METHODS list_versions
      IMPORTING
        iv_object_type TYPE trobjtype
        iv_object_name TYPE sobj_name
      RETURNING
        VALUE(rt_vers) TYPE tt_version.

ENDCLASS.


CLASS zcl_scort_t_reader IMPLEMENTATION.

  METHOD read_current.
    DATA lv_vers     TYPE versno.
    DATA lv_obj_name TYPE trobj_name.

    CLEAR rs_source.
    rs_source-object_type = iv_object_type.
    rs_source-object_name = iv_object_name.

    lv_obj_name = CONV trobj_name( iv_object_name ).

    SELECT SINGLE current_version FROM za05_scort_t
      WHERE pgmid    = @c_pgmid_r3tr
        AND object   = @iv_object_type
        AND obj_name = @lv_obj_name
      INTO @lv_vers.

    IF sy-subrc <> 0 OR lv_vers IS INITIAL OR lv_vers = '00000'.
      rs_source-found         = abap_false.
      rs_source-is_new_target = abap_true.
      rs_source-message       = 'NEW_AT_TARGET — chưa có trong ZA05_SCORT_T'.
      RETURN.
    ENDIF.

    rs_source = read_version(
      iv_object_type = iv_object_type
      iv_object_name = iv_object_name

      iv_version_no  = lv_vers ).
    rs_source-is_current = abap_true.
  ENDMETHOD.

  METHOD read_version.
    DATA lv_hex      TYPE xstring.
    DATA lv_hash     TYPE c LENGTH 40.
    DATA lv_text     TYPE string.
    DATA lv_vers     TYPE versno.
    DATA lv_trkorr   TYPE trkorr.
    DATA lv_obj_name TYPE trobj_name.
    DATA lv_cur      TYPE versno.

    CLEAR rs_source.
    rs_source-object_type = iv_object_type.
    rs_source-object_name = iv_object_name.

    lv_obj_name = CONV trobj_name( iv_object_name ).

    IF iv_version_no IS SUPPLIED AND iv_version_no IS NOT INITIAL
        AND iv_version_no <> '00000'.
      lv_vers = iv_version_no.
    ELSE.
      rs_source = read_current(
        iv_object_type = iv_object_type
      iv_object_name = iv_object_name ).
      RETURN.
    ENDIF.
    rs_source-version_no = lv_vers.

    SELECT SINGLE source_hex, src_hash, src_trkorr
      FROM za05_scort_t_src
      WHERE pgmid      = @c_pgmid_r3tr
        AND object     = @iv_object_type
        AND obj_name   = @lv_obj_name
        AND version_no = @lv_vers
      INTO (@lv_hex, @lv_hash, @lv_trkorr).

    IF sy-subrc <> 0.
      rs_source-found         = abap_false.
      rs_source-is_new_target = abap_true.
      rs_source-message       = |Version { lv_vers } không có trong ZA05_SCORT_T_SRC|.
      RETURN.
    ENDIF.

    rs_source-trkorr = lv_trkorr.

    SELECT SINGLE current_version FROM za05_scort_t
      WHERE pgmid    = @c_pgmid_r3tr
        AND object   = @iv_object_type
        AND obj_name = @lv_obj_name
      INTO @lv_cur.
    rs_source-is_current = boolc( sy-subrc = 0 AND lv_cur = lv_vers ).

    IF lv_hex IS INITIAL.
      rs_source-found         = abap_false.
      rs_source-is_new_target = abap_false.
      rs_source-decompress_ok = abap_false.
      rs_source-hash_stored   = lv_hash.
      rs_source-message       = |SOURCE_HEX empty (vers { lv_vers })|.
      RETURN.
    ENDIF.

    lv_text = zcl_scort_compression_utl=>decode_hex_to_text( lv_hex ).
    IF lv_text IS INITIAL.
      rs_source-found         = abap_false.
      rs_source-decompress_ok = abap_false.
      rs_source-hash_stored   = lv_hash.
      rs_source-message       = |Decompress failed (vers { lv_vers })|.
      RETURN.
    ENDIF.

    rs_source-found         = abap_true.
    rs_source-decompress_ok = abap_true.
    rs_source-text          = lv_text.
    rs_source-lines         = zcl_scort_hash_utl=>text_to_lines( lv_text ).
    rs_source-line_count    = lines( rs_source-lines ).
    rs_source-hash_stored   = lv_hash.
    " Hash plain text — cùng Apply / CALCULATE_CHECKSUM (không hash blob GZIP)
    rs_source-hash_calc     = zcl_scort_hash_utl=>calculate_checksum( lv_text ).
    rs_source-message       = |OK ZA05 vers { lv_vers }, { rs_source-line_count } lines|.
  ENDMETHOD.

  METHOD list_versions.
    DATA:
      BEGIN OF ls_db,
        version_no  TYPE versno,
        src_hash    TYPE c LENGTH 40,
        created_by  TYPE as4user,
        src_trkorr  TYPE trkorr,
        src_preview TYPE c LENGTH 255,
      END OF ls_db,
      lt_db LIKE STANDARD TABLE OF ls_db WITH DEFAULT KEY.
    DATA ls_out      TYPE ty_version.
    DATA lv_label    TYPE string.
    DATA lv_cur      TYPE versno.
    DATA lv_obj_name TYPE trobj_name.

    CLEAR rt_vers.
    lv_obj_name = CONV trobj_name( iv_object_name ).

    SELECT SINGLE current_version FROM za05_scort_t
      WHERE pgmid    = @c_pgmid_r3tr
        AND object   = @iv_object_type
        AND obj_name = @lv_obj_name
      INTO @lv_cur.

    SELECT version_no, src_hash, created_by, src_trkorr, src_preview
      FROM za05_scort_t_src
      WHERE pgmid    = @c_pgmid_r3tr
        AND object   = @iv_object_type
        AND obj_name = @lv_obj_name
      ORDER BY version_no DESCENDING
      INTO CORRESPONDING FIELDS OF TABLE @lt_db
      UP TO 200 ROWS.

    LOOP AT lt_db INTO ls_db.
      CLEAR ls_out.
      ls_out-version_no  = ls_db-version_no.
      ls_out-checksum    = ls_db-src_hash.
      ls_out-author      = ls_db-created_by.
      ls_out-trkorr      = ls_db-src_trkorr.
      ls_out-src_preview = ls_db-src_preview.
      ls_out-is_current  = boolc( lv_cur IS NOT INITIAL AND ls_db-version_no = lv_cur ).
      lv_label = CONV string( ls_db-version_no ).
      SHIFT lv_label LEFT DELETING LEADING '0'.
      IF lv_label IS INITIAL.
        lv_label = '0'.
      ENDIF.
      IF ls_out-is_current = abap_true.
        ls_out-message = |{ lv_label } (current)|.
      ELSEIF ls_db-src_trkorr IS NOT INITIAL.
        ls_out-message = |{ lv_label } — { ls_db-src_trkorr }|.
      ELSE.
        ls_out-message = lv_label.
      ENDIF.
      APPEND ls_out TO rt_vers.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
