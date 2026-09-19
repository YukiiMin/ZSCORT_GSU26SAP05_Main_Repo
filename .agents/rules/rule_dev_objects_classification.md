---
description: Classification standards for SAP Development Objects vs GUI-only vs Composite Form Objects
---

# SAP Development Objects Classification & UX Standards

## 1. Whitelist of 22 Core Development Objects
Only the following 22 development object types are recognized as primary Development Objects in SCORT:
- **Code & OO:** `CLAS`, `INTF`, `PROG`, `FUGR`, `FUNC`
- **Dictionary:** `TABL`, `VIEW`, `DTEL`, `DOMA`, `TTYP`
- **CDS & RAP:** `DDLS`, `DCLS`, `DDLX`, `BDEF`, `SRVD`
- **Structured Composite:** `MSAG`, `DEVC`
- **GUI-only:** `TRAN`, `NROB`, `WAPA`, `SSFO`, `SHLP`

Internal metadata / registration objects (e.g. `APIS`, `IWMO`, `IWSG`, `IWVB`, `IWOM`, `IWPR`, `SICF`, `OA2S`, `STOB`, `W3HT`) must be excluded from Search filters, Value Helps, and Matrix comparison to prevent user clutter.

## 2. Handling GUI-Only Objects (`TRAN`, `NROB`, `WAPA`, `SSFO`, `SHLP`)
1. **Backend Source Reader (`ZCL_SCORT_L_READER`):**
   - Mark `message = 'NOT_SUPPORTED'` and return an empty source string (`rs_source-text = ''`).
2. **Frontend ViewSource Dialog:**
   - Default tab selection to `Metadata`.
   - In the Source Code tab, display an `IllustratedMessage` informing the user that the object must be maintained in SAP GUI / ADT.
3. **Compare View:**
   - Display a warning status badge `NOT_SUPPORTED` and an informational banner directing the user to SAP GUI / ADT.

## 3. Structured ADT Form Objects (`MSAG`, `DEVC`, `DOMA`, `DTEL`)
1. Provide parsed structured views via `AdtFormParser.js` mimicking SAP ADT Eclipse tabs.
2. Default tab in ViewSource dialog to `adtForm`.
3. In Compare view, set `compareMode = 'form'` and render side-by-side ADT form comparisons.

## 4. ABAP Class (`CLAS`) Versioning & ADT Parity Standards
1. **Source Model**: Adhere 100% to ADT 5-component architecture (`CP` Global Class, `CCDEF` Local Definitions, `CCIMP` Local Implementations, `CCAU` Test Classes, `CCMAC` Macros).
2. **Global Class (`CP`) Resolution**: Query `VRSD` under `OBJTYPE = 'CLAS'` using the snapshot version. Use `SVRS_GET_VERSION` and `reconstruct_clas_source` (`CPUB` Public, `CPRO` Protected, `CPRI` Private, `METH` Methods) to construct the complete ADT-compliant source code. The `=CP` `REPS` include only contains 28 lines of include statements and must never be treated as the global class source.
3. **Sub-Includes Resolution**: Sub-components (`CCDEF`, `CCIMP`, `CCAU`, `CCMAC`) are retrieved under `OBJTYPE = 'REPS'` using `cl_oo_classname_service=>get_<include>_name( class_name )`.

