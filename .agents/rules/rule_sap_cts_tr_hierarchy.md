---
description: SAP CTS Object Hierarchy, SE09 TR Tree Parity, and Object Search Standards
---

# SAP CTS & Transport Request Tree Standards

## 1. Object Search & DDIC Source Resolution
1. **Function Module Storage (`TADIR` vs `ENLFDIR`):**
   - Individual Function Modules (`FUNC`) do NOT exist in `TADIR`. `TADIR` only stores Function Groups (`R3TR FUGR`).
   - Any query or Value Help searching for `FUNC` must query `ENLFDIR` joined with `TADIR` (`ON tadir~object = 'FUGR' AND tadir~obj_name = enlfdir~area`) to obtain Package (`devclass`) and Author.
2. **Active Object Deletion Flag (`DELFLAG`):**
   - Always filter `( delflag IS NULL OR delflag = ' ' OR delflag = '' )` when selecting from `TADIR`.

## 2. SE09 Transport Request Tree Parity
1. **Class Methods (`LIMU METH`):**
   - Place parent Class Name in `ObjName` (Column 1).
   - Place Method Name in `Description` (Column 4).
   - Group under the folder `Method (ABAP Objects)`.
   - UI actions (`Compare`, `View Source`) on method nodes must automatically target the parent `CLAS` object.
2. **Function Group Includes (`LZ...UXX`, `LZ...TOP`, `LZ...U01`):**
   - Resolve include name to the parent Function Group (`area`).
   - Classify under `fold_type = 'FUNC'` (Function Module).
   - Label Description as `Function Group Include (<FUGR>)`.
   - Route to Program source reader (`PROG`).
3. **Audit Comment Entries (`Comment Entry: Released` / `RELE`):**
   - Parse raw audit string `<Task> <Date> <Time> <User>`.
   - Assign Task to `ObjName`, User to `Owner`, and format Date/Time as `Released: YYYY-MM-DD HH:MM:SS` in `Description`.
4. **Header Folder Row Cleanliness:**
   - Always set `description = ''` on parent folder nodes (Level 1, Level 2) to eliminate cluttered duplicate text.
5. **NodeId Uniqueness:**
   - Every node in the hierarchy must have a strictly unique `NodeId` by concatenating `Request`, `Task`, `ObjType`, `ObjName`, and `iv_suffix`.

## 3. UI5 TR Tree State Persistence & Metadata Completeness
1. **Parent TR State Preservation (No Dummy TR Resets):**
   - Closing an object comparison dialog or clearing object-level sub-filters must NEVER reset the root Transport Request selection to dummy/fallback values.
   - Controllers must cache active parent TR IDs in the view state model or route parameters and restore previous view state upon closing child dialogs.
2. **Full Metadata Completeness for Tree Objects:**
   - All development object nodes under TR tasks must reliably populate Package (`devclass`), Responsible Person (`author`), and Creation Date (`as4date`) from `TADIR` / `E070`.
   - Ensure consistency between tree table columns and object metadata inspection dialogs so no fields appear blank in list view.
