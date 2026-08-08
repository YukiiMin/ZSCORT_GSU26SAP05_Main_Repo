@EndUserText.label: 'SCORT — Object Source'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_SCORT_R_SRC'
@Metadata.allowExtensions: true
@UI.headerInfo: {
  typeName: 'Object Source',
  typeNamePlural: 'Object Sources',
  title: { value: 'ObjectName' },
  description: { value: 'Message' }
}

define root custom entity ZCR_SCORT_OBJ_SRC
{
  @UI.facet: [{
    id: 'General',
    purpose: #STANDARD,
    type: #IDENTIFICATION_REFERENCE,
    label: 'Source',
    position: 10
  }]

  @EndUserText.label: 'Server Type (L | T)'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_SCORT_VH_SERVER_TYPE', element: 'ServerType' } }]
  @UI.lineItem: [{ position: 10 }]
  @UI.selectionField: [{ position: 10 }]
  @UI.identification: [{ position: 10 }]
  key ServerType : abap.char(1);

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
    ]
  }]
  @UI.lineItem: [{ position: 30 }]
  @UI.selectionField: [{ position: 30 }]
  @UI.identification: [{ position: 30 }]
  key ObjectName : abap.char(40);

  @EndUserText.label: 'Server Id'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_SCORT_VH_SERVER_ID', element: 'ServerId' } }]
  @UI.lineItem: [{ position: 40 }]
  @UI.selectionField: [{ position: 40 }]
  @UI.identification: [{ position: 40 }]
  ServerId : abap.char(10);

  @EndUserText.label: 'Version No'
  @Consumption.valueHelpDefinition: [{
    entity: { name: 'ZCR_SCORT_OBJ_VERSION', element: 'VersionNo' },
    additionalBinding: [
      { localElement: 'ServerType', element: 'ServerType', usage: #FILTER },
      { localElement: 'ObjectType', element: 'ObjectType', usage: #FILTER },
      { localElement: 'ObjectName', element: 'ObjectName', usage: #FILTER },
      { localElement: 'ServerId', element: 'ServerId', usage: #FILTER }
    ]
  }]
  @UI.lineItem: [{ position: 50 }]
  @UI.selectionField: [{ position: 50 }]
  @UI.identification: [{ position: 50 }]
  VersionNo : abap.numc(5);

  @EndUserText.label: 'Line Count'
  @UI.lineItem: [{ position: 60 }]
  @UI.identification: [{ position: 60 }]
  LineCount : abap.int4;

  @EndUserText.label: 'Source Hash'
  @UI.lineItem: [{ position: 70 }]
  @UI.identification: [{ position: 70 }]
  SrcHash : abap.char(40);

  @EndUserText.label: 'Message'
  @UI.lineItem: [{ position: 80 }]
  @UI.identification: [{ position: 80 }]
  Message : abap.string(0);

  @EndUserText.label: 'Source Code Text'
  @UI.identification: [{ position: 90 }]
  SourceCodeText : abap.string(0);

  @EndUserText.label: 'Metadata Text'
  @UI.identification: [{ position: 100 }]
  MetadataText : abap.string(0);
}
