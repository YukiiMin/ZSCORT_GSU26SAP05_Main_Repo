@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'SCORT: Inactive Objects Helper'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #A,
    sizeCategory: #M,
    dataClass: #MIXED
}
define view entity ZIR_SCORT_INACTIVE_OBJ
  as select from dwinactiv
{
  key obj_name as ObjectName
}
group by
  obj_name
