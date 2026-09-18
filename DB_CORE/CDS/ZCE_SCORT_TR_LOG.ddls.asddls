@EndUserText.label: 'SCORT: Transport Log & Tracking'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_SCORT_TR_LOG_QUERY'
define root custom entity ZCE_SCORT_TR_LOG
{
  key Trkorr       : trkorr;
  key SystemId     : tmssysnam;
  key StepId       : abap.char(10);
  key ActionIndex  : abap.int4;

      ParentNodeId : zde_scort_parent_node_id;
      NodeId       : zde_scort_node_id;
      NodeType     : abap.char(10);
      StepTitle    : as4text;
      ReturnCode   : sysubrc;
      StatusText   : val_text;
      Timestamp    : text30;
      LogFile      : pathname;
      LogContent   : abap.string(0);
      LineCount    : abap.int4;
      Message      : bapi_msg;
}

