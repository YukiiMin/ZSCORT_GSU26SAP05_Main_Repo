sap.ui.define([], function () {
  "use strict";

  /**
   * DiffHost — wraps monaco.editor.createDiffEditor
   * original = TargetCode (destination snapshot, left)
   * modified = SourceCode (origin Active, right)
   *
   * Loads Monaco from CDN (jsDelivr) for demo simplicity.
   * For FLP / CSP: switch to npm self-host — see README.
   */
  function DiffHost(oDomElement) {
    this._el = oDomElement;
    this._editor = null;
    this._original = null;
    this._modified = null;
    this._ready = this._loadMonaco();
  }

  DiffHost.prototype._loadMonaco = function () {
    var that = this;
    if (window.monaco && window.monaco.editor) {
      return Promise.resolve(window.monaco);
    }
    return new Promise(function (resolve, reject) {
      if (window.__monacoLoading) {
        window.__monacoLoading.then(resolve).catch(reject);
        return;
      }
      window.__monacoLoading = new Promise(function (res, rej) {
        var sBase = "https://cdn.jsdelivr.net/npm/monaco-editor@0.52.0/min/vs";
        var oScript = document.createElement("script");
        oScript.src = sBase + "/loader.js";
        oScript.onload = function () {
          window.require.config({ paths: { vs: sBase } });
          window.require(["vs/editor/editor.main"], function () {
            res(window.monaco);
          }, rej);
        };
        oScript.onerror = rej;
        document.head.appendChild(oScript);
      });
      window.__monacoLoading.then(resolve).catch(reject);
    }).then(function (monaco) {
      that._monaco = monaco;
      return monaco;
    });
  };

  DiffHost.prototype.setModel = function (mOpts) {
    var that = this;
    var sOriginal = mOpts.original || "";
    var sModified = mOpts.modified || "";
    var sLang = mOpts.language || "plaintext";

    return this._ready.then(function (monaco) {
      if (!that._editor) {
        that._el.innerHTML = "";
        that._editor = monaco.editor.createDiffEditor(that._el, {
          readOnly: true,
          renderSideBySide: true,
          automaticLayout: true,
          originalEditable: false,
          theme: "vs",
          minimap: { enabled: true },
          scrollBeyondLastLine: false
        });
      }

      if (that._original) {
        that._original.dispose();
      }
      if (that._modified) {
        that._modified.dispose();
      }

      that._original = monaco.editor.createModel(sOriginal, sLang);
      that._modified = monaco.editor.createModel(sModified, sLang);
      that._editor.setModel({
        original: that._original,
        modified: that._modified
      });
    }).catch(function (e) {
      that._el.innerHTML =
        "<pre style='padding:1rem;white-space:pre-wrap;font-family:monospace'>" +
        "Monaco failed to load (CDN/CSP?).\n" +
        "--- TARGET (left) ---\n" + (sOriginal || "(empty)") +
        "\n--- SOURCE (right) ---\n" + (sModified || "(empty)") +
        "\n\nError: " + e +
        "</pre>";
    });
  };

  DiffHost.prototype.dispose = function () {
    if (this._original) {
      this._original.dispose();
    }
    if (this._modified) {
      this._modified.dispose();
    }
    if (this._editor) {
      this._editor.dispose();
    }
    this._editor = null;
  };

  return DiffHost;
});
