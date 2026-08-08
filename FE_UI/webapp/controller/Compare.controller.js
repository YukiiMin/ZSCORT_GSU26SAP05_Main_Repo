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

  // ─── Version helpers (same as REQ3 Detail.controller) ────────────────────
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

  // ─────────────────────────────────────────────────────────────────────────

  return BaseController.extend("zscort.app.controller.Compare", {

    // ─────────────────────────────────────────────────────────────────────
    //  LIFECYCLE
    // ─────────────────────────────────────────────────────────────────────

    onInit: function () {
      this.getView().setModel(new JSONModel({ objects: [] }), "local");

      this._oRouter = this.getOwnerComponent().getRouter();
      this._oRouter.getRoute("compare").attachPatternMatched(this._onDetailMatched, this);

      this._oDiffHost = null;
      this._sType     = "";
      this._sName     = "";
      this._sServer   = "TARGET";
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

    onExit: function () {
      this._iLoadToken++;
      var oApp = this.getOwnerComponent() && this.getOwnerComponent().getModel("appView");
      if (oApp) { oApp.detachPropertyChange(this._onAppViewChange, this); }
      if (this._oDiffHost) { this._oDiffHost.dispose(); this._oDiffHost = null; }
    },

    // ─────────────────────────────────────────────────────────────────────
    //  MODULE SWITCH
    // ─────────────────────────────────────────────────────────────────────

    onModuleSwitch: function (oEvent) {
      var sKey = oEvent.getParameter("item").getKey();
      switch (sKey) {
        case "objSearch": this.onNavObjSearch(); break;
        case "trSearch":  this.onNavTrSearch();  break;
        default: break;
      }
    },

    // ─────────────────────────────────────────────────────────────────────
    //  DETAIL (Monaco Diff Viewer)
    // ─────────────────────────────────────────────────────────────────────

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
      this._sServer = oQuery.serverId || oApp.getProperty("/serverId") || "TARGET";

      if (oQuery.mode)          { oApp.setProperty("/compareMode",    oQuery.mode); }
      if (oQuery.versionNo)     { oApp.setProperty("/versionNo",      padVers(oQuery.versionNo)); }
      if (oQuery.versionNoRight){ oApp.setProperty("/versionNoRight", padVers(oQuery.versionNoRight)); }

      if (padVers(oApp.getProperty("/versionNoRight")) === "99999") {
        oApp.setProperty("/versionNoRight", "99998");
      }

      oApp.setProperty("/layout", LayoutType.TwoColumnsMidExpanded);
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
        var aDeco = decorateVersions(a);
        oApp.setProperty(sProp, aDeco);
        if (sType === "T") {
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
          MessageToast.show("Target REPO version list unavailable");
        } else {
          oApp.setProperty("/versions", decorateVersions([
            { VersionNo: "00001", Message: "1" },
            { VersionNo: "00002", Message: "2" },
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
          that._useMockDetail(sMode, sVers, sRight, new Error("Empty Compare result"));
          return;
        }
        var oData = aData[0];
        oDetailModel.setData(oData);
        that._renderMonaco(oData);
      }).catch(function (oErr) {
        if (iToken !== that._iLoadToken) { return; }
        that._useMockDetail(sMode, sVers, sRight, oErr);
      });
    },

    _useMockDetail: function (sMode, sVers, sRight, oErr) {
      var oData = {
        ObjectType: this._sType,
        ObjectName: this._sName,
        ServerId:   this._sServer,
        CompareMode: sMode,
        VersionNo:   sVers,
        VersionNoRight: sRight,
        StatusCode: "DIFFERENT",
        Message:    "Mock — " + (oErr && oErr.message ? oErr.message : "OData unavailable"),
        TargetCode: "* LEFT version " + sVers + "\nREPORT z_mock.\nWRITE 'left'.\n",
        SourceCode: "* RIGHT version " + sRight + "\nREPORT z_mock.\nWRITE 'right'.\nWRITE 'extra'.\n",
        SourceLines: 4,
        TargetLines: 3
      };
      this.getOwnerComponent().getModel("detail").setData(oData);
      this._renderMonaco(oData);
      MessageToast.show(oData.Message);
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
      // Navigate back to detail (TR Objects list)
      var sTrkorr = this.getOwnerComponent().getModel("detail").getProperty("/trkorr");
      this._oRouter.navTo("detail", { trkorr: encodeURIComponent(sTrkorr) }, undefined, true);
    },

    onButtonFullScreenPress: function () {
      var oApp = this._app();
      var sLayout = oApp.getProperty("/layout");
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
