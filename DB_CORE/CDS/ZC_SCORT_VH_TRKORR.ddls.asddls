@EndUserText.label: 'VH — Transport Request (E070 Released)'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_SCORT_VH_QUERY'
@ObjectModel.resultSet.sizeCategory: #XS
define custom entity ZC_SCORT_VH_TRKORR
{
  @EndUserText.label: 'Transport Request'
  @UI.lineItem: [{ position: 10 }]
  key Trkorr : abap.char(20);

  @EndUserText.label: 'Status'
  @UI.lineItem: [{ position: 20 }]
  TrStatus : abap.char(1);

  @EndUserText.label: 'Function'
  @UI.lineItem: [{ position: 30 }]
  TrFunction : abap.char(1);

  @EndUserText.label: 'Owner'
  @UI.lineItem: [{ position: 40 }]
  As4user : abap.char(12);

  @EndUserText.label: 'Date'
  @UI.lineItem: [{ position: 50 }]
  As4date : abap.dats;

  @EndUserText.label: 'Text'
  @UI.lineItem: [{ position: 60 }]
  Description : abap.char(60);
}
