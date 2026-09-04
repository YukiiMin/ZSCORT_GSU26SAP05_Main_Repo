@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'SCORT: Search & Filter Objects in Local Server'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #XXL,
    dataClass: #MIXED
}
define root view entity ZIR_SCORT_OBJ_L
  as select from tadir
  association [0..1] to ZCR_SCORT_OBJ_SRC as _SourceCode
    on  _SourceCode.ObjectType  = $projection.ObjectType
    and _SourceCode.ObjectName  = $projection.ObjectName
    and _SourceCode.ServerType  = $projection.ServerType
{
  key pgmid       as Pgmid,
  key object      as ObjectType,
  key obj_name    as ObjectName,

      devclass    as PackageName,
      author      as PersonResponsible,
      created_on as CreatedOn,

      cast( 'L' as abap.char(1) ) as ServerType,

      /* Navigation */
      _SourceCode
}
where pgmid = 'R3TR'
  and ( delflag is null or delflag = ' ' or delflag = '' )
  and ( object = 'PROG' or object = 'CLAS' or object = 'INTF' or object = 'FUGR'
     or object = 'DDLS' or object = 'BDEF' or object = 'DCLS' or object = 'DDLX'
     or object = 'SRVD' or object = 'TABL' or object = 'DTEL' or object = 'DOMA'
     or object = 'TTYP' or object = 'VIEW' or object = 'MSAG' or object = 'DEVC'
     or object = 'TRAN' or object = 'NROB' or object = 'WAPA' or object = 'SSFO'
     or object = 'SHLP' )

union all

select from enlfdir as Func
  inner join tadir as Fgrp
    on  Fgrp.pgmid    = 'R3TR'
    and Fgrp.object   = 'FUGR'
    and Fgrp.obj_name = Func.area
    and ( Fgrp.delflag is null or Fgrp.delflag = ' ' or Fgrp.delflag = '' )
  association [0..1] to ZCR_SCORT_OBJ_SRC as _SourceCode
    on  _SourceCode.ObjectType  = $projection.ObjectType
    and _SourceCode.ObjectName  = $projection.ObjectName
    and _SourceCode.ServerType  = $projection.ServerType
{
  key cast( 'LIMU' as pgmid )            as Pgmid,
  key cast( 'FUNC' as trobjtype )        as ObjectType,
  key cast( Func.funcname as sobj_name ) as ObjectName,

      Fgrp.devclass                      as PackageName,
      Fgrp.author                        as PersonResponsible,
      Fgrp.created_on                    as CreatedOn,

      cast( 'L' as abap.char(1) )        as ServerType,

      /* Association Mapping */
      _SourceCode
}
where Func.active = 'X'
