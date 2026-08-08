@EndUserText.label: 'SCORT: Filter Parameters for TR Tree Search'
@AccessControl.authorizationCheck: #NOT_REQUIRED
/*
  Abstract Entity — defines the input parameter structure for the
  TR Tree search mode. Used by ZCE_SCORT_TR_TREE / ZCL_SCORT_TR_TREE_QUERY.
  Parameters are extracted from io_request in the Query Provider.
*/
define abstract entity ZI_SCORT_TR_TREE_PARAM
{
  @EndUserText.label: 'Transport Request No. (Wildcard)'
  Trkorr    : e070-trkorr;

  @EndUserText.label: 'Owner / User'
  Owner     : e070-as4user;

  @EndUserText.label: 'Date From'
  DateFrom  : abap.dats;

  @EndUserText.label: 'Date To'
  DateTo    : abap.dats;

  @EndUserText.label: 'TR Status (D=Modifiable, R=Released)'
  TrStatus  : e070-trstatus;
}
