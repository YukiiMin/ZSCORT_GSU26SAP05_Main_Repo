*"*---------------------------------------------------------------------*
*"* Class: ZCL_SCORT_QUERY_UTL
*"* Helper dùng chung cho các RAP Query Provider của REQ3.
*"* Bóc giá trị filter từ IF_RAP_QUERY_REQUEST (OData V4 $filter).
*"* Activate class này TRƯỚC mọi ZCL_SCORT_*_QUERY.
*"*---------------------------------------------------------------------*
CLASS zcl_scort_query_utl DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CLASS-METHODS get_filter_sql
      IMPORTING
        io_request    TYPE REF TO if_rap_query_request
      RETURNING
        VALUE(rv_sql) TYPE string.

    CLASS-METHODS value_of
      IMPORTING
        iv_sql          TYPE string
        iv_field        TYPE string
      RETURNING
        VALUE(rv_value) TYPE string.

    "! Ưu tiên get_as_ranges; fallback SQL (= / EQ / LIKE).
    CLASS-METHODS filter_low
      IMPORTING
        io_request      TYPE REF TO if_rap_query_request
        iv_field        TYPE string
      RETURNING
        VALUE(rv_value) TYPE string.

    "! Cover đầy đủ RAP: sort + paging + set_data/count (đúng flag).
    CLASS-METHODS respond
      IMPORTING
        io_request  TYPE REF TO if_rap_query_request
        io_response TYPE REF TO if_rap_query_response
      CHANGING
        ct_data     TYPE STANDARD TABLE.

    "! Ghi response rỗng (không truyền table generic — tránh lỗi activate).
    CLASS-METHODS respond_empty
      IMPORTING
        io_request  TYPE REF TO if_rap_query_request
        io_response TYPE REF TO if_rap_query_response.

  PRIVATE SECTION.
    CLASS-METHODS clean_token
      IMPORTING
        iv_raw          TYPE clike
      RETURNING
        VALUE(rv_clean) TYPE string.

    CLASS-METHODS strip_wildcards
      IMPORTING
        iv_raw          TYPE clike
      RETURNING
        VALUE(rv_clean) TYPE string.

ENDCLASS.


CLASS zcl_scort_query_utl IMPLEMENTATION.

  METHOD get_filter_sql.
    CLEAR rv_sql.
    TRY.
        rv_sql = io_request->get_filter( )->get_as_sql_string( ).
      CATCH cx_root.
        CLEAR rv_sql.
    ENDTRY.
  ENDMETHOD.

  METHOD value_of.
    DATA lv_upper   TYPE string.
    DATA lv_field   TYPE string.
    DATA lv_pos     TYPE i.
    DATA lv_off     TYPE i.
    DATA lv_len     TYPE i.
    DATA lv_chunk   TYPE string.
    DATA lv_char    TYPE c LENGTH 1.
    DATA lv_in_q    TYPE abap_bool.
    DATA lv_started TYPE abap_bool.
    DATA lv_op_len  TYPE i.

    CLEAR rv_value.
    IF iv_sql IS INITIAL OR iv_field IS INITIAL.
      RETURN.
    ENDIF.

    lv_upper = to_upper( iv_sql ).
    lv_field = to_upper( iv_field ).

    " = / EQ / LIKE (FE typeahead hay dùng LIKE)
    FIND |{ lv_field } =| IN lv_upper MATCH OFFSET lv_pos.
    IF sy-subrc = 0.
      lv_op_len = 1.
    ELSE.
      FIND |{ lv_field } EQ| IN lv_upper MATCH OFFSET lv_pos.
      IF sy-subrc = 0.
        lv_op_len = 2.
      ELSE.
        FIND |{ lv_field } LIKE| IN lv_upper MATCH OFFSET lv_pos.
        IF sy-subrc <> 0.
          RETURN.
        ENDIF.
        lv_op_len = 4.
      ENDIF.
    ENDIF.
    lv_off = lv_pos + strlen( lv_field ) + 1 + lv_op_len.

    lv_len = strlen( iv_sql ).
    WHILE lv_off < lv_len.
      lv_char = iv_sql+lv_off(1).
      IF lv_started = abap_false.
        IF lv_char = ` ` OR lv_char = cl_abap_char_utilities=>horizontal_tab.
          lv_off = lv_off + 1.
          CONTINUE.
        ENDIF.
        lv_started = abap_true.
        IF lv_char = `'`.
          lv_in_q = abap_true.
          lv_off = lv_off + 1.
          CONTINUE.
        ENDIF.
      ENDIF.
      IF lv_in_q = abap_true.
        IF lv_char = `'`.
          EXIT.
        ENDIF.
        lv_chunk = lv_chunk && lv_char.
      ELSE.
        IF lv_char = ` ` OR lv_char = `)`.
          EXIT.
        ENDIF.
        lv_chunk = lv_chunk && lv_char.
      ENDIF.
      lv_off = lv_off + 1.
    ENDWHILE.

    rv_value = strip_wildcards( clean_token( lv_chunk ) ).
  ENDMETHOD.

  METHOD filter_low.
    DATA lt_ranges TYPE if_rap_query_filter=>tt_name_range_pairs.
    DATA lv_field  TYPE string.
    DATA lv_name   TYPE string.

    CLEAR rv_value.
    lv_field = to_upper( CONDENSE( iv_field ) ).
    IF lv_field IS INITIAL.
      RETURN.
    ENDIF.

    TRY.
        lt_ranges = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_root.
        CLEAR lt_ranges.
    ENDTRY.

    LOOP AT lt_ranges INTO DATA(ls_pair).
      lv_name = to_upper( CONDENSE( CONV string( ls_pair-name ) ) ).
      CHECK lv_name = lv_field.
      READ TABLE ls_pair-range INTO DATA(ls_r) INDEX 1.
      IF sy-subrc = 0 AND ls_r-low IS NOT INITIAL.
        rv_value = strip_wildcards( clean_token( ls_r-low ) ).
        RETURN.
      ENDIF.
    ENDLOOP.

    rv_value = value_of( iv_sql = get_filter_sql( io_request ) iv_field = lv_field ).
  ENDMETHOD.

  METHOD clean_token.
    rv_clean = CONDENSE( iv_raw ).
    REPLACE ALL OCCURRENCES OF `'` IN rv_clean WITH ``.
    REPLACE ALL OCCURRENCES OF `"` IN rv_clean WITH ``.
    rv_clean = to_upper( CONDENSE( rv_clean ) ).
  ENDMETHOD.

  METHOD strip_wildcards.
    rv_clean = CONDENSE( iv_raw ).
    REPLACE ALL OCCURRENCES OF `%` IN rv_clean WITH ``.
    REPLACE ALL OCCURRENCES OF `*` IN rv_clean WITH ``.
    rv_clean = CONDENSE( rv_clean ).
  ENDMETHOD.

  METHOD respond.
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

    " Chỉ gọi set_* khi FE xin — gọi thừa → "feature is not implemented"
    IF lv_data_req = abap_true.
      TRY.
          io_response->set_data( <lt_page> ).
        CATCH cx_root.
      ENDTRY.
    ENDIF.
    IF lv_count_req = abap_true.
      TRY.
          io_response->set_total_number_of_records( CONV int8( lines( <lt_all> ) ) ).
        CATCH cx_root.
      ENDTRY.
    ENDIF.

    IF lv_data_req = abap_false AND lv_count_req = abap_false.
      TRY.
          io_response->set_data( <lt_page> ).
        CATCH cx_root.
      ENDTRY.
      TRY.
          io_response->set_total_number_of_records( CONV int8( lines( <lt_all> ) ) ).
        CATCH cx_root.
      ENDTRY.
    ENDIF.
  ENDMETHOD.

  METHOD respond_empty.
    TRY.
        IF io_request->is_total_numb_of_rec_requested( ).
          io_response->set_total_number_of_records( 0 ).
        ENDIF.
      CATCH cx_root.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
