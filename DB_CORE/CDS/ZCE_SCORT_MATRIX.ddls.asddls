@EndUserText.label: 'SCORT: Compare Matrix (Custom Entity)'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_SCORT_MATRIX_QUERY'
@Metadata.allowExtensions: true
@UI.headerInfo: {
    typeName: 'Object Compare',
    typeNamePlural: 'Object Compare Matrix',
    title: { type: #STANDARD, value: 'ObjectName' },
    description: { type: #STANDARD, value: 'ExistenceStatus' }
}
define custom entity ZCE_SCORT_MATRIX
{
      @UI.lineItem: [{ position: 10, label: 'Pgmid' }]
      @UI.identification: [{ position: 10 }]
  key Pgmid           : pgmid;

      @UI.lineItem: [{ position: 20, label: 'Object Type' }]
      @UI.identification: [{ position: 20 }]
      @UI.selectionField: [{ position: 10 }]
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_SCORT_VH_OBJ_TYPE', element: 'ObjectType' } }]
  key ObjectType      : trobjtype;

      @Search.defaultSearchElement: true
      @UI.lineItem: [{ position: 30, type: #WITH_NAVIGATION_PATH, targetElement: '_SourceCode', label: 'Object Name' }]
      @UI.identification: [{ position: 30 }]
      @UI.selectionField: [{ position: 20 }]
      @Consumption.valueHelpDefinition: [{
        entity: { name: 'ZC_SCORT_VH_OBJ_NAME', element: 'ObjectName' },
        additionalBinding: [
          { localElement: 'ObjectType', element: 'ObjectType', usage: #FILTER },
          { localElement: 'ObjectType', element: 'ObjectType', usage: #RESULT }
        ]
      }]
  key ObjectName      : trobj_name;

      @UI.lineItem: [{ position: 40, label: 'Local Package' }]
      @UI.identification: [{ position: 40 }]
      LocalPackage    : devclass;

      @UI.lineItem: [{ position: 50, label: 'Target Package' }]
      @UI.identification: [{ position: 50 }]
      TargetPackage   : devclass;

      @UI.lineItem: [{ position: 60, label: 'Local Author' }]
      @UI.identification: [{ position: 60 }]
      LocalAuthor     : as4user;

      @UI.lineItem: [{ position: 70, label: 'Target Author' }]
      @UI.identification: [{ position: 70 }]
      TargetAuthor    : as4user;

      @UI.lineItem: [{ position: 80, label: 'Existence Status' }]
      @UI.identification: [{ position: 80 }]
      ExistenceStatus : abap.char(15);

      @UI.hidden: true
      ServerType      : abap.char(1);

      /* Navigation Property: OData nav link to Source Code entity */
      _SourceCode     : association [0..1] to ZCR_SCORT_OBJ_SRC on $projection.ObjectType = _SourceCode.ObjectType
                                                              and $projection.ObjectName = _SourceCode.ObjectName
                                                              and $projection.ServerType = _SourceCode.ServerType;
}
