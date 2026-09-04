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
