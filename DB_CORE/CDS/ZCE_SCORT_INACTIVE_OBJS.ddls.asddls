@EndUserText.label: 'SCORT: Inactive Objects Validation'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_SCORT_INACTIVE_QUERY'
@Metadata.allowExtensions: true
define root custom entity ZCE_SCORT_INACTIVE_OBJS
{
  key Trkorr       : trkorr;
  key ObjectName   : sobj_name;
  key ObjectType   : trobjtype;

      ParentTrkorr : strkorr;
      Uname        : uname;
      Status       : abap.char(20);
      ShortText    : as4text;
}
