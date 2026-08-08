@EndUserText.label: 'SCORT: TR Request/Task/Object Hierarchy Tree'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_SCORT_TR_TREE_QUERY'
@Metadata.allowExtensions: true
@UI.headerInfo: {
    typeName: 'TR Node',
    typeNamePlural: 'TR Hierarchy',
    title: { type: #STANDARD, value: 'Trkorr' },
    description: { type: #STANDARD, value: 'NodeType' }
}
/*
  Custom Entity — Query Provider Pattern (Tree/Hierarchy).
  ZCL_SCORT_TR_TREE_QUERY implements IF_RAP_QUERY_PROVIDER.
  Reads from: E070 (TR Header), E07T (TR Description), E071 (TR Objects).
  Builds 3-level virtual tree:
    Level 0: TR Request (Parent TR, strkorr IS INITIAL)
    Level 1: TR Task   (Child TR, strkorr = Parent Trkorr)
    Level 2: Objects   (Entries from E071 for the Task)
  NodeID = concatenation of Trkorr + ObjName (CHAR40, unique).
*/
define root custom entity ZCE_SCORT_TR_TREE
{
  @EndUserText.label: 'Node ID (Virtual, CHAR40)'
  @UI.lineItem: [
    { position: 10, label: 'Node ID' },
    { type: #FOR_ACTION, dataAction: 'ReleaseRequest', label: 'Release' },
    { type: #FOR_ACTION, dataAction: 'ApplyToTarget', label: 'Apply to Target' }
  ]
  key NodeId             : zde_scort_node_id;

  @EndUserText.label: 'Parent Node ID'
  @UI.lineItem: [{ position: 20, label: 'Parent Node' }]
  ParentNodeId           : zde_scort_parent_node_id;

  @EndUserText.label: 'Tree Level (0=TR, 1=Task, 2=Object)'
  @UI.lineItem: [{ position: 30, label: 'Level' }]
  TreeLevel              : zde_scort_tree_level;

  @EndUserText.label: 'Node Type (TR/TASK/OBJ)'
  @UI.lineItem: [{ position: 40, label: 'Type' }]
  NodeType               : abap.char(4);

  @EndUserText.label: 'Transport Request Number'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_SCORT_VH_TRKORR', element: 'Trkorr' } }]
  @UI.lineItem: [{ position: 50, label: 'TR Number' }]
  @UI.selectionField: [{ position: 10 }]
  Trkorr                 : trkorr; // Maps to e070-trkorr

  @EndUserText.label: 'Parent Transport Request'
  ParentTrkorr           : strkorr; // Maps to e070-strkorr

  @EndUserText.label: 'TR Description / Short Text'
  @UI.lineItem: [{ position: 60, label: 'Description' }]
  Description            : as4text; // Maps to e07t-as4text

  @EndUserText.label: 'Owner / Responsible User'
  @UI.lineItem: [{ position: 70, label: 'Owner' }]
  @UI.selectionField: [{ position: 20 }]
  Owner                  : as4user; // Maps to e070-as4user

  @EndUserText.label: 'Created Date'
  @UI.lineItem: [{ position: 80, label: 'Date' }]
  @UI.selectionField: [{ position: 30 }]
  As4date                : as4date; // Maps to e070-as4date

  @EndUserText.label: 'TR Status (D=Modifiable, R=Released)'
  @UI.lineItem: [{ position: 90, label: 'Status' }]
  @UI.selectionField: [{ position: 40 }]
  TrStatus               : trstatus; // Maps to e070-trstatus

  @EndUserText.label: 'Object Name (for Level 2)'
  @UI.lineItem: [{ position: 100, label: 'Object Name' }]
  ObjName                : trobj_name; // Maps to e071-obj_name

  @EndUserText.label: 'Object Type (for Level 2)'
  @UI.lineItem: [{ position: 110, label: 'Object Type' }]
  ObjType                : trobjtype; // Maps to e071-object

  @EndUserText.label: 'Program ID (for Level 2)'
  Pgmid                  : pgmid; // Maps to e071-pgmid
}
