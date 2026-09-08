sap.ui.define([
  "zscort/app/controller/BaseController",
  "sap/ui/model/json/JSONModel",
  "sap/m/MessageBox",
  "sap/m/MessageToast",
  "sap/ui/core/ValueState",
  "zscort/app/util/ValueHelp",
  "sap/ui/model/Filter",
  "sap/ui/model/FilterOperator",
  "sap/ui/model/Sorter"
], function (BaseController, JSONModel, MessageBox, MessageToast, ValueState, ValueHelp, Filter, FilterOperator, Sorter) {
  "use strict";

  var OBJ_SERVICE_URI = "/sap/opu/odata4/sap/zui_scort_obj_search_o4/srvd/sap/zsd_scort_obj_search/0001/";

  return BaseController.extend("zscort.app.controller.ObjSearch", {

    onInit: function () {
      var oModel = new JSONModel({
        filterObjName:   "",
        filterObjTypes:  [],
        filterPackage:   "",
        filterAuthor:    "",
        activeTab:       "local",
        countLocal:  0,
        countTarget: 0,
        countMatrix: 0,
        busyLocal:  false,
        busyTarget: false,
        busyMatrix: false,
        loadingMoreLocal:  false,
        loadingMoreTarget: false,
        matrixServerType: "L",
        matrixFilter:     "",
        localRows:  [],
        targetRows: [],
        matrixRows: [],
        noDataText: "Enter search criteria and press Search"
      });
      oModel.setSizeLimit(100000);
      this.getView().setModel(oModel, "objSearch");

      var oRouter = this.getOwnerComponent().getRouter();
      if (oRouter) {
        var oRoute = oRouter.getRoute("objSearch");
        if (oRoute) {
          oRoute.attachPatternMatched(this._onRouteMatched, this);
        }
        var oObjCmpRoute = oRouter.getRoute("objCompare");
        if (oObjCmpRoute) {
          oObjCmpRoute.attachPatternMatched(this._onRouteMatched, this);
        }
      }
      this._app().setProperty("/currentModule", "objSearch");
    },

    _onRouteMatched: function () {
      this._app().setProperty("/currentModule", "objSearch");
      this._ensureBeginVisible();
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

    onSegmentedButtonModuleSwitchSelectionChange: function (oEvent) {
      var sKey = oEvent.getParameter("item").getKey();
      switch (sKey) {
        case "trSearch": this.onNavTrSearch(); break;
        case "compare":  this.onNavCompare();  break;
        default: break;
      }
    },

    onButtonNavObjSearchPress: function () {
      return BaseController.prototype.onButtonNavObjSearchPress.apply(this, arguments);
    },
    onButtonNavTrReleasePress: function () {
      try {
        this.onNavTrSearch();
      } catch (oErr) {
        // eslint-disable-next-line no-console
        console.error("onButtonNavTrReleasePress failed:", oErr);
        MessageToast.show("Could not open TR Search: " + (oErr && oErr.message || oErr));
      }
    },
    onDialogViewSourceAfterClose: function () {
      return BaseController.prototype.onDialogViewSourceAfterClose.apply(this, arguments);
    },
    onButtonCloseDialogPress: function () {
      return BaseController.prototype.onButtonCloseDialogPress.apply(this, arguments);
    },
    onDialogViewSourceAfterOpen: function () {
      return BaseController.prototype.onDialogViewSourceAfterOpen.apply(this, arguments);
    },

    onSearchButtonPress: function () {
      var oM = this.getView().getModel("objSearch");
      var sObj = (oM.getProperty("/filterObjName") || "").trim();
      var sPkg = (oM.getProperty("/filterPackage") || "").trim();
      var sOwn = (oM.getProperty("/filterAuthor") || "").trim();

      if (!sObj && !sPkg && !sOwn) {
        MessageBox.warning(this._getText("msgEnterAtLeastOneFilter") || "Please enter at least 1 filter criterion (Object Name, Package, or Person Responsible).");
        return;
      }

      this._invalidateAllTabs();
      oM.setProperty("/busyMatrix", true);

      var pLocal = this._searchLocal();
      var pTarget = this._searchTarget();
      var that = this;

      Promise.all([pLocal, pTarget]).then(function () {
        that._searchMatrix();
        oM.setProperty("/busyMatrix", false);
      }).catch(function () {
        that._searchMatrix();
        oM.setProperty("/busyMatrix", false);
      });
    },

    _invalidateAllTabs: function () {
      var oM = this.getView().getModel("objSearch");
      this._bLocalLoaded  = false;
      this._bTargetLoaded = false;
      this._bMatrixLoaded = false;
      this._aRawMatrixData = [];
      this._aRawLocalData = [];
      this._aRawTargetData = [];
      this._nextLinkLocal = null;
      this._nextLinkTarget = null;
      this._bFetchingLocal = false;
      this._bFetchingTarget = false;
      oM.setProperty("/loadingMoreLocal", false);
      oM.setProperty("/loadingMoreTarget", false);
      oM.setProperty("/localRows", []);
      oM.setProperty("/targetRows", []);
      oM.setProperty("/matrixRows", []);
      oM.setProperty("/countLocal", 0);
      oM.setProperty("/countTarget", 0);
      oM.setProperty("/countMatrix", 0);
    },

    onFilterObjNameInputSubmit: function () { this.onSearchButtonPress(); },
    onFilterPackageInputSubmit: function () { this.onSearchButtonPress(); },
    onFilterAuthorInputSubmit: function () { this.onSearchButtonPress(); },

    onIconTabBarModeSelect: function (oEvent) {
      var sKey = oEvent.getParameter("key");
      this.getView().getModel("objSearch").setProperty("/activeTab", sKey);
      // Lazy load only if this tab was never loaded for the current filter set
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
      this._invalidateAllTabs();
    },

    _escapeOData: function (s) {
      return String(s || "").replace(/'/g, "''");
    },

    /**
     * ZSCORT* → startswith; *FOO* → contains; *FOO → endswith; FOO → contains
     */
    _wildcardToClause: function (sField, sPattern) {
      var sRaw = (sPattern || "").trim();
      if (!sRaw) { return ""; }
      var sVal = sRaw.toUpperCase();
      var bLeadStar = sVal.charAt(0) === "*";
      var bTrailStar = sVal.charAt(sVal.length - 1) === "*";
      var sCore = sVal.replace(/\*/g, "");
      if (!sCore) { return ""; }
      var sEsc = this._escapeOData(sCore);
      // mid-wildcard e.g. FOO*BAR → contains
      if (sVal.indexOf("*") > 0 && sVal.indexOf("*") < sVal.length - 1) {
        return "contains(" + sField + ",'" + sEsc + "')";
      }
      if (!bLeadStar && bTrailStar) {
        return "startswith(" + sField + ",'" + sEsc + "')";
      }
      if (bLeadStar && !bTrailStar) {
        return "endswith(" + sField + ",'" + sEsc + "')";
      }
      return "contains(" + sField + ",'" + sEsc + "')";
    },

    _clientMatchWildcard: function (sValue, sPattern) {
      var sRaw = (sPattern || "").trim();
      if (!sRaw) { return true; }
      var sVal = String(sValue || "").toUpperCase();
      var sPat = sRaw.toUpperCase();
      var bLeadStar = sPat.charAt(0) === "*";
      var bTrailStar = sPat.charAt(sPat.length - 1) === "*";
      var sCore = sPat.replace(/\*/g, "");
      if (!sCore) { return true; }
      if (sPat.indexOf("*") > 0 && sPat.indexOf("*") < sPat.length - 1) {
        return sVal.indexOf(sCore) >= 0;
      }
      if (!bLeadStar && bTrailStar) {
        return sVal.indexOf(sCore) === 0;
      }
      if (bLeadStar && !bTrailStar) {
        return sVal.length >= sCore.length &&
          sVal.lastIndexOf(sCore) === sVal.length - sCore.length;
      }
      return sVal.indexOf(sCore) >= 0;
    },

    _buildODataFilter: function (sKind) {
      var oM = this.getView().getModel("objSearch");
      var aParts = [];
      var bMatrix = sKind === "matrix";
      var sPkgField = bMatrix ? "LocalPackage" : "PackageName";
      var sAuthorField = bMatrix ? "LocalAuthor" : "PersonResponsible";

      var sObjName = (oM.getProperty("/filterObjName") || "").trim();
      var sPackage = (oM.getProperty("/filterPackage") || "").trim();
      var aTypes = oM.getProperty("/filterObjTypes") || [];

      // Matrix = UNION ALL (ZIR_SCORT_OBJ_M). SADL dumps (HTTP 500 / RAISE_SHORTDUMP) on
      // startswith/contains/$filter of non-key columns and often even ExistenceStatus.
      // Server-side: only ObjectType eq / ObjectName eq (exact, no wildcards). Everything
      // else is applied client-side in _applyClientFilters.
      if (bMatrix) {
        if (aTypes.length === 1) {
          aParts.push("ObjectType eq '" + this._escapeOData(aTypes[0]) + "'");
        } else if (aTypes.length > 1) {
          aParts.push("(" + aTypes.map(function (t) {
            return "ObjectType eq '" + String(t).replace(/'/g, "''") + "'";
          }).join(" or ") + ")");
        }
        if (sObjName && sObjName.indexOf("*") < 0) {
          aParts.push("ObjectName eq '" + this._escapeOData(sObjName.toUpperCase()) + "'");
        } else if (!sObjName && !sPackage && aTypes.length === 0) {
          // Still need a bound — prefer ObjectType PROG as safest narrow key for demo,
          // but leave empty and let client synthesize from Local+Target on failure.
        }
        return aParts.filter(Boolean).join(" and ");
      }

      // Avoid dumping full TADIR: default ObjectName starts with Z when both name/package empty
      if (!sObjName && !sPackage) {
        aParts.push("startswith(ObjectName,'Z')");
      } else if (sObjName) {
        aParts.push(this._wildcardToClause("ObjectName", sObjName));
      }

      if (aTypes.length === 1) {
        aParts.push("ObjectType eq '" + this._escapeOData(aTypes[0]) + "'");
      } else if (aTypes.length > 1) {
        aParts.push("(" + aTypes.map(function (t) {
          return "ObjectType eq '" + String(t).replace(/'/g, "''") + "'";
        }).join(" or ") + ")");
      }

      if (sPackage) {
        aParts.push(this._wildcardToClause(sPkgField, sPackage));
      }

      var sAuthor = (oM.getProperty("/filterAuthor") || "").trim();
      if (sAuthor) {
        aParts.push(this._wildcardToClause(sAuthorField, sAuthor));
      }

      if (sKind === "target") {
        aParts.push("ServerId eq 'TARGET'");
      }

      return aParts.filter(Boolean).join(" and ");
    },

    _applyClientFilters: function (aData, sKind) {
      var oM = this.getView().getModel("objSearch");
      var that = this;
      var sObjName = (oM.getProperty("/filterObjName") || "").trim();
      var sPackage = (oM.getProperty("/filterPackage") || "").trim();
      var sAuthor = (oM.getProperty("/filterAuthor") || "").trim();
      var aTypes = oM.getProperty("/filterObjTypes") || [];
      var bDefaultZ = !sObjName && !sPackage;

      return (aData || []).filter(function (o) {
        if (bDefaultZ) {
          if (String(o.ObjectName || "").toUpperCase().charAt(0) !== "Z") { return false; }
        } else if (sObjName && !that._clientMatchWildcard(o.ObjectName, sObjName)) {
          return false;
        }
        if (aTypes.length && aTypes.indexOf(o.ObjectType) < 0) { return false; }

        if (sPackage) {
          if (sKind === "matrix") {
            var bPkgMatch = that._clientMatchWildcard(o.LocalPackage, sPackage) || that._clientMatchWildcard(o.TargetPackage, sPackage);
            if (!bPkgMatch) { return false; }
          } else {
            if (!that._clientMatchWildcard(o.PackageName, sPackage)) { return false; }
          }
        }

        if (sAuthor) {
          if (sKind === "matrix") {
            var bAuthorMatch = that._clientMatchWildcard(o.LocalAuthor, sAuthor) || that._clientMatchWildcard(o.TargetAuthor, sAuthor);
            if (!bAuthorMatch) { return false; }
          } else {
            if (!that._clientMatchWildcard(o.PersonResponsible, sAuthor)) { return false; }
          }
        }

        return true;
      });
    },

    _serviceUri: function () {
      var oOdm = this.getOwnerComponent().getModel("objModel");
      var sUri = oOdm && oOdm.getServiceUrl && oOdm.getServiceUrl();
      return sUri || OBJ_SERVICE_URI;
    },

    _buildEntityUrl: function (sEntity, sFilter) {
      var sUrl = this._serviceUri().replace(/\/?$/, "/") + sEntity.replace(/^\//, "");
      if (sFilter) {
        sUrl += "?$filter=" + encodeURIComponent(sFilter);
      }
      return sUrl;
    },

    _setRows: function (sProp, aData, sCountProp) {
      var oM = this.getView().getModel("objSearch");
      var a = aData || [];
      oM.setProperty("/" + sProp, a);
      if (sCountProp) {
        oM.setProperty("/" + sCountProp, a.length);
      }
    },

    _searchLocal: function () {
      var oM = this.getView().getModel("objSearch");
      var oOdm = this.getOwnerComponent().getModel("objModel");
      if (!oOdm) {
        this._loadLocalMock();
        return Promise.resolve();
      }

      oM.setProperty("/busyLocal", true);
      oM.setProperty("/loadingMoreLocal", false);
      var sFilter = this._buildODataFilter("local");
      var sUrl = this._buildEntityUrl("LocalObjects", sFilter);
      var that = this;

      this._bFetchingLocal = true;
      this._aRawLocalData = [];
      this._nextLinkLocal = null;

      return ValueHelp.fetchProgressiveJson(sUrl, function (aAllSoFar, aChunk, bHasMore, sNextLink) {
        that._nextLinkLocal = sNextLink;
        that._aRawLocalData = aAllSoFar;
        var aFiltered = that._applyClientFilters(aAllSoFar, "local");
        that._setRows("localRows", aFiltered, "countLocal");
        oM.setProperty("/busyLocal", false);
        oM.setProperty("/loadingMoreLocal", bHasMore);
        that._bLocalLoaded = true;
        that._searchMatrix();
      }, 90000).then(function (aData) {
        that._bFetchingLocal = false;
        that._nextLinkLocal = null;
        that._aRawLocalData = aData;
        var aFiltered = that._applyClientFilters(aData, "local");
        that._setRows("localRows", aFiltered, "countLocal");
        oM.setProperty("/busyLocal", false);
        oM.setProperty("/loadingMoreLocal", false);
        that._bLocalLoaded = true;
        that._searchMatrix();
        if (!aFiltered.length) {
          MessageToast.show(that._getText("noData") || "No local objects matched the filter");
        }
        return aFiltered;
      }).catch(function (oErr) {
        that._bFetchingLocal = false;
        oM.setProperty("/busyLocal", false);
        oM.setProperty("/loadingMoreLocal", false);
        if (!that._aRawLocalData || !that._aRawLocalData.length) {
          that._setRows("localRows", [], "countLocal");
          MessageBox.error("OData Local Error: " + (oErr.message || oErr));
        }
        return that._aRawLocalData || [];
      });
    },

    onLocalTableScroll: function (oEvent) {
      var iFirst = oEvent.getParameter("firstVisibleRow");
      var oTable = this.byId("idLocalTable");
      var iVisibleCount = oTable ? oTable.getVisibleRowCount() : 20;
      var aRows = this._aRawLocalData || [];

      if (this._nextLinkLocal && !this._bFetchingLocal && (iFirst + iVisibleCount >= aRows.length - 25)) {
        this._fetchNextLocalChunk();
      }
    },

    _fetchNextLocalChunk: function () {
      if (!this._nextLinkLocal || this._bFetchingLocal) { return; }
      this._bFetchingLocal = true;
      var that = this;
      var oM = this.getView().getModel("objSearch");
      oM.setProperty("/loadingMoreLocal", true);

      ValueHelp.fetchPageJson(this._nextLinkLocal, 30000).then(function (oPage) {
        that._bFetchingLocal = false;
        that._nextLinkLocal = oPage.nextLink;
        that._aRawLocalData = (that._aRawLocalData || []).concat(oPage.data || []);
        var aFiltered = that._applyClientFilters(that._aRawLocalData, "local");
        that._setRows("localRows", aFiltered, "countLocal");
        oM.setProperty("/loadingMoreLocal", !!oPage.nextLink);
        that._searchMatrix();
      }).catch(function () {
        that._bFetchingLocal = false;
        oM.setProperty("/loadingMoreLocal", false);
      });
    },

    _loadLocalMock: function () {
      var aFiltered = this._applyClientFilters([], "local");
      this._setRows("localRows", aFiltered, "countLocal");
      this._bLocalLoaded = true;
    },

    _searchTarget: function () {
      var oM = this.getView().getModel("objSearch");
      var oOdm = this.getOwnerComponent().getModel("objModel");
      if (!oOdm) {
        this._loadTargetMock();
        return Promise.resolve();
      }

      oM.setProperty("/busyTarget", true);
      oM.setProperty("/loadingMoreTarget", false);
      var sFilter = this._buildODataFilter("target");
      var sUrl = this._buildEntityUrl("TargetObjects", sFilter);
      var that = this;

      this._bFetchingTarget = true;
      this._aRawTargetData = [];
      this._nextLinkTarget = null;

      return ValueHelp.fetchProgressiveJson(sUrl, function (aAllSoFar, aChunk, bHasMore, sNextLink) {
        that._nextLinkTarget = sNextLink;
        that._aRawTargetData = aAllSoFar;
        var aFiltered = that._applyClientFilters(aAllSoFar, "target");
        that._setRows("targetRows", aFiltered, "countTarget");
        oM.setProperty("/busyTarget", false);
        oM.setProperty("/loadingMoreTarget", bHasMore);
        that._bTargetLoaded = true;
        that._searchMatrix();
      }, 90000).then(function (aData) {
        that._bFetchingTarget = false;
        that._nextLinkTarget = null;
        that._aRawTargetData = aData;
        var aFiltered = that._applyClientFilters(aData, "target");
        that._setRows("targetRows", aFiltered, "countTarget");
        oM.setProperty("/busyTarget", false);
        oM.setProperty("/loadingMoreTarget", false);
        that._bTargetLoaded = true;
        that._searchMatrix();
        if (!aFiltered.length) {
          MessageToast.show(that._getText("noData") || "No target objects matched the filter");
        }
        return aFiltered;
      }).catch(function (oErr) {
        that._bFetchingTarget = false;
        oM.setProperty("/busyTarget", false);
        oM.setProperty("/loadingMoreTarget", false);
        if (!that._aRawTargetData || !that._aRawTargetData.length) {
          that._setRows("targetRows", [], "countTarget");
          MessageBox.error("OData Target Error: " + (oErr.message || oErr));
        }
        return that._aRawTargetData || [];
      });
    },

    onTargetTableScroll: function (oEvent) {
      var iFirst = oEvent.getParameter("firstVisibleRow");
      var oTable = this.byId("idTargetTable");
      var iVisibleCount = oTable ? oTable.getVisibleRowCount() : 20;
      var aRows = this._aRawTargetData || [];

      if (this._nextLinkTarget && !this._bFetchingTarget && (iFirst + iVisibleCount >= aRows.length - 25)) {
        this._fetchNextTargetChunk();
      }
    },

    _fetchNextTargetChunk: function () {
      if (!this._nextLinkTarget || this._bFetchingTarget) { return; }
      this._bFetchingTarget = true;
      var that = this;
      var oM = this.getView().getModel("objSearch");
      oM.setProperty("/loadingMoreTarget", true);

      ValueHelp.fetchPageJson(this._nextLinkTarget, 30000).then(function (oPage) {
        that._bFetchingTarget = false;
        that._nextLinkTarget = oPage.nextLink;
        that._aRawTargetData = (that._aRawTargetData || []).concat(oPage.data || []);
        var aFiltered = that._applyClientFilters(that._aRawTargetData, "target");
        that._setRows("targetRows", aFiltered, "countTarget");
        oM.setProperty("/loadingMoreTarget", !!oPage.nextLink);
        that._searchMatrix();
      }).catch(function () {
        that._bFetchingTarget = false;
        oM.setProperty("/loadingMoreTarget", false);
      });
    },

    _loadTargetMock: function () {
      var aMock = [
        { ObjectType: "CLAS", ObjectName: "ZCL_SCORT_R_SRC",   PackageName: "ZSCORT_TARGET", PersonResponsible: "DEVELOPER", ChangedOn: "20260201", ServerId: "TARGET" },
        { ObjectType: "DDLS", ObjectName: "ZIR_SCORT_OBJ_L",   PackageName: "ZSCORT_TARGET", PersonResponsible: "DEVELOPER", ChangedOn: "20260201", ServerId: "TARGET" }
      ];
      var aFiltered = this._applyClientFilters(aMock, "target");
      this._setRows("targetRows", aFiltered, "countTarget");
      this._bTargetLoaded = true;
      MessageToast.show("Mock Target data loaded");
    },

    _searchMatrix: function () {
      var oM = this.getView().getModel("objSearch");
      var aLocal = oM.getProperty("/localRows") || [];
      var aTarget = oM.getProperty("/targetRows") || [];

      var mLocal = {};
      var aMatrix = [];

      aLocal.forEach(function (l) {
        var sKey = (l.ObjectType || "").trim() + "_" + (l.ObjectName || "").trim();
        mLocal[sKey] = l;
      });

      var mTarget = {};
      aTarget.forEach(function (t) {
        var sKey = (t.ObjectType || "").trim() + "_" + (t.ObjectName || "").trim();
        mTarget[sKey] = t;
      });

      // 1. Process all local objects
      aLocal.forEach(function (l) {
        var sKey = (l.ObjectType || "").trim() + "_" + (l.ObjectName || "").trim();
        var oTarget = mTarget[sKey];
        if (oTarget) {
          aMatrix.push({
            ObjectType: l.ObjectType,
            ObjectName: l.ObjectName,
            ExistenceStatus: "BOTH",
            LocalPackage: l.PackageName,
            TargetPackage: oTarget.PackageName,
            LocalAuthor: l.PersonResponsible,
            TargetAuthor: oTarget.PersonResponsible
          });
        } else {
          aMatrix.push({
            ObjectType: l.ObjectType,
            ObjectName: l.ObjectName,
            ExistenceStatus: "LOCAL_ONLY",
            LocalPackage: l.PackageName,
            TargetPackage: "",
            LocalAuthor: l.PersonResponsible,
            TargetAuthor: ""
          });
        }
      });

      // 2. Add TARGET_ONLY objects
      aTarget.forEach(function (t) {
        var sKey = (t.ObjectType || "").trim() + "_" + (t.ObjectName || "").trim();
        if (!mLocal[sKey]) {
          aMatrix.push({
            ObjectType: t.ObjectType,
            ObjectName: t.ObjectName,
            ExistenceStatus: "TARGET_ONLY",
            LocalPackage: "",
            TargetPackage: t.PackageName,
            LocalAuthor: "",
            TargetAuthor: t.PersonResponsible
          });
        }
      });

      this._aRawMatrixData = aMatrix;
      this._filterAndDisplayMatrix();
      this._bMatrixLoaded = true;
    },

    _filterAndDisplayMatrix: function () {
      var oM = this.getView().getModel("objSearch");
      var aRaw = this._aRawMatrixData || [];
      var aFiltered = this._applyClientFilters(aRaw, "matrix");
      var sStatusFilter = oM.getProperty("/matrixFilter") || "";
      if (sStatusFilter) {
        aFiltered = aFiltered.filter(function (o) {
          return o.ExistenceStatus === sStatusFilter;
        });
      }
      this._setRows("matrixRows", aFiltered, "countMatrix");
    },

    onButtonSearchMatrixPress: function () {
      if (!this._aRawMatrixData || !this._bMatrixLoaded) {
        this._searchMatrix();
      } else {
        this._filterAndDisplayMatrix();
      }
    },

    onSegmentedButtonMatrixServerSwitchSelectionChange: function () {
      this._bMatrixLoaded = false;
      this._searchMatrix();
    },

    onSegmentedButtonMatrixFilterSelectionChange: function () {
      this._filterAndDisplayMatrix();
    },

    _loadMatrixMock: function () {
      var oM = this.getView().getModel("objSearch");
      var aMock = [
        { ObjectType: "CLAS", ObjectName: "ZCL_SCORT_R_SRC",           ExistenceStatus: "BOTH",        LocalPackage: "ZSCORT_SAP05", TargetPackage: "ZSCORT_TARGET", LocalAuthor: "DEVELOPER" },
        { ObjectType: "DDLS", ObjectName: "ZIR_SCORT_OBJ_L",           ExistenceStatus: "BOTH",        LocalPackage: "ZSCORT_SAP05", TargetPackage: "ZSCORT_TARGET", LocalAuthor: "DEVELOPER" },
        { ObjectType: "CLAS", ObjectName: "ZCL_SCORT_COMPRESSION_UTL", ExistenceStatus: "LOCAL_ONLY",  LocalPackage: "ZSCORT_SAP05", TargetPackage: "", LocalAuthor: "DEVELOPER" },
        { ObjectType: "TABL", ObjectName: "ZA_SCORT_T",                ExistenceStatus: "LOCAL_ONLY",  LocalPackage: "ZSCORT_SAP05", TargetPackage: "", LocalAuthor: "DEVELOPER" },
        { ObjectType: "PROG", ObjectName: "ZOLD_PROG_AT_TARGET",       ExistenceStatus: "TARGET_ONLY", LocalPackage: "",             TargetPackage: "ZSCORT_TARGET", LocalAuthor: "" }
      ];
      this._aRawMatrixData = aMock;
      this._filterAndDisplayMatrix();
      this._bMatrixLoaded = true;
      MessageToast.show("Sample existence rows (offline)");
    },

    onTableLocalSelectionChange: function (oEvent) {
      var oCtx = oEvent.getParameter("rowContext");
      if (!oCtx) {
        var iIndex = oEvent.getParameter("rowIndex");
        var oTable = oEvent.getSource();
        if (iIndex >= 0 && oTable) {
          oCtx = oTable.getContextByIndex(iIndex);
        }
      }
      if (!oCtx) { return; }
      var oObj = oCtx.getObject();
      this.navToCompare(oObj.ObjectType, oObj.ObjectName, "L", "BOTH");
    },

    onTableTargetSelectionChange: function (oEvent) {
      var oCtx = oEvent.getParameter("rowContext");
      if (!oCtx) {
        var iIndex = oEvent.getParameter("rowIndex");
        var oTable = oEvent.getSource();
        if (iIndex >= 0 && oTable) {
          oCtx = oTable.getContextByIndex(iIndex);
        }
      }
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

    onButtonCompareLocalPress: function (oEvent) {
      this.onButtonOpenComparePress(oEvent);
    },

    onButtonViewSourceLocalPress: function (oEvent) {
      this.onButtonViewSourcePress(oEvent);
    },

    onButtonOpenComparePress: function (oEvent) {
      var oCtx = oEvent.getSource().getBindingContext("objSearch");
      if (!oCtx) { return; }
      var oObj = oCtx.getObject();
      var sServer = oObj.ExistenceStatus === "TARGET_ONLY" ? "T" : "L";
      this.navToCompare(oObj.ObjectType, oObj.ObjectName, sServer, oObj.ExistenceStatus || "BOTH");
    },

    onColumnListItemViewSourcePress: function (oEvent) { this.onButtonViewSourcePress(oEvent); },

    onButtonViewSourcePress: function (oEvent) {
      var oCtx = oEvent.getSource().getBindingContext("objSearch");
      if (!oCtx) { return; }
      var oObj = oCtx.getObject();

      var sServerType = oObj.ServerType || "L";
      var sPath = oCtx.getPath() || "";
      if (sPath.indexOf("targetRows") > -1 || sPath.indexOf("TargetObjects") > -1) { 
        sServerType = "T"; 
      } else if (sPath.indexOf("matrixRows") > -1) {
        // Honor the user's "View code as server: Local | Target" segmented button in Existence tab
        sServerType = this.getView().getModel("objSearch").getProperty("/matrixServerType") || "L";
      }

      this._openSourceDialog(oObj.ObjectType, oObj.ObjectName, sServerType, oObj);
    },

    onButtonFindAssignedTrPress: function (oEvent) {
      var oCtx = oEvent.getSource().getBindingContext("objSearch");
      if (!oCtx) { return; }
      var oObj = oCtx.getObject();
      this.getOwnerComponent().getRouter().navTo("trSearch", {
        "?query": {
          objectName: oObj.ObjectName || "",
          objectType: oObj.ObjectType || "",
          tab: "flat"
        }
      });
    },

    onButtonExportLocalPress: function () {
      MessageToast.show("Export Local — TODO: use sap.ui.export.Spreadsheet");
    },

    onButtonExportTargetPress: function () {
      MessageToast.show("Export Target — TODO: use sap.ui.export.Spreadsheet");
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
