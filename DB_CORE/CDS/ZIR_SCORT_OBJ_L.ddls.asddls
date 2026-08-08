@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'SCORT: Search & Filter Objects in Local Server'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #XXL,
    dataClass: #MIXED
}
define root view entity ZIR_SCORT_OBJ_L
  as select from tadir
  association [0..1] to ZCR_SCORT_OBJ_SRC as _SourceCode
    on  _SourceCode.ObjectType  = $projection.ObjectType
    and _SourceCode.ObjectName  = $projection.ObjectName
    and _SourceCode.ServerType  = $projection.ServerType
{
  key pgmid       as Pgmid,
  key object      as ObjectType,
  key obj_name    as ObjectName,

      devclass    as PackageName,
      author      as PersonResponsible,
      created_on as CreatedOn, // Resolves the unknown as4date error

      cast( 'L' as abap.char(1) ) as ServerType,

      /* Navigation */
      _SourceCode
}
where pgmid = 'R3TR'
