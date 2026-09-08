@EndUserText.label: 'VH — Transport Request (E070 Released)'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_SCORT_VH_QUERY'
@ObjectModel.resultSet.sizeCategory: #XS
define custom entity ZC_SCORT_VH_TRKORR
{
      @EndUserText.label: 'Transport Request'
      @UI.lineItem: [{ position: 10 }]
  key Trkorr      : trkorr;

      @EndUserText.label: 'Status'
      @UI.lineItem: [{ position: 20 }]
      TrStatus    : trstatus;

      @EndUserText.label: 'Function'
      @UI.lineItem: [{ position: 30 }]
      TrFunction  : trfunction;

      @EndUserText.label: 'Owner'
      @UI.lineItem: [{ position: 40 }]
      As4user     : as4user;

      @EndUserText.label: 'Date'
      @UI.lineItem: [{ position: 50 }]
      As4date     : as4date;

      @EndUserText.label: 'Text'
      @UI.lineItem: [{ position: 60 }]
      Description : as4text;
}
