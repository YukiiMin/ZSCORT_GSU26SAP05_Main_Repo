@EndUserText.label: 'SCORT — Object Versions'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_SCORT_VERSION_QUERY'
@Metadata.allowExtensions: true
@UI.headerInfo: {
  typeName: 'Object Version',
  typeNamePlural: 'Object Versions',
  title: { value: 'VersionNo' },
  description: { value: 'Message' }
}

define root custom entity ZCR_SCORT_OBJ_VERSION
{
  @UI.facet: [{
    id: 'General',
    purpose: #STANDARD,
    type: #IDENTIFICATION_REFERENCE,
    label: 'Version',
    position: 10
  }]

  @EndUserText.label: 'Server Type (L = Origin | T = Target)'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_SCORT_VH_SERVER_TYPE', element: 'ServerType' } }]
  @UI.selectionField: [{ position: 5 }]
  key ServerType : abap.char(1);

  @EndUserText.label: 'Object Type'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_SCORT_VH_OBJ_TYPE', element: 'ObjectType' } }]
  @UI.lineItem: [{ position: 10 }]
  @UI.selectionField: [{ position: 10 }]
  key ObjectType : abap.char(4);

  @EndUserText.label: 'Object Name'
  @Consumption.valueHelpDefinition: [{
    entity: { name: 'ZC_SCORT_VH_OBJ_NAME', element: 'ObjectName' },
    additionalBinding: [{ localElement: 'ObjectType', element: 'ObjectType', usage: #FILTER }]
  }]
  @UI.lineItem: [{ position: 20 }]
  @UI.selectionField: [{ position: 20 }]
  key ObjectName : abap.char(40);

  @EndUserText.label: 'Version No (99998 = Active)'
  @UI.lineItem: [{ position: 30 }]
  @UI.identification: [{ position: 10 }]
  key VersionNo : abap.numc(5);

  @EndUserText.label: 'Server Id'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_SCORT_VH_SERVER_ID', element: 'ServerId' } }]
  @UI.selectionField: [{ position: 25 }]
  ServerId : abap.char(10);

  @EndUserText.label: 'Author'
  @UI.lineItem: [{ position: 40 }]
  Author : abap.char(12);

  @EndUserText.label: 'Date'
  @UI.lineItem: [{ position: 50 }]
  Datum : abap.dats;

  @EndUserText.label: 'Time'
  @UI.lineItem: [{ position: 60 }]
  Uzeit : abap.tims;

  @EndUserText.label: 'Transport'
  @UI.lineItem: [{ position: 70 }]
  Korrnum : abap.char(20);

  @EndUserText.label: 'Is Active (99998)'
  @UI.lineItem: [{ position: 80 }]
  IsActive : abap_boolean;

  @EndUserText.label: 'Source Kind (VRSD | CUSTOM)'
  @UI.lineItem: [{ position: 85 }]
  SourceKind : abap.char(10);

  @EndUserText.label: 'Source Hash'
  @UI.lineItem: [{ position: 88 }]
  SrcHash : abap.char(40);

  @EndUserText.label: 'Message'
  @UI.lineItem: [{ position: 90 }]
  Message : abap.string(0);
}
