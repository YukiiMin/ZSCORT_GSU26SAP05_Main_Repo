@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'SCORT: Compare Matrix Local vs Target (Existence Status)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #XXL,
    dataClass: #MIXED
}
/*+  UNION approach: LEFT OUTER JOIN from TADIR → ZA_SCORT_T for BOTH/LOCAL_ONLY,
     UNION with reverse LEFT OUTER JOIN for TARGET_ONLY.
     P_ServerType drives which server code is shown in UI.
*/
define root view entity ZIR_SCORT_OBJ_M
  with parameters
    P_ServerType : abap.char(1)  /* 'L' = Local, 'T' = Target */
  as select from tadir as Local
    left outer join zascort_t as Target
      on  Target.server_id    = 'TARGET'
      and Target.object_type  = Local.object
      and Target.object_name  = Local.obj_name
  association [0..1] to ZCR_SCORT_OBJ_SRC as _SourceCode
    on  _SourceCode.ObjectType  = $projection.ObjectType
    and _SourceCode.ObjectName  = $projection.ObjectName
    and _SourceCode.ServerType  = $parameters.P_ServerType
{
  key Local.pgmid                                     as Pgmid,
  key Local.object                                    as ObjectType,
  key Local.obj_name                                  as ObjectName,

      Local.devclass                                  as LocalPackage,
      Local.author                                    as LocalAuthor,
      Target.devclass                                 as TargetPackage,
      Target.author                                   as TargetAuthor,

      /* Computed existence status */
      case
        when Target.object_name is not initial
          then 'BOTH'
        else 'LOCAL_ONLY'
      end                                             as ExistenceStatus,

      $parameters.P_ServerType                        as ServerType,

      /* Navigation */
      _SourceCode
}
where Local.pgmid = 'R3TR'

union all

/* TARGET_ONLY: objects existing in Target but not in Local */
select from zascort_t as Target
    left outer join tadir as Local
      on  Local.pgmid    = 'R3TR'
      and Local.object   = Target.object_type
      and Local.obj_name = Target.object_name
  association [0..1] to ZCR_SCORT_OBJ_SRC as _SourceCode
    on  _SourceCode.ObjectType  = $projection.ObjectType
    and _SourceCode.ObjectName  = $projection.ObjectName
    and _SourceCode.ServerType  = $parameters.P_ServerType
{
  key cast( 'R3TR' as abap.char(4) )                 as Pgmid,
  key Target.object_type                              as ObjectType,
  key Target.object_name                              as ObjectName,

      cast( '' as devclass )                          as LocalPackage,
      cast( '' as as4user )                           as LocalAuthor,
      Target.devclass                                 as TargetPackage,
      Target.author                                   as TargetAuthor,

      cast( 'TARGET_ONLY' as abap.char(15) )          as ExistenceStatus,

      $parameters.P_ServerType                        as ServerType,

      _SourceCode
}
where Target.server_id   = 'TARGET'
  and Local.obj_name is initial
