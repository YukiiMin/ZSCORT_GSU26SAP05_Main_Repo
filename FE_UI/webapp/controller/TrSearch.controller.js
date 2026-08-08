sap.ui.define([
  "zscort/app/controller/BaseController",
  "sap/ui/model/json/JSONModel",
  "sap/ui/model/Filter",
  "sap/ui/model/FilterOperator",
  "sap/ui/table/TreeAutoScrollMode",
  "sap/m/MessageBox",
  "sap/m/MessageToast",
  "sap/ui/core/ValueState"
], function (BaseController, JSONModel, Filter, FilterOperator, TreeAutoScrollMode, MessageBox, MessageToast, ValueState) {
  "use strict";

  return BaseController.extend("zscort.app.controller.TrSearch", {

    // ─────────────────────────────────────────────────────────────────────
    //  LIFECYCLE
    // ─────────────────────────────────────────────────────────────────────

    onInit: function () {
      var oModel = new JSONModel({
        filterTrkorr:    "",
        filterOwner:     "",
        filterDateFrom:  "",
        filterDateTo:    "",
        filterStatus:    "",
        filterFlatObjName: "",
        filterFlatObjType: "",
        activeTab:       "tree",
        busyTree:        false,
        busyFlat:        false,
        countFlat:       0,
        noDataText:      "Enter search criteria and press Search"
      });
      this.getView().setModel(oModel, "trSearch");

      this.getOwnerComponent().getRouter()
        .getRoute("trSearch")
        .attachPatternMatched(this._onRouteMatched, this);

      this._app().setProperty("/currentModule", "trSearch");
    },

    _onRouteMatched: function () {
      this._app().setProperty("/currentModule", "trSearch");
    },

    // ─────────────────────────────────────────────────────────────────────
    //  MODULE SWITCH
    // ─────────────────────────────────────────────────────────────────────

    onModuleSwitch: function (oEvent) {
      var sKey = oEvent.getParameter("item").getKey();
      switch (sKey) {
        case "objSearch": this.onNavObjSearch(); break;
        case "compare":   this.onNavCompare();   break;
        default: break;
      }
    },

    // ─────────────────────────────────────────────────────────────────────
    //  SEARCH
    // ─────────────────────────────────────────────────────────────────────

    onSearch: function () {
      var sTab = this.getView().getModel("trSearch").getProperty("/activeTab");
      if (sTab === "tree") {
        this._searchTree();
      } else {
        this._searchFlat();
      }
    },

    onTabSelect: function (oEvent) {
      var sKey = oEvent.getParameter("key");
      this.getView().getModel("trSearch").setProperty("/activeTab", sKey);
      if (sKey === "flat" && !this._bFlatLoaded) {
        this._searchFlat();
      }
    },

    onClearFilter: function () {
      var oM = this.getView().getModel("trSearch");
      oM.setProperty("/filterTrkorr",    "");
      oM.setProperty("/filterOwner",     "");
      oM.setProperty("/filterDateFrom",  "");
      oM.setProperty("/filterDateTo",    "");
      oM.setProperty("/filterStatus",    "");
      oM.setProperty("/filterFlatObjName", "");
      oM.setProperty("/filterFlatObjType", "");
      this._bFlatLoaded = false;
    },

    // ─── Tree Search (ZCE_SCORT_TR_TREE via ZC_SCORT_TR_TREE) ──────────

    _searchTree: function () {
      var oM   = this.getView().getModel("trSearch");
      var oTrM = this.getOwnerComponent().getModel("trModel");
      oM.setProperty("/busyTree", true);

      if (!oTrM) {
        this._loadTreeMock();
        return;
      }

      var aFilters = this._buildTrFilters();
      var oBinding = oTrM.bindList("/TrTree", null, null, aFilters, {
        $select: "NodeId,ParentNodeId,TreeLevel,NodeType,Trkorr,ParentTrkorr,Description,Owner,As4date,TrStatus,ObjName,ObjType,Pgmid",
        $$operationMode: "Server"
      });

      var that = this;
      oBinding.requestContexts(0, 2000).then(function (aCtx) {
        var aFlat = aCtx.map(function (c) { return c.getObject(); });
        var oTreeData = that._buildTreeData(aFlat);
        var oTreeModel = new JSONModel(oTreeData);
        that.byId("trTreeTable").setModel(oTreeModel, "trTree");

        // Bind as tree using NodeId/ParentNodeId hierarchy
        that.byId("trTreeTable").bindRows({
          path:      "trTree>/",
          parameters: {
            arrayNames: ["children"]
          }
        });

        oM.setProperty("/busyTree", false);
      }).catch(function (oErr) {
        oM.setProperty("/busyTree", false);
        MessageBox.warning("TR Tree OData error: " + (oErr.message || oErr), {
          onClose: function () { that._loadTreeMock(); }
        });
      });
    },

    /**
     * Convert flat NodeId/ParentNodeId list → nested children[] tree
     * for JSONTreeBinding (sap.ui.table.TreeTable with arrayNames).
     */
    _buildTreeData: function (aFlat) {
      var mById  = {};
      var aRoots = [];

      // Index all nodes
      aFlat.forEach(function (n) {
        n.children = [];
        mById[n.NodeId] = n;
      });

      // Link parent-child
      aFlat.forEach(function (n) {
        if (n.ParentNodeId && mById[n.ParentNodeId]) {
          mById[n.ParentNodeId].children.push(n);
        } else {
          aRoots.push(n);
        }
      });

      return aRoots;
    },

    _loadTreeMock: function () {
      var oM = this.getView().getModel("trSearch");
      var aMock = [
        {
          NodeId: "S40K900123", ParentNodeId: "", TreeLevel: 0, NodeType: "TR",
          Trkorr: "S40K900123", Description: "SCORT Development", Owner: "DEVELOPER",
          As4date: "20260801", TrStatus: "D",
          children: [
            {
              NodeId: "S40K900124", ParentNodeId: "S40K900123", TreeLevel: 1, NodeType: "TASK",
              Trkorr: "S40K900124", Description: "Task: CDS Views", Owner: "DEVELOPER",
              As4date: "20260801", TrStatus: "D",
              children: [
                { NodeId: "S40K900124ZIR_SCORT_OBJ_L", ParentNodeId: "S40K900124", TreeLevel: 2, NodeType: "OBJ",
                  Trkorr: "S40K900124", ObjType: "DDLS", ObjName: "ZIR_SCORT_OBJ_L", Pgmid: "R3TR", children: [] },
                { NodeId: "S40K900124ZIR_SCORT_OBJ_M", ParentNodeId: "S40K900124", TreeLevel: 2, NodeType: "OBJ",
                  Trkorr: "S40K900124", ObjType: "DDLS", ObjName: "ZIR_SCORT_OBJ_M", Pgmid: "R3TR", children: [] }
              ]
            },
            {
              NodeId: "S40K900125", ParentNodeId: "S40K900123", TreeLevel: 1, NodeType: "TASK",
              Trkorr: "S40K900125", Description: "Task: ABAP Classes", Owner: "DEVELOPER",
              As4date: "20260801", TrStatus: "D",
              children: [
                { NodeId: "S40K900125ZCL_SCORT_R_SRC", ParentNodeId: "S40K900125", TreeLevel: 2, NodeType: "OBJ",
                  Trkorr: "S40K900125", ObjType: "CLAS", ObjName: "ZCL_SCORT_R_SRC", Pgmid: "R3TR", children: [] }
              ]
            }
          ]
        }
      ];
      var oTreeModel = new JSONModel(aMock);
      this.byId("trTreeTable").setModel(oTreeModel, "trTree");
      this.byId("trTreeTable").bindRows({
        path:       "trTree>/",
        parameters: { arrayNames: ["children"] }
      });
      oM.setProperty("/busyTree", false);
      MessageToast.show("Mock TR Tree data loaded");
    },

    onExpandAll: function () {
      this.byId("trTreeTable").expandToLevel(3);
    },

    onCollapseAll: function () {
      this.byId("trTreeTable").collapseAll();
    },

    onTreeRowSelect: function (oEvent) {
      // Selection handled by action button (onTreeObjCompare) for Level 2 nodes
    },

    onTreeObjCompare: function (oEvent) {
      var oCtx = oEvent.getSource().getBindingContext("trTree");
      if (!oCtx) { return; }
      var oNode = oCtx.getObject();
      if (oNode.NodeType === "OBJ" && oNode.ObjName && oNode.ObjType) {
        this.navToCompare(oNode.ObjType, oNode.ObjName, "L", "BOTH");
      }
    },

    // ─── Flat List Search (ZI_SCORT_TR_OBJ_SEARCH) ──────────────────────

    onSearchFlat: function () {
      this._searchFlat();
    },

    _searchFlat: function () {
      var oM   = this.getView().getModel("trSearch");
      var oTrM = this.getOwnerComponent().getModel("trModel");
      oM.setProperty("/busyFlat", true);

      if (!oTrM) {
        this._loadFlatMock();
        return;
      }

      var aFilters = this._buildTrFilters();
      var sFlatObjName = (oM.getProperty("/filterFlatObjName") || "").trim();
      var sFlatObjType = (oM.getProperty("/filterFlatObjType") || "").trim();
      if (sFlatObjName) {
        aFilters.push(new Filter("ObjectName", FilterOperator.Contains, sFlatObjName));
      }
      if (sFlatObjType) {
        aFilters.push(new Filter("ObjectType", FilterOperator.EQ, sFlatObjType));
      }

      var oBinding = oTrM.bindList("/TrObjectSearch", null, null, aFilters, {
        $select: "Trkorr,ObjectType,ObjectName,Owner,TrStatus,CurrentManagingTr,ParentTrkorr"
      });

      var that = this;
      oBinding.requestContexts(0, 1000).then(function (aCtx) {
        var aData = aCtx.map(function (c) { return c.getObject(); });
        oM.setProperty("/countFlat", aData.length);
        that.byId("tblFlat").setModel(new JSONModel(aData), "trSearch");
        oM.setProperty("/busyFlat", false);
        that._bFlatLoaded = true;
      }).catch(function (oErr) {
        oM.setProperty("/busyFlat", false);
        MessageBox.warning("Flat List OData error: " + (oErr.message || oErr), {
          onClose: function () { that._loadFlatMock(); }
        });
      });
    },

    _loadFlatMock: function () {
      var oM = this.getView().getModel("trSearch");
      var aMock = [
        { Trkorr: "S40K900124", ObjectType: "DDLS", ObjectName: "ZIR_SCORT_OBJ_L", Owner: "DEVELOPER", TrStatus: "D", CurrentManagingTr: "S40K900123" },
        { Trkorr: "S40K900124", ObjectType: "DDLS", ObjectName: "ZIR_SCORT_OBJ_M", Owner: "DEVELOPER", TrStatus: "D", CurrentManagingTr: "S40K900123" },
        { Trkorr: "S40K900125", ObjectType: "CLAS", ObjectName: "ZCL_SCORT_R_SRC", Owner: "DEVELOPER", TrStatus: "D", CurrentManagingTr: "S40K900123" }
      ];
      oM.setProperty("/countFlat", aMock.length);
      this.byId("tblFlat").setModel(new JSONModel(aMock), "trSearch");
      oM.setProperty("/busyFlat", false);
      this._bFlatLoaded = true;
      MessageToast.show("Mock Flat List data loaded");
    },

    onFlatObjCompare: function (oEvent) {
      var oCtx = oEvent.getSource().getBindingContext("trSearch");
      if (!oCtx) { return; }
      var oObj = oCtx.getObject();
      this.navToCompare(oObj.ObjectType, oObj.ObjectName, "L", "BOTH");
    },

    onExportFlat: function () {
      MessageToast.show("Export — TODO: sap.ui.export.Spreadsheet");
    },

    // ─────────────────────────────────────────────────────────────────────
    //  FILTER BUILDER
    // ─────────────────────────────────────────────────────────────────────

    _buildTrFilters: function () {
      var oM = this.getView().getModel("trSearch");
      var aFilters = [];

      var sTrkorr = (oM.getProperty("/filterTrkorr") || "").trim();
      if (sTrkorr) {
        aFilters.push(new Filter("Trkorr", FilterOperator.Contains, sTrkorr.replace(/\*/g, "")));
      }

      var sOwner = (oM.getProperty("/filterOwner") || "").trim();
      if (sOwner) {
        aFilters.push(new Filter("Owner", FilterOperator.Contains, sOwner));
      }

      var sDateFrom = (oM.getProperty("/filterDateFrom") || "").trim();
      var sDateTo   = (oM.getProperty("/filterDateTo")   || "").trim();
      if (sDateFrom) {
        aFilters.push(new Filter("As4date", FilterOperator.GE, sDateFrom));
      }
      if (sDateTo) {
        aFilters.push(new Filter("As4date", FilterOperator.LE, sDateTo));
      }

      var sStatus = (oM.getProperty("/filterStatus") || "").trim();
      if (sStatus) {
        aFilters.push(new Filter("TrStatus", FilterOperator.EQ, sStatus));
      }

      return aFilters;
    },

    // ─────────────────────────────────────────────────────────────────────
    //  FORMATTERS
    // ─────────────────────────────────────────────────────────────────────

    formatDate: function (sDate) {
      if (!sDate || sDate.length < 8) { return sDate || ""; }
      return sDate.substring(0, 4) + "-" + sDate.substring(4, 6) + "-" + sDate.substring(6, 8);
    },

    formatTrStatus: function (sStatus) {
      switch ((sStatus || "").toUpperCase()) {
        case "D": return ValueState.Warning;    // Modifiable = orange
        case "R": return ValueState.Success;    // Released   = green
        default:  return ValueState.None;
      }
    },

    formatNodeIcon: function (sType) {
      switch ((sType || "").toUpperCase()) {
        case "TR":   return "sap-icon://transport-request";
        case "TASK": return "sap-icon://task";
        case "OBJ":  return "sap-icon://form";
        default:     return "sap-icon://document";
      }
    },

    formatNodeColor: function (sType) {
      switch ((sType || "").toUpperCase()) {
        case "TR":   return "#0070f2";
        case "TASK": return "#e9730c";
        case "OBJ":  return "#188918";
        default:     return "#6a6d70";
      }
    }
  });
});
