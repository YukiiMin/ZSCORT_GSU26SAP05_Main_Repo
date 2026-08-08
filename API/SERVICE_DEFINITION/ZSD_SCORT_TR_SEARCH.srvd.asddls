@EndUserText.label: 'SCORT: Service Definition - TR Search (Tree + Flat List)'
/*
  Exposes:
  - ZC_SCORT_TR_TREE       : TR Request/Task/Object Hierarchy Tree (Mode 1)
  - ZC_SCORT_TR_OBJ_SEARCH : Objects in TR Flat List (Mode 2)
*/
define service ZSD_SCORT_TR_SEARCH {
  expose ZCE_SCORT_TR_TREE      as TrTree;
  expose ZCR_SCORT_TR_OBJ_SEARCH as TrObjectSearch;

  /* Value Helps */
  expose ZC_SCORT_VH_TRKORR         as VHTrkorr;
  expose ZC_SCORT_VH_OBJ_TYPE       as VHObjType;
  expose ZC_SCORT_VH_OBJ_NAME       as VHObjName;
  expose ZC_SCORT_VH_SERVER_ID      as VHServerId;
  expose ZC_SCORT_VH_SERVER_TYPE    as VHServerType;
  expose ZC_SCORT_VH_COMPARE_MODE   as VHCompareMode;
  expose ZC_SCORT_VH_COMPARE_STATUS as VHCompareStatus;
}
