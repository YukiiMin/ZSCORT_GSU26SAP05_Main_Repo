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

      var sInitialTab = oApp.getProperty("/compareInitialTab") || "gitReview";
      oApp.setProperty("/compareInitialTab", "");
      var oTabBar = this.byId("idCompareIconTabBar");
      if (oTabBar) {
        oTabBar.setSelectedKey(sInitialTab);
      }

      if (!oDetailModel.getProperty("/versionServerType")) {
        oDetailModel.setProperty("/versionServerType", "L");
      }

      this._mGitModel = null;
      this._mVersModel = null;
      this._oLocalMeta = null;
      this._oTargetMeta = null;

      // Lazy load only the active tab
      if (sInitialTab === "versionMgmt") {
        this.onReloadVersions();
      } else {
        this._loadGitReviewSource();
      }
    },

    // ==========================================
    // ADT FORM DIFF MODEL BINDING HELPER
    // ==========================================
    _applyAdtFormModels: function (sLeftCode, sRightCode, oLeftMeta, oRightMeta) {
      if (this._sType === "DOMA") {
        this.getView().setModel(new JSONModel(AdtFormParser.parseDomain(sLeftCode)), "adtDomain");
        this.getView().setModel(new JSONModel(AdtFormParser.parseDomain(sRightCode)), "adtDomainTarget");
      } else if (this._sType === "DTEL") {
        this.getView().setModel(new JSONModel(AdtFormParser.parseDataElement(sLeftCode)), "adtDtel");
        this.getView().setModel(new JSONModel(AdtFormParser.parseDataElement(sRightCode)), "adtDtelTarget");
      } else if (this._sType === "MSAG") {
        this.getView().setModel(new JSONModel(AdtFormParser.parseMessageClass(sLeftCode)), "adtMsag");
        this.getView().setModel(new JSONModel(AdtFormParser.parseMessageClass(sRightCode)), "adtMsagTarget");
      } else if (this._sType === "DEVC") {
        var oLMeta = oLeftMeta || this._oVersLeftMeta || this._oLocalMeta;
        var oRMeta = oRightMeta || this._oVersRightMeta || this._oTargetMeta;
        this.getView().setModel(new JSONModel(AdtFormParser.parsePackage(sLeftCode, oLMeta)), "adtDevc");
        this.getView().setModel(new JSONModel(AdtFormParser.parsePackage(sRightCode, oRMeta)), "adtDevcTarget");
      } else if (this._sType === "TTYP") {
        this.getView().setModel(new JSONModel(AdtFormParser.parseTableType(sLeftCode)), "adtTtyp");
        this.getView().setModel(new JSONModel(AdtFormParser.parseTableType(sRightCode)), "adtTtypTarget");
      }
    },

    // ==========================================
    // TAB 1: GIT REVIEW / SERVER COMPARE (Local Active vs Target)
    // ==========================================
    _loadGitReviewSource: function () {
      var that = this;
      var oObjUri = this.getOwnerComponent().getManifestEntry("sap.app").dataSources.objService.uri.replace(/\/?$/, "/");
      var sUrlLocal = oObjUri + "SourceCodeView?$filter=ServerType eq 'L' and ObjectType eq '" + this._sType + "' and ObjectName eq '" + this._sName.replace(/'/g, "''") + "' and VersionNo eq '99998'";
      var sUrlTarget = oObjUri + "SourceCodeView?$filter=ServerType eq 'T' and ObjectType eq '" + this._sType + "' and ObjectName eq '" + this._sName.replace(/'/g, "''") + "'";
      var sUrlLocalMeta = oObjUri + "LocalObjects?$filter=ObjectType eq '" + this._sType + "' and ObjectName eq '" + this._sName.replace(/'/g, "''") + "'";
      var sUrlTargetMeta = oObjUri + "TargetObjects?$filter=ObjectType eq '" + this._sType + "' and ObjectName eq '" + this._sName.replace(/'/g, "''") + "'";

      var oTabBar = this.byId("idCompareIconTabBar");
      var bGitActive = !oTabBar || oTabBar.getSelectedKey() === "gitReview";
      var oDp = this.byId("idDetailDynamicPage");
      if (oDp && bGitActive) oDp.setBusy(true);

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

        var aNotSupportedTypes = ["TRAN", "NROB", "WAPA", "SSFO", "SHLP"];
        var bNotSupported = aNotSupportedTypes.indexOf(that._sType) !== -1 ||
          (oResLocal && oResLocal.Message === "NOT_SUPPORTED");

        var sTargetCode = (!bNotSupported && bTargetExists && oResTarget && oResTarget.SourceCodeText) ? oResTarget.SourceCodeText : "";
        var sLocalCode = (!bNotSupported && bLocalExists && oResLocal && oResLocal.SourceCodeText) ? oResLocal.SourceCodeText : "";

        var bIsStructure = that._sType === "TABL" && (
          (sLocalCode && (sLocalCode.indexOf("define structure") !== -1 || sLocalCode.indexOf("#STRUCTURE") !== -1)) ||
          (sTargetCode && (sTargetCode.indexOf("define structure") !== -1 || sTargetCode.indexOf("#STRUCTURE") !== -1)) ||
          (oResLocal && oResLocal.Message && oResLocal.Message.indexOf("structure") !== -1)
        );

        that._sGitLocalCode = sLocalCode;
        that._sGitTargetCode = sTargetCode;

        var oDetailModel = that.getOwnerComponent().getModel("detail");
        if (oDetailModel) {
          oDetailModel.setProperty("/isStructure", bIsStructure);
          oDetailModel.setProperty("/subCategory", bIsStructure ? "Structure" : (that._sType === "TABL" ? "Database Table" : ""));
          oDetailModel.setProperty("/isNotSupported", bNotSupported);
          oDetailModel.setProperty("/targetExists", bTargetExists);
          oDetailModel.setProperty("/localExists", bLocalExists);

          if (bNotSupported) {
            oDetailModel.setProperty("/compareMode", "text");
          } else if (["DOMA", "DTEL", "MSAG", "DEVC", "TTYP"].indexOf(that._sType) !== -1) {
            that._applyAdtFormModels(sLocalCode, sTargetCode);
            oDetailModel.setProperty("/compareMode", "form");
          } else {
            oDetailModel.setProperty("/compareMode", "text");
          }
        }

        if (that._sType === "CLAS") {
          var aLocalComps = [];
          var aTargetComps = [];
          try {
            if (bLocalExists && oResLocal && oResLocal.MetadataText) {
              aLocalComps = JSON.parse(oResLocal.MetadataText);
            }
          } catch (e) {}
          try {
            if (bTargetExists && oResTarget && oResTarget.MetadataText) {
              aTargetComps = JSON.parse(oResTarget.MetadataText);
            }
          } catch (e) {}
          that._aClassLocalComps = aLocalComps;
          that._aClassTargetComps = bTargetExists ? aTargetComps : [];
          that._lastFullLocalSrc = sLocalCode;
          that._lastFullTargetSrc = bTargetExists ? sTargetCode : "";

          var oCpLocal = aLocalComps.find(function (c) { return c.id === "CP"; });
          var oCpTarget = bTargetExists ? aTargetComps.find(function (c) { return c.id === "CP"; }) : null;
          if (oCpLocal && oCpLocal.source) {
            sLocalCode = oCpLocal.source;
          }
          if (bTargetExists && oCpTarget && oCpTarget.source) {
            sTargetCode = oCpTarget.source;
          } else if (!bTargetExists) {
            sTargetCode = "";
          }

          if (oDetailModel) {
            oDetailModel.setProperty("/activeClassComponent", "CP");
            var sCpStatus = bTargetExists ? "Component: CP (Global Class)" : "Component: CP (Local Only)";
            var sCpState = bTargetExists ? "Success" : "Information";
            oDetailModel.setProperty("/classComponentStatus", sCpStatus);
            oDetailModel.setProperty("/classComponentStatusState", sCpState);
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
          if (oDetailModel && oDetailModel.getProperty("/compareMode") === "form") {
            var oDpInner = that.byId("idDetailDynamicPage");
            if (oDpInner) oDpInner.setBusy(false);
            return;
          }
          that._ensureGitDiffHost();
          if (that._oGitDiffHost) {
            that._oGitDiffHost.setModel(that._mGitModel).then(function () {
              var oDpInner = that.byId("idDetailDynamicPage");
              if (oDpInner) oDpInner.setBusy(false);
              that._oGitDiffHost.setSideBySide(that._bSideGit);
            });
          } else if (iAttempt < 10) {
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

    onCompareClassTabSelect: function (oEvent) {
      var sKey = oEvent.getParameter("key") || oEvent.getSource().getSelectedKey();
      var oDetailModel = this.getOwnerComponent().getModel("detail");
      if (oDetailModel) {
        oDetailModel.setProperty("/activeClassComponent", sKey);
      }

      var bTargetExists = oDetailModel ? !!oDetailModel.getProperty("/targetExists") : false;
      var oLocalComp = (this._aClassLocalComps || []).find(function (c) { return c.id === sKey; });
      var oTargetComp = bTargetExists ? (this._aClassTargetComps || []).find(function (c) { return c.id === sKey; }) : null;

      var sLocalSrc = oLocalComp ? (oLocalComp.source || "") : "";
      var sTargetSrc = (bTargetExists && oTargetComp) ? (oTargetComp.source || "") : "";

      if (!sLocalSrc && sKey === "CP" && this._lastFullLocalSrc) {
        sLocalSrc = this._lastFullLocalSrc;
      }
      if (bTargetExists && !sTargetSrc && sKey === "CP" && this._lastFullTargetSrc) {
        sTargetSrc = this._lastFullTargetSrc;
      }

      var bHasLocal = !!(oLocalComp && oLocalComp.hasContent);
      var bHasTarget = bTargetExists && !!(oTargetComp && oTargetComp.hasContent);
      var sStatus = "";
      var sStatusState = "None";

      if (!bTargetExists) {
        sStatus = bHasLocal ? "Component: " + sKey + " (Local Only)" : "Component: " + sKey + " (Empty)";
        sStatusState = bHasLocal ? "Information" : "None";
      } else {
        sStatus = (bHasLocal || bHasTarget) ? "Component: " + sKey : "(Empty on both)";
        sStatusState = (bHasLocal && bHasTarget) ? "Success" : (bHasLocal ? "Information" : "None");
      }

      if (oDetailModel) {
        oDetailModel.setProperty("/classComponentStatus", sStatus);
        oDetailModel.setProperty("/classComponentStatusState", sStatusState);
      }

      this._mGitModel = {
        original: sLocalSrc,
        modified: sTargetSrc,
        language: this._getMonacoLang(this._sType)
      };

      if (this._oGitDiffHost) {
        this._oGitDiffHost.setModel(this._mGitModel);
      }

      // If versions are currently compared in Monaco Editor, re-compare for newly selected sub-component
      if (this._oVersDiffHost && oDetailModel && oDetailModel.getProperty("/showEditor") && this._oVersLeftMeta && this._oVersRightMeta) {
        this.onComparePress();
      }
    },

    onTabSelect: function (oEvent) {
      var sKey = oEvent.getParameter("key");
      var that = this;
      setTimeout(function () {
        if (sKey === "gitReview") {
          if (!that._mGitModel) {
            that._loadGitReviewSource();
          } else {
            that._ensureGitDiffHost(true);
            if (that._mGitModel && that._oGitDiffHost) {
              that._oGitDiffHost.setModel(that._mGitModel);
            }
            if (["DOMA", "DTEL", "MSAG", "DEVC", "TTYP"].indexOf(that._sType) !== -1 && that._sGitLocalCode !== undefined) {
              that._applyAdtFormModels(that._sGitLocalCode, that._sGitTargetCode);
            }
          }
        } else if (sKey === "versionMgmt") {
          that.onReloadVersions();
          var oDetailModel = that.getOwnerComponent().getModel("detail");
          if (oDetailModel.getProperty("/showEditor")) {
            that._ensureVersDiffHost(true);
            if (that._mVersModel && that._oVersDiffHost) {
              that._oVersDiffHost.setModel(that._mVersModel);
            }
            if (["DOMA", "DTEL", "MSAG", "DEVC", "TTYP"].indexOf(that._sType) !== -1 && that._sVersSrcLeft !== undefined) {
              that._applyAdtFormModels(that._sVersSrcLeft, that._sVersSrcRight);
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

    onVersCompareModeChange: function (oEvent) {
      var sKey = oEvent.getParameter("item") ? oEvent.getParameter("item").getKey() : oEvent.getSource().getSelectedKey();
      var oDetailModel = this.getOwnerComponent().getModel("detail");
      if (oDetailModel) {
        oDetailModel.setProperty("/versCompareMode", sKey);
      }
      if (sKey === "text") {
        var that = this;
        setTimeout(function () {
          that._ensureVersDiffHost(true);
          if (that._mVersModel && that._oVersDiffHost) {
            that._oVersDiffHost.setModel(that._mVersModel);
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
      var sModel = oDetailModel.getProperty("/aiModel") || "gemini-3.8-flash";
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

      var sServerType = oDetailModel.getProperty("/versionServerType") || "L";
      var sUri = this._mainServiceUri();
      var sFilter = "ServerType eq '" + sServerType + "' and ObjectType eq '" + this._sType + "' and ObjectName eq '" + this._sName.replace(/'/g, "''") + "'";
      var sUrl = sUri + "Version?$filter=" + sFilter;

      ValueHelp.fetchJson(sUrl, 12000).then(function (aItems) {
        var aList = aItems || [];

        aList.sort(function (a, b) {
           var bActiveA = !!(a.IsActive || padVers(a.VersionNo) === "99998");
           var bActiveB = !!(b.IsActive || padVers(b.VersionNo) === "99998");
           if (bActiveA && !bActiveB) return -1;
           if (!bActiveA && bActiveB) return 1;
           var vA = padVers(a.VersionNo);
           var vB = padVers(b.VersionNo);
           return vB.localeCompare(vA);
        });

        oDetailModel.setProperty("/versions", aList);
        oDetailModel.setProperty("/busyVersions", false);
        var oTbl = that.byId("idVersionsTable");
        if (oTbl) { oTbl.clearSelection(); }
      }).catch(function () {
        oDetailModel.setProperty("/versions", []);
        oDetailModel.setProperty("/busyVersions", false);
      });
    },

    onVersionServerTypeChange: function (oEvent) {
      var sKey = oEvent.getParameter("item").getKey();
      var oDetailModel = this.getOwnerComponent().getModel("detail");
      if (oDetailModel) {
        oDetailModel.setProperty("/versionServerType", sKey);
      }
      this.onReloadVersions();
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
      var oDetailModel = this.getOwnerComponent().getModel("detail");
      var sActiveComp = (sObjType === "CLAS" && oDetailModel) ? (oDetailModel.getProperty("/activeClassComponent") || "CP") : "CP";

      if (sObjType === "CLAS") {
        sObjName = (this._sName || oRowData.ObjectName || "").split("=")[0].trim();
      }

      var oMeta = Object.assign({}, oRowData, {
        ObjectType: sObjType,
        ObjectName: sObjName,
        ServerType: sServerType,
        VersionNo: sVers,
        preferredComponent: sActiveComp
      });

      this._openSourceDialog(sObjType, sObjName, sServerType, oMeta);
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

      var sActiveComp = oDetailModel.getProperty("/activeClassComponent") || "CP";
      if (this._sType === "CLAS") {
        sTitleL += " (" + sActiveComp + ")";
        sTitleR += " (" + sActiveComp + ")";
      }

      oDetailModel.setProperty("/leftTitle", sTitleL);
      oDetailModel.setProperty("/rightTitle", sTitleR);

      var sObjUri = this.getOwnerComponent().getManifestEntry("sap.app").dataSources.objService.uri.replace(/\/?$/, "/");
      var sObjNameL = this._sName;
      var sObjNameR = this._sName;
      if (this._sType === "CLAS") {
        var sCleanBase = (this._sName || "").split("=")[0].trim();
        sObjNameL = sCleanBase;
        sObjNameR = sCleanBase;
      }

      var sUrlLeft = sObjUri + "SourceCodeView?$filter=ServerType eq '" + oLeft.ServerType + "' and ObjectType eq '" + this._sType + "' and ObjectName eq '" + sObjNameL.replace(/'/g, "''") + "' and VersionNo eq '" + padVers(oLeft.VersionNo) + "'";
      var sUrlRight = sObjUri + "SourceCodeView?$filter=ServerType eq '" + oRight.ServerType + "' and ObjectType eq '" + this._sType + "' and ObjectName eq '" + sObjNameR.replace(/'/g, "''") + "' and VersionNo eq '" + padVers(oRight.VersionNo) + "'";

      oDetailModel.setProperty("/showEditor", true);
      this.byId("idDetailDynamicPage").setBusy(true);

      var that = this;
      Promise.all([
        ValueHelp.fetchJson(sUrlLeft, 15000),
        ValueHelp.fetchJson(sUrlRight, 15000)
      ]).then(function(aResults) {
        var oResLeft = (aResults[0] && aResults[0][0]) || { SourceCodeText: "" };
        var oResRight = (aResults[1] && aResults[1][0]) || { SourceCodeText: "" };

        var sSrcLeft = oResLeft.SourceCodeText || "";
        var sSrcRight = oResRight.SourceCodeText || "";

        if (that._sType === "CLAS") {
          if (oResLeft.MetadataText) {
            try {
              var aL = JSON.parse(oResLeft.MetadataText);
              var cL = aL.find(function (c) { return c.id === sActiveComp; });
              if (cL && cL.source && (!sSrcLeft || sActiveComp !== "CP")) { sSrcLeft = cL.source; }
            } catch (e) {}
          }
          if (oResRight.MetadataText) {
            try {
              var aR = JSON.parse(oResRight.MetadataText);
              var cR = aR.find(function (c) { return c.id === sActiveComp; });
              if (cR && cR.source && (!sSrcRight || sActiveComp !== "CP")) { sSrcRight = cR.source; }
            } catch (e) {}
          }
        }

        that._sVersSrcLeft = sSrcLeft;
        that._sVersSrcRight = sSrcRight;

        var bIsAdtForm = ["DOMA", "DTEL", "MSAG", "DEVC", "TTYP"].indexOf(that._sType) !== -1;
        if (bIsAdtForm) {
          that._applyAdtFormModels(sSrcLeft, sSrcRight);
          oDetailModel.setProperty("/versCompareMode", "form");
        } else {
          oDetailModel.setProperty("/versCompareMode", "text");
        }

        that._ensureVersDiffHost();
        var sLang = that._getMonacoLang(that._sType);
        that._mVersModel = {
          original: sSrcLeft,
          modified: sSrcRight,
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
      if (oDetailModel && oDetailModel.getProperty("/isStructure")) { return; }
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
      var bTargetHasSnapshot = oSummary.targetHasSnapshot !== false && oSummary.target_has_snapshot !== false && oSummary.statusText !== "TARGET_NOT_IN_SNAPSHOT" && oSummary.status_text !== "TARGET_NOT_IN_SNAPSHOT";

      oDetailModel.setProperty("/targetHasSnapshot", bTargetHasSnapshot);
      oDetailModel.setProperty("/tableLeftRowCount", iTotalLeft);
      oDetailModel.setProperty("/tableRightRowCount", iTotalRight);
      oDetailModel.setProperty("/tableLeftRowCountText", iTotalLeft + " total rows");
      oDetailModel.setProperty("/tableRightRowCountText", bTargetHasSnapshot ? (iTotalRight + " total rows") : "No snapshot");

      oDetailModel.setProperty("/tableDiffTotalCount", bTargetHasSnapshot ? iTotalDiff : 0);
      oDetailModel.setProperty("/tableDiffUpdateCount", bTargetHasSnapshot ? (oSummary.updated || 0) : 0);
      oDetailModel.setProperty("/tableDiffInsertCount", bTargetHasSnapshot ? (oSummary.inserted || 0) : 0);
      oDetailModel.setProperty("/tableDiffDeleteCount", bTargetHasSnapshot ? (oSummary.deleted || 0) : 0);
      oDetailModel.setProperty("/tableDiffIsCapped", !!oSummary.isCapped);

      if (!bTargetHasSnapshot) {
        oDetailModel.setProperty("/tableDataIsIdentical", false);
        oDetailModel.setProperty("/tableDiffSummaryText", "Target has no snapshot data. Displaying Local active data (" + iTotalLeft + " rows).");
        oDetailModel.setProperty("/tableDiffSummaryState", "Information");
      } else if (iTotalDiff === 0) {
        oDetailModel.setProperty("/tableDataIsIdentical", true);
        oDetailModel.setProperty("/tableDiffSummaryText", "Data 100% Identical (" + iTotalLeft + " rows)");
        oDetailModel.setProperty("/tableDiffSummaryState", "Success");
        return;
      } else {
        oDetailModel.setProperty("/tableDataIsIdentical", false);
        oDetailModel.setProperty("/tableDiffSummaryText", iTotalDiff + " difference(s) detected (Ins: " + (oSummary.inserted || 0) + ", Mod: " + (oSummary.updated || 0) + ", Del: " + (oSummary.deleted || 0) + ")");
        oDetailModel.setProperty("/tableDiffSummaryState", "Warning");
      }

      var sFilterKey = oDetailModel.getProperty("/tableDiffFilterKey") || "ALL";
      var aFilteredDiffs = aDiffRows;
      if (bTargetHasSnapshot && sFilterKey !== "ALL") {
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

        if (bTargetHasSnapshot && d.diffType !== "LOCAL_ONLY") {
          oR._diffType = d.diffType;
          oR._keyValue = d.keyValue;
          oR._changedFields = d.changedFields || [];
          oR._rowIndex = idx + 1;
          aRightRows.push(oR);
        }

        aLeftRows.push(oL);
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
        if (!bTargetHasSnapshot) {
          oTblRight.setNoData("Target object is not snapshotted yet");
        }
        oTblRight.setModel(new JSONModel(aRightRows), "tblRight");
        oTblRight.bindRows("tblRight>/");
      }
    },

    /**
     * Build dynamic diff columns for left or right table
     * @param {sap.ui.table.Table} oTable Target sap.ui.table.Table control
     * @param {object[]} aCols Columns metadata array
     * @param {string} sSide 'L' for Local or 'R' for Target
     */
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
              if (sType === "LOCAL_ONLY") return sSide === "L" ? "Local Active" : "No Snapshot";
              return sType || "";
            }
          },
          state: {
            path: sModelName + ">_diffType",
            formatter: function (sType) {
              if (sType === "UPDATE") return "Warning";
              if (sType === "INSERT") return sSide === "L" ? "None" : "Success";
              if (sType === "DELETE") return sSide === "L" ? "Error" : "None";
              if (sType === "LOCAL_ONLY") return sSide === "L" ? "Information" : "None";
              return "None";
            }
          },
          icon: {
            path: sModelName + ">_diffType",
            formatter: function (sType) {
              if (sType === "UPDATE") return "sap-icon://edit";
              if (sType === "INSERT") return sSide === "L" ? "sap-icon://border" : "sap-icon://add";
              if (sType === "DELETE") return sSide === "L" ? "sap-icon://delete" : "sap-icon://border";
              if (sType === "LOCAL_ONLY") return sSide === "L" ? "sap-icon://database" : "";
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
      var sModel = oDetailModel.getProperty("/aiModel") || "gemini-3.8-flash";
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
      var oDetailModel = this.getOwnerComponent().getModel("detail");
      if (oDetailModel) {
        oDetailModel.setProperty("/sideBySideForm", this._bSideVers);
      }
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
        sModel = (oSb && oSb.getSelectedKey()) || "gemini-3.8-flash";
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

    formatVersionNoWithActive: function(sVer, bIsActive) {
      if (!sVer) return "";
      if (padVers(sVer) === "99998") return "Active";
      var sClean = parseInt(sVer, 10).toString();
      if (bIsActive) {
        return "Active (" + sClean + ")";
      }
      return sClean;
    },

    formatDate: function(sDate) {
      if (!sDate) return "";
      var s = String(sDate).trim();
      if (s.length === 8 && /^\d{8}$/.test(s)) {
        return s.substr(0,4) + "-" + s.substr(4,2) + "-" + s.substr(6,2);
      }
      if (/^\d{4}-\d{2}-\d{2}/.test(s)) {
        return s.substring(0, 10);
      }
      return s;
    },

    formatTime: function(sTime) {
      if (!sTime) return "";
      var s = String(sTime).trim();
      if (s.length === 6 && /^\d{6}$/.test(s)) {
        return s.substr(0,2) + ":" + s.substr(2,2) + ":" + s.substr(4,2);
      }
      if (/^\d{2}:\d{2}/.test(s)) {
        return s.substring(0, 8);
      }
      return s;
    }

  });
});
