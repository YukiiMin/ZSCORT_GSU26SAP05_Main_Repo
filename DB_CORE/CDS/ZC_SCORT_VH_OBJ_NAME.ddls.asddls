@EndUserText.label: 'VH — Object Name (theo ObjectType, Z*/Y*, max 100)'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_SCORT_VH_QUERY'
@ObjectModel.resultSet.sizeCategory: #XS
define custom entity ZC_SCORT_VH_OBJ_NAME
{
  @EndUserText.label: 'Object Type'
  @UI.hidden: true
  key ObjectType : abap.char(4);

  @EndUserText.label: 'Object Name'
  @UI.lineItem: [{ position: 10 }]
  key ObjectName : abap.char(40);

  @EndUserText.label: 'Package'
  @UI.lineItem: [{ position: 20 }]
  Devclass : abap.char(30);

  @EndUserText.label: 'Author'
  @UI.lineItem: [{ position: 30 }]
  Author : abap.char(12);
}
