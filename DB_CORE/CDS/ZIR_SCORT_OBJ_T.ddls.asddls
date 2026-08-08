@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'SCORT: Search & Filter Objects in Target Server (Custom Table)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #XL,
    dataClass: #MIXED
}
define root view entity ZIR_SCORT_OBJ_T
  as select from zascort_t
  association [0..1] to ZCR_SCORT_OBJ_SRC as _SourceCode
    on  _SourceCode.ObjectType  = $projection.ObjectType
    and _SourceCode.ObjectName  = $projection.ObjectName
    and _SourceCode.ServerType  = 'T'
{
  key server_id   as ServerId,
  key object_type as ObjectType,
  key object_name as ObjectName,

      devclass    as PackageName,
      author      as PersonResponsible,
      created_at  as CreatedOn,
      changed_at  as ChangedOn,

      /* Navigation */
      _SourceCode
}
where server_id = 'TARGET'
