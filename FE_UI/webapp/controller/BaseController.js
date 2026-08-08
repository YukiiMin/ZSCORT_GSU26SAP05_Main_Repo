sap.ui.define([
  "sap/ui/core/mvc/Controller",
  "sap/ui/core/Fragment",
  "zscort/app/monaco/CodeHost"
], function (Controller, Fragment, CodeHost) {
  "use strict";

  /**
   * BaseController — shared navigation helpers.
   * All page controllers extend this class.
   */
  return Controller.extend("zscort.app.controller.BaseController", {

    // ─── Navigation helpers ───────────────────────────────────────────────

    onButtonNavObjSearchPress: function () {
      this._app().setProperty("/currentModule", "objSearch");
      this.getOwnerComponent().getRouter().navTo("objSearch");
    },

    onNavTrSearch: function () {
      this._app().setProperty("/currentModule", "trSearch");
      this.getOwnerComponent().getRouter().navTo("trSearch");
    },

    onNavCompare: function () {
      this._app().setProperty("/currentModule", "compare");
      this.getOwnerComponent().getRouter().navTo("compare");
    },

    onHomePress: function () {
      this.onButtonNavObjSearchPress();
    },

    onMenuPress: function () {
      this.onButtonNavObjSearchPress();
    },

    // ─── Internal helpers ─────────────────────────────────────────────────

    _app: function () {
      return this.getOwnerComponent().getModel("appView");
    },

    _i18n: function (sKey) {
      return this.getOwnerComponent().getModel("i18n").getResourceBundle().getText(sKey);
    },

    /**
     * Navigate to Code Compare screen with a specific object pre-selected.
     * Called from ObjectSearch when user clicks on an object row.
     */
    navToCompare: function (sObjectType, sObjectName, sServerId, sCompareStatus) {
      this._app().setProperty("/currentModule", "compare");
      this.getOwnerComponent().getRouter().navTo("compareDetail", {
        objectType: sObjectType,
        objectName: encodeURIComponent(sObjectName),
        query: {
          serverId: sServerId || "TARGET",
          status: sCompareStatus || "BOTH",
          mode: "L_VS_T"
        }
      });
    },

    _openSourceDialog: function (sObjType, sObjName, sServerType) {
      var oView = this.getView();
      // Usually the current view has its own model or we can use a temporary model
      // But we will use the appView model or the local view model. Let's use a standard property on the view model.
      var oM = oView.getModel("objSearch") || oView.getModel("detail") || this.getOwnerComponent().getModel("appView");
      var that = this;

      oM.setProperty("/viewSourceType", sObjType);
      oM.setProperty("/viewSourceName", sObjName);
      oM.setProperty("/viewSourceServer", sServerType);
      oM.setProperty("/viewSourceMessage", "Loading...");
      oM.setProperty("/viewSourceHash", "");

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

      var oOdm = this.getOwnerComponent().getModel("objModel");
      if (!oOdm) {
        oM.setProperty("/viewSourceMessage", "Mock data loaded");
        oM.setProperty("/viewSourceHash", "MOCK_HASH_123");
        this._renderCodeHost("* Mock ABAP code\nREPORT z_test.");
        return;
      }

      // Fetch from OData: /SourceCodeView(ObjectType='...',ObjectName='...',ServerType='...')
      var sPath = "/SourceCodeView(ObjectType='" + sObjType + "',ObjectName='" + sObjName.replace(/'/g, "''") + "',ServerType='" + sServerType + "')";
      var oContext = oOdm.bindContext(sPath);

      oContext.requestObject().then(function (oData) {
        oM.setProperty("/viewSourceMessage", oData.Message || "OK");
        oM.setProperty("/viewSourceHash", oData.SrcHash || "");
        that._renderCodeHost(oData.SourceCodeText || "");
      }).catch(function (oErr) {
        oM.setProperty("/viewSourceMessage", "Error: " + (oErr.message || oErr));
        oM.setProperty("/viewSourceHash", "");
        that._renderCodeHost("/* Error loading source */");
      });
    },

    _renderCodeHost: function (sCode) {
      var that = this;
      setTimeout(function () {
        var el = document.querySelector(".codeHost");
        if (el && !that._oCodeHost) {
          that._oCodeHost = new CodeHost(el);
        } else if (el && that._oCodeHost && that._oCodeHost._el !== el) {
          that._oCodeHost.dispose();
          that._oCodeHost = new CodeHost(el);
        }
        if (that._oCodeHost) {
          that._oCodeHost.setValue(sCode, "abap");
        }
      }, 50);
    },

    onDialogViewSourceAfterClose: function () {
      if (this._oSourceDialog) {
        this._oSourceDialog.close();
      }
      if (this._oCodeHost) {
        this._oCodeHost.dispose();
        this._oCodeHost = null;
      }
    },

    onButtonCloseDialogPress: function () {
      if (this._oSourceDialog) {
        this._oSourceDialog.close();
      }
    }
  });
});
