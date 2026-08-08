@EndUserText.label: 'SCORT REQ3 — Code Compare Service (read-only)'
define service ZSD_SCORT_COMPARE {
  // BƯỚC 1 — Cột Master
  expose ZCR_SCORT_TR_CMP      as TrCmp;

  // BƯỚC 2 — Cột Detail (Monaco)
  expose ZCR_SCORT_COMPARE     as Compare;

  // TH2 — Version list
  expose ZCR_SCORT_OBJ_VERSION as Version;

  // Optional — preview 1 phía
  expose ZCR_SCORT_OBJ_SRC     as ObjectSource;

  // Value Helps (F4) — bắt buộc expose để @Consumption.valueHelpDefinition hoạt động
  expose ZC_SCORT_VH_TRKORR          as VHTrkorr;
  expose ZC_SCORT_VH_OBJ_TYPE        as VHObjType;
  expose ZC_SCORT_VH_OBJ_NAME        as VHObjName;
  expose ZC_SCORT_VH_COMPARE_MODE    as VHCompareMode;
  expose ZC_SCORT_VH_COMPARE_STATUS  as VHCompareStatus;
  expose ZC_SCORT_VH_SERVER_TYPE     as VHServerType;
  expose ZC_SCORT_VH_SERVER_ID       as VHServerId;
}
