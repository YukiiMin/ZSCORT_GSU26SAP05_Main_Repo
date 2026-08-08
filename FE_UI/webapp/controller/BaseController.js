sap.ui.define([
  "sap/ui/core/mvc/Controller",
  "sap/ui/core/Fragment",
  "sap/m/MessageToast",
  "sap/f/library",
  "zscort/app/monaco/CodeHost",
  "sap/ui/core/format/DateFormat"
], function (Controller, Fragment, MessageToast, fLibrary, CodeHost, DateFormat) {
  "use strict";

  var LayoutType = fLibrary.LayoutType;

  return Controller.extend("zscort.app.controller.BaseController", {

    onButtonNavObjSearchPress: function () {
      var oApp = this._app();
      oApp.setProperty("/layout", LayoutType.OneColumn);
      oApp.setProperty("/currentModule", "objSearch");
      this.getOwnerComponent().getRouter().navTo("objSearch");
    },

    onNavObjSearch: function () {
      this.onButtonNavObjSearchPress();
    },

    onNavTrSearch: function () {
      try {
        var oApp = this._app();
        // Collapse Compare mid/end columns so TrSearch (begin) is fully visible
        oApp.setProperty("/layout", LayoutType.OneColumn);
        oApp.setProperty("/currentModule", "trSearch");
        this.getOwnerComponent().getRouter().navTo("trSearch");
      } catch (oErr) {
        // eslint-disable-next-line no-console
        console.error("onNavTrSearch failed:", oErr);
        MessageToast.show("Navigation to TR Search failed: " + (oErr && oErr.message || oErr));
      }
    },

    onNavCompare: function () {
      // Segmented "Code Compare" without object keys → TR master list
      var oApp = this._app();
      oApp.setProperty("/layout", LayoutType.OneColumn);
      oApp.setProperty("/currentModule", "compare");
      this.getOwnerComponent().getRouter().navTo("master");
    },

    onHomePress: function () {
      this.onButtonNavObjSearchPress();
    },

    onMenuPress: function () {
      this.onButtonNavObjSearchPress();
    },

    _app: function () {
      return this.getOwnerComponent().getModel("appView");
    },

    _i18n: function (sKey) {
      return this.getOwnerComponent().getModel("i18n").getResourceBundle().getText(sKey);
    },

    /**
     * Direct "quick compare" entry point (Object Search / TR Search rows) — opens Compare
     * as a 2-column view (Begin = origin search screen, Mid = Compare) via the "objCompare"
     * route. The TR-flow (Master → Detail → Compare) uses the 3-column "compare" route via
     * Detail.controller.js#onButtonComparePress directly, unaffected by this helper.
     */
    navToCompare: function (sObjectType, sObjectName, sServerId, sCompareStatus) {
      var oApp = this._app();
      var sOrigin = oApp.getProperty("/currentModule");
      if (sOrigin !== "objSearch" && sOrigin !== "trSearch") {
        sOrigin = "objSearch";
      }
      oApp.setProperty("/compareOrigin", sOrigin);
      oApp.setProperty("/currentModule", "compare");
      // Compare OData key ServerId is TGT (ZA_SCORT_T_SRC), not L/T (those are SourceCodeView ServerType).
      var sSrv = (sServerId === "T" || sServerId === "L" || !sServerId)
        ? (oApp.getProperty("/serverId") || "TGT")
        : sServerId;
      this.getOwnerComponent().getRouter().navTo("objCompare", {
        objectType: sObjectType,
        objectName: encodeURIComponent(sObjectName),
        query: {
          serverId: sSrv,
          status: sCompareStatus || "BOTH",
          mode: oApp.getProperty("/compareMode") || "L_VS_T"
        }
      });
    },

    _openSourceDialog: function (sObjType, sObjName, sServerType) {
      var oView = this.getView();
      var oApp = this._app();
      var oM = oView.getModel("objSearch") || oView.getModel("detail") || oApp;
      var that = this;

      function setProp(sKey, v) {
        oM.setProperty("/" + sKey, v);
        if (oApp && oApp !== oM) {
          oApp.setProperty("/" + sKey, v);
        }
      }

      setProp("viewSourceType", sObjType);
      setProp("viewSourceName", sObjName);
      setProp("viewSourceServer", sServerType);
      setProp("viewSourceMessage", "Loading...");
      setProp("viewSourceHash", "");
      setProp("viewSourceCode", "");
      this._pendingSourceCode = null;

      if (!this._oSourceDialog) {
        Fragment.load({
          id: oView.getId(),
          name: "zscort.app.view.ViewSource",
          controller: this
        }).then(function (oDialog) {
          that._oSourceDialog = oDialog;
          oView.addDependent(that._oSourceDialog);
          that._oSourceDialog.open();
          that._loadSourceCode(sObjType, sObjName, sServerType, oM);
        });
      } else {
        this._oSourceDialog.open();
        this._loadSourceCode(sObjType, sObjName, sServerType, oM);
      }
    },

    _loadSourceCode: function (sObjType, sObjName, sServerType, oM) {
      var that = this;
      var oApp = this._app();

      function setProp(sKey, v) {
        oM.setProperty("/" + sKey, v);
        if (oApp && oApp !== oM) {
          oApp.setProperty("/" + sKey, v);
        }
      }

      var oOdm = this.getOwnerComponent().getModel("objModel");
      if (!oOdm) {
        setProp("viewSourceMessage", "Mock data loaded");
        setProp("viewSourceHash", "MOCK_HASH_123");
        that._pendingSourceCode = "* Mock ABAP code\nREPORT z_test.";
        that._renderCodeHost(that._pendingSourceCode);
        return;
      }

      // CDS key order: ServerType, ObjectType, ObjectName
      var sPath = "/SourceCodeView(ServerType='" + sServerType +
        "',ObjectType='" + sObjType +
        "',ObjectName='" + sObjName.replace(/'/g, "''") + "')";
      var oContext = oOdm.bindContext(sPath);

      oContext.requestObject().then(function (oData) {
        setProp("viewSourceMessage", oData.Message || "OK");
        setProp("viewSourceHash", oData.SrcHash || "");
        that._pendingSourceCode = oData.SourceCodeText || "";
        that._renderCodeHost(that._pendingSourceCode);
      }).catch(function (oErr) {
        setProp("viewSourceMessage", "Error: " + (oErr.message || oErr));
        setProp("viewSourceHash", "");
        that._pendingSourceCode = "/* Error loading source */";
        that._renderCodeHost(that._pendingSourceCode);
      });
    },

    onDialogViewSourceAfterOpen: function () {
      if (this._pendingSourceCode !== null && this._pendingSourceCode !== undefined) {
        this._renderCodeHost(this._pendingSourceCode);
      }
    },

    _renderCodeHost: function (sCode) {
      var that = this;
      var oDialog = this._oSourceDialog;
      var iAttempt = 0;

      function tryRender() {
        iAttempt += 1;
        var el = null;
        if (oDialog && oDialog.getDomRef) {
          var oDom = oDialog.getDomRef();
          if (oDom) {
            el = oDom.querySelector(".codeHost");
          }
        }
        if (!el) {
          el = document.querySelector(".codeHost");
        }
        if (!el) {
          if (iAttempt < 20) {
            setTimeout(tryRender, 50);
          }
          return;
        }
        if (el.offsetHeight < 40) {
          el.style.minHeight = "60vh";
          el.style.height = "60vh";
        }
        if (!that._oCodeHost) {
          that._oCodeHost = new CodeHost(el);
        } else if (that._oCodeHost._el !== el) {
          that._oCodeHost.dispose();
          that._oCodeHost = new CodeHost(el);
        }
        that._oCodeHost.setValue(sCode || "", "abap");
        if (that._oCodeHost.layout) {
          that._oCodeHost.layout();
        } else if (that._oCodeHost._editor && that._oCodeHost._editor.layout) {
          that._oCodeHost._editor.layout();
        }
      }

      setTimeout(tryRender, 0);
    },

    onDialogViewSourceAfterClose: function () {
      if (this._oCodeHost) {
        this._oCodeHost.dispose();
        this._oCodeHost = null;
      }
      this._pendingSourceCode = null;
    },

    onButtonCloseDialogPress: function () {
      if (this._oSourceDialog) {
        this._oSourceDialog.close();
      }
    },

    onButtonCopySourcePress: function () {
      if (this._pendingSourceCode) {
        var el = document.createElement("textarea");
        el.value = this._pendingSourceCode;
        document.body.appendChild(el);
        el.select();
        document.execCommand("copy");
        document.body.removeChild(el);
        MessageToast.show("Source code copied to clipboard!");
      } else {
        MessageToast.show("No source code to copy.");
      }
    },

    formatDate: function (vDate) {
      if (!vDate) { return ""; }
      var s = String(vDate);
      var oDate;
      if (/^\d{4}-\d{2}-\d{2}/.test(s)) {
        oDate = new Date(s);
      } else {
        var sDigits = s.replace(/\D/g, "");
        if (sDigits.length >= 8) {
          var y = sDigits.substring(0, 4);
          var m = parseInt(sDigits.substring(4, 6), 10) - 1;
          var d = sDigits.substring(6, 8);
          oDate = new Date(y, m, d);
        }
      }
      if (oDate && !isNaN(oDate.getTime())) {
        var oFormat = DateFormat.getDateInstance({ style: "medium" });
        return oFormat.format(oDate);
      }
      return s;
    }
  });
});
