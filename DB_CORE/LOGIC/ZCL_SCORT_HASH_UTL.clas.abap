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
    " Deprecated — Apply không normalize. Giữ API, trả nguyên dòng.
    rt_lines = it_lines.
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
