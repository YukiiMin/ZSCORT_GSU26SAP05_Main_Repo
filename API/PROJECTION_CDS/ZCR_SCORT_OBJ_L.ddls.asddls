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
  - Navigation to Source Code viewer (ZCR_SCORT_OBJ_SRC)
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
  @Search.defaultSearchElement: true
  @Search.fuzzinessThreshold: 0.7
  @UI.lineItem: [{ position: 10, label: 'Object Name' }]
  @UI.selectionField: [{ position: 10 }]
  key Pgmid,

  @UI.lineItem: [{ position: 20, label: 'Object Type' }]
  @UI.selectionField: [{ position: 20 }]
  @Consumption.filter: { selectionType: #SINGLE, multipleSelections: true }
  key ObjectType,

  @Search.defaultSearchElement: true
  @UI.lineItem: [{ position: 30, label: 'Object Name' }]
  @UI.selectionField: [{ position: 30 }]
  key ObjectName,

  @UI.lineItem: [{ position: 40, label: 'Package' }]
  @UI.selectionField: [{ position: 40 }]
  PackageName,

  @UI.lineItem: [{ position: 50, label: 'Person Responsible' }]
  @UI.selectionField: [{ position: 50 }]
  PersonResponsible,

  @UI.lineItem: [{ position: 60, label: 'Created On' }]
  CreatedOn,

  CreatedAt,

  /* Navigation to Source Code + Metadata viewer */
  @UI.lineItem: [{ position: 70, label: 'View Source', type: #FOR_ACTION }]
  _SourceCode
}
