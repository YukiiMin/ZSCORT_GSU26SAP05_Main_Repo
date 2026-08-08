sap.ui.define([
  "zscort/app/controller/BaseController",
  "sap/ui/model/json/JSONModel",
  "sap/m/MessageBox",
  "sap/m/MessageToast",
  "sap/f/library",
  "sap/ui/core/ValueState",
  "sap/ui/model/Filter",
  "sap/ui/model/FilterOperator",
  "zscort/app/monaco/DiffHost",
  "zscort/app/util/ValueHelp"
], function (
  BaseController,
  JSONModel,
  MessageBox,
  MessageToast,
  fLibrary,
  ValueState,
  Filter,
  FilterOperator,
  DiffHost,
  ValueHelp
) {
  "use strict";

  var LayoutType = fLibrary.LayoutType;

  function padVers(v) {
    var s = String(v === undefined || v === null ? "" : v).trim();
    if (!s) { return ""; }
    if (/^\d+$/.test(s)) { return ("00000" + s).slice(-5); }
    return s.toUpperCase();
  }

  function versionLabel(oVers) {
    var sKey = padVers(oVers && oVers.VersionNo);
    if (!sKey || sKey === "00000") { return ""; }
    if (sKey === "99998") {
      var sMsgA = (oVers.Message || "").trim();
      return sMsgA && /^active/i.test(sMsgA) ? sMsgA : "Active";
    }
    var sNum  = sKey.replace(/^0+/, "") || "0";
    var sMsg  = (oVers.Message || "").trim();
    if (sMsg && !/^\d{5}\b/.test(sMsg) && sMsg.indexOf("REPS/") !== 0) {
      if (sMsg === sNum || sMsg.indexOf(sNum + " —") === 0 || sMsg.indexOf(sNum + " -") === 0) { return sMsg; }
      if (/^\d+\b/.test(sMsg)) { return sMsg; }
    }
    if (oVers.Korrnum) { return sNum + " — " + oVers.Korrnum; }
    return sNum;
  }

  function decorateVersions(aList) {
    return (aList || [])
      .filter(function (v) { return padVers(v.VersionNo) !== "00000"; })
      .map(function (v) {
        var o = Object.assign({}, v);
        o.VersionNo    = padVers(o.VersionNo);
        o.VersionLabel = versionLabel(o);
        return o;
      });
  }


  return BaseController.extend("zscort.app.controller.Compare", {

    onInit: function () {
      this.getView().setModel(new JSONModel({ objects: [] }), "local");

      this._oRouter = this.getOwnerComponent().getRouter();
      // Two Target entries share this same view/controller class:
      //  - "compareView"    (target "compare",    endColumnPages) → TR flow, 3 columns
      //  - "compareMidView" (target "compareMid", midColumnPages) → direct "quick compare", 2 columns
      this._bDirectMode = this.getView().getId().indexOf("compareMidView") > -1;
      this._sRouteName = this._bDirectMode ? "objCompare" : "compare";
      this._oRouter.getRoute(this._sRouteName).attachPatternMatched(this._onDetailMatched, this);

      this._oDiffHost = null;
      this._sType     = "";
      this._sName     = "";
      this._sServer   = "TGT";
      this._iLoadToken = 0;
      this._bSuspendModeWatch = false;
      this._aAllObjects = [];
      this._sSearch = "";

      this.getOwnerComponent().getModel("appView").attachPropertyChange(this._onAppViewChange, this);
      this._app().setProperty("/currentModule", "compare");
    },

    onAfterRendering: function () {
      this._ensureDiffHost();
    },

    _serviceUri: function () {
      var oModel = this.getOwnerComponent().getModel();
      var sUri = oModel && oModel.getServiceUrl && oModel.getServiceUrl();
      return sUri || this.getOwnerComponent().getManifestEntry("sap.app").dataSources.mainService.uri;
    },

    onExit: function () {
      this._iLoadToken++;
      var oApp = this.getOwnerComponent() && this.getOwnerComponent().getModel("appView");
      if (oApp) { oApp.detachPropertyChange(this._onAppViewChange, this); }
      if (this._oDiffHost) { this._oDiffHost.dispose(); this._oDiffHost = null; }
    },


    onModuleSwitch: function (oEvent) {
      var sKey = oEvent.getParameter("item").getKey();
      switch (sKey) {
        case "objSearch": this.onNavObjSearch(); break;
        case "trSearch":  this.onNavTrSearch();  break;
        default: break;
      }
    },


    _ensureDiffHost: function () {
      var oHtml = this.byId("monacoHost");
      if (!oHtml) { return this._oDiffHost; }
      var el = oHtml.getDomRef ? oHtml.getDomRef() : null;
      if (el && el.classList && !el.classList.contains("monacoHost")) {
        el = el.querySelector(".monacoHost") || el;
      }
      if (!el) {
        var oViewDom = this.getView().getDomRef();
        if (oViewDom) { el = oViewDom.querySelector(".monacoHost"); }
      }
      if (el && !this._oDiffHost) {
        this._oDiffHost = new DiffHost(el);
      } else if (el && this._oDiffHost && this._oDiffHost._el !== el) {
        this._oDiffHost.dispose();
        this._oDiffHost = new DiffHost(el);
      }
      return this._oDiffHost;
    },

    _onAppViewChange: function (oEvent) {
      if (this._bSuspendModeWatch) { return; }
      var sPath = (oEvent.getParameter("path") || "").replace(/^\//, "");
      if (sPath !== "compareMode") { return; }
      if (!this._sType || !this._sName) { return; }
      this._reloadForCurrentMode(true);
    },

    _onDetailMatched: function (oEvent) {
      var oArgs  = oEvent.getParameter("arguments");
      var oQuery = oArgs["?query"] || {};
      var oApp   = this._app();

      this._bSuspendModeWatch = true;
      this._sType   = oArgs.objectType;
      this._sName   = decodeURIComponent(oArgs.objectName);
      this._sServer = oQuery.serverId || oApp.getProperty("/serverId") || "TGT";
      if (this._sServer === "L" || this._sServer === "T" || this._sServer === "TARGET") {
        this._sServer = "TGT";
      }

      if (oQuery.mode)          { oApp.setProperty("/compareMode",    oQuery.mode); }
      if (oQuery.versionNo)     { oApp.setProperty("/versionNo",      padVers(oQuery.versionNo)); }
      if (oQuery.versionNoRight){ oApp.setProperty("/versionNoRight", padVers(oQuery.versionNoRight)); }

      if (padVers(oApp.getProperty("/versionNoRight")) === "99999") {
        oApp.setProperty("/versionNoRight", "99998");
      }

      // Direct "quick compare" (Object Search / TR Search row) → Begin+Mid only (Compare in Mid).
      // TR-flow compare (Master → Detail → Compare) → all 3 columns, End expanded for Monaco width.
      oApp.setProperty("/layout", this._bDirectMode
        ? LayoutType.TwoColumnsMidExpanded
        : LayoutType.ThreeColumnsEndExpanded);
      this._bSuspendModeWatch = false;
      this._reloadForCurrentMode(false);
    },

    _reloadForCurrentMode: function (bResetVersions) {
      var oApp  = this._app();
      var sMode = oApp.getProperty("/compareMode") || "L_VS_T";
      var that  = this;

      if (bResetVersions) {
        oApp.setProperty("/versionNo",       "");
        oApp.setProperty("/versionNoRight",  "99998");
        oApp.setProperty("/versions",        []);
        oApp.setProperty("/targetVersions",  []);
      }

      if (sMode === "VER_VS_VER" || sMode === "ACTIVE_VS_VER") {
        if (!padVers(oApp.getProperty("/versionNoRight"))) {
          oApp.setProperty("/versionNoRight", "99998");
        }
        this._loadVersionList("L").then(function () { that._loadDetail(); });
        return;
      }
      this._loadVersionList("T").then(function () { that._loadDetail(); });
    },

    _loadVersionList: function (sServerType) {
      var oApp  = this._app();
      var sType = sServerType || "L";
      var sProp = sType === "T" ? "/targetVersions" : "/versions";
      var sFilter = [
        "ServerType eq '" + sType + "'",
        "ObjectType eq '" + this._sType + "'",
        "ObjectName eq '" + this._sName.replace(/'/g, "''") + "'"
      ].join(" and ");
      var sUrl = this._serviceUri() + "Version?$filter=" + encodeURIComponent(sFilter);

      return ValueHelp.fetchJson(sUrl, 12000).then(function (a) {
        var aDeco = decorateVersions(a || []);
        oApp.setProperty(sProp, aDeco);
        if (sType === "T") {
          // Empty = NEW_AT_TARGET (chưa Apply) — không toast lỗi
          if (!padVers(oApp.getProperty("/versionNo")) && aDeco.length) {
            var oCur = aDeco.find(function (v) { return v.IsActive === true || v.IsActive === "X" || v.IsActive === "true"; });
            oApp.setProperty("/versionNo", padVers((oCur || aDeco[0]).VersionNo));
          }
        } else {
          var aHist = aDeco.filter(function (v) { return padVers(v.VersionNo) !== "99998"; });
          if (!oApp.getProperty("/versionNo") && aHist.length) {
            oApp.setProperty("/versionNo", padVers(aHist[0].VersionNo));
          }
          if (!padVers(oApp.getProperty("/versionNoRight"))) {
            oApp.setProperty("/versionNoRight", "99998");
          }
        }
      }).catch(function () {
        if (sType === "T") {
          oApp.setProperty("/targetVersions", []);
          // SYNTAX_ERROR / service down — vẫn mở Compare (NEW_AT_TARGET fallback)
          MessageToast.show("No Target versions yet (Apply first) or fix Version OData on S40");
        } else {
          oApp.setProperty("/versions", decorateVersions([
            { VersionNo: "99998", Message: "Active" }
          ]));
        }
      });
    },

    _loadDetail: function () {
      var oDetailModel = this.getOwnerComponent().getModel("detail");
      var oApp  = this._app();
      var that  = this;
      var iToken = ++this._iLoadToken;

      var sMode  = oApp.getProperty("/compareMode") || "L_VS_T";
      if (sMode === "ACTIVE_VS_VER") { sMode = "VER_VS_VER"; }
      var sVers  = padVers(oApp.getProperty("/versionNo"));
      var sRight = padVers(oApp.getProperty("/versionNoRight")) || "99998";
      if (sRight === "99999") { sRight = "99998"; }

      oDetailModel.setData({
        ObjectType: this._sType,
        ObjectName: this._sName,
        ServerId:   this._sServer,
        CompareMode: sMode,
        VersionNo:   sVers,
        VersionNoRight: sRight,
        StatusCode: "",
        Message:    this._i18n("loading"),
        TargetCode: "",
        SourceCode: "",
        SourceLines: 0,
        TargetLines: 0
      });

      var aParts = [
        "ObjectType eq '" + this._sType + "'",
        "ObjectName eq '" + this._sName.replace(/'/g, "''") + "'",
        "ServerId eq '"   + this._sServer + "'",
        "CompareMode eq '" + sMode + "'"
      ];
      if (sMode === "VER_VS_VER") {
        if (!sVers) {
          oDetailModel.setProperty("/Message", "Enter Left version then Reload");
          oDetailModel.setProperty("/StatusCode", "SOURCE_MISSING");
          return;
        }
        aParts.push("VersionNo eq '" + sVers + "'");
        aParts.push("VersionNoRight eq '" + sRight + "'");
      } else if (sMode === "L_VS_T" && sVers) {
        aParts.push("VersionNo eq '" + sVers + "'");
      }

      var sUrl = this._serviceUri() + "Compare?$filter=" + encodeURIComponent(aParts.join(" and "));

      ValueHelp.fetchJson(sUrl, 25000).then(function (aData) {
        if (iToken !== that._iLoadToken) { return; }
        if (!aData.length) {
          that._handleCompareUnavailable(sMode, sVers, sRight, new Error("Empty Compare result"), iToken);
          return;
        }
        var oData = aData[0];
        var sMsg = String(oData.Message || oData.message || "");
        var sCode = oData.StatusCode || oData.status_code || "";
        var bEmptyCodes = !(oData.TargetCode || oData.SourceCode || oData.target_code || oData.source_code);
        // Backend may return 200 with CX_SY_* in Message (caught dump) — fallback to SourceCodeView
        if (bEmptyCodes && (
          /CX_SY_|SHORTDUMP|SYNTAX_ERROR|ILLEGAL_TYPE|PARAM_NOT_FOUND/i.test(sMsg) ||
          (sMode === "VER_VS_VER" && sCode === "SOURCE_MISSING")
        )) {
          that._handleCompareUnavailable(sMode, sVers, sRight, new Error(sMsg || sCode), iToken);
          return;
        }
        oDetailModel.setData(oData);
        that._renderMonaco(oData);
      }).catch(function (oErr) {
        if (iToken !== that._iLoadToken) { return; }
        that._handleCompareUnavailable(sMode, sVers, sRight, oErr, iToken);
      });
    },

    /**
     * Compare OData (mainService) may dump with SYNTAX_ERROR on S40.
     * L_VS_T → NEW_AT_TARGET style (empty left + Local Active right via objService).
     * VER_VS_VER → load both sides from SourceCodeView (objService), no fake mock code.
     */
    _handleCompareUnavailable: function (sMode, sVers, sRight, oErr, iToken) {
      if (sMode === "L_VS_T") {
        this._showNewAtTarget(sMode, sVers, sRight, iToken);
        return;
      }
      if (sMode === "VER_VS_VER" || sMode === "ACTIVE_VS_VER") {
        this._showVerVsVerFromSource(sMode, sVers, sRight, oErr, iToken);
        return;
      }
      var oData = {
        ObjectType: this._sType,
        ObjectName: this._sName,
        ServerId:   this._sServer,
        CompareMode: sMode,
        VersionNo:   sVers,
        VersionNoRight: sRight,
        StatusCode: "SOURCE_MISSING",
        Message:    "Compare service unavailable — " + (oErr && oErr.message ? oErr.message : "no data"),
        TargetCode: "",
        SourceCode: "",
        SourceLines: 0,
        TargetLines: 0
      };
      this.getOwnerComponent().getModel("detail").setData(oData);
      this._renderMonaco(oData);
      MessageToast.show(oData.Message);
    },

    _fetchSourceSide: function (sServerType, sVersionNo) {
      var sFilter = [
        "ServerType eq '" + sServerType + "'",
        "ObjectType eq '" + this._sType + "'",
        "ObjectName eq '" + this._sName.replace(/'/g, "''") + "'"
      ];
      if (sVersionNo) {
        sFilter.push("VersionNo eq '" + padVers(sVersionNo) + "'");
      }
      var sUri = this.getOwnerComponent().getManifestEntry("sap.app").dataSources.objService.uri;
      var sUrl = sUri.replace(/\/?$/, "/") + "SourceCodeView?$filter=" +
        encodeURIComponent(sFilter.join(" and ")) + "&$top=1";
      return ValueHelp.fetchJson(sUrl, 20000).then(function (a) {
        return (a && a[0]) || null;
      }).catch(function () {
        return null;
      });
    },

    _showNewAtTarget: function (sMode, sVers, sRight, iToken) {
      var that = this;
      var oDetailModel = this.getOwnerComponent().getModel("detail");
      var oBase = {
        ObjectType: this._sType,
        ObjectName: this._sName,
        ServerId:   this._sServer,
        CompareMode: sMode,
        VersionNo:   sVers || "",
        VersionNoRight: sRight || "99998",
        StatusCode: "NEW_AT_TARGET",
        Message:    "Not on Target yet — left empty; right = Local Active",
        TargetCode: "",
        SourceCode: "",
        SourceLines: 0,
        TargetLines: 0
      };

      this._fetchSourceSide("L", "99998").then(function (oSrc) {
        if (iToken !== that._iLoadToken) { return; }
        if (oSrc) {
          oBase.SourceCode = oSrc.SourceCodeText || "";
          oBase.SourceLines = oSrc.LineCount || 0;
        }
        oDetailModel.setData(oBase);
        that._renderMonaco(oBase);
      });
    },

    _showVerVsVerFromSource: function (sMode, sVers, sRight, oErr, iToken) {
      var that = this;
      var oDetailModel = this.getOwnerComponent().getModel("detail");
      var sLeft = padVers(sVers);
      var sRightV = padVers(sRight) || "99998";

      Promise.all([
        this._fetchSourceSide("L", sLeft),
        this._fetchSourceSide("L", sRightV)
      ]).then(function (aSides) {
        if (iToken !== that._iLoadToken) { return; }
        var oLeft = aSides[0];
        var oRight = aSides[1];
        var sLeftCode = (oLeft && oLeft.SourceCodeText) || "";
        var sRightCode = (oRight && oRight.SourceCodeText) || "";
        var bOk = !!(sLeftCode || sRightCode);
        var oData = {
          ObjectType: that._sType,
          ObjectName: that._sName,
          ServerId:   that._sServer,
          CompareMode: sMode,
          VersionNo:   sLeft,
          VersionNoRight: sRightV,
          StatusCode: bOk ? (sLeftCode === sRightCode ? "IDENTICAL" : "DIFFERENT") : "SOURCE_MISSING",
          Message: bOk
            ? "Local versions via SourceCodeView (Compare service unavailable)"
            : ("Could not load versions — " + (oErr && oErr.message ? oErr.message : "no data")),
          TargetCode: sLeftCode,
          SourceCode: sRightCode,
          TargetLines: (oLeft && oLeft.LineCount) || 0,
          SourceLines: (oRight && oRight.LineCount) || 0
        };
        oDetailModel.setData(oData);
        that._renderMonaco(oData);
        if (!bOk) {
          MessageToast.show(oData.Message);
        }
      });
    },

    _renderMonaco: function (oData) {
      var that = this;
      setTimeout(function () {
        var oHost = that._ensureDiffHost();
        if (!oHost) { return; }
        oHost.setModel({
          original: oData.TargetCode || "",
          modified: oData.SourceCode || "",
          language: "abap"
        });
      }, 50);
    },

    onModeChange: function (oEvent) {
      var oItem = oEvent && oEvent.getParameter("item");
      var sMode = oItem ? oItem.getKey() : "";
      var oApp = this._app();
      // Avoid double-reload: binding may already have written compareMode (triggers propertyChange).
      if (sMode && oApp.getProperty("/compareMode") !== sMode) {
        oApp.setProperty("/compareMode", sMode);
      } else if (sMode && this._sType && this._sName) {
        this._reloadForCurrentMode(true);
      }
    },

    onVHCompareMode: function () {
      var oApp = this._app();
      var that = this;
      ValueHelp.open({
        sServiceUri: this._serviceUri(),
        sEntitySet: "/VHCompareMode",
        sKey: "CompareMode",
        sDescriptionKey: "Description",
        sTitle: this._i18n("vhCompareMode"),
        sInitialKey: oApp.getProperty("/compareMode") || "L_VS_T",
        aColumns: [
          { key: "CompareMode", label: "Mode" },
          { key: "Description", label: "Description" }
        ],
        fnConfirm: function (sKey) {
          oApp.setProperty("/compareMode", sKey);
          if (that._sType && that._sName) {
            that._reloadForCurrentMode(true);
          }
        }
      });
    },

    onVersionChange: function (oEvent) {
      var sKey = oEvent.getParameter("selectedItem") && oEvent.getParameter("selectedItem").getKey();
      if (sKey) {
        this._app().setProperty("/versionNo", padVers(sKey));
        this._loadDetail();
      }
    },

    onVersionRightChange: function (oEvent) {
      var sKey = oEvent.getParameter("selectedItem") && oEvent.getParameter("selectedItem").getKey();
      if (sKey) {
        this._app().setProperty("/versionNoRight", padVers(sKey));
        this._loadDetail();
      }
    },

    onVHVersionLeft:    function () { this._openVersionVH("/versionNo",      "L"); },
    onVHVersionRight:   function () { this._openVersionVH("/versionNoRight", "L"); },
    onVHTargetVersion:  function () { this._openVersionVH("/versionNo",      "T"); },

    _openVersionVH: function (sAppPath, sServerType) {
      var oApp  = this._app();
      var that  = this;
      var sType = sServerType || "L";
      var sFilter = [
        "ServerType eq '" + sType + "'",
        "ObjectType eq '" + this._sType + "'",
        "ObjectName eq '" + this._sName.replace(/'/g, "''") + "'"
      ].join(" and ");
      ValueHelp.open({
        oModel:     this.getOwnerComponent().getModel(),
        sEntitySet: "/Version",
        sKey:       "VersionNo",
        sDescriptionKey: "Message",
        sTitle:     sType === "T" ? this._i18n("vhTargetVersionTitle") : this._i18n("vhVersionTitle"),
        sInitialKey: oApp.getProperty(sAppPath) || "",
        sFetchUrl:   this._serviceUri() + "Version?$filter=" + encodeURIComponent(sFilter),
        iTimeoutMs:  12000,
        aFilters: [
          new Filter("ServerType",  FilterOperator.EQ, sType),
          new Filter("ObjectType",  FilterOperator.EQ, this._sType),
          new Filter("ObjectName",  FilterOperator.EQ, this._sName)
        ],
        aColumns: [
          { key: "VersionLabel", label: "Version" },
          { key: "Author",       label: "Author" },
          { key: "Korrnum",      label: "TR" },
          { key: "SrcHash",      label: "Checksum" }
        ],
        fnConfirm:  function (sKey) { oApp.setProperty(sAppPath, padVers(sKey)); that._loadDetail(); },
        aRowsMap:   decorateVersions
      });
    },

    onReloadDiff: function () {
      var oApp = this._app();
      oApp.setProperty("/versionNo",      padVers(oApp.getProperty("/versionNo")));
      oApp.setProperty("/versionNoRight", padVers(oApp.getProperty("/versionNoRight")) || "99998");
      this._loadDetail();
    },

    onButtonCloseComparePress: function () {
      this._iLoadToken++;
      var oApp = this._app();

      if (this._bDirectMode) {
        // Opened directly from Object Search / TR Search → go back to whichever screen
        // it was opened from, restoring the single-column layout those screens expect.
        oApp.setProperty("/layout", LayoutType.OneColumn);
        var sOrigin = oApp.getProperty("/compareOrigin") || "objSearch";
        if (sOrigin === "trSearch") {
          this.onNavTrSearch();
        } else {
          this.onNavObjSearch();
        }
        return;
      }

      // TR-flow: navigate back to the Detail page for the TR that was being worked on.
      var sTrkorr = oApp.getProperty("/trkorr");
      if (sTrkorr) {
        this._oRouter.navTo("detail", { trkorr: encodeURIComponent(sTrkorr) }, undefined, true);
      } else {
        this._oRouter.navTo("master", {}, undefined, true);
      }
    },

    onButtonFullScreenPress: function () {
      var oApp = this._app();
      var sLayout = oApp.getProperty("/layout");

      if (this._bDirectMode) {
        oApp.setProperty("/layout", sLayout === LayoutType.MidColumnFullScreen
          ? LayoutType.TwoColumnsMidExpanded
          : LayoutType.MidColumnFullScreen);
        return;
      }

      if (sLayout === LayoutType.ThreeColumnsEndExpanded) {
        oApp.setProperty("/layout", LayoutType.EndColumnFullScreen);
      } else {
        oApp.setProperty("/layout", LayoutType.ThreeColumnsEndExpanded);
      }
    },

    onStateChanged: function () { /* FCL state change, no action needed */ },

    formatStatusState: function (sStatus) {
      switch ((sStatus || "").toUpperCase()) {
        case "DIFFERENT":
        case "BAD_HEX":       return ValueState.Error;
        case "NEW_AT_TARGET": return ValueState.Success;
        case "ORIGIN_MISSING":
        case "SOURCE_MISSING": return ValueState.Warning;
        case "NOT_SUPPORTED": return ValueState.Information;
        default:              return ValueState.None;
      }
    }
  });
});
