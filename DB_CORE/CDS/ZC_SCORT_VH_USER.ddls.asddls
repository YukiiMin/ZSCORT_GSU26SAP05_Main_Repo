@EndUserText.label: 'VH — User / Person Responsible'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_SCORT_VH_QUERY'
@ObjectModel.resultSet.sizeCategory: #XS
define custom entity ZC_SCORT_VH_USER
{
  @EndUserText.label: 'User ID'
  @UI.lineItem: [{ position: 10 }]
  key UserId : abap.char(12);

  @EndUserText.label: 'Full Name'
  @UI.lineItem: [{ position: 20 }]
  FullName : abap.char(40);
}
