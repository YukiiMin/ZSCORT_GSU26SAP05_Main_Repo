@EndUserText.label: 'VH — Package / Development Class'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_SCORT_VH_QUERY'
@ObjectModel.resultSet.sizeCategory: #XS
define custom entity ZC_SCORT_VH_PACKAGE
{
  @EndUserText.label: 'Package Name'
  @UI.lineItem: [{ position: 10 }]
  key PackageName : abap.char(30);

  @EndUserText.label: 'Description'
  @UI.lineItem: [{ position: 20 }]
  Description : abap.char(60);
}
