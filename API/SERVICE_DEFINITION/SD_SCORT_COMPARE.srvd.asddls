@EndUserText.label: 'SCORT — Code Compare Service (read-only)'
define service SD_SCORT_COMPARE {
  // Master
  expose ZCR_SCORT_TR_CMP      as TrCmp;

  // Detail (Monaco)
  expose ZCR_SCORT_COMPARE     as Compare;

  // Version list
  expose ZCR_SCORT_OBJ_VERSION as Version;

  // Optional — one-side preview
  expose ZCR_SCORT_OBJ_SRC     as ObjectSource;

  // Value Helps
  expose ZC_SCORT_VH_TRKORR          as VHTrkorr;
  expose ZC_SCORT_VH_OBJ_TYPE        as VHObjType;
  expose ZC_SCORT_VH_OBJ_NAME        as VHObjName;
  expose ZC_SCORT_VH_COMPARE_MODE    as VHCompareMode;
  expose ZC_SCORT_VH_COMPARE_STATUS  as VHCompareStatus;
  expose ZC_SCORT_VH_SERVER_TYPE     as VHServerType;
  expose ZC_SCORT_VH_SERVER_ID       as VHServerId;
}
