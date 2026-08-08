@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'SCORT: Search Objects in TR Request/Task (Flat List)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #XL,
    dataClass: #MIXED
}
/*
  Flat list view — every row = 1 object assigned to a TR/Task.
*/
define root view entity ZIR_SCORT_TR_OBJ_SEARCH
  as select from e071 as Object
    inner join   e070 as Header on Header.trkorr = Object.trkorr
{
  key Object.trkorr           as Trkorr,
  key Object.pgmid            as Pgmid,
  key Object.object           as ObjectType,
  key Object.obj_name         as ObjectName,

      Header.strkorr          as ParentTrkorr,
      Header.as4user          as Owner,
      Header.as4date          as CreatedOn,
      Header.trstatus         as TrStatus,

      /* Computed: SỬ DỤNG IS NOT INITIAL THAY VÌ <> '' ĐỂ TRÁNH LỖI NULL/BLANK */
      case
        when Header.strkorr is not initial
          then Header.strkorr
        else Header.trkorr
      end                     as CurrentManagingTr,

      Object.activity         as Activity
}
/* Nếu muốn tìm kiếm cả sub-objects (như LIMU), hãy cân nhắc bỏ dòng WHERE này hoặc thêm điều kiện */
where Object.pgmid = 'R3TR'
