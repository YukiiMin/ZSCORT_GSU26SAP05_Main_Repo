sap.ui.define([], function () {
  "use strict";

  /**
   * DiffHost — Iframe-based wrapper for Monaco Editor
   * Isolates Monaco loader from UI5 loader to prevent CDN/CSP/Require.js collisions.
   */
  function DiffHost(oDomElement) {
    this._el = oDomElement;
    this._iframe = null;
    this._readyResolver = null;
    this._isReady = false;
    this._pendingDiff = null;
    this._lastModel = null;
    this._bSideBySide = true;

    this._readyPromise = new Promise(function(resolve) {
        this._readyResolver = resolve;
    }.bind(this));

    this._initIframe();
  }

  DiffHost.prototype._initIframe = function () {
    var that = this;
    if (!this._el) { return; }
    this._el.innerHTML = "";
    this._el.style.width = "100%";
    this._el.style.height = "100%";

    this._iframe = document.createElement("iframe");
    var sIframeUrl = sap.ui.require.toUrl("zscort/app/monaco/monaco_diff.html");
    
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
            if (that._pendingDiff) {
                that._postMessage(that._pendingDiff);
                that._pendingDiff = null;
            } else if (that._lastModel) {
                that.setModel(that._lastModel);
            }
            that.setSideBySide(that._bSideBySide);
        }
    };
    window.addEventListener("message", this._messageListener);

    this._el.appendChild(this._iframe);
  };

  DiffHost.prototype.isAttached = function () {
    return !!(this._iframe && this._el && this._iframe.parentNode === this._el && document.body.contains(this._iframe));
  };

  DiffHost.prototype.attachTo = function (oNewDomElement) {
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

  DiffHost.prototype._postMessage = function(oMsg) {
      if (this._iframe && this._iframe.contentWindow) {
          this._iframe.contentWindow.postMessage(oMsg, "*");
      }
  };

  DiffHost.prototype.setModel = function (mOpts) {
    var that = this;
    this._lastModel = mOpts;
    var sOriginal = mOpts.original || "";
    var sModified = mOpts.modified || "";
    var sLang = mOpts.language || "abap";

    var oMsg = {
        type: "SET_DIFF",
        original: sOriginal,
        modified: sModified,
        language: sLang
    };

    if (this._isReady) {
        this._postMessage(oMsg);
    } else {
        this._pendingDiff = oMsg;
    }
    return this._readyPromise;
  };

  DiffHost.prototype.dispose = function () {
    if (this._messageListener) {
        window.removeEventListener("message", this._messageListener);
        this._messageListener = null;
    }
    if (this._iframe && this._iframe.parentNode) {
        this._iframe.parentNode.removeChild(this._iframe);
    }
    this._iframe = null;
  };

  DiffHost.prototype.nextDiff = function () {
    this._postMessage({ type: "NEXT_DIFF" });
  };

  DiffHost.prototype.prevDiff = function () {
    this._postMessage({ type: "PREV_DIFF" });
  };

  DiffHost.prototype.setSideBySide = function (bSideBySide) {
    this._bSideBySide = bSideBySide;
    this._postMessage({ type: "SET_SIDE_BY_SIDE", renderSideBySide: bSideBySide });
  };

  return DiffHost;
});
