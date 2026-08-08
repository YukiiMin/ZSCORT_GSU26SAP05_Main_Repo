@EndUserText.label: 'SCORT: Projection - Compare Matrix (Existence Status + checkDiff)'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@UI.headerInfo: {
    typeName: 'Object Compare',
    typeNamePlural: 'Object Compare Matrix',
    title: { type: #STANDARD, value: 'ObjectName' },
    description: { type: #STANDARD, value: 'ExistenceStatus' }
}
define root view entity ZCR_SCORT_OBJ_M
  provider contract transactional_query
  as projection on ZIR_SCORT_OBJ_M( P_ServerType: '' )
{
  @UI.lineItem: [{ position: 10, label: 'Pgmid' }]
  key Pgmid,

  @UI.lineItem: [{ position: 20, label: 'Object Type' }]
  @UI.selectionField: [{ position: 10 }]
  key ObjectType,

  @Search.defaultSearchElement: true
  @UI.lineItem: [{ position: 30, label: 'Object Name' }]
  @UI.selectionField: [{ position: 20 }]
  key ObjectName,

  @UI.lineItem: [{ position: 40, label: 'Local Package' }]
  LocalPackage,

  @UI.lineItem: [{ position: 50, label: 'Target Package' }]
  TargetPackage,

  @UI.lineItem: [{ position: 60, label: 'Local Author' }]
  LocalAuthor,

  @UI.lineItem: [{ position: 70, label: 'Target Author' }]
  TargetAuthor,

  @UI.lineItem: [{
      position: 80,
      label: 'Existence Status',
      criticality: 'ExistenceStatusCriticality'
  }]
  ExistenceStatus,

  ServerType,

  /*
    Expose checkDiff action button in Fiori Elements List Report toolbar.
    Generates "Check Diff" button per row when instance features allow.
  */
  @UI.lineItem: [{
      position: 90,
      label: 'Check Diff',
      type: #FOR_ACTION,
      dataAction: 'checkDiff',
      requiresContext: true
  }]
  _SourceCode
}
