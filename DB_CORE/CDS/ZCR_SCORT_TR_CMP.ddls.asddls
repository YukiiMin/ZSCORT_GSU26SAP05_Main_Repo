@EndUserText.label: 'SCORT — Transport Compare'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_SCORT_TR_CMP_QUERY'
@Metadata.allowExtensions: true
@UI.headerInfo: {
  typeName: 'TR Object',
  typeNamePlural: 'TR Objects',
  title: { value: 'ObjectName' },
  description: { value: 'CompareStatus' }
}

define root custom entity ZCR_SCORT_TR_CMP
{
  @UI.facet: [{
    id: 'General',
    purpose: #STANDARD,
    type: #IDENTIFICATION_REFERENCE,
    label: 'Master Compare',
    position: 10
  }]

  @EndUserText.label: 'Transport Request'
  @Consumption.valueHelpDefinition: [{
    entity: { name: 'ZC_SCORT_VH_TRKORR', element: 'Trkorr' },
    useForValidation: false
  }]
  @UI.lineItem: [{ position: 10 }]
  @UI.selectionField: [{ position: 10 }]
  @UI.identification: [{ position: 10 }]
  key Trkorr : abap.char(20);

  @EndUserText.label: 'Object Type'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_SCORT_VH_OBJ_TYPE', element: 'ObjectType' } }]
  @UI.lineItem: [{ position: 20 }]
  @UI.selectionField: [{ position: 20 }]
  @UI.identification: [{ position: 20 }]
  key ObjectType : abap.char(4);

  @EndUserText.label: 'Object Name'
  @Consumption.valueHelpDefinition: [{
    entity: { name: 'ZC_SCORT_VH_OBJ_NAME', element: 'ObjectName' },
    additionalBinding: [
      { localElement: 'ObjectType', element: 'ObjectType', usage: #FILTER },
      { localElement: 'ObjectType', element: 'ObjectType', usage: #RESULT }
    ],
    useForValidation: false
  }]
  @UI.lineItem: [{ position: 30 }]
  @UI.selectionField: [{ position: 30 }]
  @UI.identification: [{ position: 30 }]
  key ObjectName : abap.char(40);

  @EndUserText.label: 'Compare Status'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_SCORT_VH_COMPARE_STATUS', element: 'CompareStatus' } }]
  @UI.lineItem: [{ position: 40, criticality: 'StatusCriticality' }]
  @UI.selectionField: [{ position: 50 }]
  @UI.identification: [{ position: 40, criticality: 'StatusCriticality' }]
  CompareStatus : abap.char(20);

  @EndUserText.label: 'Status Criticality'
  @UI.hidden: true
  StatusCriticality : abap.int1;

  @EndUserText.label: 'Origin Hash'
  @UI.lineItem: [{ position: 50 }]
  @UI.identification: [{ position: 50 }]
  OriginHash : abap.char(40);

  @EndUserText.label: 'Target Hash'
  @UI.lineItem: [{ position: 60 }]
  @UI.identification: [{ position: 60 }]
  TargetHash : abap.char(40);

  @EndUserText.label: 'Origin Lines'
  @UI.lineItem: [{ position: 70 }]
  @UI.identification: [{ position: 70 }]
  OriginLines : abap.int4;

  @EndUserText.label: 'Target Version'
  @UI.lineItem: [{ position: 80 }]
  @UI.identification: [{ position: 80 }]
  TargetVers : abap.numc(5);

  @EndUserText.label: 'Server Id'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_SCORT_VH_SERVER_ID', element: 'ServerId' } }]
  @UI.selectionField: [{ position: 40 }]
  @UI.identification: [{ position: 90 }]
  ServerId : abap.char(10);

  @EndUserText.label: 'Message'
  @UI.lineItem: [{ position: 100 }]
  @UI.identification: [{ position: 100 }]
  Message : abap.string(0);
}
