sap.ui.define([
  "zscort/app/controller/BaseController",
  "sap/ui/model/json/JSONModel",
  "sap/ui/model/Filter",
  "sap/ui/model/FilterOperator",
  "sap/ui/core/ValueState"
], function (BaseController, JSONModel, Filter, FilterOperator, ValueState) {
  "use strict";

  return BaseController.extend("zscort.app.controller.Detail", {

    onInit: function () {
      var oViewModel = new JSONModel({
        trkorr: "",
        busy: false
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
      
      this._bindTable(sTrkorr);
    },

    _bindTable: function (sTrkorr) {
      var oTable = this.byId("idObjectsTable");
      var sServerId = this._app().getProperty("/serverId") || "TARGET";
      
      var aFilters = [
        new Filter("Trkorr", FilterOperator.EQ, sTrkorr),
        new Filter("ServerId", FilterOperator.EQ, sServerId)
      ];

      var oMainModel = this.getOwnerComponent().getModel(); // mainService
      
      // Bind directly to /TrCmp from mainService
      oTable.bindRows({
        path: "/TrCmp",
        model: "", // default model
        filters: aFilters,
        parameters: {
          $select: "ObjectType,ObjectName,CompareStatus,Message"
        }
      });
    },

    onReleaseButtonPress: function () {
      var sTrkorr = this.getView().getModel("detail").getProperty("/trkorr");
      if (!sTrkorr) return;
      var oOdm = this.getOwnerComponent().getModel("trModel");
      var oAction = oOdm.bindContext("/TrTree('" + sTrkorr + "')/com.sap.gateway.srvd.zsd_scort_tr_search.v0001.ReleaseRequest(...)");
      
      var that = this;
      oAction.execute().then(function () {
        sap.m.MessageToast.show("Release triggered successfully.");
        that.onButtonRefreshPress(); // Refresh data to update status
      }).catch(function (oError) {
        sap.m.MessageBox.error("Error triggering Release: " + oError.message);
      });
    },

    onApplyToTargetButtonPress: function () {
      var sTrkorr = this.getView().getModel("detail").getProperty("/trkorr");
      if (!sTrkorr) return;
      var oOdm = this.getOwnerComponent().getModel("trModel");
      var oAction = oOdm.bindContext("/TrTree('" + sTrkorr + "')/com.sap.gateway.srvd.zsd_scort_tr_search.v0001.ApplyToTarget(...)");
      
      oAction.execute().then(function () {
        sap.m.MessageToast.show("Apply to Target triggered successfully.");
      }).catch(function (oError) {
        sap.m.MessageBox.error("Error triggering Apply to Target: " + oError.message);
      });
    },

    onButtonRefreshPress: function () {
      var sTrkorr = this.getView().getModel("detail").getProperty("/trkorr");
      if (sTrkorr) {
        this._bindTable(sTrkorr);
      }
    },

    onButtonNavBackPress: function () {
      this.getOwnerComponent().getRouter().navTo("master", {}, undefined, true);
    },

    onButtonCloseDetailPress: function () {
      this.getOwnerComponent().getRouter().navTo("master", {}, undefined, true);
    },

    onButtonComparePress: function (oEvent) {
      var oRow = oEvent.getSource().getParent();
      var oCtx = oRow.getBindingContext();
      if (!oCtx) return;

      var sObjectType = oCtx.getProperty("ObjectType");
      var sObjectName = oCtx.getProperty("ObjectName");

      // Navigate to Compare view (End Column)
      this.getOwnerComponent().getRouter().navTo("compare", {
        objectType: encodeURIComponent(sObjectType),
        objectName: encodeURIComponent(sObjectName)
      });
    },

    onButtonViewSourcePress: function (oEvent) {
      var oRow = oEvent.getSource().getParent().getParent(); // Button -> HBox -> table:Row
      if (oRow && oRow.getBindingContext) {
        var oCtx = oRow.getBindingContext();
        if (oCtx) {
          var sObjectType = oCtx.getProperty("ObjectType");
          var sObjectName = oCtx.getProperty("ObjectName");
          var sServerId = this._app().getProperty("/serverId") || "TARGET";
          var sServerType = (sServerId === "TARGET") ? "T" : "L";
          this._openSourceDialog(sObjectType, sObjectName, sServerType);
        }
      }
    },

    onTableObjectRowSelectionChange: function (oEvent) {
      // Optional: Handle row selection to show quick info, or just rely on Compare button
    },

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
