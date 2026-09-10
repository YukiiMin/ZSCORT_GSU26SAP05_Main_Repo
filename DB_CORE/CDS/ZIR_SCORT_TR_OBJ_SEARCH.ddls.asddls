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
  as select from    e071  as Object
    inner join      e070  as Header       on Header.trkorr = Object.trkorr
    left outer join e070  as ParentHeader on ParentHeader.trkorr = Header.strkorr
    left outer join tadir as Tadir        on  Tadir.pgmid    = Object.pgmid
                                          and Tadir.object   = Object.object
                                          and Tadir.obj_name = Object.obj_name
{
  key Object.trkorr                                as Trkorr,
  key Object.pgmid                                 as Pgmid,
  key cast( case
              when Object.object = 'REPS' or Object.object = 'REPT'
                then 'PROG'
              when Object.object = 'TABD' or Object.object = 'TABT'
                then 'TABL'
              when Object.object = 'METH' or Object.object = 'CPUB' or Object.object = 'CPRI'
                or Object.object = 'CPRO' or Object.object = 'CLSD' or Object.object = 'CINC'
                then 'CLAS'
              else Object.object
            end as trobjtype )                     as ObjectType,
  key Object.obj_name                              as ObjectName,

      Header.strkorr                               as ParentTrkorr,
      Header.as4user                               as Owner,
      ParentHeader.as4user                         as ParentOwner,
      Header.as4date                               as CreatedOn,
      Header.trstatus                              as TrStatus,

      cast( case
              when Header.strkorr is not initial
                then Header.strkorr
              else Header.trkorr
            end as zde_scort_current_managing_tr ) as CurrentManagingTr,

      Object.activity                              as Activity,
      Tadir.devclass                               as PackageName,

      cast( case
              when Object.activity = 'D' or Tadir.delflag = 'X'
                then 'DELETED'
              when Tadir.obj_name is not null
                then 'ACTIVE'
              when Object.pgmid = 'LIMU' and Object.object = 'FUNC'
                then 'ACTIVE'
              else 'NOT_FOUND'
            end as abap.char(10) )                 as ObjectStatus
}
where
     Object.pgmid = 'R3TR'
  or Object.pgmid = 'LIMU'

union all

select from e071 as Object
  inner join enlfdir as Func
    on  Func.area   = Object.obj_name
    and Func.active = 'X'
  inner join e070 as Header
    on Header.trkorr = Object.trkorr
  left outer join e070 as ParentHeader
    on ParentHeader.trkorr = Header.strkorr
  left outer join tadir as Tadir
    on  Tadir.pgmid    = 'R3TR'
    and Tadir.object   = 'FUGR'
    and Tadir.obj_name = Object.obj_name
{
  key Object.trkorr                                as Trkorr,
  key cast( 'LIMU' as pgmid )                      as Pgmid,
  key cast( 'FUNC' as trobjtype )                  as ObjectType,
  key cast( Func.funcname as sobj_name )           as ObjectName,

      Header.strkorr                               as ParentTrkorr,
      Header.as4user                               as Owner,
      ParentHeader.as4user                         as ParentOwner,
      Header.as4date                               as CreatedOn,
      Header.trstatus                              as TrStatus,

      cast( case
              when Header.strkorr is not initial
                then Header.strkorr
              else Header.trkorr
            end as zde_scort_current_managing_tr ) as CurrentManagingTr,

      Object.activity                              as Activity,
      Tadir.devclass                               as PackageName,

      cast( 'ACTIVE' as abap.char(10) )            as ObjectStatus
}
where
      Object.pgmid  = 'R3TR'
  and Object.object = 'FUGR'
