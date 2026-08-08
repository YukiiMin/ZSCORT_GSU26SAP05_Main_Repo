@EndUserText.label: 'SCORT: Projection - Search & Filter Local Objects (UI)'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
/*
  CDS Root Projection View for Local Object Search UI.
  Wraps ZIR_SCORT_OBJ_L.
  UI Annotations:
  - Wildcard search on ObjectName
  - Selection Fields: ObjectType, PackageName, PersonResponsible
  - LineItem: flat list display per object row
  - Navigation to Source Code viewer (ZCR_SCORT_OBJ_SRC) via _SourceCode
*/
@UI.headerInfo: {
    typeName: 'Local Object',
    typeNamePlural: 'Local Objects',
    title: { type: #STANDARD, value: 'ObjectName' },
    description: { type: #STANDARD, value: 'ObjectType' }
}
define root view entity ZCR_SCORT_OBJ_L
  provider contract transactional_query
  as projection on ZIR_SCORT_OBJ_L
{
  @UI.identification: [{ position: 10 }]
  @Search.defaultSearchElement: true
  @Search.fuzzinessThreshold: 0.7
  @UI.lineItem: [{ position: 10, label: 'Pgmid' }]
  @UI.selectionField: [{ position: 10 }]
  key Pgmid,

  @UI.lineItem: [{ position: 20, label: 'Object Type' }]
  @UI.identification: [{ position: 20 }]
  @UI.selectionField: [{ position: 20 }]
  @Consumption.filter: { selectionType: #SINGLE, multipleSelections: true }
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_SCORT_VH_OBJ_TYPE', element: 'ObjectType' } }]
  key ObjectType,

  @Search.defaultSearchElement: true
  @UI.lineItem: [{ position: 30, label: 'Object Name' }]
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

  @UI.hidden: true
  ServerType,

  /* Navigation Property: OData will expose as nav link, FE navigates to Object Page */
  _SourceCode
}
