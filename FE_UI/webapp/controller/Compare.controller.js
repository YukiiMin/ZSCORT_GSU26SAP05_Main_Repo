sap.ui.define([
  "zscort/app/controller/BaseController",
  "sap/ui/model/json/JSONModel",
  "sap/m/MessageBox",
  "sap/m/MessageToast",
  "sap/f/library",
  "zscort/app/monaco/DiffHost",
  "zscort/app/util/ValueHelp"
], function (
  BaseController,
  JSONModel,
  MessageBox,
  MessageToast,
  fLibrary,
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

  return BaseController.extend("zscort.app.controller.Compare", {

    onInit: function () {
      this._oRouter = this.getOwnerComponent().getRouter();
      this._bDirectMode = this.getView().getId().indexOf("compareMidView") > -1;
      this._oRouter.getRoute("objCompare").attachPatternMatched(this._onDetailMatched, this);
      this._oRouter.getRoute("compare").attachPatternMatched(this._onDetailMatched, this);

      this._oGitDiffHost = null;
      this._oVersDiffHost = null;
      this._sType = "";
      this._sName = "";
      this._bSideGit = true;
      this._bSideVers = true;

      this._app().setProperty("/currentModule", "compare");
    },

    onAfterRendering: function () {
      this._ensureGitDiffHost();
      this._ensureVersDiffHost();
    },

    _serviceUri: function () {
      var oModel = this.getOwnerComponent().getModel();
      var sUri = oModel && oModel.getServiceUrl && oModel.getServiceUrl();
      return sUri || this.getOwnerComponent().getManifestEntry("sap.app").dataSources.mainService.uri;
    },

    onExit: function () {
      if (this._oGitDiffHost) { this._oGitDiffHost.dispose(); }
      if (this._oVersDiffHost) { this._oVersDiffHost.dispose(); }
    },

    _onDetailMatched: function (oEvent) {
      var oArgs = oEvent.getParameter("arguments");
      if (!oArgs || !oArgs.objectType || !oArgs.objectName) { return; }
      this._sType = oArgs.objectType;
      this._sName = decodeURIComponent(oArgs.objectName);
      
      var oDetailModel = this.getOwnerComponent().getModel("detail");
      oDetailModel.setProperty("/ObjectType", this._sType);
      oDetailModel.setProperty("/ObjectName", this._sName);
      oDetailModel.setProperty("/versions", []);
      oDetailModel.setProperty("/showEditor", false);

      var oApp = this._app();
      oApp.setProperty("/layout", this._bDirectMode ? LayoutType.TwoColumnsMidExpanded : LayoutType.ThreeColumnsEndExpanded);

      // Auto-load Tab 1 (Git Review) and Tab 2 (Versions)
      this._loadGitReviewSource();
      this.onReloadVersions();
    },

    // ==========================================
    // TAB 1: GIT REVIEW (Local Active vs Target)
    // ==========================================
    _loadGitReviewSource: function () {
      var that = this;
      var oObjUri = this.getOwnerComponent().getManifestEntry("sap.app").dataSources.objService.uri.replace(/\/?$/, "/");
      var sUrlLocal = oObjUri + "SourceCodeView?$filter=" + encodeURIComponent("ServerType eq 'L' and ObjectType eq '" + this._sType + "' and ObjectName eq '" + this._sName.replace(/'/g, "''") + "' and VersionNo eq '99998'");
      var sUrlTarget = oObjUri + "SourceCodeView?$filter=" + encodeURIComponent("ServerType eq 'T' and ObjectType eq '" + this._sType + "' and ObjectName eq '" + this._sName.replace(/'/g, "''") + "'");

      this.byId("idDetailDynamicPage").setBusy(true);

      Promise.all([
        ValueHelp.fetchJson(sUrlLocal, 15000).catch(function() { return []; }),
        ValueHelp.fetchJson(sUrlTarget, 15000).catch(function() { return []; })
      ]).then(function (aResults) {
        var oResLocal = (aResults[0] && aResults[0][0]) || { SourceCodeText: "" };
        var oResTarget = (aResults[1] && aResults[1][0]) || { SourceCodeText: "" };

        that._ensureGitDiffHost();
        var sLang = that._getMonacoLang();
        that._mGitModel = {
          original: oResLocal.SourceCodeText || "",
          modified: oResTarget.SourceCodeText || "",
          language: sLang
        };

        that._oGitDiffHost.setModel(that._mGitModel).then(function () {
          that.byId("idDetailDynamicPage").setBusy(false);
          that._oGitDiffHost.setSideBySide(that._bSideGit);
        });
      }).catch(function (e) {
        that.byId("idDetailDynamicPage").setBusy(false);
        MessageBox.error("Failed to load Git Review source.\n" + String(e));
      });
    },

    onTabSelect: function (oEvent) {
      var sKey = oEvent.getParameter("key");
      var that = this;
      setTimeout(function () {
        if (sKey === "gitReview") {
          that._ensureGitDiffHost(true);
          if (that._mGitModel && that._oGitDiffHost) {
            that._oGitDiffHost.setModel(that._mGitModel);
          }
        } else if (sKey === "versionMgmt") {
          var oDetailModel = that.getOwnerComponent().getModel("detail");
          if (oDetailModel.getProperty("/showEditor")) {
            that._ensureVersDiffHost(true);
            if (that._mVersModel && that._oVersDiffHost) {
              that._oVersDiffHost.setModel(that._mVersModel);
            }
          }
        }
      }, 50);
    },

    onMonacoPrevDiffGit: function () {
      if (this._oGitDiffHost) { this._oGitDiffHost.prevDiff(); }
    },
    onMonacoNextDiffGit: function () {
      if (this._oGitDiffHost) { this._oGitDiffHost.nextDiff(); }
    },
    onMonacoToggleSideBySideGit: function () {
      this._bSideGit = !this._bSideGit;
      if (this._oGitDiffHost) { this._oGitDiffHost.setSideBySide(this._bSideGit); }
    },

    // ==========================================
    // TAB 2: VERSION MANAGEMENT (ADT Style)
    // ==========================================
    onReloadVersions: function () {
      var that = this;
      var oDetailModel = this.getOwnerComponent().getModel("detail");
      oDetailModel.setProperty("/busyVersions", true);
      oDetailModel.setProperty("/showEditor", false);

      var sUri = this._serviceUri();
      var sUrlLocal = sUri + "Version?$filter=" + encodeURIComponent("ServerType eq 'L' and ObjectType eq '" + this._sType + "' and ObjectName eq '" + this._sName.replace(/'/g, "''") + "'");

      Promise.all([
        ValueHelp.fetchJson(sUrlLocal, 12000).catch(function() { return []; })
      ]).then(function(aResults) {
        var aLocal = aResults[0] || [];

        aLocal.sort(function(a, b) {
           var vA = padVers(a.VersionNo);
           var vB = padVers(b.VersionNo);
           if (vA === "99998" && vB !== "99998") return -1;
           if (vB === "99998" && vA !== "99998") return 1;
           return vB.localeCompare(vA);
        });

        oDetailModel.setProperty("/versions", aLocal);
        oDetailModel.setProperty("/busyVersions", false);
        var oTbl = that.byId("idVersionsTable");
        if (oTbl) { oTbl.clearSelection(); }
      });
    },

    onVersionSelectionChange: function () {
      var oTable = this.byId("idVersionsTable");
      if (!oTable) { return; }
      var aIndices = oTable.getSelectedIndices();
      this.byId("btnCompare").setEnabled(aIndices.length === 2);
    },

    onComparePress: function () {
      var oTable = this.byId("idVersionsTable");
      var aIndices = oTable.getSelectedIndices();
      if (aIndices.length !== 2) {
        MessageToast.show("Please select exactly 2 versions to compare.");
        return;
      }

      var oDetailModel = this.getOwnerComponent().getModel("detail");
      var oCtx1 = oTable.getContextByIndex(aIndices[0]).getObject();
      var oCtx2 = oTable.getContextByIndex(aIndices[1]).getObject();

      var v1 = padVers(oCtx1.VersionNo);
      var v2 = padVers(oCtx2.VersionNo);

      var oLeft, oRight;
      if (v1 === "99998" && v2 !== "99998") {
         oRight = oCtx1; oLeft = oCtx2;
      } else if (v2 === "99998" && v1 !== "99998") {
         oRight = oCtx2; oLeft = oCtx1;
      } else if (v1 > v2) {
         oRight = oCtx1; oLeft = oCtx2;
      } else {
         oRight = oCtx2; oLeft = oCtx1;
      }

      var sTitleL = (oLeft.ServerType === 'L' ? 'Local ' : 'Target ') + this.formatVersionNo(oLeft.VersionNo);
      var sTitleR = (oRight.ServerType === 'L' ? 'Local ' : 'Target ') + this.formatVersionNo(oRight.VersionNo);

      oDetailModel.setProperty("/leftTitle", sTitleL);
      oDetailModel.setProperty("/rightTitle", sTitleR);

      var sObjUri = this.getOwnerComponent().getManifestEntry("sap.app").dataSources.objService.uri.replace(/\/?$/, "/");
      var sUrlLeft = sObjUri + "SourceCodeView?$filter=" + encodeURIComponent("ServerType eq '" + oLeft.ServerType + "' and ObjectType eq '" + this._sType + "' and ObjectName eq '" + this._sName.replace(/'/g, "''") + "' and VersionNo eq '" + padVers(oLeft.VersionNo) + "'");
      var sUrlRight = sObjUri + "SourceCodeView?$filter=" + encodeURIComponent("ServerType eq '" + oRight.ServerType + "' and ObjectType eq '" + this._sType + "' and ObjectName eq '" + this._sName.replace(/'/g, "''") + "' and VersionNo eq '" + padVers(oRight.VersionNo) + "'");

      oDetailModel.setProperty("/showEditor", true);
      this.byId("idDetailDynamicPage").setBusy(true);

      var that = this;
      Promise.all([
        ValueHelp.fetchJson(sUrlLeft, 15000),
        ValueHelp.fetchJson(sUrlRight, 15000)
      ]).then(function(aResults) {
        var oResLeft = (aResults[0] && aResults[0][0]) || { SourceCodeText: "" };
        var oResRight = (aResults[1] && aResults[1][0]) || { SourceCodeText: "" };

        that._ensureVersDiffHost();
        var sLang = that._getMonacoLang();
        that._mVersModel = {
          original: oResLeft.SourceCodeText || "",
          modified: oResRight.SourceCodeText || "",
          language: sLang
        };

        that._oVersDiffHost.setModel(that._mVersModel).then(function () {
          that.byId("idDetailDynamicPage").setBusy(false);
          that._oVersDiffHost.setSideBySide(that._bSideVers);
        });
      }).catch(function(e) {
        that.byId("idDetailDynamicPage").setBusy(false);
        MessageBox.error("Failed to load version source code.\n" + String(e));
      });
    },

    onMonacoPrevDiffVers: function () {
      if (this._oVersDiffHost) { this._oVersDiffHost.prevDiff(); }
    },
    onMonacoNextDiffVers: function () {
      if (this._oVersDiffHost) { this._oVersDiffHost.nextDiff(); }
    },
    onMonacoToggleSideBySideVers: function () {
      this._bSideVers = !this._bSideVers;
      if (this._oVersDiffHost) { this._oVersDiffHost.setSideBySide(this._bSideVers); }
    },

    // ==========================================
    // HELPERS & LAYOUT
    // ==========================================
    _ensureGitDiffHost: function (bForceReattach) {
      var oDom = this.byId("monacoGitContainer") ? this.byId("monacoGitContainer").getDomRef() : null;
      if (!oDom) { return; }
      if (!this._oGitDiffHost) {
        this._oGitDiffHost = new DiffHost(oDom);
      } else if (bForceReattach || !this._oGitDiffHost.isAttached()) {
        this._oGitDiffHost.attachTo(oDom);
      }
    },

    _ensureVersDiffHost: function (bForceReattach) {
      var oDom = this.byId("monacoVersContainer") ? this.byId("monacoVersContainer").getDomRef() : null;
      if (!oDom) { return; }
      if (!this._oVersDiffHost) {
        this._oVersDiffHost = new DiffHost(oDom);
      } else if (bForceReattach || !this._oVersDiffHost.isAttached()) {
        this._oVersDiffHost.attachTo(oDom);
      }
    },

    _getMonacoLang: function () {
      var t = (this._sType || "").toUpperCase();
      if (t === "PROG" || t === "CLAS" || t === "INTF" || t === "FUNC" || t === "FUGR") { return "abap"; }
      if (t === "DDLS" || t === "DCLS") { return "sql"; }
      return "plaintext";
    },

    onButtonFullScreenPress: function () {
      var oApp = this._app();
      var sCur = oApp.getProperty("/layout");
      var sNew = (sCur === LayoutType.MidColumnFullScreen || sCur === LayoutType.EndColumnFullScreen)
        ? (this._bDirectMode ? LayoutType.TwoColumnsMidExpanded : LayoutType.ThreeColumnsEndExpanded)
        : (this._bDirectMode ? LayoutType.MidColumnFullScreen : LayoutType.EndColumnFullScreen);
      oApp.setProperty("/layout", sNew);
    },

    onButtonCloseComparePress: function () {
      var oApp = this._app();
      var sOrigin = oApp.getProperty("/compareOrigin") || (this._bDirectMode ? "objSearch" : "detail");

      if (sOrigin === "objSearch") {
        oApp.setProperty("/layout", LayoutType.OneColumn);
        oApp.setProperty("/currentModule", "objSearch");
        this._oRouter.navTo("objSearch");
      } else if (this._bDirectMode) {
        oApp.setProperty("/layout", LayoutType.OneColumn);
        oApp.setProperty("/currentModule", "trSearch");
        this._oRouter.navTo("trSearch");
      } else {
        oApp.setProperty("/layout", LayoutType.TwoColumnsMidExpanded);
        oApp.setProperty("/currentModule", "trSearch");
        this._oRouter.navTo("detail", {
          trkorr: oApp.getProperty("/currentTR") || "DUMMY"
        });
      }
    },

    formatVersionNo: function(sVer) {
      if (!sVer) return "";
      if (padVers(sVer) === "99998") return "Active";
      return parseInt(sVer, 10).toString();
    },

    formatDate: function(sDate) {
      if (!sDate) return "";
      if (sDate.length === 8) {
        return sDate.substr(0,4) + "-" + sDate.substr(4,2) + "-" + sDate.substr(6,2);
      }
      return sDate;
    }

  });
});
