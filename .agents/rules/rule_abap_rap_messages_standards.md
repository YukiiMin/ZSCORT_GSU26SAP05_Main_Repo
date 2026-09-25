---
description: Official SAP ABAP Cloud & RAP standards for Message Handling, Syntax Templates, and DDIC Type Compatibility
---

# SAP ABAP RAP Message & Syntax Standards

When writing or refactoring SAP ABAP, RAP entities, and DDIC integration code, you MUST strictly adhere to official SAP standards and keyword documentation.

## 1. Message Handling in SAP RAP
1. **No Ad-Hoc JSON Utility Classes:** NEVER build custom helper classes to format JSON success/error responses for SAP backend services.
2. **Zero Hardcoded Message Strings (Strict i18n Invariant):**
   - NEVER return hardcoded string literals (e.g. `'Object type not supported'`, `'Chưa có version Target'`) in backend queries, actions, or services.
   - ALL user-facing messages, comparison statuses, and error texts MUST be registered in T100 Message Class (`ZCM_SCORT.msag.xml`) and mapped to constants in `ZCM_SCORT.clas.abap`.
   - Resolve messages dynamically via `zcm_scort=>get_text_by_key( is_t100_key = ... )` to ensure native translation support (`sy-langu`).
3. **T100 Message Class (`MSAG`):**
   - Store under `DB_CORE/TEXTS/<NAME>.msag.xml`.
   - Use numbered messages (001, 002, ...) with placeholders (`&1` - `&4`).
4. **RAP Message Class (`CLAS`):**
   - Prefix: `ZCM_<COMPONENT>` (e.g. `ZCM_SCORT`).
   - Base Class: `cx_static_check`.
   - Required Interfaces: `if_t100_message`, `if_t100_dyn_msg`, `if_abap_behv_message`.
   - Define message key constants containing `msgid`, `msgno`, `attr1`, `attr2`, `attr3`, `attr4`.
5. **Behavior Pool Message Dispatch:**
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
6. **MSAG Companion Plain-Text / Markdown Catalog:**
   - Whenever creating or updating a SAP Message Class (`<NAME>.msag.xml`), ALWAYS create and maintain a companion catalog `<NAME>.md` (and `<NAME>.txt`) in the same folder (`DB_CORE/TEXTS/`).
   - The companion file MUST include:
     - **Quick Copy Section (TSV)**: Raw tab-separated lines (`<MSGNR>\t<TEXT>`) for direct copy-paste into SAP GUI SE91 / ADT Table Control.
     - **Exact SAP Placeholders**: Use unescaped `&1`, `&2`, `&3`, `&4` (never `&amp;`).
     - **Concise Variants (<= 39 chars)**: Provide compact variants when message texts exceed 39 characters for compact UI/dialog views.
     - **Detailed Table**: Number, Short Text, Character Count, and Parameter Meanings.
7. **T100 Message Text Length Constraint (<= 72 Chars):**
   - In SAP SE91 and table `T100`, message short text has a strict maximum length of 73 characters (`CHAR73`).
   - Every message definition MUST NOT exceed 72 characters when placeholders `&1`-`&4` are substituted to prevent unexpected truncation across SAP GUI, RFC, and OData error responses.

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
2. **Zero Vietnamese in Source Code:** Never write Vietnamese comments, characters, or text literals inside ABAP backend source files. All user-facing texts must reside in `MSAG` or UI `i18n.properties`.
3. **No Numbered Steps or Phase Labels:** NEVER include numbered comments (e.g., `" 1. Extract...`, `" 2. Fetch...`, `" Step 1...`, `" B1...`).
4. **No Decorative Banners or ASCII Boxes:** Do NOT use comment boxes (`*"*---------------------*`) or divider lines.
5. **No Explanatory Inline Comments:** Do NOT add line-by-line comments describing obvious operations (e.g., `" Parse request JSON`, `" Handle CORS`). Code must be clean, modular, and self-documenting.
6. **Architectural Comments Only:** Comments are permissible ONLY when documenting architectural non-obvious workarounds or SAP kernel compatibility constraints.

## 5. Kernel Deep Structures & Dynamic Component Parsing
1. **Release-Dependent Structures:** When interfacing with deep SAP kernel structures (such as `SVRS2_VERSIONABLE_OBJECT` in Version Management):
   - Never statically access release-dependent sub-fields that may vary across SAP releases.
   - Use dynamic component lookup (`ASSIGN COMPONENT <field> OF STRUCTURE ...`) with fallback candidates (`ABAPTEXT`, `ABAPTXT`, `SOURCE`, `TEXT`, `LINES`, `DELTA`) to ensure 100% cross-release compatibility and eliminate static syntax check failures.

## 6. Backend Pure Business Data vs. Frontend Presentation & Localization
1. **Raw Technical Facts SSOT:**
   - Khi Backend SAP không cung cấp sẵn văn bản tài liệu chuẩn kèm ngôn ngữ bản địa (`sy-langu`) từ các bảng hệ thống (như `DOKTL`), Backend chỉ chịu trách nhiệm trả về **dữ liệu nghiệp vụ / kỹ thuật thô (Raw Business Attributes)**: `ObjectType`, `ObjectName`, `Task`, `User`, `Status`, `ErrorCode`.
2. **Prohibition of Multi-Sentence Prose in ABAP:**
   - Tuyệt đối KHÔNG tự sáng tác, nối chuỗi văn bản diễn giải dài dòng, danh sách checklist hướng dẫn hoặc câu văn chẩn đoán UI bằng ABAP String Template (`|...|`).
3. **Frontend Presentation Ownership:**
   - Toàn bộ việc biên soạn câu chữ, định dạng thẻ Card, phân tích chẩn đoán, hiển thị hướng dẫn giải quyết (Resolution steps) và thông báo (`MessageToast`, `MessageBox`) PHẢI do **Frontend UI5 đảm nhiệm thông qua `i18n.properties`** có tham số hóa (`{0}`, `{1}`, `{2}`).

