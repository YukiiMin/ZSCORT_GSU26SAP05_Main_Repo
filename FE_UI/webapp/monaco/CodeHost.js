sap.ui.define([], function () {
  "use strict";

  /**
   * CodeHost — Iframe-based wrapper for Monaco Editor
   * Single file viewer for ABAP source code.
   */
  function CodeHost(oDomElement) {
    this._el = oDomElement;
    this._iframe = null;
    this._readyResolver = null;
    this._isReady = false;
    this._pendingCode = null;
    this._lastCode = "";
    this._lastLang = "abap";

    this._readyPromise = new Promise(function(resolve) {
        this._readyResolver = resolve;
    }.bind(this));

    this._initIframe();
  }

  CodeHost.prototype._initIframe = function () {
    var that = this;
    if (!this._el) { return; }
    this._el.innerHTML = "";
    this._el.style.width = "100%";
    this._el.style.height = "100%";

    this._iframe = document.createElement("iframe");
    var sIframeUrl = sap.ui.require.toUrl("zscort/app/monaco/monaco_code.html");
    
    this._iframe.src = sIframeUrl;
    this._iframe.style.width = "100%";
    this._iframe.style.height = "100%";
    this._iframe.style.border = "none";
    this._iframe.style.display = "block";

    this._messageListener = function(event) {
        if (event.data && event.data.type === "MONACO_READY") {
            that._isReady = true;
            if (typeof that._readyResolver === "function") {
                that._readyResolver();
            }
            if (that._pendingCode) {
                that._postMessage(that._pendingCode);
                that._pendingCode = null;
            } else if (that._lastCode !== null && that._lastCode !== undefined) {
                that.setValue(that._lastCode, that._lastLang);
            }
        }
    };
    window.addEventListener("message", this._messageListener);

    this._el.appendChild(this._iframe);
  };

  CodeHost.prototype.isAttached = function () {
    return !!(this._iframe && this._el && this._iframe.parentNode === this._el && document.body.contains(this._iframe));
  };

  CodeHost.prototype.attachTo = function (oNewDomElement) {
    this._el = oNewDomElement;
    if (this._messageListener) {
      window.removeEventListener("message", this._messageListener);
      this._messageListener = null;
    }
    this._isReady = false;
    this._readyPromise = new Promise(function(resolve) {
        this._readyResolver = resolve;
    }.bind(this));
    this._initIframe();
  };

  CodeHost.prototype._postMessage = function(oMsg) {
      if (this._iframe && this._iframe.contentWindow) {
          this._iframe.contentWindow.postMessage(oMsg, "*");
      }
  };

  CodeHost.prototype.setValue = function (sValue, sLang) {
    var sVal = sValue || "";
    var sLg = sLang || "abap";
    this._lastCode = sVal;
    this._lastLang = sLg;

    var oMsg = {
        type: "SET_CODE",
        value: sVal,
        language: sLg
    };

    if (this._isReady) {
        this._postMessage(oMsg);
    } else {
        this._pendingCode = oMsg;
    }
    return this._readyPromise;
  };

  CodeHost.prototype.dispose = function () {
    if (this._messageListener) {
        window.removeEventListener("message", this._messageListener);
        this._messageListener = null;
    }
    if (this._iframe && this._iframe.parentNode) {
        this._iframe.parentNode.removeChild(this._iframe);
    }
    this._iframe = null;
  };

  return CodeHost;
});
