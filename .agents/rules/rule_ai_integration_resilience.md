---
description: Standards for Dual-Mode AI integration, SICF REST Handlers, and robust JSON payload parsing
---

# Dual-Mode AI Integration & SICF Handler Standards

## 1. Architecture: Dual-Mode Execution
- **Mode 1 (`FE_DIRECT`):** Direct client-side calls to Google Gemini using rotating API key pools for instant execution without backend configuration dependencies.
- **Mode 2 (`BE_SAP`):** HTTP POST requests sent to `/sap/bc/zscort_ai`, handled by `ZCL_SCORT_AI_HTTP_HANDLER` -> `ZCL_SCORT_AI_ASSISTANT`.

## 2. SAP SICF Endpoint Configuration Invariants
1. **Service Registration:** Create node under `/default_host/sap/bc/<service_name>` (e.g. `zscort_ai`).
2. **Handler Assignment:** Assign the handler class implementing `IF_HTTP_EXTENSION` (e.g. `ZCL_SCORT_AI_HTTP_HANDLER`) in the **Handler List** tab.
3. **Logon Data:** Maintain predefined client and service user in **Logon Data** tab to allow headless UI5 API calls without authentication popups.
4. **Activation:** Always right-click node and choose **Activate Service**.

## 3. Resilient AI JSON Normalization (`_normalizeAiResponse`)
1. **Unwrap Gemini Envelope:** Recognize `{ candidates: [ { content: { parts: [{ text: "..." }] } } ] }` returned by backend proxy and extract inner JSON text before parsing.
2. **Strip Markdown Fences:** Remove leading ```` ```json ```` and trailing ```` ``` ````.
3. **Outer Boundary Slicing:** Extract JSON strictly between first `{` and last `}`.
4. **Defensive UI Rendering:** Ensure list renderers for `findings` and `risks` handle both array of strings and array of objects gracefully to prevent blank views (`—`, `Score: N/A`) or raw JSON string dumps.
