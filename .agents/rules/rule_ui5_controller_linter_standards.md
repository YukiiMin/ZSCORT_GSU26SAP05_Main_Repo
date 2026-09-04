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
