---
description: Patterns and rules for integrating Monaco Editor in SAPUI5 using an Iframe sandbox
---

# SAPUI5 Monaco Editor Integration (Iframe Sandbox)

When integrating Monaco Editor into a SAPUI5 application, you MUST strictly follow the Iframe Sandbox pattern.

## 1. Context & Motivation
The AMD loaders of both libraries (`require.js` for Monaco and `ui5loader` for UI5) conflict globally in the `window` scope. This causes fatal crashes (`sap.ui.ModuleSystem` errors or `monaco` being undefined). Furthermore, Monaco's internal UI can be crushed by UI5's layout engine if not wrapped correctly.

## 2. The Solution (Reusable Pattern)
To guarantee isolation and stability, Monaco MUST be loaded inside an isolated `iframe`. Communication between the UI5 controller and the editor is handled via `window.postMessage`.

### 2.1 Iframe HTML Files (`monaco_diff.html` / `monaco_code.html`)
- **Isolation:** Load Monaco's `loader.js` script natively via standard HTML script tags.
- **Config:** Set `renderSideBySideInlineBreakpoint: 0` to prevent Monaco from forcing single-column diff mode when the split-screen view is narrow.
- **Lifecycle:** Dispatch a `MONACO_READY` message to `window.parent` when the editor is initialized.
- **Communication:** Listen for `message` events from the parent window (e.g., `SET_DIFF`, `SET_CODE`) to update the models.

### 2.2 UI5 Wrapper Class (`DiffHost.js` / `CodeHost.js`)
- Expose an API identical to the original implementation (e.g., `.setModel()`, `.setSideBySide()`) but proxy the commands via `iframe.contentWindow.postMessage`.
- Return a `Promise` from `.setModel()` that resolves when the `MONACO_READY` message is received, ensuring controllers don't crash with `Cannot read properties of undefined (reading 'then')`.

### 2.3 UI5 XML View Layout
- **Rule:** NEVER use a standard `<VBox height="100%">` inside an `<IconTabFilter>` for embedding the iframe container. UI5's layout engine often collapses the height to 0px.
- **Rule:** Use a `sap.ui.layout.Splitter` for bulletproof 100% height stretching. Place the iframe container inside the Splitter and set `layoutData` to `size="auto"`.

### 2.4 Model Lifecycle & Safe Diff Navigation (Monaco v0.52+)
- **Set Before Dispose:** When updating diff models (`SET_DIFF`), always instantiate and assign the new models to `diffEditor.setModel({ original, modified })` BEFORE calling `dispose()` on previous models. This prevents `TextModel got disposed before DiffEditorWidget model got reset`.
- **Safe Diff Navigation:** Guard `monaco.editor.createDiffNavigator` with type checks. Use `diffEditor.goToDiff('next' | 'previous')` as fallback when `diffNavigator` is unavailable.
