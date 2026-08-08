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
  key ServerId,

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

  ChangedOn,

  /* Navigation to Source Code (compressed, decompressed by ZCL_SCORT_T_READER) */
  _SourceCode
}
