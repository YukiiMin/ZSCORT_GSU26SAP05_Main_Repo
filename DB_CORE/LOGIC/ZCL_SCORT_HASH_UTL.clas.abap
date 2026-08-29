*"*---------------------------------------------------------------------*
*"* Class: ZCL_SCORT_HASH_UTL
*"* Checksum khớp REQ2 Apply:
*"*   ZCL026_SCORT_TARGET_APPLY=>CALCULATE_CHECKSUM
*"* = SHA1 trên raw SOURCE_CODE (không normalize / không bỏ dòng trống).
*"*---------------------------------------------------------------------*
CLASS zcl_scort_hash_utl DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_string_tab TYPE STANDARD TABLE OF string WITH DEFAULT KEY.
    TYPES ty_hash       TYPE c LENGTH 40.

    "! Alias giữ tên cũ — giờ = raw SHA1 (không normalize), khớp Apply.
    CLASS-METHODS normalize_and_hash
      IMPORTING
        it_lines       TYPE ty_string_tab
      RETURNING
        VALUE(rv_hash) TYPE ty_hash.

    "! Giống ZCL026_SCORT_TARGET_APPLY=>CALCULATE_CHECKSUM
    CLASS-METHODS calculate_checksum
      IMPORTING
        iv_source          TYPE string
      RETURNING
        VALUE(rv_checksum) TYPE ty_hash.

    CLASS-METHODS normalize_lines
      IMPORTING
        it_lines        TYPE ty_string_tab
      RETURNING
        VALUE(rt_lines) TYPE ty_string_tab.

    CLASS-METHODS lines_to_text
      IMPORTING
        it_lines       TYPE ty_string_tab
      RETURNING
        VALUE(rv_text) TYPE string.

    "! Tiền xử lý (Pre-Diff Adapter) xóa trailing spaces, CRLF và comment rác.
    CLASS-METHODS normalize_source
      IMPORTING
        it_lines        TYPE ty_string_tab
      RETURNING
        VALUE(rt_lines) TYPE ty_string_tab.

    CLASS-METHODS text_to_lines
      IMPORTING
        iv_text         TYPE string
      RETURNING
        VALUE(rt_lines) TYPE ty_string_tab.

    CLASS-METHODS hash_text
      IMPORTING
        iv_text        TYPE string
      RETURNING
        VALUE(rv_hash) TYPE ty_hash.

ENDCLASS.


CLASS zcl_scort_hash_utl IMPLEMENTATION.

  METHOD lines_to_text.
    " Khớp concat_lines_of( ... sep = newline ) bên Apply
    CLEAR rv_text.
    IF it_lines IS INITIAL.
      RETURN.
    ENDIF.
    rv_text = concat_lines_of(
                table = it_lines
                sep   = cl_abap_char_utilities=>newline ).
  ENDMETHOD.

  METHOD text_to_lines.
    CLEAR rt_lines.
    IF iv_text IS INITIAL.
      RETURN.
    ENDIF.
    SPLIT iv_text AT cl_abap_char_utilities=>newline INTO TABLE rt_lines.
  ENDMETHOD.

  METHOD normalize_lines.
    rt_lines = normalize_source( it_lines ).
  ENDMETHOD.

  METHOD normalize_source.
    DATA: lv_line TYPE string.
    CLEAR rt_lines.
    LOOP AT it_lines INTO lv_line.
      " Loại bỏ CRLF sang LF (hoặc bỏ CR vì LOOP string tab đã chia theo newline)
      REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf IN lv_line WITH cl_abap_char_utilities=>newline.
      REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>horizontal_tab IN lv_line WITH ` `.
      
      " Xóa khoảng trắng thừa ở cuối dòng (trailing spaces)
      REPLACE REGEX `\s+$` IN lv_line WITH ``.

      " Bỏ qua các dòng trống
      IF lv_line IS INITIAL.
        CONTINUE.
      ENDIF.
      
      DATA(lv_trim) = lv_line.
      CONDENSE lv_trim.
      " Bỏ qua các dòng comment rác (chỉ chứa * hoặc ")
      IF lv_trim(1) = '*' OR lv_trim(1) = '"'.
        IF strlen( lv_trim ) = 1.
          CONTINUE.
        ENDIF.
      ENDIF.

      APPEND lv_line TO rt_lines.
    ENDLOOP.
  ENDMETHOD.

  METHOD calculate_checksum.
    CLEAR rv_checksum.

    IF iv_source IS INITIAL.
      rv_checksum = 'INITIAL'.
      RETURN.
    ENDIF.

    TRY.
        cl_abap_message_digest=>calculate_hash_for_char(
          EXPORTING
            if_algorithm  = 'SHA1'
            if_data       = iv_source
          IMPORTING
            ef_hashstring = DATA(lv_hash) ).
        rv_checksum = lv_hash.
      CATCH cx_root.
        rv_checksum = 'ERROR'.
    ENDTRY.
  ENDMETHOD.

  METHOD hash_text.
    rv_hash = calculate_checksum( iv_text ).
  ENDMETHOD.

  METHOD normalize_and_hash.
    " Không strip/trim — cùng blob mà Apply ghi vào CHECKSUM
    rv_hash = calculate_checksum( lines_to_text( it_lines ) ).
  ENDMETHOD.

ENDCLASS.
