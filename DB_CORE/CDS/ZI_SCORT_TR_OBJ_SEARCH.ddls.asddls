@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'SCORT: Search Objects in TR Request/Task (Flat List)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #XL,
    dataClass: #MIXED
}
/*
  Flat list view — every row = 1 object assigned to a TR/Task.
  Key computed field CurrentManagingTr:
    IF Task belongs to a parent TR (strkorr IS NOT INITIAL)
      THEN CurrentManagingTr = Header.strkorr (the parent TR)
      ELSE CurrentManagingTr = Header.trkorr  (the TR itself, for standalone tasks)
  Data Sources: E071 (objects), E070 (TR header).
*/
define root view entity ZI_SCORT_TR_OBJ_SEARCH
  as select from e071 as Object
    inner join   e070 as Header
      on Header.trkorr = Object.trkorr
{
  key Object.trkorr                                               as Trkorr,
  key Object.pgmid                                               as Pgmid,
  key Object.object                                              as ObjectType,
  key Object.obj_name                                            as ObjectName,

      Header.strkorr                                             as ParentTrkorr,
      Header.as4user                                             as Owner,
      Header.as4date                                             as CreatedOn,
      Header.trstatus                                            as TrStatus,

      /* Computed: resolve which TR is actually managing this object */
      case
        when Header.strkorr <> ''
          then Header.strkorr
        else Header.trkorr
      end                                                        as CurrentManagingTr,

      Object.activity                                            as Activity
}
where Object.pgmid = 'R3TR'
