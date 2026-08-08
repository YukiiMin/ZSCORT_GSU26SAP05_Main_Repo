@EndUserText.label: 'VH — Server Id (Target snapshot)'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_SCORT_VH_QUERY'
@ObjectModel.resultSet.sizeCategory: #XS
define custom entity ZC_SCORT_VH_SERVER_ID
{
  @EndUserText.label: 'Server Id'
  @UI.lineItem: [{ position: 10 }]
  key ServerId : abap.char(10);

  @EndUserText.label: 'Description'
  @UI.lineItem: [{ position: 20 }]
  Description : abap.char(60);
}
