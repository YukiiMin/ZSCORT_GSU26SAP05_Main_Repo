sap.ui.define([
  "zscort/app/controller/BaseController",
  "sap/ui/model/json/JSONModel",
  "sap/m/MessageBox",
  "sap/m/MessageToast",
  "sap/f/library",
  "zscort/app/monaco/DiffHost",
  "zscort/app/util/ValueHelp",
  "zscort/app/util/AiReview",
  "sap/m/StandardListItem"
], function (
  BaseController,
  JSONModel,
  MessageBox,
  MessageToast,
  fLibrary,
  DiffHost,
  ValueHelp,
  AiReview,
  StandardListItem
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
      this._oRouter.getRoute("trCompare").attachPatternMatched(this._onDetailMatched, this);
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
      var oArgs = oEvent.getParameter("arguments");
      if (!oArgs || !oArgs.objectType || !oArgs.objectName) { return; }
      this._sType = oArgs.objectType;
      this._sName = decodeURIComponent(oArgs.objectName);
      
      var oDetailModel = this.getOwnerComponent().getModel("detail");
      oDetailModel.setProperty("/ObjectType", this._sType);
      oDetailModel.setProperty("/ObjectName", this._sName);
      oDetailModel.setProperty("/versions", []);
      oDetailModel.setProperty("/showEditor", false);
      if (!oDetailModel.getProperty("/aiExecutionMode")) {
        oDetailModel.setProperty("/aiExecutionMode", "FE_DIRECT");
      }

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

        if (that._oGitDiffHost) {
          that._oGitDiffHost.setModel(that._mGitModel).then(function () {
            that.byId("idDetailDynamicPage").setBusy(false);
            that._oGitDiffHost.setSideBySide(that._bSideGit);
          });
        } else {
          that.byId("idDetailDynamicPage").setBusy(false);
        }
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

    // ==========================================
    // TAB 3: DUAL-ACTION AI REVIEW (DUAL MODE: FE_DIRECT / BE_SAP)
    // ==========================================
    _getAiMode: function () {
      var oDetailModel = this.getView().getModel("detail");
      var sMode = oDetailModel ? oDetailModel.getProperty("/aiExecutionMode") : null;
      if (!sMode) {
        var oSb = this.byId("sbAiMode");
        sMode = (oSb && oSb.getSelectedKey()) || "FE_DIRECT";
      }
      return sMode;
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
        sMode
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
          var sSnippet = f.line_or_snippet ? "[" + f.line_or_snippet + "] " : "";
          var sTitle = sSide + sSnippet + (f.message || "");
          var sDesc = f.suggestion ? "💡 Suggestion: " + f.suggestion : "";
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
        sMode
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
