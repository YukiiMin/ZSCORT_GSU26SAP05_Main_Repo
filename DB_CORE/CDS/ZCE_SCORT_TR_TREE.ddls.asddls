@EndUserText.label: 'SCORT: TR Request/Task/Object Hierarchy Tree'
@ObjectModel.query.implementedBy: 'ZCL_SCORT_TR_TREE_QUERY'
@AccessControl.authorizationCheck: #NOT_REQUIRED
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
define custom entity ZCE_SCORT_TR_TREE
{
  @EndUserText.label: 'Node ID (Virtual, CHAR40)'
  key NodeId             : zde_scort_node_id;

  @EndUserText.label: 'Parent Node ID'
  ParentNodeId           : zde_scort_parent_node_id;

  @EndUserText.label: 'Tree Level (0=TR, 1=Task, 2=Object)'
  TreeLevel              : zde_scort_tree_level;

  @EndUserText.label: 'Node Type (TR/TASK/OBJ)'
  NodeType               : abap.char(4);

  @EndUserText.label: 'Transport Request Number'
  Trkorr                 : e070-trkorr;

  @EndUserText.label: 'Parent Transport Request'
  ParentTrkorr           : e070-strkorr;

  @EndUserText.label: 'TR Description / Short Text'
  Description            : e07t-as4text;

  @EndUserText.label: 'Owner / Responsible User'
  Owner                  : e070-as4user;

  @EndUserText.label: 'Created Date'
  As4date                : e070-as4date;

  @EndUserText.label: 'TR Status (D=Modifiable, R=Released)'
  TrStatus               : e070-trstatus;

  @EndUserText.label: 'Object Name (for Level 2)'
  ObjName                : e071-obj_name;

  @EndUserText.label: 'Object Type (for Level 2)'
  ObjType                : e071-object;

  @EndUserText.label: 'Program ID (for Level 2)'
  Pgmid                  : e071-pgmid;
}
