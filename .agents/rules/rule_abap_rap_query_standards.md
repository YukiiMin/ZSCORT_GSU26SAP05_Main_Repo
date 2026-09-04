---
description: Standards for RAP Custom Entity Query Providers, Multi-Key Merge-Sort, and Memory Optimization
---

# ABAP RAP Custom Entity Query Provider Standards

When implementing Query Provider classes (`IF_RAP_QUERY_PROVIDER`) for Custom Entities (`ZCE_*`):

## 1. SADL Dump Prevention & Architectural Scope
1. **Prefer Custom Entities for Cross-System/Parameterized Views:** Avoid parameterized `UNION ALL` CDS View Entities with RAP BOs for complex comparison matrices. OData V4 string operators (`startswith`, `contains`) against parameterized union entities trigger fatal SADL dumps (`CX_SADL_DUMP_APPL_MODEL_ERROR`).
2. **Full Engine Control:** Use `ZCE_*` + `IF_RAP_QUERY_PROVIDER` to gain complete control over Open SQL push-down, memory limits, and sorting.

## 2. Multi-Key Merge-Sort (3-Key Coordinate Alignment)
1. **3-Dimensional Key:** When merging and comparing heterogeneous object collections (e.g. Local SAP Objects vs Remote Snapshot), the comparison key MUST consist of `(pgmid, objecttype, objectname)`.
2. **Sorting Both Sides:** Always execute `SORT lt_local BY pgmid objecttype objectname` and `SORT lt_target BY pgmid objecttype objectname` before entering the merge loop.
3. **Strict 3-Way Cursor Comparison:** In the two-pointer `WHILE` loop, evaluate:
   - `pgmid` first (`<`, `>`, `=`).
   - If `pgmid` is equal, evaluate `objecttype` (`<`, `>`, `=`).
   - If `objecttype` is equal, evaluate `objectname` (`<`, `>`, `=`).
   - Never skip `pgmid`; doing so causes cursor desynchronization between root (`R3TR`) and sub-objects (`LIMU`).

## 3. SQL Push-Down Filtering & Windowed Paging
1. **Push Down Before Fetching:** Extract filter ranges using `io_request->get_filter( )->get_as_ranges( )` and push them directly into the `WHERE` clauses of backend SQL queries (`tadir`, `enlfdir`, snapshot tables).
2. **Conditional Auxiliary Queries:** Only query auxiliary tables (e.g. `enlfdir` for Function Modules) when `FUNC` or `LIMU` is requested or unconstrained.
3. **Windowed Memory Paging:** Slicing (`offset` and `page_size` from `io_request->get_paging( )`) must occur strictly after sorting the final merged table to minimize memory footprint.

## 4. Dynamic UI5 Header Sorting
1. Read requested sorting from `io_request->get_sort_elements( )`.
2. Build an `abap_sortorder_tab` with uppercase field names and execute dynamic sorting: `SORT ct_data BY (lt_sort)`.

## 5. Strict ABAP Syntax Invariants in Query Logic
1. **String Offset:** Substring offset calculation MUST be stored in an integer variable first. Never write compound expressions directly inside substring offsets:
   ```abap
   " CORRECT:
   DATA(lv_off) = strlen( lv_str ) - 14.
   DATA(lv_sub) = lv_str+lv_off(14).

   " INCORRECT (Syntax Error):
   DATA(lv_sub) = lv_str+(strlen( lv_str ) - 14)(14).
   ```
2. **Types vs Data:** Internal table structure templates must be declared using `TYPES: BEGIN OF ty_...`, NOT `DATA: BEGIN OF ty_...`.
