sap.ui.define([
  "zscort/app/controller/BaseController",
  "sap/ui/model/json/JSONModel",
  "sap/m/MessageBox",
  "sap/m/MessageToast",
  "sap/ui/core/ValueState",
  "zscort/app/util/ValueHelp"
], function (BaseController, JSONModel, MessageBox, MessageToast, ValueState, ValueHelp) {
  "use strict";

  return BaseController.extend("zscort.app.controller.TrSearch", {

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
      // Ensure this page is the visible begin-column page (FCL may keep ObjSearch on top)
      this._ensureBeginVisible();
    },

    _ensureBeginVisible: function () {
      try {
        var oFcl = this.getOwnerComponent().getRootControl().byId("fcl");
        if (!oFcl) { return; }
        var oView = this.getView();
        var sId = oView.getId();
        if (typeof oFcl.to === "function") {
          oFcl.to(sId);
        }
      } catch (e) { /* ignore */ }
    },


    onModuleSwitch: function (oEvent) {
      var sKey = oEvent.getParameter("item").getKey();
      switch (sKey) {
        case "objSearch": this.onNavObjSearch(); break;
        case "compare":   this.onNavCompare();   break;
        default: break;
      }
    },

    onSearch: function () {
      var oM = this.getView().getModel("trSearch");
      var sTrk = (oM.getProperty("/filterTrkorr") || "").trim();
      var sOwn = (oM.getProperty("/filterOwner") || "").trim();

      if (!sTrk && !sOwn) {
        sap.m.MessageBox.warning("Vui lòng nhập ít nhất Transport Request hoặc Owner để giới hạn phạm vi tìm kiếm.");
        return;
      }

      var sTab = oM.getProperty("/activeTab");
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


    _trServiceUri: function () {
      var sUri = this.getOwnerComponent().getManifestEntry("sap.app").dataSources.trService.uri;
      return String(sUri || "").replace(/\/?$/, "/");
    },

    _applyTreeRows: function (aFlat, bSilent) {
      var oM = this.getView().getModel("trSearch");
      var oTree = this.byId("trTreeTable");
      if (!oTree) {
        oM.setProperty("/busyTree", false);
        return;
      }
      var oTreeData = this._buildTreeData(aFlat || []);
      oTree.setModel(new JSONModel(oTreeData), "trTree");
      oTree.bindRows({
        path: "trTree>/",
        parameters: { arrayNames: ["children"] }
      });
      setTimeout(function () {
        try { oTree.expandToLevel(3); } catch (e) { /* ignore */ }
      }, 0);
      oM.setProperty("/busyTree", false);
      if (bSilent) { return; }
      var nObj = (aFlat || []).filter(function (n) { return n.NodeType === "OBJ"; }).length;
      if (!(aFlat && aFlat.length)) {
        MessageToast.show("No TR matched");
      } else {
        MessageToast.show(aFlat.length + " node(s), " + nObj + " object(s)");
      }
    },

    _clientFilterTree: function (aFlat) {
      var oM = this.getView().getModel("trSearch");
      var sTrkorr = (oM.getProperty("/filterTrkorr") || "").trim().toUpperCase().replace(/\*/g, "");
      var sOwner = (oM.getProperty("/filterOwner") || "").trim().toUpperCase().replace(/\*/g, "");
      var sStatus = (oM.getProperty("/filterStatus") || "").trim().toUpperCase();
      if (sOwner === "USERNAME" || sOwner === "USER") { sOwner = ""; }

      var a = aFlat || [];
      if (!sTrkorr && !sOwner && !sStatus) { return a; }

      var mKeep = {};
      var i;
      var bChanged;

      a.forEach(function (n) {
        var sT = String(n.Trkorr || "").toUpperCase();
        var sP = String(n.ParentTrkorr || "").toUpperCase();
        var sO = String(n.Owner || "").toUpperCase();
        var sS = String(n.TrStatus || "").toUpperCase();
        var bTrk = !sTrkorr || sT.indexOf(sTrkorr) >= 0 || sP.indexOf(sTrkorr) >= 0;
        var bOwn = !sOwner || sO.indexOf(sOwner) >= 0;
        var bSta = !sStatus || sS === sStatus || n.NodeType === "OBJ";
        if (bTrk && bOwn && bSta) {
          mKeep[n.NodeId] = true;
        }
      });

      for (i = 0; i < 5; i++) {
        bChanged = false;
        a.forEach(function (n) {
          if (mKeep[n.NodeId] && n.ParentNodeId && !mKeep[n.ParentNodeId]) {
            mKeep[n.ParentNodeId] = true;
            bChanged = true;
          }
        });
        if (!bChanged) { break; }
      }

      for (i = 0; i < 5; i++) {
        bChanged = false;
        a.forEach(function (n) {
          if (!mKeep[n.NodeId] && n.ParentNodeId && mKeep[n.ParentNodeId]) {
            mKeep[n.NodeId] = true;
            bChanged = true;
          }
        });
        if (!bChanged) { break; }
      }

      return a.filter(function (n) { return mKeep[n.NodeId]; });
    },

    _searchTree: function (bSilent) {
      var oM = this.getView().getModel("trSearch");
      var that = this;
      var sUrlBare = this._trServiceUri() + "TrTree";
      var sFilter = this._buildTrODataFilter();
      var sUrlFiltered = sFilter
        ? (this._trServiceUri() + "TrTree?$filter=" + encodeURIComponent(sFilter))
        : sUrlBare;

      oM.setProperty("/busyTree", true);
      if (!bSilent) {
        MessageToast.show("Searching TR…");
      }

      function finish(aFlat) {
        that._applyTreeRows(that._clientFilterTree(aFlat || []), bSilent);
      }
      function fail(oErr) {
        oM.setProperty("/busyTree", false);
        MessageBox.warning("TR Tree error: " + (oErr.message || oErr), {
          onClose: function () { that._loadTreeMock(); }
        });
      }

      ValueHelp.fetchAllJson(sUrlFiltered, 60000).then(finish).catch(function () {
        if (!bSilent) {
          MessageToast.show("Retry without filter…");
        }
        ValueHelp.fetchAllJson(sUrlBare, 60000).then(finish).catch(fail);
      });
    },

    
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

    onTreeOpenDetail: function (oEvent) {
      var oCtx = oEvent.getSource().getBindingContext("trTree");
      if (!oCtx) { return; }
      var oNode = oCtx.getObject();
      var sTrkorr = oNode.Trkorr || oNode.ParentTrkorr;
      if (!sTrkorr) { return; }
      // Prefer parent request for tasks so Detail Release/Apply bind the request
      if (oNode.NodeType === "TASK" && oNode.ParentTrkorr) {
        sTrkorr = oNode.ParentTrkorr;
      }
      this._app().setProperty("/currentModule", "compare");
      this.getOwnerComponent().getRouter().navTo("detail", {
        trkorr: encodeURIComponent(sTrkorr)
      });
    },

    _openTasksUnderTr: function (oTrNode) {
      var aKids = (oTrNode && oTrNode.children) || [];
      return aKids.filter(function (c) {
        return c && c.NodeType === "TASK" && c.TrStatus !== "R";
      });
    },

    _releaseErrorText: function (oErr) {
      if (!oErr) { return "Release failed"; }
      var s = oErr.message || String(oErr);
      try {
        var aErr = oErr.error && oErr.error.details;
        if (aErr && aErr.length) {
          s = aErr.map(function (d) { return d.message; }).filter(Boolean).join("\n") || s;
        }
      } catch (e) { /* ignore */ }
      return s;
    },

    onTreeReleasePress: function (oEvent) {
      var oCtx = oEvent.getSource().getBindingContext("trTree");
      if (!oCtx) { return; }
      var oNode = oCtx.getObject();
      var sTrkorr = oNode.Trkorr;
      if (!sTrkorr) { return; }
      if (oNode.TrStatus === "R") {
        MessageToast.show(sTrkorr + " already released");
        return;
      }

      // SAP: phải Release Task trước, rồi mới Release TR cha
      if (oNode.NodeType === "TR") {
        var aOpen = this._openTasksUnderTr(oNode);
        if (aOpen.length) {
          MessageBox.error(
            "Release task first:\n" +
            aOpen.map(function (t) { return t.Trkorr + " (status " + (t.TrStatus || "?") + ")"; }).join("\n")
          );
          return;
        }
      }

      var oOdm = this.getOwnerComponent().getModel("trModel");
      if (!oOdm) {
        MessageToast.show("TR service not available");
        return;
      }

      var that = this;
      var sKey = String(sTrkorr).replace(/'/g, "''");
      var sPath = "/TrTree('" + sKey + "')/com.sap.gateway.srvd.zsd_scort_tr_search.v0001.ReleaseRequest(...)";
      var sHint = oNode.NodeType === "TASK"
        ? "Release task " + sTrkorr + "?"
        : "Release TR " + sTrkorr + "?";

      MessageBox.confirm(sHint, {
        title: "Release Transport",
        onClose: function (sAction) {
          if (sAction !== MessageBox.Action.OK) { return; }
          oOdm.bindContext(sPath).execute().then(function () {
            MessageToast.show("Release OK: " + sTrkorr);
            that._searchTree(true);
          }).catch(function (oErr) {
            MessageBox.error(that._releaseErrorText(oErr));
          });
        }
      });
    },


    onSearchFlat: function () {
      this._searchFlat();
    },

    _searchFlat: function () {
      var oM = this.getView().getModel("trSearch");
      var that = this;
      var aParts = this._buildTrODataFilterParts();
      var sFlatObjName = (oM.getProperty("/filterFlatObjName") || "").trim().replace(/\*/g, "");
      var sFlatObjType = (oM.getProperty("/filterFlatObjType") || "").trim();
      if (sFlatObjName) {
        aParts.push("contains(ObjectName,'" + sFlatObjName.replace(/'/g, "''") + "')");
      }
      if (sFlatObjType) {
        aParts.push("ObjectType eq '" + sFlatObjType.replace(/'/g, "''") + "'");
      }
      var sFilter = aParts.join(" and ");
      var sUrl = this._trServiceUri() + "TrObjectSearch" +
        (sFilter ? ("?$filter=" + encodeURIComponent(sFilter) + "&$top=1000") : "?$top=1000");

      oM.setProperty("/busyFlat", true);
      ValueHelp.fetchJson(sUrl, 30000).then(function (aData) {
        aData = aData || [];
        oM.setProperty("/countFlat", aData.length);
        var oTbl = that.byId("tblFlat");
        if (oTbl) {
          oTbl.setModel(new JSONModel(aData), "trSearch");
        }
        oM.setProperty("/busyFlat", false);
        that._bFlatLoaded = true;
        if (!aData.length) {
          MessageToast.show("No objects matched");
        }
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

    onFlatOpenDetail: function (oEvent) {
      var oCtx = oEvent.getSource().getBindingContext("trSearch");
      if (!oCtx) { return; }
      var oObj = oCtx.getObject();
      var sTrkorr = oObj.CurrentManagingTr || oObj.ParentTrkorr || oObj.Trkorr;
      if (!sTrkorr) { return; }
      this._app().setProperty("/currentModule", "compare");
      this.getOwnerComponent().getRouter().navTo("detail", {
        trkorr: encodeURIComponent(sTrkorr)
      });
    },

    onExportFlat: function () {
      MessageToast.show("Export — TODO: sap.ui.export.Spreadsheet");
    },

    /**
     * Prefer eq / startswith — avoid OData contains() which RAP custom entity
     * often cannot convert to ranges (empty result / HTTP 500).
     */
    _buildTrODataFilterParts: function () {
      var oM = this.getView().getModel("trSearch");
      var aParts = [];

      var sTrkorr = (oM.getProperty("/filterTrkorr") || "").trim().toUpperCase();
      if (sTrkorr) {
        var bWild = sTrkorr.indexOf("*") >= 0;
        sTrkorr = sTrkorr.replace(/\*/g, "").replace(/'/g, "''");
        if (sTrkorr) {
          aParts.push(bWild
            ? ("startswith(Trkorr,'" + sTrkorr + "')")
            : ("Trkorr eq '" + sTrkorr + "'"));
        }
      }

      var sOwner = (oM.getProperty("/filterOwner") || "").trim().toUpperCase();
      // Ignore placeholder text accidentally typed into the field
      if (sOwner && sOwner !== "USERNAME" && sOwner !== "USER") {
        sOwner = sOwner.replace(/\*/g, "").replace(/'/g, "''");
        if (sOwner) {
          aParts.push("startswith(Owner,'" + sOwner + "')");
        }
      }

      var sDateFrom = (oM.getProperty("/filterDateFrom") || "").trim();
      var sDateTo = (oM.getProperty("/filterDateTo") || "").trim();
      if (sDateFrom) {
        aParts.push("As4date ge '" + sDateFrom.replace(/'/g, "''") + "'");
      }
      if (sDateTo) {
        aParts.push("As4date le '" + sDateTo.replace(/'/g, "''") + "'");
      }

      var sStatus = (oM.getProperty("/filterStatus") || "").trim();
      if (sStatus) {
        aParts.push("TrStatus eq '" + sStatus.replace(/'/g, "''") + "'");
      }

      return aParts;
    },

    _buildTrODataFilter: function () {
      return this._buildTrODataFilterParts().join(" and ");
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
        case "FOLD": return "sap-icon://folder-blank";
        case "OBJ":  return "sap-icon://form";
        default:     return "sap-icon://document";
      }
    },

    formatNodeColor: function (sType) {
      switch ((sType || "").toUpperCase()) {
        case "TR":   return "#0070f2";
        case "TASK": return "#e9730c";
        case "FOLD": return "#d8b024";
        case "OBJ":  return "#188918";
        default:     return "#6a6d70";
      }
    }
  });
});
