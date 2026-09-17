---
description: UI5 Controller Coding Standards & UI5Plugin Linter Compliance
---

# UI5 Controller & Linter Compliance Standards

## 1. Zero Tolerance for WrongParametersLinter Errors
1. **Accurate Parameter Passing:** When invoking methods defined in `BaseController` (such as `_getMonacoLang(sObjType)` or `_renderCodeHost(sCode, sObjType)`), child controllers MUST explicitly supply all expected parameters (e.g. `this._getMonacoLang(this._sType)`).
2. **JSDoc Optional Parameter Syntax:** If a parameter is optional, it MUST be enclosed in square brackets in JSDoc:
   ```javascript
   /**
    * Get Monaco language identifier for a given object type.
    * @param {string} [sObjType] Optional Development Object Type (e.g. 'CLAS', 'TABL', 'DDLS')
    * @returns {string} Monaco language ('abap' or 'sql')
    */
   _getMonacoLang: function (sObjType) { ... }
   ```
3. **No Signature Divergence:** Child controllers must never override base methods with differing parameter counts or visibility modifiers.
4. **Dialog Open Signatures:** Ensure caller invocations match the exact signature:
   `_openSourceDialog: function (sObjType, sObjName, sServerType, oMetaData)`

## 2. Multi-Service OData V4 URI Routing & Strict Service Partitioning
1. **Explicit Service Accessors:** In applications consuming multiple OData V4 Service Definitions (`mainService`, `objService`, `trService`), controllers MUST NEVER rely on an ambiguous single `_serviceUri()` fallback.
2. **Dedicated Helpers in `BaseController`:** Define explicit helper accessors for each service entry in `manifest.json`:
   - `_mainServiceUri()`: For comparison and versioning entities (`Compare`, `Version`, `TrCmp`, `ObjectSource`).
   - `_objServiceUri()`: For object catalog and active source entities (`LocalObjects`, `TargetObjects`, `SourceCodeView`, `CompareMatrix`).
   - `_trServiceUri()`: For transport tree navigation and search entities (`TrTree`, `TrSearch`, `TrObjectSearch`).
3. **No Private Member Overrides (`WrongOverrideLinter`):** Subclasses MUST NOT override private methods (`_serviceUri`, `_mainServiceUri`, `_objServiceUri`, `_trServiceUri`, etc.) defined in `BaseController` to prevent `WrongOverrideLinter` violations.

## 3. Strict Version Snapshot Fidelity (No Silent Fallbacks)
1. **No Silent Active Fallback:** When a specific version identifier (e.g. `VersionNo eq '00003'` or a version mapped to a Released TR) is requested, the system MUST NOT silently fall back to `fetchActive()` on error or empty results.
2. **Explicit User Feedback:** Any missing or unreadable historical snapshot must explicitly report the failure state (e.g., `Version 00003 not found or unreadable`) so users are never misled by active TADIR code being shown as historical code.
3. **Header Identification Invariant:** Any dialog or page rendering source code MUST include the active/version identifier in both the Dialog Title and Header Status Badge (e.g., `Program: <NAME> — Version: 00003`).

## 4. fetchJson Response Invariant & OData Filter URL Encoding

1. **fetchJson luôn trả về array:** `ValueHelp.fetchJson(sUrl)` always resolves to an array (`oJson.value || []`), even for single-entity OData calls. Consumer code MUST treat the response as array — never as a plain object.
2. **Custom RAP Entity read-by-key không hỗ trợ single-object response:** Entities backed by `IF_RAP_QUERY_PROVIDER` (ZCE_* custom entities) forward all calls — including read-by-key — through the collection `select` method. Always use `$filter=Field eq 'value'` instead of `EntitySet('KEY')`, then pick the correct node from the result array:
   ```javascript
   var sUrl = this._trServiceUri() + "TrTree?$filter=Trkorr eq '" + sSafe + "'&$top=50";
   ValueHelp.fetchJson(sUrl).then(function(aData) {
     var oTr = aData.find(function(n) { return n.NodeType === "TR" || n.TreeLevel === 0; }) || aData[0];
     if (!oTr) { return; }
     oM.setProperty("/owner", oTr.Owner || "");
   });
   ```
3. **KHÔNG dùng `encodeURIComponent()` cho OData `$filter` string:** Encoding sẽ chuyển dấu `'` thành `%27` và `=` thành `%3D`, phá vỡ OData filter syntax. Chỉ escape OData string literal bằng `replace(/'/g, "''")`:
   ```javascript
   // CORRECT:
   var sSafe = String(sTrkorr).replace(/'/g, "''");
   var sUrl = uri + "TrTree?$filter=Trkorr eq '" + sSafe + "'";

   // INCORRECT — breaks OData filter:
   var sUrl = uri + "TrTree?$filter=" + encodeURIComponent("Trkorr eq '" + sSafe + "'");
   ```
4. **JSONModel initial state completeness:** Tất cả properties được bind trong View XML (`{detail>/activeTasks}`, `{detail>/parentObjectsCount}`, `{detail>/isUnreleased}`, v.v.) phải được khai báo trong `new JSONModel({...})` tại `onInit` để tránh binding resolve thành `undefined` và tab count/badge không hiển thị.

