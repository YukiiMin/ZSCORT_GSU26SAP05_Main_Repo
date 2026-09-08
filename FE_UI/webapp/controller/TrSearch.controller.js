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
        filterObjName:   "",
        filterObjType:   "",
        filterFlatObjName: "",
        filterFlatObjType: "",
        activeTab:       "tree",
        busyTree:        false,
        busyFlat:        false,
        countFlat:       0,
        flatRows:        [],
        noDataText:      "Enter search criteria and press Search"
      });
      oModel.setSizeLimit(100000);
      this.getView().setModel(oModel, "trSearch");

      var oSavedSettings = null;
      try {
        oSavedSettings = JSON.parse(localStorage.getItem("scort_flat_table_cols") || "null");
      } catch (e) { /* ignore */ }
      var oSettingsModel = new JSONModel(oSavedSettings || {
        showTrkorr: true,
        showManagingTr: true,
        showType: true,
        showName: true,
        showOwner: true,
        showStatus: true
      });
      this.getView().setModel(oSettingsModel, "tableSettings");

      var oRouter = this.getOwnerComponent().getRouter();
      if (oRouter) {
        ["trSearch", "home", "master", "detail", "compare", "trCompare"].forEach(function (sRoute) {
          var r = oRouter.getRoute(sRoute);
          if (r) {
            r.attachPatternMatched(this._onRouteMatched, this);
          }
        }, this);
      }

      this._app().setProperty("/currentModule", "trSearch");
    },

    _onRouteMatched: function (oEvent) {
      this._app().setProperty("/currentModule", "trSearch");
      this._ensureBeginVisible();

      var oArgs = oEvent && oEvent.getParameter && oEvent.getParameter("arguments");
      var oQuery = (oArgs && oArgs["?query"]) || {};
      if (oQuery.objectName || oQuery.objectType) {
        var oM = this.getView().getModel("trSearch");
        if (oQuery.objectName) {
          oM.setProperty("/filterObjName", oQuery.objectName);
          oM.setProperty("/filterFlatObjName", oQuery.objectName);
        }
        if (oQuery.objectType) {
          oM.setProperty("/filterObjType", oQuery.objectType);
          oM.setProperty("/filterFlatObjType", oQuery.objectType);
        }
        if (oQuery.tab) {
          oM.setProperty("/activeTab", oQuery.tab);
        }
        this.onSearch();
      }
    },

    _ensureBeginVisible: function () {
      try {
        var oRoot = this.getOwnerComponent().getRootControl();
        var oFcl = oRoot && oRoot.byId && oRoot.byId("fcl");
        if (!oFcl) {
          oFcl = sap.ui.getCore().byId("container-zscort.app---appView--fcl");
        }
        if (oFcl && typeof oFcl.toBeginColumnPage === "function") {
          oFcl.toBeginColumnPage(this.getView());
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
      var sObj = (oM.getProperty("/filterObjName") || "").trim();
      var sType = (oM.getProperty("/filterObjType") || "").trim();
      var sFrom = (oM.getProperty("/filterDateFrom") || "").trim();
      var sTo = (oM.getProperty("/filterDateTo") || "").trim();
      var sStat = (oM.getProperty("/filterStatus") || "").trim();

      if (!sTrk && !sOwn && !sObj && !sType && !sFrom && !sTo && !sStat) {
        MessageBox.warning(this._getText("msgEnterFilterCriteria") || "Please enter at least one filter criterion (Transport Request, Owner, or Object Name).");
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
      oM.setProperty("/filterObjName",   "");
      oM.setProperty("/filterObjType",   "");
      oM.setProperty("/filterFlatObjName", "");
      oM.setProperty("/filterFlatObjType", "");
      oM.setProperty("/flatRows", []);
      oM.setProperty("/countFlat", 0);
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
      var oTreeM = new JSONModel(oTreeData);
      oTreeM.setSizeLimit(100000);
      oTree.setModel(oTreeM, "trTree");
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
        MessageToast.show(this._getText("searchingTr") || "Searching TR…");
      }

      function finish(aFlat) {
        that._applyTreeRows(that._clientFilterTree(aFlat || []), bSilent);
      }
      function fail(oErr) {
        oM.setProperty("/busyTree", false);
        MessageBox.error("TR Tree OData Error: " + (oErr.message || oErr));
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
        var sType = oNode.ObjType;
        if (sType === "METH" || sType === "CPUB" || sType === "CPRI" || sType === "CPRO" || sType === "CLSD") {
          sType = "CLAS";
        } else if (sType === "FUNC" && oNode.ObjName && (oNode.ObjName.indexOf("UXX") > 0 || oNode.ObjName.indexOf("TOP") > 0)) {
          sType = "PROG";
        }
        this.navToCompare(sType, oNode.ObjName, "L", "BOTH");
      }
    },

    onTreeObjViewSource: function (oEvent) {
      var oCtx = oEvent.getSource().getBindingContext("trTree");
      if (!oCtx) { return; }
      var oNode = oCtx.getObject();
      if (oNode.NodeType === "OBJ" && oNode.ObjName && oNode.ObjType) {
        var sType = oNode.ObjType;
        if (sType === "METH" || sType === "CPUB" || sType === "CPRI" || sType === "CPRO" || sType === "CLSD") {
          sType = "CLAS";
        } else if (sType === "FUNC" && oNode.ObjName && (oNode.ObjName.indexOf("UXX") > 0 || oNode.ObjName.indexOf("TOP") > 0)) {
          sType = "PROG";
        }
        this._openSourceDialog(sType, oNode.ObjName, "L", oNode);
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
      var sObjName = (oM.getProperty("/filterObjName") || oM.getProperty("/filterFlatObjName") || "").trim().replace(/\*/g, "");
      var sObjType = (oM.getProperty("/filterObjType") || oM.getProperty("/filterFlatObjType") || "").trim();
      if (sObjName) {
        aParts.push("contains(ObjectName,'" + sObjName.replace(/'/g, "''") + "')");
      }
      if (sObjType) {
        aParts.push("ObjectType eq '" + sObjType.replace(/'/g, "''") + "'");
      }
      var sFilter = aParts.join(" and ");
      var sUrl = this._trServiceUri() + "TrObjectSearch" +
        (sFilter ? ("?$filter=" + encodeURIComponent(sFilter)) : "");

      oM.setProperty("/busyFlat", true);
      ValueHelp.fetchAllJson(sUrl, 60000).then(function (aData) {
        aData = aData || [];
        oM.setProperty("/countFlat", aData.length);
        oM.setProperty("/flatRows", aData);
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
      oM.setProperty("/flatRows", aMock);
      oM.setProperty("/busyFlat", false);
      this._bFlatLoaded = true;
      MessageToast.show("Mock Flat List data loaded");
    },

    onOpenFlatTableSettings: function () {
      if (!this._oFlatSettingsDialog) {
        this._oFlatSettingsDialog = sap.ui.xmlfragment(
          this.getView().getId(),
          "zscort.app.view.fragment.FlatTableSettingsDialog",
          this
        );
        this.getView().addDependent(this._oFlatSettingsDialog);
      }
      this._oFlatSettingsDialog.open();
    },

    onApplyFlatTableSettings: function () {
      var oSettings = this.getView().getModel("tableSettings").getData();
      try {
        localStorage.setItem("scort_flat_table_cols", JSON.stringify(oSettings));
      } catch (e) { /* ignore */ }
      if (this._oFlatSettingsDialog) {
        this._oFlatSettingsDialog.close();
      }
      MessageToast.show(this._getText("msgSettingsApplied") || "Table settings applied");
    },

    onCloseFlatTableSettings: function () {
      if (this._oFlatSettingsDialog) {
        this._oFlatSettingsDialog.close();
      }
    },

    onResetFlatTableLayout: function () {
      var oDefault = {
        showTrkorr: true,
        showManagingTr: true,
        showType: true,
        showName: true,
        showOwner: true,
        showStatus: true
      };
      this.getView().getModel("tableSettings").setData(oDefault);
      try {
        localStorage.removeItem("scort_flat_table_cols");
      } catch (e) { /* ignore */ }
      MessageToast.show(this._getText("msgLayoutReset") || "Layout reset to default");
    },

    onFlatRowSelect: function () {
      // Single row selection
    },

    onFlatObjCompare: function (oEvent) {
      var oCtx = oEvent.getSource().getBindingContext("trSearch");
      if (!oCtx) { return; }
      var oObj = oCtx.getObject();
      this.navToCompare(oObj.ObjectType, oObj.ObjectName, "L", "BOTH");
    },

    onFlatObjViewSource: function (oEvent) {
      var oCtx = oEvent.getSource().getBindingContext("trSearch");
      if (!oCtx) { return; }
      var oObj = oCtx.getObject();
      this._openSourceDialog(oObj.ObjectType, oObj.ObjectName, "L", oObj);
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

      var sObjName = (oM.getProperty("/filterObjName") || "").trim().replace(/\*/g, "");
      var sObjType = (oM.getProperty("/filterObjType") || "").trim();
      if (sObjName) {
        aParts.push("contains(ObjName,'" + sObjName.replace(/'/g, "''") + "')");
      }
      if (sObjType) {
        aParts.push("ObjType eq '" + sObjType.replace(/'/g, "''") + "'");
      }

      return aParts;
    },

    _buildTrODataFilter: function () {
      return this._buildTrODataFilterParts().join(" and ");
    },

    formatTrStatusText: function (sStatus) {
      switch ((sStatus || "").toUpperCase()) {
        case "D": return "Modifiable";
        case "R": return "Released";
        case "N": return "Released (protected)";
        default:  return sStatus || "";
      }
    },

    formatTrStatus: function (sStatus) {
      switch ((sStatus || "").toUpperCase()) {
        case "D": return ValueState.Warning;    // Modifiable = orange
        case "R": return ValueState.Success;    // Released   = green
        case "N": return ValueState.Success;
        default:  return ValueState.None;
      }
    },

    formatNodeIcon: function (sType) {
      switch ((sType || "").toUpperCase()) {
        case "TR":   return "sap-icon://transport-request";
        case "TASK": return "sap-icon://task";
        case "FOLD": return "sap-icon://folder-blank";
        case "OBJ":  return "sap-icon://form";
        case "ATTR": return "sap-icon://tag";
        case "COMM": return "sap-icon://notes";
        default:     return "sap-icon://document";
      }
    },

    formatNodeColor: function (sType) {
      switch ((sType || "").toUpperCase()) {
        case "TR":   return "#0070f2";
        case "TASK": return "#e9730c";
        case "FOLD": return "#d8b024";
        case "OBJ":  return "#188918";
        case "ATTR": return "#8b5cf6";
        case "COMM": return "#475569";
        default:     return "#6a6d70";
      }
    }
  });
});
