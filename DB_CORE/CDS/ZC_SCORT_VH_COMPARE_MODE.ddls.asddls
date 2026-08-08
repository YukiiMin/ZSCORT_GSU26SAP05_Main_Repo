@EndUserText.label: 'VH — Compare Mode'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_SCORT_VH_QUERY'
@ObjectModel.resultSet.sizeCategory: #XS
define custom entity ZC_SCORT_VH_COMPARE_MODE
{
  @EndUserText.label: 'Compare Mode'
  @UI.lineItem: [{ position: 10 }]
  key CompareMode : abap.char(20);

  @EndUserText.label: 'Description'
  @UI.lineItem: [{ position: 20 }]
  Description : abap.char(80);
}
