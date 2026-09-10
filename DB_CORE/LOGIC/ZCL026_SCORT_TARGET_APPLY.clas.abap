CLASS zcl026_scort_target_apply DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_selected_obj,
             object   TYPE e071-object,
             obj_name TYPE e071-obj_name,
           END OF ty_selected_obj,
           tt_selected_objs TYPE STANDARD TABLE OF ty_selected_obj WITH DEFAULT KEY.

    CLASS-METHODS apply_to_target
      IMPORTING
        iv_parent_trkorr    TYPE trkorr
        it_selected_objects TYPE tt_selected_objs OPTIONAL
      EXPORTING
        ev_success          TYPE abap_bool
        ev_message          TYPE string .

  PRIVATE SECTION.
    CLASS-METHODS normalize_object
      IMPORTING
        iv_pgmid    TYPE e071-pgmid
        iv_object   TYPE e071-object
      EXPORTING
        ev_pgmid    TYPE e071-pgmid
        ev_object   TYPE e071-object
      CHANGING
        cv_obj_name TYPE e071-obj_name OPTIONAL.

    CLASS-METHODS calculate_checksum
      IMPORTING
        iv_source          TYPE string
      RETURNING
        VALUE(rv_checksum) TYPE char40 .

    CLASS-METHODS compress_source
      IMPORTING
        iv_source            TYPE string
      RETURNING
        VALUE(rv_source_hex) TYPE xstring .
ENDCLASS.


CLASS zcl026_scort_target_apply IMPLEMENTATION.

  METHOD apply_to_target.
    DATA: lt_catalog_modify  TYPE TABLE OF za05_scort_t,
          lt_src_insert      TYPE TABLE OF za05_scort_t_src,
          lv_changed_count   TYPE i VALUE 0,
          lv_unchanged_count TYPE i VALUE 0.

    ev_success = abap_false.

    SELECT SINGLE trkorr, trfunction, trstatus, as4user, as4date, as4time, strkorr
      FROM e070
      WHERE trkorr = @iv_parent_trkorr
      INTO @DATA(ls_e070).

    IF sy-subrc <> 0.
      ev_message = zcm_scort=>get_text_by_key( is_t100_key = zcm_scort=>tr_not_found iv_attr1 = CONV #( iv_parent_trkorr ) ).
      RETURN.
    ENDIF.

    IF ls_e070-strkorr IS NOT INITIAL OR ls_e070-trfunction = 'S' OR ls_e070-trfunction = 'Q'.
      ev_message = zcm_scort=>get_text_by_key(
                     is_t100_key = zcm_scort=>tr_is_subtask
                     iv_attr1    = CONV #( iv_parent_trkorr )
                     iv_attr2    = CONV #( ls_e070-strkorr ) ).
      RETURN.
    ENDIF.

    IF ls_e070-trfunction <> 'K'.
      ev_message = zcm_scort=>get_text_by_key(
                     is_t100_key = zcm_scort=>tr_not_workbench
                     iv_attr1    = CONV #( iv_parent_trkorr )
                     iv_attr2    = CONV #( ls_e070-trfunction ) ).
      RETURN.
    ENDIF.

    IF ls_e070-trstatus <> 'R' AND ls_e070-trstatus <> 'N'.
      ev_message = zcm_scort=>get_text_by_key(
                     is_t100_key = zcm_scort=>tr_not_released
                     iv_attr1    = CONV #( iv_parent_trkorr )
                     iv_attr2    = CONV #( ls_e070-trstatus ) ).
      RETURN.
    ENDIF.

    SELECT SINGLE as4text
      FROM e07t
      WHERE trkorr = @iv_parent_trkorr
        AND langu  = @sy-langu
      INTO @DATA(lv_descript).

    SELECT pgmid, object, obj_name, objfunc, activity
      FROM e071
      WHERE ( trkorr = @iv_parent_trkorr OR trkorr IN ( SELECT trkorr FROM e070 WHERE strkorr = @iv_parent_trkorr ) )
        AND pgmid IN ('R3TR', 'LIMU')
      INTO TABLE @DATA(lt_raw_objects).

    IF lt_raw_objects IS INITIAL.
      ev_message = zcm_scort=>get_text_by_key(
                     is_t100_key = zcm_scort=>tr_no_comparable_objs
                     iv_attr1    = CONV #( iv_parent_trkorr ) ).
      RETURN.
    ENDIF.

    TYPES: BEGIN OF ty_object,
             pgmid    TYPE e071-pgmid,
             object   TYPE e071-object,
             obj_name TYPE e071-obj_name,
             objfunc  TYPE e071-objfunc,
             activity TYPE e071-activity,
           END OF ty_object.

    DATA: lt_objects TYPE TABLE OF ty_object,
          ls_norm    TYPE ty_object.

    LOOP AT lt_raw_objects INTO DATA(ls_raw).
      ls_norm-obj_name = ls_raw-obj_name.
      ls_norm-objfunc  = ls_raw-objfunc.
      ls_norm-activity = ls_raw-activity.

      normalize_object(
        EXPORTING
          iv_pgmid    = ls_raw-pgmid
          iv_object   = ls_raw-object
        IMPORTING
          ev_pgmid    = ls_norm-pgmid
          ev_object   = ls_norm-object
        CHANGING
          cv_obj_name = ls_norm-obj_name
      ).

      APPEND ls_norm TO lt_objects.
    ENDLOOP.

    SORT lt_objects BY pgmid object obj_name.
    DELETE ADJACENT DUPLICATES FROM lt_objects COMPARING pgmid object obj_name.

    IF it_selected_objects IS NOT INITIAL.
      DATA lt_filtered_objects LIKE lt_objects.
      LOOP AT lt_objects INTO DATA(ls_filter_obj).
        IF line_exists( it_selected_objects[ object = ls_filter_obj-object obj_name = ls_filter_obj-obj_name ] ).
          APPEND ls_filter_obj TO lt_filtered_objects.
        ENDIF.
      ENDLOOP.
      lt_objects = lt_filtered_objects.
    ENDIF.

    GET TIME STAMP FIELD DATA(lv_timestamp).

    LOOP AT lt_objects INTO DATA(ls_obj).

      IF zcl_scort_l_reader=>is_supported( ls_obj-object ) = abap_false.
        CONTINUE.
      ENDIF.

      DATA(lv_is_deleted) = abap_false.
      IF ls_obj-objfunc = 'D' OR ls_obj-activity = 'D'.
        lv_is_deleted = abap_true.
      ENDIF.

      DATA(ls_src) = zcl_scort_l_reader=>read_active(
        iv_object_type = ls_obj-object
        iv_object_name = CONV sobj_name( ls_obj-obj_name ) ).

      IF ls_src-found = abap_false.
        lv_is_deleted = abap_true.
      ENDIF.

      IF lv_is_deleted = abap_true.
        SELECT SINGLE *
          FROM za05_scort_t
          WHERE pgmid    = @ls_obj-pgmid
            AND object   = @ls_obj-object
            AND obj_name = @ls_obj-obj_name
          INTO @DATA(ls_del_cat).
        IF sy-subrc = 0.
          DELETE FROM za05_scort_t
            WHERE pgmid    = @ls_obj-pgmid
              AND object   = @ls_obj-object
              AND obj_name = @ls_obj-obj_name.

          DATA(lv_del_ver) = ls_del_cat-current_version + 1.
          APPEND VALUE za05_scort_t_src(
            client      = sy-mandt
            pgmid       = ls_obj-pgmid
            object      = ls_obj-object
            obj_name    = ls_obj-obj_name
            version_no  = lv_del_ver
            src_trkorr  = iv_parent_trkorr
            src_hash    = 'DELETED'
            src_preview = 'DELETED'
            created_by  = sy-uname
            created_at  = sy-datum
            created_tm  = sy-uzeit
            released_by = sy-uname
            released_at = lv_timestamp
          ) TO lt_src_insert.
          lv_changed_count = lv_changed_count + 1.
        ENDIF.
        CONTINUE.
      ENDIF.

      SELECT SINGLE devclass
        FROM tadir
        WHERE pgmid    = @ls_obj-pgmid
          AND object   = @ls_obj-object
          AND obj_name = @ls_obj-obj_name
        INTO @DATA(lv_devclass).

      DATA(lv_source)   = ls_src-text.
      DATA(lv_checksum) = ls_src-hash.
      IF lv_checksum IS INITIAL.
        lv_checksum = calculate_checksum( lv_source ).
      ENDIF.
      DATA(lv_source_hex) = compress_source( lv_source ).
      DATA(lv_preview)    = COND char255( WHEN strlen( lv_source ) > 255 THEN lv_source(255) ELSE lv_source ).

      SELECT SINGLE *
        FROM za05_scort_t
        WHERE pgmid    = @ls_obj-pgmid
          AND object   = @ls_obj-object
          AND obj_name = @ls_obj-obj_name
        INTO @DATA(ls_catalog).

      DATA: ls_new_catalog TYPE za05_scort_t,
            ls_src_detail  TYPE za05_scort_t_src.

      IF sy-subrc <> 0.
        ls_new_catalog-client          = sy-mandt.
        ls_new_catalog-pgmid           = ls_obj-pgmid.
        ls_new_catalog-object          = ls_obj-object.
        ls_new_catalog-obj_name        = ls_obj-obj_name.
        ls_new_catalog-devclass        = lv_devclass.
        ls_new_catalog-author          = ls_e070-as4user.
        ls_new_catalog-descript        = lv_descript.
        ls_new_catalog-current_version = 1.
        ls_new_catalog-changed_by      = sy-uname.
        ls_new_catalog-changed_at      = sy-datum.
        ls_new_catalog-changed_tm      = sy-uzeit.
        ls_new_catalog-last_changed_at = lv_timestamp.
        APPEND ls_new_catalog TO lt_catalog_modify.

        ls_src_detail-client      = sy-mandt.
        ls_src_detail-pgmid       = ls_obj-pgmid.
        ls_src_detail-object      = ls_obj-object.
        ls_src_detail-obj_name    = ls_obj-obj_name.
        ls_src_detail-version_no  = 1.
        ls_src_detail-src_trkorr  = iv_parent_trkorr.
        ls_src_detail-source_hex  = lv_source_hex.
        ls_src_detail-src_hash    = lv_checksum.
        ls_src_detail-src_preview = lv_preview.
        ls_src_detail-created_by  = sy-uname.
        ls_src_detail-created_at  = sy-datum.
        ls_src_detail-created_tm  = sy-uzeit.
        ls_src_detail-released_by = sy-uname.
        ls_src_detail-released_at = lv_timestamp.
        APPEND ls_src_detail TO lt_src_insert.

        lv_changed_count = lv_changed_count + 1.

      ELSE.
        SELECT SINGLE src_hash
          FROM za05_scort_t_src
          WHERE pgmid      = @ls_catalog-pgmid
            AND object     = @ls_catalog-object
            AND obj_name   = @ls_catalog-obj_name
            AND version_no = @ls_catalog-current_version
          INTO @DATA(lv_current_hash).

        IF lv_checksum = lv_current_hash.
          lv_unchanged_count = lv_unchanged_count + 1.

        ELSE.
          DATA(lv_next_ver) = ls_catalog-current_version + 1.

          ls_new_catalog                 = ls_catalog.
          ls_new_catalog-devclass        = lv_devclass.
          ls_new_catalog-current_version = lv_next_ver.
          ls_new_catalog-changed_by      = sy-uname.
          ls_new_catalog-changed_at      = sy-datum.
          ls_new_catalog-changed_tm      = sy-uzeit.
          ls_new_catalog-last_changed_at = lv_timestamp.
          APPEND ls_new_catalog TO lt_catalog_modify.

          ls_src_detail-client      = sy-mandt.
          ls_src_detail-pgmid       = ls_obj-pgmid.
          ls_src_detail-object      = ls_obj-object.
          ls_src_detail-obj_name    = ls_obj-obj_name.
          ls_src_detail-version_no  = lv_next_ver.
          ls_src_detail-src_trkorr  = iv_parent_trkorr.
          ls_src_detail-source_hex  = lv_source_hex.
          ls_src_detail-src_hash    = lv_checksum.
          ls_src_detail-src_preview = lv_preview.
          ls_src_detail-created_by  = sy-uname.
          ls_src_detail-created_at  = sy-datum.
          ls_src_detail-created_tm  = sy-uzeit.
          ls_src_detail-released_by = sy-uname.
          ls_src_detail-released_at = lv_timestamp.
          APPEND ls_src_detail TO lt_src_insert.

          lv_changed_count = lv_changed_count + 1.

        ENDIF.

      ENDIF.

    ENDLOOP.

    IF lt_catalog_modify IS NOT INITIAL OR lt_src_insert IS NOT INITIAL OR lv_changed_count > 0.

      TRY.
          IF lt_catalog_modify IS NOT INITIAL.
            MODIFY za05_scort_t FROM TABLE @lt_catalog_modify.
          ENDIF.
          IF lt_src_insert IS NOT INITIAL.
            SORT lt_src_insert BY pgmid object obj_name version_no.
            DELETE ADJACENT DUPLICATES FROM lt_src_insert
              COMPARING pgmid object obj_name version_no.
            MODIFY za05_scort_t_src FROM TABLE @lt_src_insert.
          ENDIF.
          COMMIT WORK AND WAIT.
          ev_success = abap_true.
          ev_message = zcm_scort=>get_text_by_key( is_t100_key = zcm_scort=>target_apply_success iv_attr1 = CONV #( lv_changed_count ) iv_attr2 = CONV #( lv_unchanged_count ) ).
        CATCH cx_root INTO DATA(lx_db).
          ROLLBACK WORK.
          ev_success = abap_false.
          ev_message = zcm_scort=>get_text_by_key( is_t100_key = zcm_scort=>internal_error iv_attr1 = lx_db->get_text( ) ).
      ENDTRY.

    ELSE.
      ev_success = abap_true.
      ev_message = zcm_scort=>get_text_by_key( is_t100_key = zcm_scort=>target_apply_success iv_attr1 = '0' iv_attr2 = CONV #( lv_unchanged_count ) ).
    ENDIF.

  ENDMETHOD.


  METHOD normalize_object.
    ev_pgmid  = iv_pgmid.
    ev_object = iv_object.

    IF iv_pgmid = 'LIMU'.
      CASE iv_object.
        WHEN 'FUNC'.
          ev_pgmid  = 'LIMU'.
          ev_object = 'FUNC'.
        WHEN 'REPS' OR 'REPT'.
          ev_pgmid  = 'R3TR'.
          ev_object = 'PROG'.
        WHEN 'CPUB' OR 'CPRI' OR 'CPRO' OR 'CLSD'.
          ev_pgmid  = 'R3TR'.
          ev_object = 'CLAS'.
        WHEN 'METH'.
          ev_pgmid  = 'R3TR'.
          ev_object = 'CLAS'.
          IF cv_obj_name IS SUPPLIED AND strlen( cv_obj_name ) > 30.
            cv_obj_name = cv_obj_name(30).
            CONDENSE cv_obj_name.
          ENDIF.
      ENDCASE.
    ENDIF.
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
            ef_hashstring = DATA(lv_hash)
        ).
        rv_checksum = lv_hash.
      CATCH cx_root.
        rv_checksum = 'ERROR'.
    ENDTRY.
  ENDMETHOD.


  METHOD compress_source.
    CLEAR rv_source_hex.
    IF iv_source IS INITIAL.
      RETURN.
    ENDIF.

    rv_source_hex = zcl_scort_compression_utl=>encode_text_to_hex( iv_source ).
    IF rv_source_hex IS INITIAL.
      TRY.
          cl_abap_gzip=>compress_text(
            EXPORTING
              text_in  = iv_source
            IMPORTING
              gzip_out = rv_source_hex
          ).
        CATCH cx_root.
          CLEAR rv_source_hex.
      ENDTRY.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
