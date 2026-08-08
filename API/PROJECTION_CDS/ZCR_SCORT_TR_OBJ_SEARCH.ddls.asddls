@EndUserText.label: 'SCORT: Projection - Search Objects in TR (Flat List Report)'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@UI.headerInfo: {
    typeName: 'TR Object',
    typeNamePlural: 'Objects in TR',
    title: { type: #STANDARD, value: 'ObjectName' },
    description: { type: #STANDARD, value: 'ObjectType' }
}
define root view entity ZCR_SCORT_TR_OBJ_SEARCH
  provider contract transactional_query
  as projection on ZIR_SCORT_TR_OBJ_SEARCH
{
  @UI.lineItem: [{ position: 10, label: 'TR Number' }]
  @UI.selectionField: [{ position: 10 }]
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_SCORT_VH_TRKORR', element: 'Trkorr' } }]
  key Trkorr,

  @UI.lineItem: [{ position: 20, label: 'Pgmid' }]
  key Pgmid,

  @UI.lineItem: [{ position: 30, label: 'Object Type' }]
  @UI.selectionField: [{ position: 30 }]
  @Consumption.filter: { selectionType: #SINGLE, multipleSelections: true }
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_SCORT_VH_OBJ_TYPE', element: 'ObjectType' } }]
  key ObjectType,

  @Search.defaultSearchElement: true
  @UI.lineItem: [{ position: 40, label: 'Object Name' }]
  @UI.selectionField: [{ position: 40 }]
  @Consumption.valueHelpDefinition: [{
    entity: { name: 'ZC_SCORT_VH_OBJ_NAME', element: 'ObjectName' },
    additionalBinding: [
      { localElement: 'ObjectType', element: 'ObjectType', usage: #FILTER },
      { localElement: 'ObjectType', element: 'ObjectType', usage: #RESULT }
    ]
  }]
  key ObjectName,

  ParentTrkorr,

  @UI.lineItem: [{ position: 50, label: 'Owner' }]
  @UI.selectionField: [{ position: 50 }]
  Owner,

  @UI.lineItem: [{ position: 60, label: 'Created On' }]
  CreatedOn,

  @UI.lineItem: [{
      position: 70,
      label: 'TR Status'
  }]
  @UI.selectionField: [{ position: 60 }]
  TrStatus,

  /* Key computed field: identifies actual managing TR */
  @UI.lineItem: [{ position: 80, label: 'Current Managing TR' }]
  CurrentManagingTr,

  Activity
}
