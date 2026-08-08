@EndUserText.label: 'VH — Server Type (L / T)'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_SCORT_VH_QUERY'
@ObjectModel.resultSet.sizeCategory: #XS
define custom entity ZC_SCORT_VH_SERVER_TYPE
{
  @EndUserText.label: 'Server Type'
  @UI.lineItem: [{ position: 10 }]
  key ServerType : abap.char(1);

  @EndUserText.label: 'Description'
  @UI.lineItem: [{ position: 20 }]
  Description : abap.char(40);
}
