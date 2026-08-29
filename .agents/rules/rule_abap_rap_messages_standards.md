---
description: Official SAP ABAP Cloud & RAP standards for Message Handling, Syntax Templates, and DDIC Type Compatibility
---

# SAP ABAP RAP Message & Syntax Standards

When writing or refactoring SAP ABAP, RAP entities, and DDIC integration code, you MUST strictly adhere to official SAP standards and keyword documentation.

## 1. Message Handling in SAP RAP
1. **No Ad-Hoc JSON Utility Classes:** NEVER build custom helper classes to format JSON success/error responses for SAP backend services.
2. **T100 Message Class (`MSAG`):**
   - Store under `DB_CORE/TEXTS/<NAME>.msag.xml`.
   - Use numbered messages (001, 002, ...) with placeholders (`&1` - `&4`).
3. **RAP Message Class (`CLAS`):**
   - Prefix: `ZCM_<COMPONENT>` (e.g. `ZCM_SCORT`).
   - Base Class: `cx_static_check`.
   - Required Interfaces: `if_t100_message`, `if_t100_dyn_msg`, `if_abap_behv_message`.
   - Define message key constants containing `msgid`, `msgno`, `attr1`, `attr2`, `attr3`, `attr4`.
4. **Behavior Pool Message Dispatch:**
   - Append to `reported-<entity>` using:
     ```abap
     APPEND VALUE #(
       %tky = <key>-%tky
       %msg = NEW zcm_scort(
                severity = if_abap_behv_message=>severity-error
                textid   = zcm_scort=>tr_not_found
                attr1    = CONV #( <key>-objectname ) )
     ) TO reported-<entity>.
     ```

## 2. ABAP String Templates, Literals & VALUE Constructor Invariants
1. **No Multiline Templates:** NEVER span string templates `|...|` across multiple editor lines.
2. **Template Delimiters:** Never use raw `|` inside a string template; escape with `\|` or use character literals `'...'` with `&&`.
3. **String Literals vs Character Literals:**
   - Single quotes `'...'` create fixed-length `c` types.
   - Backticks `` `...` `` create dynamic `string` types.
   - In `VALUE #( ... )` constructor expressions for `table of string`, always use backtick literals `` `TEXT` `` or direct assignments to avoid `incompatible row type` compiler errors.
4. **Newlines:** Use `cl_abap_char_utilities=>newline` and `cl_abap_char_utilities=>cr_lf` for newline formatting.
5. **Double Quotes:** In ABAP, `" ...` denotes a comment. Never use double quotes for string literals.

## 3. DDIC & Function Module Types
1. **BTP Destinations:** Always use `TYPE rfcdest` for destination parameters in `cl_http_client=>create_by_destination`.
2. **Object Types and Names:** Use `TYPE csequence` in method signatures to accept both fixed-length DDIC fields (`TROBJTYPE`, `SOBJ_NAME`) and `STRING` without type conflicts.

## 4. ABAP Commenting Guidelines (English & Clean Code)
1. **English Only:** Use ONLY English for all comments across ABAP backend code, DDIC objects, and RAP definitions.
2. **Introductory / High-Level Only:** Only add high-level introductory comments, class/method headers, or ABAP Doc comments (`"! ...`).
3. **No Explanatory Inline Comments:** Do NOT add line-by-line explanatory comments describing what standard code is doing. Code must remain clean and self-explanatory.
4. **No Vietnamese in Source Code:** Never write Vietnamese comments or text inside ABAP backend source files. Multi-language texts must strictly go to Message Classes (`MSAG`) or UI i18n properties.

## 5. Kernel Deep Structures & Dynamic Component Parsing
1. **Release-Dependent Structures:** When interfacing with deep SAP kernel structures (such as `SVRS2_VERSIONABLE_OBJECT` in Version Management):
   - Never statically access release-dependent sub-fields that may vary across SAP releases.
   - Use dynamic component lookup (`ASSIGN COMPONENT <field> OF STRUCTURE ...`) with fallback candidates (`ABAPTEXT`, `ABAPTXT`, `SOURCE`, `TEXT`, `LINES`, `DELTA`) to ensure 100% cross-release compatibility and eliminate static syntax check failures.
