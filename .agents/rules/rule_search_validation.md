---
description: Input Validation and Table Optimization Rules for Search Screens
---

# Search Input Validation & Table Optimization

When implementing or modifying search screens in Freestyle SAPUI5, you MUST strictly follow these search input constraints and table optimization patterns.

## 1. Context & Motivation
Allowing unconstrained/empty queries on large SAP tables (such as `TADIR`, `E070`, `E071`, or TR metadata tables) can cause full table scans, backend memory exhaustion, and HTTP timeout errors.

## 2. Input Constraints (Validation)
- **Object Search (`ObjSearch.controller.js`)**: Before triggering a search, ALWAYS verify that the user has entered at least one of the following criteria: `Object Name`, `Package`, or `Person Responsible`. If all three are empty, block the search and display a `sap.m.MessageBox.warning`.
- **TR Search (`TrSearch.controller.js`)**: Before triggering a search, ALWAYS verify that the user has entered at least `Transport Request` or `Owner`. If both are empty, block the search and display a `sap.m.MessageBox.warning`.

## 3. Table Features
- Use `sap.ui.table.Table` with `enableGrouping="true"` so users can dynamically group flat lists (e.g., Owner -> Package) instead of needing a complex TreeTable for simple hierarchical data.
