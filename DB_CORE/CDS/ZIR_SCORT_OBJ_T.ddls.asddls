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
  as select from za05_scort_t
  association [0..1] to ZCR_SCORT_OBJ_SRC as _SourceCode
    on  _SourceCode.ObjectType  = $projection.ObjectType
    and _SourceCode.ObjectName  = $projection.ObjectName
    and _SourceCode.ServerType  = $projection.ServerType
{
  key cast('TARGET' as abap.char(10)) as ServerId,
  key object                         as ObjectType,
  key obj_name                       as ObjectName,

      devclass                       as PackageName,
      author                         as PersonResponsible,
      changed_at                     as CreatedOn,
      changed_at                     as ChangedOn,

      cast( 'T' as abap.char(1) )    as ServerType,

      /* Navigation */
      _SourceCode
}
