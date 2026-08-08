@EndUserText.label: 'SCORT: Service Definition - Object Search (Local, Target, Compare)'
/*
  Exposes:
  - ZCR_SCORT_OBJ_L : Search & Filter Local Objects
  - ZCR_SCORT_OBJ_T : Search & Filter Target Objects
  - ZCR_SCORT_OBJ_M : Compare Matrix with checkDiff
  - ZCR_SCORT_OBJ_SRC : Source Code & Metadata Viewer (Custom Entity)
*/
define service ZSD_SCORT_OBJ_SEARCH {
  expose ZCR_SCORT_OBJ_L   as LocalObjects;
  expose ZCR_SCORT_OBJ_T   as TargetObjects;
  expose ZCR_SCORT_OBJ_M   as CompareMatrix;
  expose ZCR_SCORT_OBJ_SRC as SourceCodeView;

  /* Value Helps */
  expose ZC_SCORT_VH_TRKORR         as VHTrkorr;
  expose ZC_SCORT_VH_OBJ_TYPE       as VHObjType;
  expose ZC_SCORT_VH_OBJ_NAME       as VHObjName;
  expose ZC_SCORT_VH_COMPARE_MODE   as VHCompareMode;
  expose ZC_SCORT_VH_COMPARE_STATUS as VHCompareStatus;
  expose ZC_SCORT_VH_SERVER_TYPE    as VHServerType;
  expose ZC_SCORT_VH_SERVER_ID      as VHServerId;
  expose ZC_SCORT_VH_USER           as VHUser;
  expose ZC_SCORT_VH_PACKAGE        as VHPackage;
}
