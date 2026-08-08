@EndUserText.label: 'VH — Object Type'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_SCORT_VH_QUERY'
@ObjectModel.resultSet.sizeCategory: #XS
define custom entity ZC_SCORT_VH_OBJ_TYPE
{
  @EndUserText.label: 'Object Type'
  @UI.lineItem: [{ position: 10 }]
  key ObjectType : abap.char(4);

  @EndUserText.label: 'Description'
  @UI.lineItem: [{ position: 20 }]
  Description : abap.char(60);
}
