---
description: Modern Native SAPUI5 Multi-Language (i18n) Implementation Standard
---

# Modern Native SAPUI5 Multi-Language (i18n) Standards

When building or updating multi-language support in SAPUI5 Fiori applications, you MUST follow these standards.

## 1. Context & Motivation
SAPUI5 version 1.118+ deprecated legacy APIs like `sap.ui.getCore().getConfiguration().setLanguage()`.
Additionally, standard `.properties` files in SAP tooling require ASCII encoding, meaning accented/non-ASCII characters (e.g., Vietnamese, Japanese, Chinese, German umlauts) must be escaped (`\uXXXX`) to prevent encoding corruption.

## 2. Best Practices & Rules

### A. Hot-Switching & State Persistence (UI5 1.118+)
- **Module:** Use `sap/base/i18n/Localization` (`Localization.setLanguage(sLang)`).
- **Persistence:** Save selected language in `localStorage` (`scort_lang`) and initialize during `Component.js#init`.
- **Dynamic Controller Texts:** Always resolve dynamic messages via ResourceBundle:
  ```javascript
  var oBundle = this.getView().getModel("i18n").getResourceBundle();
  var sMsg = oBundle.getText("key_name");
  ```

### B. File Formatting & Unicode Escape Encoding
- All `.properties` files must store accented/non-ASCII characters in `\uXXXX` Unicode Escape format (e.g. `T\u00ecm ki\u1ebfm` for `Tìm kiếm`).
- **Strict 4-Hex Digits:** Every `\u` escape MUST have exactly 4 hexadecimal characters. Sequences like `\u305ず` (3 hex digits) cause an unrecoverable UI5 boot failure (`Error: Incomplete Unicode Escape '\u305'`).
- File naming structure:
  - `i18n.properties` (Default / Fallback)
  - `i18n_en.properties` (English)
  - `i18n_vi.properties` (Vietnamese)
  - `i18n_de.properties` (German)
  - `i18n_ja.properties` (Japanese)
  - `i18n_zh.properties` (Chinese)

### C. UI Component Integration
- Place a `sap.m.SegmentedButton` in the `ShellBar` / Header toolbar bound to `appView>/currentLanguage`.
- Trigger `Localization.setLanguage(sKey)` on `selectionChange` to dynamically re-bind all `{i18n>...}` texts across the app with zero latency and no page reload.
