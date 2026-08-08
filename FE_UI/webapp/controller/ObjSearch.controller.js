sap.ui.define([
  "zscort/app/controller/BaseController",
  "sap/ui/model/json/JSONModel",
  "sap/m/MessageBox",
  "sap/m/MessageToast",
  "sap/ui/core/ValueState",
  "zscort/app/util/ValueHelp"
], function (BaseController, JSONModel, MessageBox, MessageToast, ValueState, ValueHelp) {
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
        matrixServerType: "L",
        matrixFilter:     "",
        localRows:  [],
        targetRows: [],
        matrixRows: [],
        noDataText: "Enter search criteria and press Search"
      });
      this.getView().setModel(oModel, "objSearch");

      this.getOwnerComponent().getRouter()
        .getRoute("objSearch")
        .attachPatternMatched(this._onRouteMatched, this);

      this._app().setProperty("/currentModule", "objSearch");
    },

    _onRouteMatched: function () {
      this._app().setProperty("/currentModule", "objSearch");
      try {
        var oFcl = this.getOwnerComponent().getRootControl().byId("fcl");
        if (oFcl && typeof oFcl.to === "function") {
          oFcl.to(this.getView().getId());
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
      // New criteria apply to all tabs — drop stale caches and refresh Local + Target + Matrix
      // so badge counts stay in sync (previously only the active tab was searched).
      this._invalidateAllTabs();
      this._searchLocal();
      this._searchTarget();
      this.onButtonSearchMatrixPress();
    },

    _invalidateAllTabs: function () {
      var oM = this.getView().getModel("objSearch");
      this._bLocalLoaded  = false;
      this._bTargetLoaded = false;
      this._bMatrixLoaded = false;
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
      var sPkgField = sKind === "matrix" ? "LocalPackage" : "PackageName";
      var sAuthorField = sKind === "matrix" ? "LocalAuthor" : "PersonResponsible";
      var bDefaultZ = !sObjName && !sPackage;

      return (aData || []).filter(function (o) {
        if (bDefaultZ) {
          if (String(o.ObjectName || "").toUpperCase().charAt(0) !== "Z") { return false; }
        } else if (sObjName && !that._clientMatchWildcard(o.ObjectName, sObjName)) {
          return false;
        }
        if (aTypes.length && aTypes.indexOf(o.ObjectType) < 0) { return false; }
        if (sPackage && !that._clientMatchWildcard(o[sPkgField], sPackage)) { return false; }
        if (sAuthor && !that._clientMatchWildcard(o[sAuthorField], sAuthor)) { return false; }
        return true;
      });
    },

    _serviceUri: function () {
      var oOdm = this.getOwnerComponent().getModel("objModel");
      var sUri = oOdm && oOdm.getServiceUrl && oOdm.getServiceUrl();
      return sUri || OBJ_SERVICE_URI;
    },

    _fetchEntitySet: function (sEntity, sFilter, iTop) {
      var sUrl = this._serviceUri().replace(/\/?$/, "/") + sEntity.replace(/^\//, "");
      var aQ = [];
      if (sFilter) {
        aQ.push("$filter=" + encodeURIComponent(sFilter));
      }
      if (iTop) {
        aQ.push("$top=" + iTop);
      }
      if (aQ.length) {
        sUrl += "?" + aQ.join("&");
      }
      return ValueHelp.fetchJson(sUrl, 20000);
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
        return;
      }

      oM.setProperty("/busyLocal", true);
      var sFilter = this._buildODataFilter("local");
      var that = this;

      this._fetchEntitySet("LocalObjects", sFilter, 500).then(function (aData) {
        var aFiltered = that._applyClientFilters(aData, "local");
        that._setRows("localRows", aFiltered, "countLocal");
        oM.setProperty("/busyLocal", false);
        that._bLocalLoaded = true;
        if (!aFiltered.length) {
          MessageToast.show("No local objects matched the filter");
        }
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
      var aFiltered = this._applyClientFilters(aMock, "local");
      this._setRows("localRows", aFiltered, "countLocal");
      this._bLocalLoaded = true;
      MessageToast.show("Mock data loaded - connect OData for live results");
    },

    _searchTarget: function () {
      var oM = this.getView().getModel("objSearch");
      var oOdm = this.getOwnerComponent().getModel("objModel");
      if (!oOdm) {
        this._loadTargetMock();
        return;
      }

      oM.setProperty("/busyTarget", true);
      var sFilter = this._buildODataFilter("target");
      var that = this;

      this._fetchEntitySet("TargetObjects", sFilter, 500).then(function (aData) {
        var aFiltered = that._applyClientFilters(aData, "target");
        that._setRows("targetRows", aFiltered, "countTarget");
        oM.setProperty("/busyTarget", false);
        that._bTargetLoaded = true;
        if (!aFiltered.length) {
          MessageToast.show("No target objects matched the filter");
        }
      }).catch(function (oErr) {
        oM.setProperty("/busyTarget", false);
        var sMsg = String(oErr && (oErr.message || oErr) || "");
        if (/\$kind|kind/i.test(sMsg)) {
          MessageToast.show("Target metadata/key error ($kind). Using mock data.");
        } else {
          MessageToast.show("Target OData error — using mock. " + sMsg);
        }
        that._loadTargetMock();
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

    /**
     * Build Compare Matrix client-side from LocalObjects + TargetObjects.
     * Used when /CompareMatrix dumps (UNION ALL + SADL $filter → HTTP 500).
     */
    _synthesizeMatrixFromSides: function () {
      var that = this;
      var oM = this.getView().getModel("objSearch");
      var sLocalFilter = this._buildODataFilter("local");
      var sTargetFilter = this._buildODataFilter("target");
      var sStatusFilter = oM.getProperty("/matrixFilter") || "";

      return Promise.all([
        this._fetchEntitySet("LocalObjects", sLocalFilter, 500).catch(function () { return []; }),
        this._fetchEntitySet("TargetObjects", sTargetFilter, 500).catch(function () { return []; })
      ]).then(function (aSides) {
        var aLocal = that._applyClientFilters(aSides[0] || [], "local");
        var aTarget = that._applyClientFilters(aSides[1] || [], "target");
        var mLocal = {};
        var mTarget = {};
        var aRows = [];

        aLocal.forEach(function (o) {
          mLocal[o.ObjectType + "|" + o.ObjectName] = o;
        });
        aTarget.forEach(function (o) {
          mTarget[o.ObjectType + "|" + o.ObjectName] = o;
        });

        Object.keys(mLocal).forEach(function (k) {
          var oL = mLocal[k];
          var oT = mTarget[k];
          aRows.push({
            ObjectType: oL.ObjectType,
            ObjectName: oL.ObjectName,
            ExistenceStatus: oT ? "BOTH" : "LOCAL_ONLY",
            LocalPackage: oL.PackageName || "",
            TargetPackage: oT ? (oT.PackageName || "") : "",
            LocalAuthor: oL.PersonResponsible || "",
            TargetAuthor: oT ? (oT.PersonResponsible || "") : "",
            ServerType: oM.getProperty("/matrixServerType") || "L"
          });
        });
        Object.keys(mTarget).forEach(function (k) {
          if (mLocal[k]) { return; }
          var oT = mTarget[k];
          aRows.push({
            ObjectType: oT.ObjectType,
            ObjectName: oT.ObjectName,
            ExistenceStatus: "TARGET_ONLY",
            LocalPackage: "",
            TargetPackage: oT.PackageName || "",
            LocalAuthor: "",
            TargetAuthor: oT.PersonResponsible || "",
            ServerType: oM.getProperty("/matrixServerType") || "L"
          });
        });

        if (sStatusFilter) {
          aRows = aRows.filter(function (o) { return o.ExistenceStatus === sStatusFilter; });
        }
        return aRows;
      });
    },

    onButtonSearchMatrixPress: function () {
      var oM = this.getView().getModel("objSearch");
      var that = this;

      // Do NOT call CompareMatrix OData — ZCR_SCORT_OBJ_M (UNION ALL) dumps on S40:
      // ST22 CX_SADL_DUMP_APPL_MODEL_ERROR / STOB ZCR_SCORT_OBJ_M.
      // Existence = synthesize from LocalObjects + TargetObjects only.
      oM.setProperty("/busyMatrix", true);
      this._synthesizeMatrixFromSides().then(function (aRows) {
        that._setRows("matrixRows", aRows, "countMatrix");
        oM.setProperty("/busyMatrix", false);
        that._bMatrixLoaded = true;
        var nLocalOnly = aRows.filter(function (r) { return r.ExistenceStatus === "LOCAL_ONLY"; }).length;
        var nBoth = aRows.filter(function (r) { return r.ExistenceStatus === "BOTH"; }).length;
          MessageToast.show("Existence: " + nBoth + " BOTH, " + nLocalOnly + " LOCAL_ONLY");
      }).catch(function () {
        oM.setProperty("/busyMatrix", false);
        that._loadMatrixMock();
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
        { ObjectType: "CLAS", ObjectName: "ZCL_SCORT_R_SRC",           ExistenceStatus: "BOTH",        LocalPackage: "ZSCORT_SAP05", TargetPackage: "ZSCORT_TARGET", LocalAuthor: "DEVELOPER" },
        { ObjectType: "DDLS", ObjectName: "ZIR_SCORT_OBJ_L",           ExistenceStatus: "BOTH",        LocalPackage: "ZSCORT_SAP05", TargetPackage: "ZSCORT_TARGET", LocalAuthor: "DEVELOPER" },
        { ObjectType: "CLAS", ObjectName: "ZCL_SCORT_COMPRESSION_UTL", ExistenceStatus: "LOCAL_ONLY",  LocalPackage: "ZSCORT_SAP05", TargetPackage: "", LocalAuthor: "DEVELOPER" },
        { ObjectType: "TABL", ObjectName: "ZA_SCORT_T",                ExistenceStatus: "LOCAL_ONLY",  LocalPackage: "ZSCORT_SAP05", TargetPackage: "", LocalAuthor: "DEVELOPER" },
        { ObjectType: "PROG", ObjectName: "ZOLD_PROG_AT_TARGET",       ExistenceStatus: "TARGET_ONLY", LocalPackage: "",             TargetPackage: "ZSCORT_TARGET", LocalAuthor: "" }
      ];
      var sStatusFilter = oM.getProperty("/matrixFilter") || "";
      var aFiltered = this._applyClientFilters(aMock, "matrix");
      if (sStatusFilter) {
        aFiltered = aFiltered.filter(function (o) { return o.ExistenceStatus === sStatusFilter; });
      }
      this._setRows("matrixRows", aFiltered, "countMatrix");
      this._bMatrixLoaded = true;
      MessageToast.show("Sample existence rows (offline)");
    },

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

    onColumnListItemViewSourcePress: function (oEvent) { this.onButtonViewSourcePress(oEvent); },

    onButtonViewSourcePress: function (oEvent) {
      var oCtx = oEvent.getSource().getBindingContext("objSearch");
      if (!oCtx) { return; }
      var oObj = oCtx.getObject();

      var sServerType = oObj.ServerType || "L";
      var sPath = oCtx.getPath() || "";
      if (sPath.indexOf("targetRows") > -1 || sPath.indexOf("TargetObjects") > -1) { sServerType = "T"; }
      if (oObj.ExistenceStatus === "TARGET_ONLY") { sServerType = "T"; }
      if (oObj.ExistenceStatus === "LOCAL_ONLY") { sServerType = "L"; }
      if (oObj.ExistenceStatus === "BOTH") {
        sServerType = this.getView().getModel("objSearch").getProperty("/matrixServerType") || "L";
      }

      this._openSourceDialog(oObj.ObjectType, oObj.ObjectName, sServerType);
    },

    onButtonExportLocalPress: function () {
      MessageToast.show("Export Local — TODO: use sap.ui.export.Spreadsheet");
    },

    onButtonExportTargetPress: function () {
      MessageToast.show("Export Target — TODO: use sap.ui.export.Spreadsheet");
    },

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
