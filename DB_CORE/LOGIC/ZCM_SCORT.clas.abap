CLASS zcm_scort DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_t100_message .
    INTERFACES if_t100_dyn_msg .
    INTERFACES if_abap_behv_message .

    CONSTANTS:
      gc_msgid TYPE symsgid VALUE 'ZCM_SCORT',

      BEGIN OF tr_not_found,
        msgid TYPE symsgid VALUE 'ZCM_SCORT',
        msgno TYPE symsgno VALUE '001',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF tr_not_found,

      BEGIN OF tr_already_released,
        msgid TYPE symsgid VALUE 'ZCM_SCORT',
        msgno TYPE symsgno VALUE '002',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF tr_already_released,

      BEGIN OF tr_released_success,
        msgid TYPE symsgid VALUE 'ZCM_SCORT',
        msgno TYPE symsgno VALUE '003',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF tr_released_success,

      BEGIN OF release_failed,
        msgid TYPE symsgid VALUE 'ZCM_SCORT',
        msgno TYPE symsgno VALUE '004',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE 'MV_ATTR2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF release_failed,

      BEGIN OF target_apply_started,
        msgid TYPE symsgid VALUE 'ZCM_SCORT',
        msgno TYPE symsgno VALUE '010',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF target_apply_started,

      BEGIN OF target_apply_success,
        msgid TYPE symsgid VALUE 'ZCM_SCORT',
        msgno TYPE symsgno VALUE '011',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE 'MV_ATTR2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF target_apply_success,

      BEGIN OF source_missing,
        msgid TYPE symsgid VALUE 'ZCM_SCORT',
        msgno TYPE symsgno VALUE '020',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE 'MV_ATTR2',
        attr3 TYPE scx_attrname VALUE 'MV_ATTR3',
        attr4 TYPE scx_attrname VALUE '',
      END OF source_missing,

      BEGIN OF ai_audit_completed,
        msgid TYPE symsgid VALUE 'ZCM_SCORT',
        msgno TYPE symsgno VALUE '030',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE 'MV_ATTR2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF ai_audit_completed,

      BEGIN OF ai_transport_evaluated,
        msgid TYPE symsgid VALUE 'ZCM_SCORT',
        msgno TYPE symsgno VALUE '031',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF ai_transport_evaluated,

      BEGIN OF ai_keys_exhausted,
        msgid TYPE symsgid VALUE 'ZCM_SCORT',
        msgno TYPE symsgno VALUE '032',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF ai_keys_exhausted,

      BEGIN OF ai_core_dest_unavailable,
        msgid TYPE symsgid VALUE 'ZCM_SCORT',
        msgno TYPE symsgno VALUE '033',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF ai_core_dest_unavailable,

      BEGIN OF ai_invalid_action,
        msgid TYPE symsgid VALUE 'ZCM_SCORT',
        msgno TYPE symsgno VALUE '034',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF ai_invalid_action,

      BEGIN OF http_method_not_allowed,
        msgid TYPE symsgid VALUE 'ZCM_SCORT',
        msgno TYPE symsgno VALUE '040',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF http_method_not_allowed,

      BEGIN OF request_body_empty,
        msgid TYPE symsgid VALUE 'ZCM_SCORT',
        msgno TYPE symsgno VALUE '041',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF request_body_empty,

      BEGIN OF internal_error,
        msgid TYPE symsgid VALUE 'ZCM_SCORT',
        msgno TYPE symsgno VALUE '050',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF internal_error,

      BEGIN OF obj_type_not_supported,
        msgid TYPE symsgid VALUE 'ZCM_SCORT',
        msgno TYPE symsgno VALUE '060',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF obj_type_not_supported,

      BEGIN OF source_not_found,
        msgid TYPE symsgid VALUE 'ZCM_SCORT',
        msgno TYPE symsgno VALUE '061',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE 'MV_ATTR2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF source_not_found,

      BEGIN OF target_initial_apply,
        msgid TYPE symsgid VALUE 'ZCM_SCORT',
        msgno TYPE symsgno VALUE '062',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE 'MV_ATTR2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF target_initial_apply,

      BEGIN OF target_bad_hex,
        msgid TYPE symsgid VALUE 'ZCM_SCORT',
        msgno TYPE symsgno VALUE '063',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE 'MV_ATTR2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF target_bad_hex,

      BEGIN OF hashes_identical,
        msgid TYPE symsgid VALUE 'ZCM_SCORT',
        msgno TYPE symsgno VALUE '064',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE 'MV_ATTR2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF hashes_identical,

      BEGIN OF hashes_different,
        msgid TYPE symsgid VALUE 'ZCM_SCORT',
        msgno TYPE symsgno VALUE '065',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE 'MV_ATTR2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF hashes_different,

      BEGIN OF tr_e070_not_found,
        msgid TYPE symsgid VALUE 'ZCM_SCORT',
        msgno TYPE symsgno VALUE '066',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF tr_e070_not_found,

      BEGIN OF tr_not_released,
        msgid TYPE symsgid VALUE 'ZCM_SCORT',
        msgno TYPE symsgno VALUE '067',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE 'MV_ATTR2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF tr_not_released,

      BEGIN OF tr_no_comparable_objs,
        msgid TYPE symsgid VALUE 'ZCM_SCORT',
        msgno TYPE symsgno VALUE '068',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF tr_no_comparable_objs,

      BEGIN OF missing_tr_param,
        msgid TYPE symsgid VALUE 'ZCM_SCORT',
        msgno TYPE symsgno VALUE '069',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF missing_tr_param,

      BEGIN OF task_released_success,
        msgid TYPE symsgid VALUE 'ZCM_SCORT',
        msgno TYPE symsgno VALUE '070',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE 'MV_ATTR2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF task_released_success,

      BEGIN OF tr_is_subtask,
        msgid TYPE symsgid VALUE 'ZCM_SCORT',
        msgno TYPE symsgno VALUE '071',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE 'MV_ATTR2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF tr_is_subtask,

      BEGIN OF tr_not_workbench,
        msgid TYPE symsgid VALUE 'ZCM_SCORT',
        msgno TYPE symsgno VALUE '072',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE 'MV_ATTR2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF tr_not_workbench,

      BEGIN OF release_incomplete,
        msgid TYPE symsgid VALUE 'ZCM_SCORT',
        msgno TYPE symsgno VALUE '073',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE 'MV_ATTR2',
        attr3 TYPE scx_attrname VALUE 'MV_ATTR3',
        attr4 TYPE scx_attrname VALUE '',
      END OF release_incomplete,

      BEGIN OF release_task_first,
        msgid TYPE symsgid VALUE 'ZCM_SCORT',
        msgno TYPE symsgno VALUE '074',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF release_task_first.

    DATA:
      mv_attr1 TYPE string,
      mv_attr2 TYPE string,
      mv_attr3 TYPE string,
      mv_attr4 TYPE string.

    METHODS constructor
      IMPORTING
        textid   LIKE if_t100_message=>t100key OPTIONAL
        previous LIKE previous OPTIONAL
        severity TYPE if_abap_behv_message=>t_severity DEFAULT if_abap_behv_message=>severity-error
        attr1    TYPE string OPTIONAL
        attr2    TYPE string OPTIONAL
        attr3    TYPE string OPTIONAL
        attr4    TYPE string OPTIONAL.

    CLASS-METHODS get_text_by_key
      IMPORTING
        is_t100_key   TYPE scx_t100key
        iv_attr1      TYPE string OPTIONAL
        iv_attr2      TYPE string OPTIONAL
        iv_attr3      TYPE string OPTIONAL
        iv_attr4      TYPE string OPTIONAL
      RETURNING
        VALUE(rv_msg) TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcm_scort IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    CALL METHOD super->constructor
      EXPORTING
        previous = previous.

    me->mv_attr1 = attr1.
    me->mv_attr2 = attr2.
    me->mv_attr3 = attr3.
    me->mv_attr4 = attr4.

    CLEAR me->textid.
    IF textid IS INITIAL.
      if_t100_message~t100key = if_t100_message=>default_textid.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.

    if_abap_behv_message~m_severity = severity.
  ENDMETHOD.


  METHOD get_text_by_key.
    DATA: lv_msg TYPE string.
    MESSAGE ID is_t100_key-msgid
            TYPE 'S'
            NUMBER is_t100_key-msgno
            WITH iv_attr1 iv_attr2 iv_attr3 iv_attr4
            INTO lv_msg.
    rv_msg = lv_msg.
  ENDMETHOD.

ENDCLASS.
