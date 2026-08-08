sap.ui.define([], function () {
  "use strict";

  /**
   * CodeHost — wraps monaco.editor.create
   * Single file viewer for ABAP source code.
   */
  function CodeHost(oDomElement) {
    this._el = oDomElement;
    this._editor = null;
    this._model = null;
    this._ready = this._loadMonaco();
  }

  CodeHost.prototype._loadMonaco = function () {
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

  CodeHost.prototype.setValue = function (sValue, sLang) {
    var that = this;
    sValue = sValue || "";
    sLang = sLang || "abap";

    return this._ready.then(function (monaco) {
      if (!that._editor) {
        that._el.innerHTML = "";
        that._editor = monaco.editor.create(that._el, {
          readOnly: true,
          theme: "vs",
          minimap: { enabled: true },
          scrollBeyondLastLine: false
        });
      }

      if (that._model) {
        that._model.dispose();
      }

      that._model = monaco.editor.createModel(sValue, sLang);
      that._editor.setModel(that._model);
      that._editor.layout();
    }).catch(function (e) {
      that._el.innerHTML =
        "<pre style='padding:1rem;white-space:pre-wrap;font-family:monospace'>" +
        "Monaco failed to load.\n\n" + sValue +
        "\n\nError: " + e +
        "</pre>";
    });
  };

  CodeHost.prototype.dispose = function () {
    if (this._model) {
      this._model.dispose();
    }
    if (this._editor) {
      this._editor.dispose();
    }
    this._editor = null;
  };

  return CodeHost;
});
