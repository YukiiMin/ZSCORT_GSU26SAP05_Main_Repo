sap.ui.define([
  "zscort/app/controller/BaseController",
  "sap/ui/model/json/JSONModel",
  "sap/ui/model/Filter",
  "sap/ui/model/FilterOperator",
  "sap/m/MessageBox",
  "sap/m/MessageToast",
  "sap/ui/core/ValueState"
], function (BaseController, JSONModel, Filter, FilterOperator, MessageBox, MessageToast, ValueState) {
  "use strict";

  return BaseController.extend("zscort.app.controller.ObjSearch", {

    // ─────────────────────────────────────────────────────────────────────
    //  LIFECYCLE
    // ─────────────────────────────────────────────────────────────────────

    onInit: function () {
      // Page-local model
      var oModel = new JSONModel({
        // Filter fields
        filterObjName:   "",
        filterObjTypes:  [],
        filterPackage:   "",
        filterAuthor:    "",
        // Active tab
        activeTab:       "local",
        // Result counts
        countLocal:  0,
        countTarget: 0,
        countMatrix: 0,
        // Busy states
        busyLocal:  false,
        busyTarget: false,
        busyMatrix: false,
        // Matrix options
        matrixServerType: "L",
        matrixFilter:     "",
        // Misc
        noDataText: "Enter search criteria and press Search"
      });
      this.getView().setModel(oModel, "objSearch");

      // Route handler
      this.getOwnerComponent().getRouter()
        .getRoute("objSearch")
        .attachPatternMatched(this._onRouteMatched, this);

      // Mark current module
      this._app().setProperty("/currentModule", "objSearch");
    },

    _onRouteMatched: function () {
      this._app().setProperty("/currentModule", "objSearch");
    },

    // ─────────────────────────────────────────────────────────────────────
    //  MODULE SWITCH (SegmentedButton in ShellBar area)
    // ─────────────────────────────────────────────────────────────────────

    onSegmentedButtonModuleSwitchSelectionChange: function (oEvent) {
      var sKey = oEvent.getParameter("item").getKey();
      switch (sKey) {
        case "trSearch": this.onNavTrSearch(); break;
        case "compare":  this.onNavCompare();  break;
        default: break;
      }
    },
    
    // ─── BaseController Wrappers (for UI5 Linter) ─────────────────────────
    onButtonNavObjSearchPress: function(oEvent) { return BaseController.prototype.onButtonNavObjSearchPress.apply(this, arguments); },
    onDialogViewSourceAfterClose: function(oEvent) { return BaseController.prototype.onDialogViewSourceAfterClose.apply(this, arguments); },
    onButtonCloseDialogPress: function(oEvent) { return BaseController.prototype.onButtonCloseDialogPress.apply(this, arguments); },

    // ─────────────────────────────────────────────────────────────────────
    //  SEARCH
    // ─────────────────────────────────────────────────────────────────────

    onSearchButtonPress: function () {
      var sActiveTab = this.getView().getModel("objSearch").getProperty("/activeTab");
      switch (sActiveTab) {
        case "local":  this._searchLocal();  break;
        case "target": this._searchTarget(); break;
        case "matrix": this.onSearchMatrix(); break;
        default:       this._searchLocal();
      }
    },

    onFilterObjNameInputSubmit: function () { this.onSearchButtonPress(); },
    onFilterPackageInputSubmit: function () { this.onSearchButtonPress(); },
    onFilterAuthorInputSubmit: function () { this.onSearchButtonPress(); },

    onIconTabBarModeSelect: function (oEvent) {
      var sKey = oEvent.getParameter("key");
      this.getView().getModel("objSearch").setProperty("/activeTab", sKey);
      // Auto-search on first switch if no data loaded yet
      switch (sKey) {
        case "local":
          if (!this._bLocalLoaded) { this._searchLocal(); }
          break;
        case "target":
          if (!this._bTargetLoaded) { this._searchTarget(); }
          break;
        case "matrix":
          if (!this._bMatrixLoaded) { this.onButtonSearchMatrixPress(); }
          break;
      }
    },

    onClearButtonPress: function () {
      var oM = this.getView().getModel("objSearch");
      oM.setProperty("/filterObjName", "");
      oM.setProperty("/filterObjTypes", []);
      oM.setProperty("/filterPackage", "");
      oM.setProperty("/filterAuthor", "");
      this._bLocalLoaded  = false;
      this._bTargetLoaded = false;
      this._bMatrixLoaded = false;
    },

    // ─── Search Local (TADIR via ZCR_SCORT_OBJ_L) ─────────────────────

    _searchLocal: function () {
      var oM   = this.getView().getModel("objSearch");
      var oOdm = this.getOwnerComponent().getModel("objModel");
      if (!oOdm) {
        this._loadLocalMock();
        return;
      }

      oM.setProperty("/busyLocal", true);

      var aFilters = this._buildObjectFilters();
      var oBinding = oOdm.bindList("/LocalObjects", null, null, aFilters, {
        $select: "ObjectType,ObjectName,PackageName,PersonResponsible,CreatedOn"
      });

      var that = this;
      oBinding.requestContexts(0, 500).then(function (aCtx) {
        var aData = aCtx.map(function (c) { return c.getObject(); });
        oM.setProperty("/countLocal", aData.length);
        that.byId("tblLocal").setModel(new JSONModel(aData), "objSearch");
        oM.setProperty("/busyLocal", false);
        that._bLocalLoaded = true;
      }).catch(function (oErr) {
        oM.setProperty("/busyLocal", false);
        MessageBox.warning("OData error: " + (oErr.message || oErr) + "\n\nFalling back to mock data.", {
          onClose: function () { that._loadLocalMock(); }
        });
      });
    },

    _loadLocalMock: function () {
      var oM = this.getView().getModel("objSearch");
      var aMock = [
        { ObjectType: "CLAS", ObjectName: "ZCL_SCORT_R_SRC",            PackageName: "ZSCORT_SAP05", PersonResponsible: "DEVELOPER", CreatedOn: "20260101" },
        { ObjectType: "CLAS", ObjectName: "ZCL_SCORT_L_READER",         PackageName: "ZSCORT_SAP05", PersonResponsible: "DEVELOPER", CreatedOn: "20260101" },
        { ObjectType: "CLAS", ObjectName: "ZCL_SCORT_COMPRESSION_UTL",  PackageName: "ZSCORT_SAP05", PersonResponsible: "DEVELOPER", CreatedOn: "20260101" },
        { ObjectType: "DDLS", ObjectName: "ZIR_SCORT_OBJ_L",            PackageName: "ZSCORT_SAP05", PersonResponsible: "DEVELOPER", CreatedOn: "20260101" },
        { ObjectType: "BDEF", ObjectName: "ZIR_SCORT_OBJ_L",            PackageName: "ZSCORT_SAP05", PersonResponsible: "DEVELOPER", CreatedOn: "20260101" },
        { ObjectType: "TABL", ObjectName: "ZA_SCORT_T",                 PackageName: "ZSCORT_SAP05", PersonResponsible: "DEVELOPER", CreatedOn: "20260101" }
      ];
      var sFilter = oM.getProperty("/filterObjName").trim().toUpperCase().replace("*", "");
      var aFiltered = sFilter ? aMock.filter(function(o) {
        return o.ObjectName.indexOf(sFilter) >= 0 ||
               o.ObjectType.indexOf(sFilter) >= 0;
      }) : aMock;
      oM.setProperty("/countLocal", aFiltered.length);
      this.byId("tblLocal").setModel(new JSONModel(aFiltered), "objSearch");
      this._bLocalLoaded = true;
      MessageToast.show("Mock data loaded — connect OData for live results");
    },

    // ─── Search Target (ZA_SCORT_T via ZCR_SCORT_OBJ_T) ─────────────────

    _searchTarget: function () {
      var oM   = this.getView().getModel("objSearch");
      var oOdm = this.getOwnerComponent().getModel("objModel");
      if (!oOdm) {
        this._loadTargetMock();
        return;
      }

      oM.setProperty("/busyTarget", true);
      var aFilters = this._buildObjectFilters();
      var oBinding = oOdm.bindList("/TargetObjects", null, null, aFilters, {
        $select: "ObjectType,ObjectName,PackageName,PersonResponsible,ChangedOn"
      });

      var that = this;
      oBinding.requestContexts(0, 500).then(function (aCtx) {
        var aData = aCtx.map(function (c) { return c.getObject(); });
        oM.setProperty("/countTarget", aData.length);
        that.byId("tblTarget").setModel(new JSONModel(aData), "objSearch");
        oM.setProperty("/busyTarget", false);
        that._bTargetLoaded = true;
      }).catch(function (oErr) {
        oM.setProperty("/busyTarget", false);
        MessageBox.warning("OData error: " + (oErr.message || oErr), {
          onClose: function () { that._loadTargetMock(); }
        });
      });
    },

    _loadTargetMock: function () {
      var oM = this.getView().getModel("objSearch");
      var aMock = [
        { ObjectType: "CLAS", ObjectName: "ZCL_SCORT_R_SRC",   PackageName: "ZSCORT_TARGET", PersonResponsible: "DEVELOPER", ChangedOn: "20260201" },
        { ObjectType: "DDLS", ObjectName: "ZIR_SCORT_OBJ_L",   PackageName: "ZSCORT_TARGET", PersonResponsible: "DEVELOPER", ChangedOn: "20260201" }
      ];
      oM.setProperty("/countTarget", aMock.length);
      this.byId("tblTarget").setModel(new JSONModel(aMock), "objSearch");
      this._bTargetLoaded = true;
      MessageToast.show("Mock Target data loaded");
    },

    // ─── Search Matrix (ZCR_SCORT_OBJ_M — BOTH/LOCAL_ONLY/TARGET_ONLY) ──

    onButtonSearchMatrixPress: function () {
      var oM         = this.getView().getModel("objSearch");
      var oOdm       = this.getOwnerComponent().getModel("objModel");
      var sServerType = oM.getProperty("/matrixServerType") || "L";
      var sStatusFilter = oM.getProperty("/matrixFilter") || "";

      if (!oOdm) {
        this._loadMatrixMock();
        return;
      }

      oM.setProperty("/busyMatrix", true);
      var aFilters = this._buildObjectFilters();
      if (sStatusFilter) {
        aFilters.push(new Filter("ExistenceStatus", FilterOperator.EQ, sStatusFilter));
      }

      // Pass P_ServerType parameter via binding parameters
      var oBinding = oOdm.bindList("/CompareMatrix(P_ServerType='" + sServerType + "')", null, null, aFilters, {
        $select: "ObjectType,ObjectName,ExistenceStatus,LocalPackage,TargetPackage,LocalAuthor,TargetAuthor"
      });

      var that = this;
      oBinding.requestContexts(0, 1000).then(function (aCtx) {
        var aData = aCtx.map(function (c) { return c.getObject(); });
        oM.setProperty("/countMatrix", aData.length);
        that.byId("tblMatrix").setModel(new JSONModel(aData), "objSearch");
        oM.setProperty("/busyMatrix", false);
        that._bMatrixLoaded = true;
      }).catch(function (oErr) {
        oM.setProperty("/busyMatrix", false);
        MessageBox.warning("Matrix OData error: " + (oErr.message || oErr), {
          onClose: function () { that._loadMatrixMock(); }
        });
      });
    },

    onSegmentedButtonMatrixServerSwitchSelectionChange: function () {
      this._bMatrixLoaded = false;
      this.onButtonSearchMatrixPress();
    },

    onSegmentedButtonMatrixFilterSelectionChange: function () {
      this.onButtonSearchMatrixPress();
    },

    _loadMatrixMock: function () {
      var oM = this.getView().getModel("objSearch");
      var aMock = [
        { ObjectType: "CLAS", ObjectName: "ZCL_SCORT_R_SRC",           ExistenceStatus: "BOTH",        LocalPackage: "ZSCORT_SAP05", TargetPackage: "ZSCORT_TARGET" },
        { ObjectType: "DDLS", ObjectName: "ZIR_SCORT_OBJ_L",           ExistenceStatus: "BOTH",        LocalPackage: "ZSCORT_SAP05", TargetPackage: "ZSCORT_TARGET" },
        { ObjectType: "CLAS", ObjectName: "ZCL_SCORT_COMPRESSION_UTL", ExistenceStatus: "LOCAL_ONLY",  LocalPackage: "ZSCORT_SAP05", TargetPackage: "" },
        { ObjectType: "TABL", ObjectName: "ZA_SCORT_T",                ExistenceStatus: "LOCAL_ONLY",  LocalPackage: "ZSCORT_SAP05", TargetPackage: "" },
        { ObjectType: "PROG", ObjectName: "ZOLD_PROG_AT_TARGET",       ExistenceStatus: "TARGET_ONLY", LocalPackage: "",             TargetPackage: "ZSCORT_TARGET" }
      ];
      var sStatusFilter = oM.getProperty("/matrixFilter") || "";
      var aFiltered = sStatusFilter ? aMock.filter(function(o) { return o.ExistenceStatus === sStatusFilter; }) : aMock;
      oM.setProperty("/countMatrix", aFiltered.length);
      this.byId("tblMatrix").setModel(new JSONModel(aFiltered), "objSearch");
      this._bMatrixLoaded = true;
      MessageToast.show("Mock Matrix data loaded");
    },

    // ─────────────────────────────────────────────────────────────────────
    //  FILTER BUILDER
    // ─────────────────────────────────────────────────────────────────────

    _buildObjectFilters: function () {
      var oM = this.getView().getModel("objSearch");
      var aFilters = [];

      var sObjName = (oM.getProperty("/filterObjName") || "").trim();
      if (sObjName) {
        aFilters.push(new Filter("ObjectName", FilterOperator.Contains, sObjName.replace(/\*/g, "")));
      }

      var aTypes = oM.getProperty("/filterObjTypes") || [];
      if (aTypes.length > 0) {
        var aTypeFilters = aTypes.map(function (t) {
          return new Filter("ObjectType", FilterOperator.EQ, t);
        });
        aFilters.push(new Filter({ filters: aTypeFilters, and: false }));
      }

      var sPackage = (oM.getProperty("/filterPackage") || "").trim();
      if (sPackage) {
        aFilters.push(new Filter("PackageName", FilterOperator.Contains, sPackage.replace(/\*/g, "")));
      }

      var sAuthor = (oM.getProperty("/filterAuthor") || "").trim();
      if (sAuthor) {
        aFilters.push(new Filter("PersonResponsible", FilterOperator.Contains, sAuthor.replace(/\*/g, "")));
      }

      return aFilters;
    },

    // ─────────────────────────────────────────────────────────────────────
    //  ROW ACTIONS
    // ─────────────────────────────────────────────────────────────────────

    onTableLocalSelectionChange: function (oEvent) {
      var oCtx = oEvent.getParameter("listItem") && oEvent.getParameter("listItem").getBindingContext("objSearch");
      if (!oCtx) { return; }
      var oObj = oCtx.getObject();
      this.navToCompare(oObj.ObjectType, oObj.ObjectName, "L", "BOTH");
    },

    onTableTargetSelectionChange: function (oEvent) {
      var oCtx = oEvent.getParameter("listItem") && oEvent.getParameter("listItem").getBindingContext("objSearch");
      if (!oCtx) { return; }
      var oObj = oCtx.getObject();
      this.navToCompare(oObj.ObjectType, oObj.ObjectName, "T", "BOTH");
    },

    onObjectIdentifierObjNameTitlePress: function (oEvent) {
      var oSrc = oEvent.getSource();
      var oCtx = oSrc.getBindingContext("objSearch");
      if (!oCtx) { return; }
      var oObj = oCtx.getObject();
      this.navToCompare(oObj.ObjectType, oObj.ObjectName, "L", "BOTH");
    },

    onButtonOpenComparePress: function (oEvent) {
      var oCtx = oEvent.getSource().getBindingContext("objSearch");
      if (!oCtx) { return; }
      var oObj = oCtx.getObject();
      var sServer = oObj.ExistenceStatus === "TARGET_ONLY" ? "T" : "L";
      this.navToCompare(oObj.ObjectType, oObj.ObjectName, sServer, oObj.ExistenceStatus || "BOTH");
    },

    onColumnListItemViewSourcePress: function(oEvent) { this.onButtonViewSourcePress(oEvent); },

    onButtonViewSourcePress: function (oEvent) {
      var oCtx = oEvent.getSource().getBindingContext("objSearch");
      if (!oCtx) { return; }
      var oObj = oCtx.getObject();
      
      var sServerType = oObj.ServerType || "L";
      // If from Target table, it's 'T'
      if (oCtx.getPath().indexOf("TargetObjects") > -1) { sServerType = "T"; }
      if (oObj.ExistenceStatus === "TARGET_ONLY") { sServerType = "T"; }

      this._openSourceDialog(oObj.ObjectType, oObj.ObjectName, sServerType);
    },

    onButtonExportLocalPress: function () {
      MessageToast.show("Export Local — TODO: use sap.ui.export.Spreadsheet");
    },

    onButtonExportTargetPress: function () {
      MessageToast.show("Export Target — TODO: use sap.ui.export.Spreadsheet");
    },

    // ─────────────────────────────────────────────────────────────────────
    //  FORMATTERS
    // ─────────────────────────────────────────────────────────────────────

    formatDate: function (sDate) {
      if (!sDate || sDate.length < 8) { return sDate || ""; }
      return sDate.substring(0, 4) + "-" + sDate.substring(4, 6) + "-" + sDate.substring(6, 8);
    },

    formatExistenceState: function (sStatus) {
      switch ((sStatus || "").toUpperCase()) {
        case "BOTH":        return ValueState.Success;
        case "LOCAL_ONLY":  return ValueState.Warning;
        case "TARGET_ONLY": return ValueState.Error;
        default:            return ValueState.None;
      }
    }
  });
});
