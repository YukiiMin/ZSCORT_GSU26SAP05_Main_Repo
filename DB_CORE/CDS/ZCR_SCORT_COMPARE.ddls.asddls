@EndUserText.label: 'SCORT — Compare Detail'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_SCORT_COMPARE_QUERY'
@Metadata.allowExtensions: true
@UI.headerInfo: {
  typeName: 'Compare Detail',
  typeNamePlural: 'Compare Details',
  title: { value: 'ObjectName' },
  description: { value: 'StatusCode' }
}

define root custom entity ZCR_SCORT_COMPARE
{
  @UI.facet: [{
    id: 'General',
    purpose: #STANDARD,
    type: #IDENTIFICATION_REFERENCE,
    label: 'Detail',
    position: 10
  }]

  @EndUserText.label: 'Object Type'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_SCORT_VH_OBJ_TYPE', element: 'ObjectType' } }]
  @UI.lineItem: [{ position: 10 }]
  @UI.selectionField: [{ position: 10 }]
  @UI.identification: [{ position: 10 }]
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
  @UI.lineItem: [{ position: 20 }]
  @UI.selectionField: [{ position: 20 }]
  @UI.identification: [{ position: 20 }]
  key ObjectName : abap.char(40);

  @EndUserText.label: 'Server Id'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_SCORT_VH_SERVER_ID', element: 'ServerId' } }]
  @UI.selectionField: [{ position: 30 }]
  @UI.identification: [{ position: 25 }]
  key ServerId : abap.char(10);

  " Key — Object Page phải mang theo Mode + Version, không thì rơi về L_VS_T
  @EndUserText.label: 'Compare Mode'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_SCORT_VH_COMPARE_MODE', element: 'CompareMode' } }]
  @UI.lineItem: [{ position: 28 }]
  @UI.selectionField: [{ position: 35 }]
  @UI.identification: [{ position: 28 }]
  key CompareMode : abap.char(20);

  @EndUserText.label: 'Version Left (empty = Active)'
  @Consumption.valueHelpDefinition: [{
    entity: { name: 'ZCR_SCORT_OBJ_VERSION', element: 'VersionNo' },
    additionalBinding: [
      { localElement: 'ObjectType', element: 'ObjectType', usage: #FILTER },
      { localElement: 'ObjectName', element: 'ObjectName', usage: #FILTER },
      { localElement: 'ServerId', element: 'ServerId', usage: #FILTER }
    ]
  }]
  @UI.lineItem: [{ position: 29 }]
  @UI.selectionField: [{ position: 40 }]
  @UI.identification: [{ position: 29 }]
  key VersionNo : abap.numc(5);

  @EndUserText.label: 'Version Right (99998 = Active)'
  @Consumption.valueHelpDefinition: [{
    entity: { name: 'ZCR_SCORT_OBJ_VERSION', element: 'VersionNo' },
    additionalBinding: [
      { localElement: 'ObjectType', element: 'ObjectType', usage: #FILTER },
      { localElement: 'ObjectName', element: 'ObjectName', usage: #FILTER },
      { localElement: 'ServerId', element: 'ServerId', usage: #FILTER }
    ]
  }]
  @UI.lineItem: [{ position: 31 }]
  @UI.selectionField: [{ position: 45 }]
  @UI.identification: [{ position: 30 }]
  key VersionNoRight : abap.numc(5);

  @EndUserText.label: 'Status'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_SCORT_VH_COMPARE_STATUS', element: 'CompareStatus' } }]
  @UI.lineItem: [{ position: 35 }]
  @UI.identification: [{ position: 35 }]
  StatusCode : abap.char(20);

  @EndUserText.label: 'Target Code (left)'
  @UI.identification: [{ position: 40 }]
  TargetCode : abap.string(0);

  @EndUserText.label: 'Source Code (right)'
  @UI.identification: [{ position: 50 }]
  SourceCode : abap.string(0);

  @EndUserText.label: 'Target Hash'
  @UI.lineItem: [{ position: 60 }]
  @UI.identification: [{ position: 60 }]
  TargetHash : abap.char(40);

  @EndUserText.label: 'Source Hash'
  @UI.lineItem: [{ position: 70 }]
  @UI.identification: [{ position: 70 }]
  SourceHash : abap.char(40);

  @EndUserText.label: 'Target Lines'
  @UI.lineItem: [{ position: 80 }]
  @UI.identification: [{ position: 80 }]
  TargetLines : abap.int4;

  @EndUserText.label: 'Source Lines'
  @UI.lineItem: [{ position: 90 }]
  @UI.identification: [{ position: 90 }]
  SourceLines : abap.int4;

  @EndUserText.label: 'Message'
  @UI.lineItem: [{ position: 100 }]
  @UI.identification: [{ position: 100 }]
  Message : abap.string(0);
}
