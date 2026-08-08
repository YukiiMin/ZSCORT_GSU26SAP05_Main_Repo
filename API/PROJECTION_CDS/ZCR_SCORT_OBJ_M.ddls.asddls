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
  @UI.identification: [{ position: 10 }]
  key Pgmid,

  @UI.lineItem: [{ position: 20, label: 'Object Type' }]
  @UI.identification: [{ position: 20 }]
  @UI.selectionField: [{ position: 10 }]
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_SCORT_VH_OBJ_TYPE', element: 'ObjectType' } }]
  key ObjectType,

  @Search.defaultSearchElement: true
  @UI.lineItem: [{ position: 30, label: 'Object Name' }]
  @UI.identification: [{ position: 30 }]
  @UI.selectionField: [{ position: 20 }]
  @Consumption.valueHelpDefinition: [{
    entity: { name: 'ZC_SCORT_VH_OBJ_NAME', element: 'ObjectName' },
    additionalBinding: [
      { localElement: 'ObjectType', element: 'ObjectType', usage: #FILTER },
      { localElement: 'ObjectType', element: 'ObjectType', usage: #RESULT }
    ]
  }]
  key ObjectName,

  @UI.lineItem: [{ position: 40, label: 'Local Package' }]
  @UI.identification: [{ position: 40 }]
  LocalPackage,

  @UI.lineItem: [{ position: 50, label: 'Target Package' }]
  @UI.identification: [{ position: 50 }]
  TargetPackage,

  @UI.lineItem: [{ position: 60, label: 'Local Author' }]
  @UI.identification: [{ position: 60 }]
  LocalAuthor,

  @UI.lineItem: [{ position: 70, label: 'Target Author' }]
  @UI.identification: [{ position: 70 }]
  TargetAuthor,

  @UI.lineItem: [{
      position: 80,
      label: 'Existence Status',
      criticality: 'ExistenceStatusCriticality'
  }]
  @UI.identification: [{ position: 80 }]
  ExistenceStatus,

  @UI.hidden: true
  ServerType,

  /* Action button: Check Diff */
  @UI.lineItem: [{
      position: 90,
      label: 'Check Diff',
      type: #FOR_ACTION,
      dataAction: 'checkDiff',
      requiresContext: true
  }]
  /* Navigation Property: OData nav link to Source Code entity */
  _SourceCode
}
