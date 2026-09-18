@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'SCORT: Search Objects in TR'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #XL,
    dataClass: #MIXED
}

define root view entity ZIR_SCORT_TR_OBJ_SEARCH
  as select from    e071                   as Object
    inner join      e070                   as Header       on Header.trkorr = Object.trkorr
    left outer join e070                   as ParentHeader on ParentHeader.trkorr = Header.strkorr
    left outer join tadir                  as TadirDirect  on  TadirDirect.pgmid    = 'R3TR'
                                                           and TadirDirect.object   = Object.object
                                                           and TadirDirect.obj_name = Object.obj_name
    left outer join tadir                  as TadirProg    on  TadirProg.pgmid    = 'R3TR'
                                                           and TadirProg.object   = 'PROG'
                                                           and TadirProg.obj_name = Object.obj_name
                                                           and (
                                                              Object.object       = 'REPS'
                                                              or Object.object    = 'REPT'
                                                            )
    left outer join tadir                  as TadirTabl    on  TadirTabl.pgmid    = 'R3TR'
                                                           and TadirTabl.object   = 'TABL'
                                                           and TadirTabl.obj_name = Object.obj_name
                                                           and (
                                                              Object.object       = 'TABD'
                                                              or Object.object    = 'TABT'
                                                            )
    left outer join tadir                  as TadirDoma    on  TadirDoma.pgmid    = 'R3TR'
                                                           and TadirDoma.object   = 'DOMA'
                                                           and TadirDoma.obj_name = Object.obj_name
                                                           and Object.object      = 'DOMD'
    left outer join tadir                  as TadirDtel    on  TadirDtel.pgmid    = 'R3TR'
                                                           and TadirDtel.object   = 'DTEL'
                                                           and TadirDtel.obj_name = Object.obj_name
                                                           and Object.object      = 'DTED'
    left outer join ZIR_SCORT_INACTIVE_OBJ as Inactive     on Inactive.ObjectName = Object.obj_name
{
  key Object.trkorr                                                  as Trkorr,
  key Object.pgmid                                                   as Pgmid,
  key case
        when Object.object = 'RELE'
          then 'RELE'
        when Object.object = 'NOTE'
          then 'NOTE'
        when Object.object = 'COMM'
          then 'COMM'
        when Object.pgmid = 'CORR' or Object.pgmid = '*'
          then 'COMM'
        when Object.object = 'REPS' or Object.object = 'REPT'
          then 'PROG'
        when Object.object = 'TABD' or Object.object = 'TABT'
          then 'TABL'
        when Object.object = 'DOMD'
          then 'DOMA'
        when Object.object = 'DTED'
          then 'DTEL'
        when Object.object = 'METH' or Object.object = 'CPUB' or Object.object = 'CPRI'
          or Object.object = 'CPRO' or Object.object = 'CLSD' or Object.object = 'CINC'
          then 'CLAS'
        else Object.object
      end                                                            as ObjectType,
  key Object.obj_name                                                as ObjectName,

      Header.strkorr                                                 as ParentTrkorr,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_SCORT_VH_USER', element: 'UserId' } }]
      Header.as4user                                                 as Owner,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_SCORT_VH_USER', element: 'UserId' } }]
      ParentHeader.as4user                                           as ParentOwner,
      Header.as4date                                                 as CreatedOn,
      Header.trstatus                                                as TrStatus,

      case
        when Header.strkorr is not initial
          then Header.strkorr
        else Header.trkorr
      end                                                            as CurrentManagingTr,

      Object.activity                                                as Activity,
      coalesce( TadirDirect.devclass,
        coalesce( TadirProg.devclass,
          coalesce( TadirTabl.devclass,
            coalesce( TadirDoma.devclass, TadirDtel.devclass ) ) ) ) as PackageName,

      cast( case
              when Object.pgmid = 'CORR' or Object.pgmid = '*' or Object.object = 'RELE'
                then 'COMMENT'
              when Object.activity = 'D'
                or TadirDirect.delflag = 'X'
                or TadirProg.delflag = 'X'
                or TadirTabl.delflag = 'X'
                or TadirDoma.delflag = 'X'
                or TadirDtel.delflag = 'X'
                then 'DELETED'
              when Inactive.ObjectName is not null
                then 'INACTIVE'
              when TadirDirect.obj_name is not null
                or TadirProg.obj_name is not null
                or TadirTabl.obj_name is not null
                or TadirDoma.obj_name is not null
                or TadirDtel.obj_name is not null
                then 'ACTIVE'
              when Object.pgmid = 'LIMU' and Object.object = 'FUNC'
                then 'ACTIVE'
              else 'NOT_FOUND'
            end as abap.char(10) )                                   as ObjectStatus
}
where
     Object.pgmid = 'R3TR'
  or Object.pgmid = 'LIMU'
  or Object.pgmid = 'CORR'
  or Object.pgmid = '*'

union all

select from       e071                   as Object
  inner join      enlfdir                as Func         on  Func.area   = Object.obj_name
                                                         and Func.active = 'X'
  inner join      e070                   as Header       on Header.trkorr = Object.trkorr
  left outer join e070                   as ParentHeader on ParentHeader.trkorr = Header.strkorr
  left outer join tadir                  as Tadir        on  tadir.pgmid    = 'R3TR'
                                                         and tadir.object   = 'FUGR'
                                                         and tadir.obj_name = Object.obj_name
  left outer join ZIR_SCORT_INACTIVE_OBJ as Inactive     on Inactive.ObjectName = Func.funcname
{
  key Object.trkorr                                as Trkorr,
  key 'LIMU'                                       as Pgmid,
  key 'FUNC'                                       as ObjectType,
  key cast( Func.funcname as sobj_name )           as ObjectName,

      Header.strkorr                               as ParentTrkorr,
      Header.as4user                               as Owner,
      ParentHeader.as4user                         as ParentOwner,
      Header.as4date                               as CreatedOn,
      Header.trstatus                              as TrStatus,

      case
        when Header.strkorr is not initial
          then Header.strkorr
        else Header.trkorr
      end                                          as CurrentManagingTr,

      Object.activity                              as Activity,
      tadir.devclass                               as PackageName,

      cast( case
              when Object.activity = 'D' or tadir.delflag = 'X'
                then 'DELETED'
              when Inactive.ObjectName is not null
                then 'INACTIVE'
              else 'ACTIVE'
            end as abap.char(10) )                 as ObjectStatus
}
where
      Object.pgmid  = 'R3TR'
  and Object.object = 'FUGR'
