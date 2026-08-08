@EndUserText.label: 'VH — Compare Status (Master badge)'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_SCORT_VH_QUERY'
@ObjectModel.resultSet.sizeCategory: #XS
define custom entity ZC_SCORT_VH_COMPARE_STATUS
{
  @EndUserText.label: 'Compare Status'
  @UI.lineItem: [{ position: 10 }]
  key CompareStatus : abap.char(20);

  @EndUserText.label: 'Description'
  @UI.lineItem: [{ position: 20 }]
  Description : abap.char(80);
}
