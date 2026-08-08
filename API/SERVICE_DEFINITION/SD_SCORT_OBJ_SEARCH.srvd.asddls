@EndUserText.label: 'SCORT: Service Definition - Object Search (Local, Target, Compare)'
/*
  Exposes:
  - ZCR_SCORT_OBJ_L : Search & Filter Local Objects
  - ZCR_SCORT_OBJ_T : Search & Filter Target Objects
  - ZCR_SCORT_OBJ_M : Compare Matrix with checkDiff
  - ZCR_SCORT_OBJ_SRC : Source Code & Metadata Viewer (Custom Entity)
*/
define service SD_SCORT_OBJ_SEARCH {
  expose ZCR_SCORT_OBJ_L   as LocalObjects;
  expose ZCR_SCORT_OBJ_T   as TargetObjects;
  expose ZCR_SCORT_OBJ_M   as CompareMatrix;
  expose ZCR_SCORT_OBJ_SRC as SourceCodeView;
}
