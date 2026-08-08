CLASS zcl_scort_l_reader DEFINITION
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

    "! Read source code and metadata for a Local SAP object.
    "! Routes reading by ObjectType:
    "!   PROG / REPS: READ REPORT
    "!   FUGR / FUNC: FUNCTION_INCLUDE_INFO + READ REPORT
    "!   CLAS / INTF: CL_OO_FACTORY / CL_BLUE_SOURCE_UTILITIES
    "!   BDEF / DDLS: CL_BLUE_SOURCE_UTILITIES (text-based new-gen objects)
    "! @parameter iv_object_type | TADIR object type (PROG, CLAS, FUNC, ...)
    "! @parameter iv_object_name | TADIR object name
    "! @parameter rs_result      | Source code text + metadata JSON
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
    CLASS-METHODS read_program_source
      IMPORTING
        iv_object_name   TYPE tadir-obj_name
      RETURNING
        VALUE(rt_lines)  TYPE string_table.

    CLASS-METHODS read_fugr_source
      IMPORTING
        iv_object_name   TYPE tadir-obj_name
      RETURNING
        VALUE(rt_lines)  TYPE string_table.

    CLASS-METHODS read_class_source
      IMPORTING
        iv_object_name   TYPE tadir-obj_name
      RETURNING
        VALUE(rt_lines)  TYPE string_table.

    CLASS-METHODS read_textbased_source
      IMPORTING
        iv_object_type   TYPE tadir-object
        iv_object_name   TYPE tadir-obj_name
      RETURNING
        VALUE(rt_lines)  TYPE string_table.

    CLASS-METHODS build_metadata_json
      IMPORTING
        iv_object_type   TYPE tadir-object
        iv_object_name   TYPE tadir-obj_name
      RETURNING
        VALUE(rv_json)   TYPE string.

    CLASS-METHODS lines_to_string
      IMPORTING
        it_lines         TYPE string_table
      RETURNING
        VALUE(rv_result) TYPE string.
ENDCLASS.

CLASS zcl_scort_l_reader IMPLEMENTATION.

  METHOD read_object.
    DATA lt_source_lines TYPE string_table.

    "-- Route by object type
    CASE iv_object_type.
      WHEN 'PROG' OR 'REPS'.
        lt_source_lines = read_program_source( iv_object_name ).
      WHEN 'FUGR' OR 'FUNC'.
        lt_source_lines = read_fugr_source( iv_object_name ).
      WHEN 'CLAS' OR 'INTF'.
        lt_source_lines = read_class_source( iv_object_name ).
      WHEN 'BDEF' OR 'DDLS' OR 'DDLX' OR 'SRVD' OR 'SRVB'.
        lt_source_lines = read_textbased_source(
          iv_object_type = iv_object_type
          iv_object_name = iv_object_name
        ).
      WHEN OTHERS.
        "-- Unknown type: return empty source, metadata only
    ENDCASE.

    "-- Assemble result
    rs_result-source_code_text = lines_to_string( lt_source_lines ).
    rs_result-metadata_text    = build_metadata_json(
      iv_object_type = iv_object_type
      iv_object_name = iv_object_name
    ).

    "-- Fill basic metadata from TADIR
    SELECT SINGLE devclass, author
      FROM tadir
      WHERE pgmid    = 'R3TR'
        AND object   = @iv_object_type
        AND obj_name = @iv_object_name
      INTO ( @rs_result-package_name, @rs_result-author ).
  ENDMETHOD.

  METHOD read_program_source.
    DATA lt_table TYPE TABLE OF string.
    READ REPORT iv_object_name INTO lt_table.
    rt_lines = lt_table.
  ENDMETHOD.

  METHOD read_fugr_source.
    "-- Get list of includes for the Function Group
    DATA: lt_includes TYPE TABLE OF trdir,
          lv_include  TYPE program.

    CALL FUNCTION 'FUNCTION_INCLUDE_INFO'
      EXPORTING
        funcname        = iv_object_name
      TABLES
        incl_tab        = lt_includes
      EXCEPTIONS
        OTHERS          = 1.

    IF lt_includes IS INITIAL.
      "-- Fallback: try reading as program directly
      READ REPORT iv_object_name INTO rt_lines.
      RETURN.
    ENDIF.

    LOOP AT lt_includes ASSIGNING FIELD-SYMBOL(<inc>).
      lv_include = <inc>-name.
      DATA lt_include_lines TYPE TABLE OF string.
      READ REPORT lv_include INTO lt_include_lines.
      APPEND LINES OF lt_include_lines TO rt_lines.
      APPEND |"---- Include: { lv_include } ----|  TO rt_lines.
    ENDLOOP.
  ENDMETHOD.

  METHOD read_class_source.
    "-- Use CL_OO_FACTORY to get class descriptor, then read via CL_BLUE_SOURCE_UTILITIES
    DATA lo_factory   TYPE REF TO cl_oo_factory.
    DATA lo_class_des TYPE REF TO cl_oo_class_incl_src.

    TRY.
        cl_blue_source_utilities=>get_source(
          EXPORTING
            p_object_type = 'CLAS'
            p_object_name = iv_object_name
          IMPORTING
            p_source      = rt_lines
        ).
      CATCH cx_root.
        "-- Fallback: read main include
        DATA lv_main_incl TYPE progname.
        CONCATENATE iv_object_name '====CP' INTO lv_main_incl.
        READ REPORT lv_main_incl INTO rt_lines.
    ENDTRY.
  ENDMETHOD.

  METHOD read_textbased_source.
    "-- Text-based new-generation objects (CDS, BDEF, etc.)
    TRY.
        cl_blue_source_utilities=>get_source(
          EXPORTING
            p_object_type = iv_object_type
            p_object_name = iv_object_name
          IMPORTING
            p_source      = rt_lines
        ).
      CATCH cx_root.
        "-- Cannot read: return empty
    ENDTRY.
  ENDMETHOD.

  METHOD build_metadata_json.
    "-- Collect metadata from TADIR + TRDIR/SEOCLASS and serialize to JSON
    DATA ls_tadir TYPE tadir.
    SELECT SINGLE *
      FROM tadir
      WHERE pgmid    = 'R3TR'
        AND object   = @iv_object_type
        AND obj_name = @iv_object_name
      INTO @ls_tadir.

    DATA ls_meta TYPE REF TO data.
    DATA(lo_json) = NEW /ui2/cl_json( ).

    "-- Simple JSON structure
    rv_json = /ui2/cl_json=>serialize(
      data         = VALUE t_metadata(
        object_type = ls_tadir-object
        object_name = ls_tadir-obj_name
        devclass    = ls_tadir-devclass
        author      = ls_tadir-author
        as4date     = ls_tadir-as4date
        as4time     = ls_tadir-as4time
        genflag     = ls_tadir-genflag
      )
    ).
  ENDMETHOD.

  METHOD lines_to_string.
    DATA(lv_newline) = cl_abap_char_utilities=>newline.
    rv_result = REDUCE string(
      INIT acc  = ``
      FOR  line IN it_lines
      NEXT acc  = COND #(
        WHEN acc IS INITIAL
          THEN line
          ELSE |{ acc }{ lv_newline }{ line }|
      )
    ).
  ENDMETHOD.

ENDCLASS.
