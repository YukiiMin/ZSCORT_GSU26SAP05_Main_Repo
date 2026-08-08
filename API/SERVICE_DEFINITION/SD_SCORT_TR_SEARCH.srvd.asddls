@EndUserText.label: 'SCORT: Service Definition - TR Search (Tree + Flat List)'
/*
  Exposes:
  - ZC_SCORT_TR_TREE       : TR Request/Task/Object Hierarchy Tree (Mode 1)
  - ZC_SCORT_TR_OBJ_SEARCH : Objects in TR Flat List (Mode 2)
*/
define service SD_SCORT_TR_SEARCH {
  expose ZC_SCORT_TR_TREE       as TrTree;
  expose ZC_SCORT_TR_OBJ_SEARCH as TrObjectSearch;
}
