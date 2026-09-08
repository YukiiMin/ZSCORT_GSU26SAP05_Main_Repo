@EndUserText.label: 'VH — Object Name (theo ObjectType, Z*/Y*, max 100)'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_SCORT_VH_QUERY'
@ObjectModel.resultSet.sizeCategory: #XS
define custom entity ZC_SCORT_VH_OBJ_NAME
{
      @EndUserText.label: 'Object Type'
      @UI.hidden : true
  key ObjectType : trobjtype;

      @EndUserText.label: 'Object Name'
      @UI.lineItem:[{ position: 10 }]
  key ObjectName : trobj_name;

      @EndUserText.label: 'Package'
      @UI.lineItem:[{ position: 20 }]
      Devclass   : devclass;

      @EndUserText.label: 'Author'
      @UI.lineItem:[{ position: 30 }]
      Author     : as4user;
}
