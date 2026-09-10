sap.ui.define([
  "zscort/app/controller/BaseController",
  "sap/ui/model/json/JSONModel",
  "sap/m/MessageBox",
  "sap/m/MessageToast",
  "sap/f/library",
  "zscort/app/monaco/DiffHost",
  "zscort/app/util/ValueHelp",
  "zscort/app/util/AiReview",
  "zscort/app/util/AiPanelRenderer",
  "sap/m/StandardListItem",
  "sap/ui/core/Fragment",
  "zscort/app/util/AdtFormParser"
], function (
  BaseController,
  JSONModel,
  MessageBox,
  MessageToast,
  fLibrary,
  DiffHost,
  ValueHelp,
  AiReview,
  AiPanelRenderer,
  StandardListItem,
  Fragment,
  AdtFormParser
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
      this._oRouter.getRoute("objCompare").attachPatternMatched(this._onDetailMatched, this);
      this._oRouter.getRoute("trCompare").attachPatternMatched(this._onDetailMatched, this);
      this._oRouter.getRoute("compare").attachPatternMatched(this._onDetailMatched, this);

      this._oGitDiffHost = null;
      this._oVersDiffHost = null;
      this._sType = "";
      this._sName = "";
      this._bSideGit = true;
      this._bSideVers = true;
      this._bDirectMode = false;

      this._app().setProperty("/currentModule", "compare");
    },

    onAfterRendering: function () {
      this._ensureGitDiffHost();
      this._ensureVersDiffHost();
      if (this._mGitModel && this._oGitDiffHost) {
        this._oGitDiffHost.setModel(this._mGitModel);
      }
      if (this._mVersModel && this._oVersDiffHost) {
        this._oVersDiffHost.setModel(this._mVersModel);
      }
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
      var sRouteName = oEvent.getParameter("name");
      var bDirectRoute = (sRouteName === "objCompare" || sRouteName === "trCompare");
      this._bDirectMode = bDirectRoute;

      var sViewId = this.getView().getId() || "";
      var bIsMid = sViewId.indexOf("Mid") > -1 || sViewId.indexOf("mid") > -1;
      var bIsEnd = sViewId.indexOf("compareView") > -1;

      // If this instance is compareMidView but route is 3-column TR compare, ignore.
      if (bIsMid && !bDirectRoute) {
        return;
      }
      // If this instance is compareView (endColumn) but route is 2-column direct compare, ignore.
      if (bIsEnd && bDirectRoute) {
        return;
      }

      var oArgs = oEvent.getParameter("arguments");
      if (!oArgs || !oArgs.objectType || !oArgs.objectName) { return; }
      this._sType = oArgs.objectType;
      this._sName = decodeURIComponent(oArgs.objectName);
      
      var oDetailModel = this.getOwnerComponent().getModel("detail");
      oDetailModel.setProperty("/ObjectType", this._sType);
      oDetailModel.setProperty("/ObjectName", this._sName);
      oDetailModel.setProperty("/versions", []);
      oDetailModel.setProperty("/showEditor", false);
      oDetailModel.setProperty("/showGitAiPanel", false);
      oDetailModel.setProperty("/showVersAiPanel", false);
      if (!oDetailModel.getProperty("/aiExecutionMode")) {
        oDetailModel.setProperty("/aiExecutionMode", "BE_SAP");
      }

      this._sTableDiffVersLeft = null;
      this._sTableDiffVersRight = null;
      this._sTableDiffLeftLabel = "Local Active";
      this._sTableDiffRightLabel = "Target Snapshot";
      this._oTableDiffData = null;
      oDetailModel.setProperty("/tableDiffFilterKey", "ALL");
      oDetailModel.setProperty("/tableDataIsIdentical", false);
      oDetailModel.setProperty("/tableDiffIsCapped", false);
      oDetailModel.setProperty("/tableDiffTotalCount", 0);
      oDetailModel.setProperty("/tableDiffUpdateCount", 0);
      oDetailModel.setProperty("/tableDiffInsertCount", 0);
      oDetailModel.setProperty("/tableDiffDeleteCount", 0);
      oDetailModel.setProperty("/tableDiffLeftLabel", "Local Active");
      oDetailModel.setProperty("/tableDiffRightLabel", "Target Snapshot");
      oDetailModel.setProperty("/tableDiffSummaryText", "");

      var oApp = this._app();
      oApp.setProperty("/layout", this._bDirectMode ? LayoutType.TwoColumnsMidExpanded : LayoutType.ThreeColumnsEndExpanded);

      var oRoot = this.getOwnerComponent().getRootControl();
      var oFcl = (oRoot && oRoot.byId && oRoot.byId("fcl")) || sap.ui.getCore().byId("container-zscort.app---appView--fcl");
      if (oFcl) {
        if (this._bDirectMode && typeof oFcl.toMidColumnPage === "function") {
          oFcl.toMidColumnPage(this.getView());
        } else if (!this._bDirectMode && typeof oFcl.toEndColumnPage === "function") {
          oFcl.toEndColumnPage(this.getView());
        }
      }

      var oTabBar = this.byId("idCompareIconTabBar");
      if (oTabBar) {
        oTabBar.setSelectedKey("gitReview");
      }

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
      var sUrlLocalMeta = oObjUri + "LocalObjects?$filter=" + encodeURIComponent("ObjectType eq '" + this._sType + "' and ObjectName eq '" + this._sName.replace(/'/g, "''") + "'");
      var sUrlTargetMeta = oObjUri + "TargetObjects?$filter=" + encodeURIComponent("ObjectType eq '" + this._sType + "' and ObjectName eq '" + this._sName.replace(/'/g, "''") + "'");

      var oDp = this.byId("idDetailDynamicPage");
      if (oDp) oDp.setBusy(true);

      Promise.all([
        ValueHelp.fetchJson(sUrlLocal, 15000).catch(function() { return []; }),
        ValueHelp.fetchJson(sUrlTarget, 15000).catch(function() { return []; }),
        ValueHelp.fetchJson(sUrlLocalMeta, 10000).catch(function() { return []; }),
        ValueHelp.fetchJson(sUrlTargetMeta, 10000).catch(function() { return []; })
      ]).then(function (aResults) {
        var oResLocal = (aResults[0] && aResults[0][0]) || { SourceCodeText: "" };
        var oResTarget = (aResults[1] && aResults[1][0]) || { SourceCodeText: "" };
        that._oLocalMeta = (aResults[2] && aResults[2][0]) || {};
        that._oTargetMeta = (aResults[3] && aResults[3][0]) || {};

        var bTargetExists = !!(that._oTargetMeta && (that._oTargetMeta.ObjectName || that._oTargetMeta.ObjectType));
        var bLocalExists = !!(that._oLocalMeta && (that._oLocalMeta.ObjectName || that._oLocalMeta.ObjectType));

        var aNotSupportedTypes = ["TRAN", "NROB", "WAPA", "SSFO", "SHLP", "SRVD"];
        var bNotSupported = aNotSupportedTypes.indexOf(that._sType) !== -1 ||
          (oResLocal && oResLocal.Message === "NOT_SUPPORTED");

        var sTargetCode = (!bNotSupported && bTargetExists && oResTarget && oResTarget.SourceCodeText) ? oResTarget.SourceCodeText : "";
        var sLocalCode = (!bNotSupported && bLocalExists && oResLocal && oResLocal.SourceCodeText) ? oResLocal.SourceCodeText : "";

        var oDetailModel = that.getOwnerComponent().getModel("detail");
        if (oDetailModel) {
          oDetailModel.setProperty("/isNotSupported", bNotSupported);
          oDetailModel.setProperty("/targetExists", !!sTargetCode);
          oDetailModel.setProperty("/localExists", !!sLocalCode);

          if (bNotSupported) {
            oDetailModel.setProperty("/compareMode", "text");
          } else if (that._sType === "DOMA") {
            var oDomLocal = AdtFormParser.parseDomain(sLocalCode);
            var oDomTarget = AdtFormParser.parseDomain(sTargetCode);
            that.getView().setModel(new JSONModel(oDomLocal), "adtDomain");
            that.getView().setModel(new JSONModel(oDomTarget), "adtDomainTarget");
            oDetailModel.setProperty("/compareMode", "form");
          } else if (that._sType === "DTEL") {
            var oDtelLocal = AdtFormParser.parseDataElement(sLocalCode);
            var oDtelTarget = AdtFormParser.parseDataElement(sTargetCode);
            that.getView().setModel(new JSONModel(oDtelLocal), "adtDtel");
            that.getView().setModel(new JSONModel(oDtelTarget), "adtDtelTarget");
            oDetailModel.setProperty("/compareMode", "form");
          } else if (that._sType === "MSAG") {
            var oMsagLocal = AdtFormParser.parseMessageClass(sLocalCode);
            var oMsagTarget = AdtFormParser.parseMessageClass(sTargetCode);
            that.getView().setModel(new JSONModel(oMsagLocal), "adtMsag");
            that.getView().setModel(new JSONModel(oMsagTarget), "adtMsagTarget");
            oDetailModel.setProperty("/compareMode", "form");
          } else if (that._sType === "DEVC") {
            var oDevcLocal = AdtFormParser.parsePackage(sLocalCode);
            var oDevcTarget = AdtFormParser.parsePackage(sTargetCode);
            that.getView().setModel(new JSONModel(oDevcLocal), "adtDevc");
            that.getView().setModel(new JSONModel(oDevcTarget), "adtDevcTarget");
            oDetailModel.setProperty("/compareMode", "form");
          } else if (that._sType === "TTYP") {
            var oTtypLocal = AdtFormParser.parseTableType(sLocalCode);
            var oTtypTarget = AdtFormParser.parseTableType(sTargetCode);
            that.getView().setModel(new JSONModel(oTtypLocal), "adtTtyp");
            that.getView().setModel(new JSONModel(oTtypTarget), "adtTtypTarget");
            oDetailModel.setProperty("/compareMode", "form");
          } else {
            oDetailModel.setProperty("/compareMode", "text");
          }
        }

        if (bNotSupported) {
          var oDpInner = that.byId("idDetailDynamicPage");
          if (oDpInner) oDpInner.setBusy(false);
          return;
        }

        var sLang = that._getMonacoLang(that._sType);
        that._mGitModel = {
          original: sLocalCode,
          modified: sTargetCode,
          language: sLang
        };

        var tryRender = function (iAttempt) {
          iAttempt = iAttempt || 0;
          that._ensureGitDiffHost();
          if (that._oGitDiffHost) {
            that._oGitDiffHost.setModel(that._mGitModel).then(function () {
              var oDpInner = that.byId("idDetailDynamicPage");
              if (oDpInner) oDpInner.setBusy(false);
              that._oGitDiffHost.setSideBySide(that._bSideGit);
            });
          } else if (iAttempt < 25) {
            setTimeout(function () { tryRender(iAttempt + 1); }, 80);
          } else {
            var oDpInner = that.byId("idDetailDynamicPage");
            if (oDpInner) oDpInner.setBusy(false);
          }
        };
        tryRender(0);
      }).catch(function (e) {
        var oDpErr = that.byId("idDetailDynamicPage");
        if (oDpErr) oDpErr.setBusy(false);
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
        } else if (sKey === "tableDataDiff") {
          that._loadTableDataDiff();
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
      var oDetailModel = this.getOwnerComponent().getModel("detail");
      if (oDetailModel) {
        oDetailModel.setProperty("/sideBySideForm", this._bSideGit);
      }
    },

    onCompareModeChange: function (oEvent) {
      var sKey = oEvent.getParameter("item") ? oEvent.getParameter("item").getKey() : oEvent.getSource().getSelectedKey();
      var oDetailModel = this.getOwnerComponent().getModel("detail");
      if (oDetailModel) {
        oDetailModel.setProperty("/compareMode", sKey);
      }
      if (sKey === "text") {
        var that = this;
        setTimeout(function () {
          that._ensureGitDiffHost(true);
          if (that._mGitModel && that._oGitDiffHost) {
            that._oGitDiffHost.setModel(that._mGitModel);
          }
        }, 50);
      }
    },

    onToggleGitAiPanel: function () {
      var oDetailModel = this.getOwnerComponent().getModel("detail");
      var bShow = !oDetailModel.getProperty("/showGitAiPanel");
      oDetailModel.setProperty("/showGitAiPanel", bShow);
      if (bShow) {
        this._runGitAiAudit();
      }
    },

    _runGitAiAudit: function () {
      var oDetailModel = this.getOwnerComponent().getModel("detail");
      var oI18n = this.getOwnerComponent().getModel("i18n").getResourceBundle();
      var sLocale = (oI18n.sLocale || "en").split("_")[0].toLowerCase();
      var sMode = oDetailModel.getProperty("/aiExecutionMode") || "BE_SAP";
      var sModel = oDetailModel.getProperty("/aiModel") || "gemini-3.5-flash";
      var that = this;

      var byId = function (sId) {
        return that.byId(Fragment.createId("idGitAiFrag", sId)) || that.byId(sId);
      };

      var oLoading = byId("idSideAiLoading");
      if (oLoading) oLoading.setVisible(true);
      var oError = byId("idSideAiError");
      if (oError) oError.setVisible(false);
      var oResultBox = byId("idSideAiResultBox");
      if (oResultBox) oResultBox.setVisible(false);

      var sLocal = (this._mGitModel && this._mGitModel.original) || "";
      var sTarget = (this._mGitModel && this._mGitModel.modified) || "";
      var oLocalMeta = this._oLocalMeta || {};
      var oTargetMeta = this._oTargetMeta || {};

      AiReview.checkSyntaxAndQuality(
        this._sType,
        this._sName,
        sLocal,
        sTarget,
        sLocale,
        sMode,
        oLocalMeta,
        oTargetMeta,
        sModel
      ).then(function (oResult) {
        AiPanelRenderer.render(byId, oResult, oI18n);
      }).catch(function (oErr) {
        if (oLoading) oLoading.setVisible(false);
        if (oError) {
          oError.setText(String(oErr && oErr.message ? oErr.message : oErr));
          oError.setVisible(true);
        }
      });
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
      var oDetailModel = this.getOwnerComponent().getModel("detail");
      if (oDetailModel) {
        oDetailModel.setProperty("/selectedVersionCount", aIndices.length);
      }
      this.byId("btnCompare").setEnabled(aIndices.length === 2);
    },

    onViewVersionSourcePress: function () {
      var oTable = this.byId("idVersionsTable");
      var aIndices = oTable ? oTable.getSelectedIndices() : [];
      if (aIndices.length !== 1) {
        MessageToast.show(this._i18n("selectOneVersion") || "Please select 1 version to view source.");
        return;
      }
      var oRowData = oTable.getContextByIndex(aIndices[0]).getObject();
      this._openSingleVersionSource(oRowData);
    },

    onRowViewSourcePress: function (oEvent) {
      var oCtx = oEvent.getSource().getBindingContext("detail");
      if (!oCtx) return;
      var oRowData = oCtx.getObject();
      this._openSingleVersionSource(oRowData);
    },

    _openSingleVersionSource: function (oRowData) {
      if (!oRowData) return;
      var sServerType = oRowData.ServerType || "L";
      var sVers = padVers(oRowData.VersionNo);
      var sObjType = this._sType || oRowData.ObjectType;
      var sObjName = this._sName || oRowData.ObjectName;
      var that = this;

      var oMeta = Object.assign({}, oRowData, {
        ObjectType: sObjType,
        ObjectName: sObjName,
        ServerType: sServerType,
        VersionNo: sVers
      });

      var sObjUri = this.getOwnerComponent().getManifestEntry("sap.app").dataSources.objService.uri.replace(/\/?$/, "/");
      var sUrl = sObjUri + "SourceCodeView?$filter=" + encodeURIComponent("ServerType eq '" + sServerType + "' and ObjectType eq '" + sObjType + "' and ObjectName eq '" + sObjName.replace(/'/g, "''") + "' and VersionNo eq '" + sVers + "'");

      this._openSourceDialog(sObjType, sObjName, sServerType, oMeta);
      ValueHelp.fetchJson(sUrl, 15000).then(function (aRes) {
        var oItem = (aRes && aRes[0]) || { SourceCodeText: "" };
        var sCode = oItem.SourceCodeText || "";
        that._pendingSourceCode = sCode;
        var oM = that.getView().getModel("detail") || that._app();
        if (oM) {
          oM.setProperty("/viewSourceCode", sCode);
          oM.setProperty("/viewSourceHash", oItem.SrcHash || "V_" + sVers);
          oM.setProperty("/viewSourceMessage", "Version " + that.formatVersionNo(sVers) + " loaded (" + (oItem.LineCount || sCode.split("\n").length) + " lines)");
        }
        that._renderCodeHost(sCode, sObjType);
      }).catch(function (e) {
        MessageToast.show("Failed to load source for version " + sVers + ": " + e);
      });
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

      this._oVersLeftMeta = oLeft;
      this._oVersRightMeta = oRight;

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
        var sLang = that._getMonacoLang(that._sType);
        that._mVersModel = {
          original: oResLeft.SourceCodeText || "",
          modified: oResRight.SourceCodeText || "",
          language: sLang
        };

        that._oVersDiffHost.setModel(that._mVersModel).then(function () {
          that.byId("idDetailDynamicPage").setBusy(false);
          that._oVersDiffHost.setSideBySide(that._bSideVers);
        });

        if (that._sType === "TABL") {
          that._sTableDiffVersLeft = padVers(oLeft.VersionNo);
          that._sTableDiffVersRight = padVers(oRight.VersionNo);
          that._sTableDiffLeftLabel = sTitleL;
          that._sTableDiffRightLabel = sTitleR;
        }
      }).catch(function(e) {
        that.byId("idDetailDynamicPage").setBusy(false);
        MessageBox.error("Failed to load version source code.\n" + String(e));
      });
    },

    // ==========================================
    // TAB: TABLE DATA COMPARE (Diff-First)
    // ==========================================
    _loadTableDataDiff: function () {
      if (this._sType !== "TABL") { return; }
      var that = this;
      var oDetailModel = this.getOwnerComponent().getModel("detail");
      var sCmpUri = this.getOwnerComponent().getManifestEntry("sap.app").dataSources.mainService.uri.replace(/\/?$/, "/");

      var sLeftVers = this._sTableDiffVersLeft || "";
      var sRightVers = this._sTableDiffVersRight || "";
      var sLeftLabel = this._sTableDiffLeftLabel || "Local Active";
      var sRightLabel = this._sTableDiffRightLabel || "Target Snapshot";

      oDetailModel.setProperty("/tableDiffLeftLabel", sLeftLabel);
      oDetailModel.setProperty("/tableDiffRightLabel", sRightLabel);
      oDetailModel.setProperty("/tableDiffSummaryText", "Loading table data diff...");
      oDetailModel.setProperty("/tableDiffSummaryState", "Information");

      var aFilters = [
        "ObjectType eq 'TABL'",
        "ObjectName eq '" + this._sName.replace(/'/g, "''") + "'",
        "CompareMode eq 'TABLE_DATA'"
      ];
      if (sLeftVers) {
        aFilters.push("VersionNo eq '" + sLeftVers + "'");
      }
      if (sRightVers) {
        aFilters.push("VersionNoRight eq '" + sRightVers + "'");
      }

      var sUrl = sCmpUri + "Compare?$filter=" + encodeURIComponent(aFilters.join(" and "));
      var oDp = this.byId("idDetailDynamicPage");
      if (oDp) { oDp.setBusy(true); }

      ValueHelp.fetchJson(sUrl, 20000).then(function (aResults) {
        if (oDp) { oDp.setBusy(false); }
        var oItem = (aResults && aResults[0]) || {};
        var sJson = oItem.SourceCode || oItem.TargetCode || "{}";
        var oData = {};
        try {
          oData = JSON.parse(sJson);
        } catch (e) {
          oData = { summary: { totalLeft: 0, totalRight: 0, totalDiff: 0, inserted: 0, updated: 0, deleted: 0 }, columns: [], diffRows: [] };
        }

        that._oTableDiffData = oData;
        that._renderTableDiffGrids(oData);
      }).catch(function (e) {
        if (oDp) { oDp.setBusy(false); }
        oDetailModel.setProperty("/tableDiffSummaryText", "Failed to load table diff: " + e);
        oDetailModel.setProperty("/tableDiffSummaryState", "Error");
      });
    },

    _renderTableDiffGrids: function (oData) {
      var oDetailModel = this.getOwnerComponent().getModel("detail");
      var oSummary = oData.summary || {};
      var aCols = oData.columns || [];
      var aDiffRows = oData.diffRows || [];

      var iTotalDiff = oSummary.totalDiff || 0;
      var iTotalLeft = oSummary.totalLeft || 0;
      var iTotalRight = oSummary.totalRight || 0;

      oDetailModel.setProperty("/tableLeftRowCount", iTotalLeft);
      oDetailModel.setProperty("/tableRightRowCount", iTotalRight);
      oDetailModel.setProperty("/tableLeftRowCountText", iTotalLeft + " total rows");
      oDetailModel.setProperty("/tableRightRowCountText", iTotalRight + " total rows");

      oDetailModel.setProperty("/tableDiffTotalCount", iTotalDiff);
      oDetailModel.setProperty("/tableDiffUpdateCount", oSummary.updated || 0);
      oDetailModel.setProperty("/tableDiffInsertCount", oSummary.inserted || 0);
      oDetailModel.setProperty("/tableDiffDeleteCount", oSummary.deleted || 0);
      oDetailModel.setProperty("/tableDiffIsCapped", !!oSummary.isCapped);
      oDetailModel.setProperty("/tableDataIsIdentical", iTotalDiff === 0);

      if (iTotalDiff === 0) {
        oDetailModel.setProperty("/tableDiffSummaryText", "Data 100% Identical (" + iTotalLeft + " rows)");
        oDetailModel.setProperty("/tableDiffSummaryState", "Success");
        return;
      }

      oDetailModel.setProperty("/tableDiffSummaryText", iTotalDiff + " difference(s) detected (Ins: " + (oSummary.inserted || 0) + ", Mod: " + (oSummary.updated || 0) + ", Del: " + (oSummary.deleted || 0) + ")");
      oDetailModel.setProperty("/tableDiffSummaryState", "Warning");

      var sFilterKey = oDetailModel.getProperty("/tableDiffFilterKey") || "ALL";
      var aFilteredDiffs = aDiffRows;
      if (sFilterKey !== "ALL") {
        aFilteredDiffs = aDiffRows.filter(function (d) { return d.diffType === sFilterKey; });
      }

      var aLeftRows = [];
      var aRightRows = [];

      aFilteredDiffs.forEach(function (d, idx) {
        var oL = {};
        var oR = {};
        try { oL = d.leftRowJson ? JSON.parse(d.leftRowJson) : {}; } catch (e) {}
        try { oR = d.rightRowJson ? JSON.parse(d.rightRowJson) : {}; } catch (e) {}

        oL._diffType = d.diffType;
        oL._keyValue = d.keyValue;
        oL._changedFields = d.changedFields || [];
        oL._rowIndex = idx + 1;

        oR._diffType = d.diffType;
        oR._keyValue = d.keyValue;
        oR._changedFields = d.changedFields || [];
        oR._rowIndex = idx + 1;

        aLeftRows.push(oL);
        aRightRows.push(oR);
      });

      var oTblLeft = this.byId("idTableDataLeft");
      var oTblRight = this.byId("idTableDataRight");

      if (oTblLeft) {
        this._buildDynamicDiffColumns(oTblLeft, aCols, "L");
        oTblLeft.setModel(new JSONModel(aLeftRows), "tblLeft");
        oTblLeft.bindRows("tblLeft>/");
      }

      if (oTblRight) {
        this._buildDynamicDiffColumns(oTblRight, aCols, "R");
        oTblRight.setModel(new JSONModel(aRightRows), "tblRight");
        oTblRight.bindRows("tblRight>/");
      }
    },

    _buildDynamicDiffColumns: function (oTable, aCols, sSide) {
      oTable.destroyColumns();

      var sModelName = sSide === "L" ? "tblLeft" : "tblRight";
      var oStatusCol = new sap.ui.table.Column({
        width: "7.5rem",
        label: new sap.m.Label({ text: "Diff Status", design: "Bold" }),
        template: new sap.m.ObjectStatus({
          text: {
            path: sModelName + ">_diffType",
            formatter: function (sType) {
              if (sType === "UPDATE") return "Modified";
              if (sType === "INSERT") return sSide === "L" ? "Missing (Local)" : "Inserted (Target)";
              if (sType === "DELETE") return sSide === "L" ? "Deleted (Target)" : "Missing (Target)";
              return sType || "";
            }
          },
          state: {
            path: sModelName + ">_diffType",
            formatter: function (sType) {
              if (sType === "UPDATE") return "Warning";
              if (sType === "INSERT") return sSide === "L" ? "None" : "Success";
              if (sType === "DELETE") return sSide === "L" ? "Error" : "None";
              return "None";
            }
          },
          icon: {
            path: sModelName + ">_diffType",
            formatter: function (sType) {
              if (sType === "UPDATE") return "sap-icon://edit";
              if (sType === "INSERT") return sSide === "L" ? "sap-icon://border" : "sap-icon://add";
              if (sType === "DELETE") return sSide === "L" ? "sap-icon://delete" : "sap-icon://border";
              return "";
            }
          }
        })
      });
      oTable.addColumn(oStatusCol);

      aCols.forEach(function (col) {
        var sField = col.name;
        var bIsKey = !!col.isKey;
        var sHeaderLabel = col.text ? col.name + " (" + col.text + ")" : col.name;

        var oColumn = new sap.ui.table.Column({
          width: bIsKey ? "9.5rem" : "9rem",
          sortProperty: sField,
          filterProperty: sField,
          label: new sap.m.HBox({
            alignItems: "Center",
            items: [
              new sap.ui.core.Icon({
                src: "sap-icon://key",
                size: "0.75rem",
                color: "Critical",
                visible: bIsKey,
                class: "sapUiTinyMarginEnd"
              }),
              new sap.m.Label({ text: sHeaderLabel, design: bIsKey ? "Bold" : "Standard" })
            ]
          }),
          template: new sap.m.Text({
            text: {
              parts: [
                { path: sModelName + ">" + sField },
                { path: sModelName + ">_diffType" }
              ],
              formatter: function (vVal, sDiffType) {
                if (sSide === "L" && sDiffType === "INSERT") {
                  return "—";
                }
                if (sSide === "R" && sDiffType === "DELETE") {
                  return "—";
                }
                return vVal === undefined || vVal === null ? "" : String(vVal);
              }
            },
            wrapping: false
          })
        });
        oTable.addColumn(oColumn);
      });
    },

    onTableDiffFilterChange: function (oEvent) {
      var sKey = oEvent.getParameter("item") ? oEvent.getParameter("item").getKey() : oEvent.getSource().getSelectedKey();
      var oDetailModel = this.getOwnerComponent().getModel("detail");
      oDetailModel.setProperty("/tableDiffFilterKey", sKey);
      if (this._oTableDiffData) {
        this._renderTableDiffGrids(this._oTableDiffData);
      }
    },

    onReloadTableDataDiff: function () {
      this._loadTableDataDiff();
    },

    onToggleVersAiPanel: function () {
      var oDetailModel = this.getOwnerComponent().getModel("detail");
      var bShow = !oDetailModel.getProperty("/showVersAiPanel");
      oDetailModel.setProperty("/showVersAiPanel", bShow);
      if (bShow) {
        this._runVersAiAudit();
      }
    },

    _runVersAiAudit: function () {
      var oDetailModel = this.getOwnerComponent().getModel("detail");
      var oI18n = this.getOwnerComponent().getModel("i18n").getResourceBundle();
      var sLocale = (oI18n.sLocale || "en").split("_")[0].toLowerCase();
      var sMode = oDetailModel.getProperty("/aiExecutionMode") || "BE_SAP";
      var sModel = oDetailModel.getProperty("/aiModel") || "gemini-3.5-flash";
      var that = this;

      var byId = function (sId) {
        return that.byId(Fragment.createId("idVersAiFrag", sId)) || that.byId(sId);
      };

      var oLoading = byId("idSideAiLoading");
      if (oLoading) oLoading.setVisible(true);
      var oError = byId("idSideAiError");
      if (oError) oError.setVisible(false);
      var oResultBox = byId("idSideAiResultBox");
      if (oResultBox) oResultBox.setVisible(false);

      var sLeft = (this._mVersModel && this._mVersModel.original) || "";
      var sRight = (this._mVersModel && this._mVersModel.modified) || "";
      var oLeftMeta = this._oVersLeftMeta || {};
      var oRightMeta = this._oVersRightMeta || {};

      AiReview.checkSyntaxAndQuality(
        this._sType,
        this._sName,
        sLeft,
        sRight,
        sLocale,
        sMode,
        oLeftMeta,
        oRightMeta,
        sModel
      ).then(function (oResult) {
        AiPanelRenderer.render(byId, oResult, oI18n);
      }).catch(function (oErr) {
        if (oLoading) oLoading.setVisible(false);
        if (oError) {
          oError.setText(String(oErr && oErr.message ? oErr.message : oErr));
          oError.setVisible(true);
        }
      });
    },

    onRunAiSideAudit: function () {
      var oTabBar = this.byId("idCompareIconTabBar");
      var sKey = oTabBar ? oTabBar.getSelectedKey() : "gitReview";
      if (sKey === "versionMgmt") {
        this._runVersAiAudit();
      } else {
        this._runGitAiAudit();
      }
    },

    onCloseAiSidePanel: function () {
      var oDetailModel = this.getOwnerComponent().getModel("detail");
      oDetailModel.setProperty("/showGitAiPanel", false);
      oDetailModel.setProperty("/showVersAiPanel", false);
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
      var oBox = this.byId("monacoGitContainer");
      var oDom = oBox ? oBox.getDomRef() : null;
      if (!oDom) {
        var sId = this.getView().createId("monacoGitContainer");
        oDom = document.getElementById(sId) || document.querySelector('[id$="monacoGitContainer"]');
      }
      if (!oDom) { return; }
      if (!this._oGitDiffHost) {
        this._oGitDiffHost = new DiffHost(oDom);
      } else if (bForceReattach || !this._oGitDiffHost.isAttached() || this._oGitDiffHost._el !== oDom) {
        this._oGitDiffHost.attachTo(oDom);
      }
    },

    _ensureVersDiffHost: function (bForceReattach) {
      var oBox = this.byId("monacoVersContainer");
      var oDom = oBox ? oBox.getDomRef() : null;
      if (!oDom) {
        var sId = this.getView().createId("monacoVersContainer");
        oDom = document.getElementById(sId) || document.querySelector('[id$="monacoVersContainer"]');
      }
      if (!oDom) { return; }
      if (!this._oVersDiffHost) {
        this._oVersDiffHost = new DiffHost(oDom);
      } else if (bForceReattach || !this._oVersDiffHost.isAttached() || this._oVersDiffHost._el !== oDom) {
        this._oVersDiffHost.attachTo(oDom);
      }
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
        var sTr = oApp.getProperty("/currentTR") || oApp.getProperty("/trkorr");
        if (!sTr || sTr === "DUMMY") {
          var oDetailModel = this.getOwnerComponent().getModel("detail");
          sTr = oDetailModel && oDetailModel.getProperty("/trkorr");
        }
        if (sTr && sTr !== "DUMMY") {
          oApp.setProperty("/layout", LayoutType.TwoColumnsMidExpanded);
          oApp.setProperty("/currentModule", "detail");
          this._oRouter.navTo("detail", {
            trkorr: encodeURIComponent(sTr)
          });
        } else {
          oApp.setProperty("/layout", LayoutType.OneColumn);
          oApp.setProperty("/currentModule", "trSearch");
          this._oRouter.navTo("trSearch");
        }
      }
    },

    // ==========================================
    // TAB 3: DUAL-ACTION AI REVIEW (DUAL MODE: FE_DIRECT / BE_SAP)
    // ==========================================
    _getAiMode: function () {
      var oDetailModel = this.getView().getModel("detail");
      var sMode = oDetailModel ? oDetailModel.getProperty("/aiExecutionMode") : null;
      if (!sMode) {
        var oSb = this.byId("sbAiMode");
        sMode = (oSb && oSb.getSelectedKey()) || "BE_SAP";
      }
      return sMode;
    },

    _getAiModel: function () {
      var oDetailModel = this.getView().getModel("detail");
      var sModel = oDetailModel ? oDetailModel.getProperty("/aiModel") : null;
      if (!sModel) {
        var oSb = this.byId("sbAiModel");
        sModel = (oSb && oSb.getSelectedKey()) || "gemini-3.5-flash";
      }
      return sModel;
    },

    onAiModelChange: function (oEvent) {
      var sKey = oEvent.getParameter("selectedItem") ? oEvent.getParameter("selectedItem").getKey() : oEvent.getSource().getSelectedKey();
      var oDetailModel = this.getOwnerComponent().getModel("detail");
      if (oDetailModel) {
        oDetailModel.setProperty("/aiModel", sKey);
      }
      var oAppModel = this.getOwnerComponent().getModel("appView");
      if (oAppModel) {
        oAppModel.setProperty("/aiModel", sKey);
      }
    },

    onAiExecutionModeChange: function (oEvent) {
      var sKey = oEvent.getParameter("item") ? oEvent.getParameter("item").getKey() : oEvent.getSource().getSelectedKey();
      var oDetailModel = this.getOwnerComponent().getModel("detail");
      if (oDetailModel) {
        oDetailModel.setProperty("/aiExecutionMode", sKey);
      }
      var oAppModel = this.getOwnerComponent().getModel("appView");
      if (oAppModel) {
        oAppModel.setProperty("/aiExecutionMode", sKey);
      }
    },

    onAiSyntaxCheckPress: function () {
      var that = this;
      var oI18n = this.getOwnerComponent().getModel("i18n").getResourceBundle();

      if (!this._mGitModel) {
        MessageToast.show(oI18n.getText("aiReviewNoData"));
        return;
      }

      var sLocale = (oI18n.sLocale || "en").split("_")[0].toLowerCase();
      var sMode = this._getAiMode();
      var sModel = this._getAiModel();

      this.byId("idAiLoading").setVisible(true);
      var sLoadKey = sMode === "BE_SAP" ? "aiSyntaxCheckingSap" : "aiSyntaxChecking";
      this.byId("idAiLoadingText").setText(oI18n.getText(sLoadKey) || "Auditing ABAP syntax & code quality...");
      this.byId("idAiSyntaxResultPanel").setVisible(false);
      this.byId("idAiTransportResultPanel").setVisible(false);
      this.byId("idAiError").setVisible(false);

      var oTabBar = this.byId("idCompareIconTabBar");
      if (oTabBar.getSelectedKey() !== "aiReview") {
        oTabBar.setSelectedKey("aiReview");
      }

      AiReview.checkSyntaxAndQuality(
        this._sType,
        this._sName,
        this._mGitModel.original,
        this._mGitModel.modified,
        sLocale,
        sMode,
        this._oLocalMeta || {},
        this._oTargetMeta || {},
        sModel
      ).then(function (oResult) {
        that._renderSyntaxResult(oResult, oI18n);
      }).catch(function (oErr) {
        that.byId("idAiLoading").setVisible(false);
        var oErrStrip = that.byId("idAiError");
        var sErrMsg = String(oErr && oErr.message ? oErr.message : oErr);
        if (sMode === "BE_SAP") {
          sErrMsg += " " + oI18n.getText("aiBackendFallbackHint");
        }
        oErrStrip.setText(sErrMsg);
        oErrStrip.setVisible(true);
      });
    },

    _renderSyntaxResult: function (oResult, oI18n) {
      this.byId("idAiLoading").setVisible(false);

      var mStatusState = { PASSED: "Success", WARNING: "Warning", ERROR: "Error" };
      var mStatusIcon  = { PASSED: "✅", WARNING: "⚠️", ERROR: "🔴" };
      var sStatus = (oResult.syntax_status || "WARNING").toUpperCase();
      var oStatusCtrl = this.byId("idAiSyntaxStatus");
      oStatusCtrl.setState(mStatusState[sStatus] || "Warning");
      oStatusCtrl.setText((mStatusIcon[sStatus] || "") + " " + (oI18n.getText("aiSyntax_" + sStatus) || sStatus));

      // Score badge
      var sScoreText = "Score: " + (oResult.syntax_score || "N/A");
      if (oResult.mode === "DUAL" && oResult.target_score) {
        sScoreText = "Local: " + oResult.syntax_score + " | Target: " + oResult.target_score;
      }
      this.byId("idAiSyntaxScore").setText(sScoreText);

      // Clean ABAP Verdict
      var sVerdict = oResult.clean_abap_verdict || "Compliant";
      var oVerdictCtrl = this.byId("idAiCleanVerdict");
      oVerdictCtrl.setText("Clean ABAP: " + sVerdict);
      oVerdictCtrl.setState(sVerdict.indexOf("Compliant") > -1 ? "Success" : "Warning");

      // Better Side Badge & Comparison Box (when DUAL or better_side present)
      var oBetterSideCtrl = this.byId("idAiBetterSide");
      var oCompBox = this.byId("idAiComparisonBox");
      var sBetterSide = (oResult.better_side || "").toUpperCase();

      if (sBetterSide) {
        var mBetterText = {
          LOCAL: "🏆 Local Code is Better",
          TARGET: "🏆 Target Code is Better",
          EQUIVALENT: "⚖️ Both Sides are Equivalent"
        };
        var mBetterState = {
          LOCAL: "Success",
          TARGET: "Information",
          EQUIVALENT: "None"
        };
        oBetterSideCtrl.setText(mBetterText[sBetterSide] || ("Better: " + sBetterSide));
        oBetterSideCtrl.setState(mBetterState[sBetterSide] || "Information");
        oBetterSideCtrl.setVisible(true);

        if (oResult.better_side_reason || oResult.best_version_recommendation) {
          this.byId("idAiBetterSideReasonStrip").setText("⚖️ Comparison: " + (oResult.better_side_reason || "—"));
          this.byId("idAiBestRecommendationStrip").setText("💡 Synthesis & Improvement: " + (oResult.best_version_recommendation || "—"));
          oCompBox.setVisible(true);
        } else {
          oCompBox.setVisible(false);
        }
      } else {
        oBetterSideCtrl.setVisible(false);
        oCompBox.setVisible(false);
      }

      this.byId("idAiSyntaxSummaryText").setText(oResult.summary || "—");

      var aFindings = oResult.findings || [];
      var oList = this.byId("idAiFindingsList");
      oList.destroyItems();

      if (aFindings.length > 0) {
        aFindings.forEach(function (f) {
          if (typeof f === 'string') {
            oList.addItem(new StandardListItem({ title: f, icon: "sap-icon://hint", wrapping: true }));
            return;
          }
          var sIcon = f.type === "SYNTAX_ERROR" ? "sap-icon://error" : (f.type === "WARNING" ? "sap-icon://alert" : "sap-icon://hint");
          var sSide = f.side ? "[" + f.side.toUpperCase() + "] " : "";
          var sLineNum = f.line_number ? "[Line " + f.line_number + "] " : "";
          var sRawSnippet = (f.line_or_snippet || "").trim();

          var sLoc = "";
          if (sRawSnippet) {
            if (sRawSnippet.indexOf("Line") === 0 || sRawSnippet.indexOf("Dòng") === 0 || sRawSnippet.indexOf("[Line") === 0 || sRawSnippet.indexOf("[Dòng") === 0) {
              sLoc = (sRawSnippet.indexOf("[") === 0 ? sRawSnippet : "[" + sRawSnippet + "]") + " ";
            } else {
              sLoc = (sLineNum || "") + "[" + sRawSnippet.replace(/^\[|\]$/g, "") + "] ";
            }
          } else if (sLineNum) {
            sLoc = sLineNum;
          }

          var sTitle = sSide + sLoc + (f.message || "");
          var sSugPrefix = (oI18n && oI18n.getText("aiSuggestionPrefix")) || "💡 Cách sửa / Gợi ý Clean ABAP: ";
          var sDesc = f.suggestion ? sSugPrefix + f.suggestion : "";
          oList.addItem(new StandardListItem({
            title: sTitle,
            description: sDesc,
            icon: sIcon,
            wrapping: true
          }));
        });
      }

      this.byId("idAiSyntaxResultPanel").setVisible(true);
    },

    onAiTransportReviewPress: function () {
      var that = this;
      var oI18n = this.getOwnerComponent().getModel("i18n").getResourceBundle();

      if (!this._mGitModel) {
        MessageToast.show(oI18n.getText("aiReviewNoData"));
        return;
      }

      var sLocale = (oI18n.sLocale || "en").split("_")[0].toLowerCase();
      var sMode = this._getAiMode();
      var sModel = this._getAiModel();

      this.byId("idAiLoading").setVisible(true);
      var sLoadKey = sMode === "BE_SAP" ? "aiReviewAnalyzingSap" : "aiReviewAnalyzing";
      this.byId("idAiLoadingText").setText(oI18n.getText(sLoadKey) || oI18n.getText("aiReviewAnalyzing"));
      this.byId("idAiSyntaxResultPanel").setVisible(false);
      this.byId("idAiTransportResultPanel").setVisible(false);
      this.byId("idAiError").setVisible(false);

      var oTabBar = this.byId("idCompareIconTabBar");
      if (oTabBar.getSelectedKey() !== "aiReview") {
        oTabBar.setSelectedKey("aiReview");
      }

      AiReview.reviewTransport(
        this._sType,
        this._sName,
        this._mGitModel.original,
        this._mGitModel.modified,
        sLocale,
        sMode,
        sModel
      ).then(function (oResult) {
        that._renderTransportResult(oResult, oI18n);
      }).catch(function (oErr) {
        that.byId("idAiLoading").setVisible(false);
        var oErrStrip = that.byId("idAiError");
        var sErrMsg = String(oErr && oErr.message ? oErr.message : oErr);
        if (sMode === "BE_SAP") {
          sErrMsg += " " + oI18n.getText("aiBackendFallbackHint");
        }
        oErrStrip.setText(sErrMsg);
        oErrStrip.setVisible(true);
      });
    },

    onAiReviewPress: function () {
      this.onAiTransportReviewPress();
    },

    _renderTransportResult: function (oResult, oI18n) {
      this.byId("idAiLoading").setVisible(false);

      // Impact level -> ObjectStatus state
      var mImpactState = { LOW: "Success", MEDIUM: "Warning", HIGH: "Error", CRITICAL: "Error" };
      var mImpactIcon  = { LOW: "\u2705", MEDIUM: "\u26A0", HIGH: "\uD83D\uDD34", CRITICAL: "\uD83D\uDEA8" };
      var sImpact = (oResult.impact_level || "MEDIUM").toUpperCase();
      var oImpactCtrl = this.byId("idAiImpactStatus");
      oImpactCtrl.setState(mImpactState[sImpact] || "Warning");
      oImpactCtrl.setText((mImpactIcon[sImpact] || "") + " " + oI18n.getText("aiImpact_" + sImpact, [sImpact]));

      // Recommendation -> ObjectStatus state
      var mRecState = { TRANSPORT: "Success", DO_NOT_TRANSPORT: "Error", REVIEW_REQUIRED: "Warning" };
      var mRecText  = { TRANSPORT: "aiRec_TRANSPORT", DO_NOT_TRANSPORT: "aiRec_DO_NOT_TRANSPORT", REVIEW_REQUIRED: "aiRec_REVIEW_REQUIRED" };
      var sRec = (oResult.recommendation || "REVIEW_REQUIRED").toUpperCase();
      var oRecCtrl = this.byId("idAiRecommendStatus");
      oRecCtrl.setState(mRecState[sRec] || "Warning");
      oRecCtrl.setText(oI18n.getText(mRecText[sRec] || "aiRec_REVIEW_REQUIRED"));

      // Summary
      this.byId("idAiSummaryText").setText(oResult.summary || "—");

      // Risks list
      var aRisks = oResult.risks || [];
      var oRisksBox = this.byId("idAiRisksBox");
      var oRisksList = this.byId("idAiRisksList");
      oRisksList.destroyItems();
      if (aRisks.length > 0) {
        aRisks.forEach(function (r) {
          var sRiskText = typeof r === 'string' ? r : (r.risk || r.message || r.description || JSON.stringify(r));
          oRisksList.addItem(new StandardListItem({ title: sRiskText, icon: "sap-icon://alert", wrapping: true }));
        });
        oRisksBox.setVisible(true);
      } else {
        oRisksBox.setVisible(false);
      }

      // Notes list (Pre & Post-Import Guidelines)
      var aNotes = oResult.notes || [];
      var oNotesBox = this.byId("idAiNotesBox");
      var oNotesList = this.byId("idAiNotesList");
      oNotesList.destroyItems();
      if (aNotes.length > 0) {
        aNotes.forEach(function (n) {
          var sNoteText = typeof n === 'string' ? n : (n.note || n.message || n.description || JSON.stringify(n));
          oNotesList.addItem(new StandardListItem({ title: sNoteText, icon: "sap-icon://notes", wrapping: true }));
        });
        oNotesBox.setVisible(true);
      } else {
        oNotesBox.setVisible(false);
      }

      // Reason
      this.byId("idAiReasonText").setText(oResult.reason || "—");

      this.byId("idAiTransportResultPanel").setVisible(true);
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
