---
description: Strict standards for SAP CDS Entities, Projections, Behavior Definitions, and Service Definitions
---

# SAP CDS & Data Definition Standards

When writing, editing, or generating CDS Entities (`.asddls`), Projections (`.ddls.asddls`), Behavior Definitions (`.asbdef`), Metadata Extensions (`.asddlxs`), and Service Definitions (`.srvd.asddls`):

## 1. Comment Delimiters & Formatting
1. **NO Double Quotes (`"`):** NEVER use `"` as a comment in CDS or BDEF files. `"` is invalid in CDS grammar and causes compiler/SADL parser failures (`CX_SADL_DUMP_APPL_MODEL_ERROR`).
2. **ONLY Block Comments (`/* ... */`):** When comments are needed to mark sections, use ONLY English block comments `/* ... */`.
3. **No Explanatory / Line-by-Line Comments:** Do NOT explain what annotations or fields do line-by-line. The code must be clean, declarative, and self-documenting.
4. **No Vietnamese Comments:** NEVER write Vietnamese comments or annotations in any CDS, BDEF, or Service Definition files.

## 2. Projections & Annotations Cleanliness
1. Only include valid and active annotations. Do not leave commented-out experimental annotations.
2. Group annotations logically: `@UI.headerInfo`, `@UI.lineItem`, `@UI.selectionField`, `@Consumption.valueHelpDefinition`.
3. Ensure all exposed associations and action annotations (`@UI.lineItem: [{ type: #FOR_ACTION, dataAction: '...' }]`) match valid BDEF operations.

## 3. Service Definitions & Service Bindings Invariants (ZERO Comments)
1. **ZERO Comments in Service Definitions (`.srvd.asddls`):**
   - NEVER add comments of any kind (`/* ... */`, `//`, `"`) inside `define service { ... }`.
   - The file must contain strictly the service label header and entity exposure lines (`expose <ENTITY> as <ALIAS>;`).
2. **ZERO Comments in Service Bindings (`.srvb`):**
   - Bindings must remain pure metadata configurations without manual comments.

## 4. Value Help & `additionalBinding` Target Element Alignment
1. **Target Element Existence:** In `@Consumption.valueHelpDefinition: [{ entity: { name: '...', element: '...' }, additionalBinding: [...] }]`, every field referenced in `element` MUST exist as an active field/key in the target Value Help CDS entity.
2. **Never Map Ghost Fields:** If the target entity only filters by `ObjectType` and `ObjectName`, do NOT map `ServerId` or other unexposed fields. Mismatched elements generate SAP Gateway activation warnings (`Annotated element ... not equal to element in view ...`) and broken OData Value Help metadata.

## 5. TADIR Object Deletion Filtering (`DELFLAG`)
1. **Always Filter `delflag`:** When querying `tadir` in CDS Entities or ABAP queries (e.g., `ZIR_SCORT_OBJ_L`), ALWAYS add the condition:
   ```abap
   where pgmid = 'R3TR'
     and ( delflag is null or delflag = ' ' or delflag = '' )
   ```
2. **Alignment with SE80 / Eclipse ADT:** SAP marks deleted objects in `TADIR` with `DELFLAG = 'X'` instead of hard-deleting the row immediately. Filtering out `DELFLAG = 'X'` prevents phantom/deleted objects from surfacing on the UI.

## 6. Association Definitions in UNION / UNION ALL (Strict Invariant)
1. **Mandatory Association Redefinition:** In modern ABAP CDS View Entities (`define view entity`), when an association is exposed in a `UNION` or `UNION ALL`, the association **MUST be defined identically** (same target entity, cardinality, and `ON` conditions) in **EVERY** `SELECT` branch of the union.
2. **Never Omit Association in Sub-branches:** Omitting the `association [...] to ... as _Assoc on ...` declaration in subsequent `SELECT` branches and merely referencing `_Assoc` causes the SAP compiler to treat `_Assoc` as a physical table column of that branch, throwing the syntax check error: `The column _Assoc is unknown`.

## 7. SAP CTS Sub-object & Type Casting Invariants
1. **Function Module CTS Alignment (`LIMU FUNC`):** In SAP CTS, individual Function Modules are sub-objects belonging to a Function Group (`R3TR FUGR`). They must strictly be typed with `PGMID = 'LIMU'`:
   ```cds
   key cast( 'LIMU' as pgmid ) as Pgmid,
   key cast( 'FUNC' as trobjtype ) as ObjectType,
   key cast( Func.funcname as sobj_name ) as ObjectName
   ```
2. **Strict DDIC Data Element Casting:** In `UNION` branches, always use `cast( ... as <ddic_data_element> )` for literal keys to ensure 100% type uniformity across all union members.

