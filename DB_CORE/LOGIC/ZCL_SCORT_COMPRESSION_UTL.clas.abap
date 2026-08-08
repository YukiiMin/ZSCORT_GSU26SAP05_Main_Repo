CLASS zcl_scort_compression_utl DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Encodes source code lines to GZIP-compressed RAWSTRING.
    "! @parameter it_source_lines | Input: table of source code lines (string_table)
    "! @parameter rv_compressed   | Output: GZIP-compressed binary (RAWSTRING) for DB storage
    CLASS-METHODS encode_source_to_hex
      IMPORTING
        it_source_lines   TYPE string_table
      RETURNING
        VALUE(rv_compressed) TYPE xstring
      RAISING
        cx_parameter_invalid.

    "! Decodes GZIP-compressed RAWSTRING back to source code line table.
    "! @parameter iv_compressed   | Input: GZIP-compressed binary from DB
    "! @parameter rt_source_lines | Output: table of source code lines (string_table)
    CLASS-METHODS decode_hex_to_text
      IMPORTING
        iv_compressed     TYPE xstring
      RETURNING
        VALUE(rt_source_lines) TYPE string_table
      RAISING
        cx_parameter_invalid.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_scort_compression_utl IMPLEMENTATION.

  METHOD encode_source_to_hex.
    "-- Guard: empty input
    IF it_source_lines IS INITIAL.
      RAISE EXCEPTION TYPE cx_parameter_invalid
        EXPORTING
          parameter = 'IT_SOURCE_LINES'.
    ENDIF.

    "-- Step 1: Concatenate all lines with newline separator into one long string
    DATA(lv_newline)     = cl_abap_char_utilities=>newline.
    DATA(lv_full_source) = REDUCE string(
      INIT acc  = ``
      FOR  line IN it_source_lines
      NEXT acc  = COND #(
        WHEN acc IS INITIAL
          THEN line
          ELSE |{ acc }{ lv_newline }{ line }|
      )
    ).

    "-- Step 2: Convert string → xstring (UTF-8)
    DATA(lv_raw) = cl_abap_codepage=>convert_to( lv_full_source ).

    "-- Step 3: GZIP compress
    DATA lo_gzip TYPE REF TO cl_abap_gzip.
    CREATE OBJECT lo_gzip.
    lo_gzip->compress_binary(
      EXPORTING
        raw_in        = lv_raw
      IMPORTING
        gzip_out      = rv_compressed
    ).
  ENDMETHOD.

  METHOD decode_hex_to_text.
    "-- Guard: empty input
    IF iv_compressed IS INITIAL.
      RAISE EXCEPTION TYPE cx_parameter_invalid
        EXPORTING
          parameter = 'IV_COMPRESSED'.
    ENDIF.

    "-- Step 1: GZIP decompress → xstring
    DATA lo_gzip TYPE REF TO cl_abap_gzip.
    DATA lv_raw  TYPE xstring.
    CREATE OBJECT lo_gzip.
    lo_gzip->decompress_binary(
      EXPORTING
        gzip_in   = iv_compressed
      IMPORTING
        raw_out   = lv_raw
    ).

    "-- Step 2: xstring → string (UTF-8)
    DATA(lv_full_source) = cl_abap_codepage=>convert_from( lv_raw ).

    "-- Step 3: Split by newline → string_table
    DATA(lv_newline) = cl_abap_char_utilities=>newline.
    SPLIT lv_full_source AT lv_newline INTO TABLE rt_source_lines.
  ENDMETHOD.

ENDCLASS.
