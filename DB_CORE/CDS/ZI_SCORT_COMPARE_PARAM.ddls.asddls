@EndUserText.label: 'SCORT — Compare parameters'
@Metadata.allowExtensions: true

define abstract entity ZI_SCORT_COMPARE_PARAM
{
  @EndUserText.label: 'Object Type'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_SCORT_VH_OBJ_TYPE', element: 'ObjectType' } }]
  ObjectType : abap.char(4);

  @EndUserText.label: 'Object Name'
  @Consumption.valueHelpDefinition: [{
    entity: { name: 'ZC_SCORT_VH_OBJ_NAME', element: 'ObjectName' },
    additionalBinding: [
      { localElement: 'ObjectType', element: 'ObjectType', usage: #FILTER },
      { localElement: 'ObjectType', element: 'ObjectType', usage: #RESULT }
    ]
  }]
  ObjectName : abap.char(40);

  @EndUserText.label: 'Server Id (đích)'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_SCORT_VH_SERVER_ID', element: 'ServerId' } }]
  ServerId : abap.char(10);

  @EndUserText.label: 'Compare Mode'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_SCORT_VH_COMPARE_MODE', element: 'CompareMode' } }]
  CompareMode : abap.char(20);

  @EndUserText.label: 'Version Left (empty = Active)'
  @Consumption.valueHelpDefinition: [{
    entity: { name: 'ZCR_SCORT_OBJ_VERSION', element: 'VersionNo' },
    additionalBinding: [
      { localElement: 'ObjectType', element: 'ObjectType', usage: #FILTER },
      { localElement: 'ObjectName', element: 'ObjectName', usage: #FILTER }
    ]
  }]
  VersionNo : abap.numc(5);

  @EndUserText.label: 'Version Right (99998 = Active)'
  @Consumption.valueHelpDefinition: [{
    entity: { name: 'ZCR_SCORT_OBJ_VERSION', element: 'VersionNo' },
    additionalBinding: [
      { localElement: 'ObjectType', element: 'ObjectType', usage: #FILTER },
      { localElement: 'ObjectName', element: 'ObjectName', usage: #FILTER }
    ]
  }]
  VersionNoRight : abap.numc(5);

  @EndUserText.label: 'Transport Request'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_SCORT_VH_TRKORR', element: 'Trkorr' } }]
  Trkorr : abap.char(20);
}
