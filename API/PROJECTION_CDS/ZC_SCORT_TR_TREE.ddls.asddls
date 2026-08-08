@EndUserText.label: 'SCORT: Projection - TR Tree Hierarchy (UI Tree Table)'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@UI.headerInfo: {
    typeName: 'TR Node',
    typeNamePlural: 'TR Hierarchy',
    title: { type: #STANDARD, value: 'Trkorr' },
    description: { type: #STANDARD, value: 'NodeType' }
}
/*
  Projection for Tree Table UI.
  NodeId / ParentNodeId drive the Fiori sap.ui.table.TreeTable hierarchy.
  TreeLevel 0=TR, 1=Task, 2=Object.
*/
define view entity ZC_SCORT_TR_TREE
  as projection on ZCE_SCORT_TR_TREE
{
  @UI.lineItem: [{ position: 10, label: 'Node ID' }]
  key NodeId,

  @UI.lineItem: [{ position: 20, label: 'Parent Node' }]
  ParentNodeId,

  @UI.lineItem: [{ position: 30, label: 'Level' }]
  TreeLevel,

  @UI.lineItem: [{ position: 40, label: 'Type' }]
  NodeType,

  @UI.lineItem: [{ position: 50, label: 'TR Number' }]
  @UI.selectionField: [{ position: 10 }]
  Trkorr,

  ParentTrkorr,

  @UI.lineItem: [{ position: 60, label: 'Description' }]
  Description,

  @UI.lineItem: [{ position: 70, label: 'Owner' }]
  @UI.selectionField: [{ position: 20 }]
  Owner,

  @UI.lineItem: [{ position: 80, label: 'Date' }]
  @UI.selectionField: [{ position: 30 }]
  As4date,

  @UI.lineItem: [{
      position: 90,
      label: 'Status',
      criticality: 'TrStatusCriticality'
  }]
  @UI.selectionField: [{ position: 40 }]
  TrStatus,

  @UI.lineItem: [{ position: 100, label: 'Object Name' }]
  ObjName,

  @UI.lineItem: [{ position: 110, label: 'Object Type' }]
  ObjType,

  Pgmid
}
