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
      // Choose route based on origin module: trCompare (Begin = TrSearch) vs objCompare (Begin = ObjSearch)
      var sRoute = (sOrigin === "trSearch") ? "trCompare" : "objCompare";
      this.getOwnerComponent().getRouter().navTo(sRoute, {
        objectType: sObjectType,
        objectName: encodeURIComponent(sObjectName)
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
      setProp("viewSourceMetaData", arguments[3] || {}); // Store metadata passed by callers
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

      // Check if viewing Target for a LOCAL_ONLY object
      var oMetaData = oM.getProperty("/viewSourceMetaData") || {};
      if (sServerType === "T" && oMetaData.ExistenceStatus === "LOCAL_ONLY") {
        setProp("viewSourceMessage", "Not available in Target (LOCAL_ONLY)");
        setProp("viewSourceHash", "");
        that._pendingSourceCode = "* ==========================================================================\n* NOT AVAILABLE ON TARGET SERVER\n* ==========================================================================\n*\n* Object: " + sObjType + " " + sObjName + "\n* Status: LOCAL_ONLY\n*\n* This object has NOT been released or applied to the Target repository yet.\n* Please release the associated Transport Request to create a snapshot on Target.\n* ==========================================================================";
        that._renderCodeHost(that._pendingSourceCode);
        return;
      }
      if (sServerType === "L" && oMetaData.ExistenceStatus === "TARGET_ONLY") {
        setProp("viewSourceMessage", "Not available in Local (TARGET_ONLY)");
        setProp("viewSourceHash", "");
        that._pendingSourceCode = "* ==========================================================================\n* NOT AVAILABLE ON LOCAL SERVER\n* ==========================================================================\n*\n* Object: " + sObjType + " " + sObjName + "\n* Status: TARGET_ONLY\n*\n* This object only exists in the Target repository snapshot and is not in TADIR.\n* ==========================================================================";
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

      // Fetch metadata if it's missing (e.g. opened from TrSearch where we don't have Package/Author)
      var oMetaData = oM.getProperty("/viewSourceMetaData") || {};
      if (!oMetaData.PackageName && !oMetaData.TadirDevclass) {
        var sEntity = sServerType === "T" ? "TargetObjects" : "LocalObjects";
        var oListBinding = oOdm.bindList("/" + sEntity, null, null, null, {
          "$filter": "ObjectType eq '" + sObjType + "' and ObjectName eq '" + sObjName.replace(/'/g, "''") + "'"
        });
        oListBinding.requestContexts(0, 1).then(function (aContexts) {
          if (aContexts && aContexts.length > 0) {
            setProp("viewSourceMetaData", aContexts[0].getObject());
          }
        }).catch(function (oErr) {
          // ignore error
        });
      }
    },

    onDialogViewSourceAfterOpen: function () {
      if (this._pendingSourceCode !== null && this._pendingSourceCode !== undefined) {
        this._renderCodeHost(this._pendingSourceCode);
      }
    },

    onDialogViewSourceTabSelect: function (oEvent) {
      var sKey = oEvent.getParameter("key");
      var that = this;
      if (sKey === "source") {
        setTimeout(function () {
          if (that._pendingSourceCode !== null && that._pendingSourceCode !== undefined) {
            that._renderCodeHost(that._pendingSourceCode);
          }
        }, 50);
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
        } else if (!that._oCodeHost.isAttached() || that._oCodeHost._el !== el) {
          that._oCodeHost.attachTo(el);
        }
        that._oCodeHost.setValue(sCode || "", "abap");
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
    },

    onLanguageMenuSelect: function (oEvent) {
      var oItem = oEvent.getParameter("item");
      var sKey = oItem ? oItem.getKey() : "en";
      this._applyLanguage(sKey);
    },

    onLanguageChange: function (oEvent) {
      var sKey = oEvent.getParameter("item") ? oEvent.getParameter("item").getKey() : (oEvent.getParameter("key") || oEvent.getSource().getSelectedKey());
      this._applyLanguage(sKey || "en");
    },

    _applyLanguage: function (sKey) {
      if (!sKey) { return; }
      var sNorm = sKey.toLowerCase();
      localStorage.setItem("scort_lang", sNorm);
      var oUrl = new URL(window.location.href);
      oUrl.searchParams.set("sap-language", sNorm.toUpperCase());
      window.location.href = oUrl.toString();
    },

    _getText: function (sKey, aArgs) {
      var oBundle = this.getOwnerComponent().getModel("i18n") ? this.getOwnerComponent().getModel("i18n").getResourceBundle() : null;
      if (!oBundle) {
        var oView = this.getView();
        if (oView && oView.getModel("i18n")) {
          oBundle = oView.getModel("i18n").getResourceBundle();
        }
      }
      return oBundle ? oBundle.getText(sKey, aArgs) : sKey;
    }
  });
});
