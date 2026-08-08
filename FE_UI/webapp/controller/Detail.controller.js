sap.ui.define([
  "zscort/app/controller/BaseController",
  "sap/ui/model/json/JSONModel",
  "sap/m/MessageToast",
  "sap/m/MessageBox",
  "sap/ui/core/ValueState",
  "sap/f/library",
  "zscort/app/util/ValueHelp"
], function (BaseController, JSONModel, MessageToast, MessageBox, ValueState, fLibrary, ValueHelp) {
  "use strict";

  var LayoutType = fLibrary.LayoutType;

  return BaseController.extend("zscort.app.controller.Detail", {

    onInit: function () {
      var oViewModel = new JSONModel({
        trkorr: "",
        busy: false,
        objects: [],
        message: ""
      });
      this.getView().setModel(oViewModel, "detail");

      this.getOwnerComponent().getRouter().getRoute("detail").attachPatternMatched(this._onRouteMatched, this);
    },

    _onRouteMatched: function (oEvent) {
      var oArgs = oEvent.getParameter("arguments");
      var sTrkorr = decodeURIComponent(oArgs.trkorr);
      var oViewModel = this.getView().getModel("detail");

      oViewModel.setProperty("/trkorr", sTrkorr);
      this._app().setProperty("/currentModule", "detail");
      this._app().setProperty("/trkorr", sTrkorr);
      this._app().setProperty("/layout", LayoutType.TwoColumnsMidExpanded);
      oViewModel.setProperty("/as4date", "");

      this._loadTrHeader(sTrkorr);
      this._loadObjects(sTrkorr);
    },

    _trServiceUri: function () {
      var sUri = this.getOwnerComponent().getManifestEntry("sap.app").dataSources.trService.uri;
      return String(sUri || "").replace(/\/?$/, "/");
    },

    _loadTrHeader: function (sTrkorr) {
      var oM = this.getView().getModel("detail");
      var sUrl = this._trServiceUri() + "TrTree('" + String(sTrkorr).replace(/'/g, "''") + "')";
      ValueHelp.fetchJson(sUrl, 10000).then(function (oData) {
        if (oData && oData.As4date) {
          oM.setProperty("/as4date", oData.As4date);
        }
      }).catch(function () {
        // silently ignore error if header cannot be loaded
      });
    },

    _serviceUri: function () {
      var oModel = this.getOwnerComponent().getModel();
      var sUri = oModel && oModel.getServiceUrl && oModel.getServiceUrl();
      return sUri || this.getOwnerComponent().getManifestEntry("sap.app").dataSources.mainService.uri;
    },

    /**
     * Load TrCmp via fetch into detail>/objects (matches XML binding).
     * OData V4 bindRows + detail> cell paths was why the table always showed "No data".
     */
    _loadObjects: function (sTrkorr) {
      var oM = this.getView().getModel("detail");
      var sServerId = this._app().getProperty("/serverId") || "TGT";
      var that = this;

      oM.setProperty("/busy", true);
      oM.setProperty("/objects", []);
      oM.setProperty("/message", "");

      // TrCmp backend: ReleasedOnly mặc định true → Modifiable trả NOT_SUPPORTED, không lấy object.
      var sFilter = [
        "Trkorr eq '" + String(sTrkorr).replace(/'/g, "''") + "'",
        "ServerId eq '" + String(sServerId).replace(/'/g, "''") + "'"
      ].join(" and ");
      var sUrl = this._serviceUri().replace(/\/?$/, "/") +
        "TrCmp?$filter=" + encodeURIComponent(sFilter);

      ValueHelp.fetchJson(sUrl, 25000).then(function (aData) {
        aData = aData || [];
        // TR-level block only: NOT_SUPPORTED without ObjectName (e.g. not Released).
        // Per-object NOT_SUPPORTED (TABL/DDLS…) must still appear in the table.
        var oTrBlocked = aData.find(function (r) {
          return r.CompareStatus === "NOT_SUPPORTED" && !(r.ObjectName || r.ObjectType);
        });
        if (oTrBlocked) {
          oM.setProperty("/objects", []);
          oM.setProperty("/busy", false);
          oM.setProperty("/message", oTrBlocked.Message ||
            "TR chưa Released — không mở Compare. Release trước rồi so sánh.");
          MessageToast.show(oM.getProperty("/message"));
          return;
        }
        oM.setProperty("/objects", aData);
        oM.setProperty("/busy", false);
        if (!aData.length) {
          oM.setProperty("/message", "No objects for this TR (or empty E071).");
          MessageToast.show(oM.getProperty("/message"));
          return;
        }
        var nOk = aData.filter(function (r) {
          return r.CompareStatus !== "NOT_SUPPORTED";
        }).length;
        var nSkip = aData.length - nOk;
        if (nOk === 0) {
          oM.setProperty("/message", "No comparable objects (CLAS/PROG/INTF/FUNC/FUGR).");
          MessageToast.show(oM.getProperty("/message"));
        } else if (nSkip > 0) {
          oM.setProperty("/message", nOk + " comparable; " + nSkip + " skipped.");
        }
      }).catch(function (oErr) {
        oM.setProperty("/busy", false);
        oM.setProperty("/message", "TrCmp error: " + (oErr.message || oErr));
        MessageBox.warning(oM.getProperty("/message"));
      });
    },

    _invokeTrTreeAction: function (sActionName, sTrkorr) {
      var oOdm = this.getOwnerComponent().getModel("trModel");
      if (!oOdm) {
        return Promise.reject(new Error("TR service (trModel) not available"));
      }
      var sKey = String(sTrkorr || "").toUpperCase().replace(/'/g, "''");
      var sNs = "com.sap.gateway.srvd.zsd_scort_tr_search.v0001";
      var sPath = "/TrTree('" + sKey + "')/" + sNs + "." + sActionName + "(...)";
      return oOdm.bindContext(sPath).execute();
    },

    onReleaseButtonPress: function () {
      var sTrkorr = this.getView().getModel("detail").getProperty("/trkorr");
      if (!sTrkorr) { return; }
      var that = this;
      this._invokeTrTreeAction("ReleaseRequest", sTrkorr).then(function () {
        MessageToast.show("Release OK: " + sTrkorr);
        that.onButtonRefreshPress();
      }).catch(function (oError) {
        MessageBox.error("Release failed: " + (oError.message || oError));
      });
    },

    onApplyToTargetButtonPress: function () {
      var sTrkorr = this.getView().getModel("detail").getProperty("/trkorr");
      if (!sTrkorr) { return; }
      var that = this;
      var oM = this.getView().getModel("detail");
      oM.setProperty("/busy", true);
      MessageToast.show("Applying " + sTrkorr + "…");
      this._invokeTrTreeAction("ApplyToTarget", sTrkorr).then(function () {
        oM.setProperty("/busy", false);
        that._loadObjects(sTrkorr);
        MessageToast.show("Apply OK: " + sTrkorr);
      }).catch(function (oError) {
        oM.setProperty("/busy", false);
        MessageBox.error("Apply failed: " + (oError.message || oError));
      });
    },

    onButtonRefreshPress: function () {
      var sTrkorr = this.getView().getModel("detail").getProperty("/trkorr");
      if (sTrkorr) {
        this._loadObjects(sTrkorr);
      }
    },

    onButtonNavBackPress: function () {
      this._app().setProperty("/layout", LayoutType.OneColumn);
      this.getOwnerComponent().getRouter().navTo("master", {}, undefined, true);
    },

    onButtonCloseDetailPress: function () {
      this.onButtonNavBackPress();
    },

    onButtonNavObjSearchPress: function () {
      this.onNavObjSearch();
    },

    onButtonComparePress: function (oEvent) {
      var oCtx = oEvent.getSource().getBindingContext("detail");
      if (!oCtx) { return; }

      var sObjectType = oCtx.getProperty("ObjectType");
      var sObjectName = oCtx.getProperty("ObjectName");
      var oApp = this._app();

      this.getOwnerComponent().getRouter().navTo("compare", {
        objectType: sObjectType,
        objectName: encodeURIComponent(sObjectName),
        query: {
          serverId: oApp.getProperty("/serverId") || "TGT",
          mode: oApp.getProperty("/compareMode") || "L_VS_T"
        }
      });
    },

    onButtonViewSourcePress: function (oEvent) {
      var oCtx = oEvent.getSource().getBindingContext("detail");
      if (!oCtx) { return; }
      var sObjectType = oCtx.getProperty("ObjectType");
      var sObjectName = oCtx.getProperty("ObjectName");
      this._openSourceDialog(sObjectType, sObjectName, "L");
    },

    onTableObjectRowSelectionChange: function () { /* reserved */ },

    formatCompareStatus: function (sStatus) {
      switch ((sStatus || "").toUpperCase()) {
        case "IDENTICAL": return ValueState.Success;
        case "DIFFERENT": return ValueState.Error;
        case "NEW_AT_TARGET": return ValueState.Information;
        case "SOURCE_MISSING": return ValueState.Error;
        case "NOT_SUPPORTED": return ValueState.None;
        default: return ValueState.None;
      }
    },

    formatCompareIcon: function (sStatus) {
      switch ((sStatus || "").toUpperCase()) {
        case "IDENTICAL": return "sap-icon://sys-enter-2";
        case "DIFFERENT": return "sap-icon://error";
        case "NEW_AT_TARGET": return "sap-icon://add-document";
        case "SOURCE_MISSING": return "sap-icon://document-text";
        case "NOT_SUPPORTED": return "sap-icon://sys-help-2";
        default: return "sap-icon://status-inactive";
      }
    }

  });
});
