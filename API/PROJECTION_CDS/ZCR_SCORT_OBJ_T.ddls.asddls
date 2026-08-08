@EndUserText.label: 'SCORT: Projection - Search & Filter Target Objects (UI)'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@UI.headerInfo: {
    typeName: 'Target Object',
    typeNamePlural: 'Target Objects',
    title: { type: #STANDARD, value: 'ObjectName' },
    description: { type: #STANDARD, value: 'ObjectType' }
}
define root view entity ZCR_SCORT_OBJ_T
  provider contract transactional_query
  as projection on ZIR_SCORT_OBJ_T
{
  @Search.defaultSearchElement: true
  @UI.lineItem: [{ position: 10, label: 'Server ID' }]
  @UI.identification: [{ position: 10 }]
  key ServerId,

  @UI.lineItem: [{ position: 20, label: 'Object Type' }]
  @UI.identification: [{ position: 20 }]
  @UI.selectionField: [{ position: 20 }]
  @Consumption.filter: { selectionType: #SINGLE, multipleSelections: true }
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_SCORT_VH_OBJ_TYPE', element: 'ObjectType' } }]
  key ObjectType,

  @Search.defaultSearchElement: true
  @UI.lineItem: [{ position: 30, type: #WITH_NAVIGATION_PATH, targetElement: '_SourceCode', label: 'Object Name' }]
  @UI.identification: [{ position: 30 }]
  @UI.selectionField: [{ position: 30 }]
  @Consumption.valueHelpDefinition: [{
    entity: { name: 'ZC_SCORT_VH_OBJ_NAME', element: 'ObjectName' },
    additionalBinding: [
      { localElement: 'ObjectType', element: 'ObjectType', usage: #FILTER },
      { localElement: 'ObjectType', element: 'ObjectType', usage: #RESULT }
    ]
  }]
  key ObjectName,

  @UI.lineItem: [{ position: 40, label: 'Package' }]
  @UI.identification: [{ position: 40 }]
  @UI.selectionField: [{ position: 40 }]
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_SCORT_VH_PACKAGE', element: 'PackageName' } }]
  PackageName,

  @UI.lineItem: [{ position: 50, label: 'Person Responsible' }]
  @UI.identification: [{ position: 50 }]
  @UI.selectionField: [{ position: 50 }]
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_SCORT_VH_USER', element: 'UserId' } }]
  PersonResponsible,

  @UI.lineItem: [{ position: 60, label: 'Created On' }]
  @UI.identification: [{ position: 60 }]
  CreatedOn,

  @UI.lineItem: [{ position: 70, label: 'Changed On' }]
  @UI.identification: [{ position: 70 }]
  ChangedOn,

  @UI.hidden: true
  ServerType,

  /* Navigation Property: OData will expose as nav link, FE navigates to Object Page */
  _SourceCode
}
