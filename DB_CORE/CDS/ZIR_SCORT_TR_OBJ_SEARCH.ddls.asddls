@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'SCORT: Search Objects in TR Request/Task (Flat List)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #XL,
    dataClass: #MIXED
}

define root view entity ZIR_SCORT_TR_OBJ_SEARCH
  as select from e071 as Object
    inner join   e070 as Header on Header.trkorr = Object.trkorr
{
  key Object.trkorr                                as Trkorr,
  key Object.pgmid                                 as Pgmid,
  key Object.object                                as ObjectType,
  key Object.obj_name                              as ObjectName,

      Header.strkorr                               as ParentTrkorr,
      Header.as4user                               as Owner,
      Header.as4date                               as CreatedOn,
      Header.trstatus                              as TrStatus,

      cast( case
              when Header.strkorr is not initial
                then Header.strkorr
              else Header.trkorr
            end as zde_scort_current_managing_tr ) as CurrentManagingTr,

      Object.activity                              as Activity
}
where
     Object.pgmid = 'R3TR'
  or Object.pgmid = 'LIMU'
