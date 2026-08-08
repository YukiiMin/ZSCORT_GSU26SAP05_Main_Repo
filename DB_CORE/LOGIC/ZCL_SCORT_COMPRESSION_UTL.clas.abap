*"*---------------------------------------------------------------------*
*"* Class: ZCL_SCORT_COMPRESSION_UTL
*"* GZIP encode/decode for ZA05_SCORT_T_SRC-SOURCE_HEX
*"* REQ2: encode when Apply | REQ3: decode when Detail
*"*---------------------------------------------------------------------*
CLASS zcl_scort_compression_utl DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_string_tab TYPE STANDARD TABLE OF string WITH DEFAULT KEY.

    CLASS-METHODS encode_text_to_hex
      IMPORTING
        iv_text        TYPE string
      RETURNING
        VALUE(rv_hex)  TYPE xstring.

    CLASS-METHODS encode_lines_to_hex
      IMPORTING
        it_lines       TYPE ty_string_tab
      RETURNING
        VALUE(rv_hex)  TYPE xstring.

    CLASS-METHODS decode_hex_to_text
      IMPORTING
        iv_hex         TYPE xstring
      RETURNING
        VALUE(rv_text) TYPE string.

    CLASS-METHODS decode_hex_to_lines
      IMPORTING
        iv_hex          TYPE xstring
      RETURNING
        VALUE(rt_lines) TYPE ty_string_tab.

ENDCLASS.


CLASS zcl_scort_compression_utl IMPLEMENTATION.

  METHOD encode_text_to_hex.
    DATA lv_raw TYPE xstring.
    CLEAR rv_hex.
    IF iv_text IS INITIAL.
      RETURN.
    ENDIF.
    TRY.
        lv_raw = cl_abap_conv_codepage=>create_out( codepage = `UTF-8` )->convert( iv_text ).
        cl_abap_gzip=>compress_binary(
          EXPORTING raw_in   = lv_raw
          IMPORTING gzip_out = rv_hex ).
      CATCH cx_root.
        CLEAR rv_hex.
    ENDTRY.
  ENDMETHOD.

  METHOD encode_lines_to_hex.
    DATA lv_text TYPE string.
    lv_text = zcl_scort_hash_utl=>lines_to_text( it_lines ).
    rv_hex  = encode_text_to_hex( lv_text ).
  ENDMETHOD.

  METHOD decode_hex_to_text.
    DATA lv_raw TYPE xstring.
    CLEAR rv_text.
    IF iv_hex IS INITIAL.
      RETURN.
    ENDIF.
    TRY.
        cl_abap_gzip=>decompress_binary(
          EXPORTING gzip_in = iv_hex
          IMPORTING raw_out = lv_raw ).
        rv_text = cl_abap_conv_codepage=>create_in( codepage = `UTF-8` )->convert( lv_raw ).
      CATCH cx_root.
        CLEAR rv_text.
    ENDTRY.
  ENDMETHOD.

  METHOD decode_hex_to_lines.
    DATA lv_text TYPE string.
    lv_text  = decode_hex_to_text( iv_hex ).
    rt_lines = zcl_scort_hash_utl=>text_to_lines( lv_text ).
  ENDMETHOD.

ENDCLASS.
