CLASS zcl_scort_t_reader DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_src_result,
        source_code_text TYPE string,
        metadata_text    TYPE string,
        package_name     TYPE devclass,
        author           TYPE as4user,
        description      TYPE c LENGTH 80,
      END OF ty_src_result.

    "! Read source code and metadata for a Target (simulated) object.
    "! Reads compressed SOURCE_HEX from ZA_SCORT_T_SRC at CURRENT_VERSION.
    "! Decompresses via ZCL_SCORT_COMPRESSION_UTL=>decode_hex_to_text.
    "! Metadata from ZA_SCORT_T.
    "! @parameter iv_object_type | Object type
    "! @parameter iv_object_name | Object name
    "! @parameter rs_result      | Decompressed source text + metadata JSON
    CLASS-METHODS read_object
      IMPORTING
        iv_object_type  TYPE tadir-object
        iv_object_name  TYPE tadir-obj_name
      RETURNING
        VALUE(rs_result) TYPE ty_src_result
      RAISING
        cx_parameter_invalid.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_scort_t_reader IMPLEMENTATION.

  METHOD read_object.
    "-- Step 1: Get current version and metadata from ZASCORT_T
    DATA ls_meta TYPE zascort_t.
    SELECT SINGLE *
      FROM zascort_t
      WHERE server_id    = 'TARGET'
        AND object_type  = @iv_object_type
        AND object_name  = @iv_object_name
      INTO @ls_meta.

    IF sy-subrc <> 0.
      "-- Object does not exist in Target — return empty
      RETURN.
    ENDIF.

    rs_result-package_name = ls_meta-devclass.
    rs_result-author       = ls_meta-author.

    "-- Step 2: Read compressed source for current version
    DATA lv_source_hex TYPE xstring.
    SELECT SINGLE source_hex
      FROM zascort_t_src
      WHERE server_id    = 'TARGET'
        AND object_type  = @iv_object_type
        AND object_name  = @iv_object_name
        AND version_no   = @ls_meta-current_version
      INTO @lv_source_hex.

    IF sy-subrc <> 0 OR lv_source_hex IS INITIAL.
      "-- Source not available for this version
      rs_result-source_code_text = `[Source not available for current version]`.
      RETURN.
    ENDIF.

    "-- Step 3: Decompress using utility class
    TRY.
        DATA lt_lines TYPE string_table.
        lt_lines = zcl_scort_compression_utl=>decode_hex_to_text( lv_source_hex ).

        "-- Join lines back to full source string
        DATA(lv_newline) = cl_abap_char_utilities=>newline.
        rs_result-source_code_text = REDUCE string(
          INIT acc  = ``
          FOR  line IN lt_lines
          NEXT acc  = COND #(
            WHEN acc IS INITIAL
              THEN line
              ELSE |{ acc }{ lv_newline }{ line }|
          )
        ).
      CATCH cx_parameter_invalid INTO DATA(lx_ex).
        rs_result-source_code_text = |[Decompression failed: { lx_ex->get_text( ) }]|.
        RETURN.
    ENDTRY.

    "-- Step 4: Build simple metadata JSON
    rs_result-metadata_text = /ui2/cl_json=>serialize(
      data = VALUE t_tgt_meta(
        server_id       = 'TARGET'
        object_type     = ls_meta-object_type
        object_name     = ls_meta-object_name
        devclass        = ls_meta-devclass
        author          = ls_meta-author
        current_version = ls_meta-current_version
        changed_at      = ls_meta-changed_at
        changed_by      = ls_meta-changed_by
      )
    ).
  ENDMETHOD.

ENDCLASS.
