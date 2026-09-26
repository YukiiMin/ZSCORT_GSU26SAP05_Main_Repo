sap.ui.define([
  "sap/ui/core/mvc/Controller",
  "sap/ui/core/Fragment",
  "sap/m/MessageToast",
  "sap/m/MessageBox",
  "sap/f/library",
  "zscort/app/monaco/CodeHost",
  "sap/ui/core/format/DateFormat",
  "zscort/app/util/AiReview",
  "zscort/app/util/AiPanelRenderer",
  "sap/ui/model/json/JSONModel",
  "zscort/app/util/AdtFormParser",
  "zscort/app/util/ValueHelp"
], function (Controller, Fragment, MessageToast, MessageBox, fLibrary, CodeHost, DateFormat, AiReview, AiPanelRenderer, JSONModel, AdtFormParser, ValueHelp) {
  "use strict";

  var LayoutType = fLibrary.LayoutType;

  return Controller.extend("zscort.app.controller.BaseController", {

    getRouter: function () {
      return this.getOwnerComponent().getRouter();
    },

    getResourceBundle: function () {
      return this.getOwnerComponent().getModel("i18n").getResourceBundle();
    },

    onButtonNavObjSearchPress: function () {
      var oApp = this._app();
      oApp.setProperty("/layout", LayoutType.OneColumn);
      oApp.setProperty("/currentModule", "objSearch");
      this.getOwnerComponent().getRouter().navTo("objSearch");
    },

    onNavObjSearch: function () {
      this.onButtonNavObjSearchPress();
    },

    onNavTrSearch: function () {
      try {
        var oApp = this._app();
        // Collapse Compare mid/end columns so TrSearch (begin) is fully visible
        oApp.setProperty("/layout", LayoutType.OneColumn);
        oApp.setProperty("/currentModule", "trSearch");
        this.getOwnerComponent().getRouter().navTo("trSearch");
      } catch (oErr) {
        // eslint-disable-next-line no-console
        console.error("onNavTrSearch failed:", oErr);
        MessageToast.show("Navigation to TR Search failed: " + (oErr && oErr.message || oErr));
      }
    },

    onNavCompare: function () {
      // Segmented "Code Compare" without object keys → TR master list
      var oApp = this._app();
      oApp.setProperty("/layout", LayoutType.OneColumn);
      oApp.setProperty("/currentModule", "compare");
      this.getOwnerComponent().getRouter().navTo("master");
    },

    onHomePress: function () {
      this.onButtonNavObjSearchPress();
    },

    onMenuPress: function () {
      this.onButtonNavObjSearchPress();
    },

    _app: function () {
      return this.getOwnerComponent().getModel("appView");
    },

    _i18n: function (sKey) {
      return this.getOwnerComponent().getModel("i18n").getResourceBundle().getText(sKey);
    },

    /**
     * Direct "quick compare" entry point (Object Search / TR Search rows) — opens Compare
     * as a 2-column view (Begin = origin search screen, Mid = Compare) via the "objCompare"
     * route. The TR-flow (Master → Detail → Compare) uses the 3-column "compare" route via
     * Detail.controller.js#onButtonComparePress directly, unaffected by this helper.
     */
    navToCompare: function (sObjectType, sObjectName, sServerId, sCompareStatus) {
      var oApp = this._app();
      var sOrigin = oApp.getProperty("/currentModule");
      if (sOrigin !== "objSearch" && sOrigin !== "trSearch") {
        sOrigin = "objSearch";
      }
      oApp.setProperty("/compareOrigin", sOrigin);
      oApp.setProperty("/currentModule", "compare");
      // Choose route based on origin module: trCompare (Begin = TrSearch) vs objCompare (Begin = ObjSearch)
      var sRoute = (sOrigin === "trSearch") ? "trCompare" : "objCompare";
      this.getOwnerComponent().getRouter().navTo(sRoute, {
        objectType: sObjectType,
        objectName: encodeURIComponent(sObjectName)
      });
    },

    _openSourceDialog: function (sObjType, sObjName, sServerType, oMetaData) {
      var oView = this.getView();
      var oApp = this._app();
      var oM = oView.getModel("objSearch") || oView.getModel("detail") || oView.getModel("trSearch") || oApp;
      var that = this;

      function setProp(sKey, v) {
        oM.setProperty("/" + sKey, v);
        if (oApp && oApp !== oM) {
          oApp.setProperty("/" + sKey, v);
        }
      }

      var sVN = oMetaData && oMetaData.VersionNo ? this.padVers(oMetaData.VersionNo) : "";
      var sDisplayVers = sVN ? (sVN === "99998" || sVN === "ACTIVE" ? "Active" : sVN) : "";

      setProp("viewSourceType", sObjType);
      setProp("viewSourceName", sObjName);
      setProp("viewSourceServer", sServerType);
      setProp("viewSourceVersionNo", sDisplayVers);
      setProp("viewSourceRawVersionNo", sVN);
      setProp("viewSourceMessage", "Loading...");
      setProp("viewSourceHash", "");
      setProp("viewSourceCode", "");
      setProp("viewSourceMetaData", oMetaData || {}); // Store metadata passed by callers
      this._pendingSourceCode = null;
      this._fullClassSource = null;
      this._pendingObjType = sObjType;

      if (!this._oSourceDialog) {
        Fragment.load({
          id: oView.getId(),
          name: "zscort.app.view.ViewSource",
          controller: this
        }).then(function (oDialog) {
          that._oSourceDialog = oDialog;
          oView.addDependent(that._oSourceDialog);
          that._oSourceDialog.open();
          that._loadSourceCode(sObjType, sObjName, sServerType, oM);
        });
      } else {
        this._oSourceDialog.open();
        this._loadSourceCode(sObjType, sObjName, sServerType, oM);
      }
    },

    /**
     * Get Monaco language identifier for a given object type.
     * @param {string} [sObjType] Development Object Type (e.g. 'CLAS', 'TABL', 'DDLS')
     * @returns {string} Monaco language ('abap' or 'sql')
     */
    _getMonacoLang: function (sObjType) {
      var t = (sObjType || this._pendingObjType || this._sType || "").toUpperCase();
      if (t === "PROG" || t === "CLAS" || t === "INTF" || t === "FUNC" || t === "FUGR") { return "abap"; }
      if (t === "DDLS" || t === "DCLS" || t === "BDEF" || t === "DDLX" || t === "SRVD" || t === "TABL" || t === "DTEL" || t === "DOMA" || t === "TTYP" || t === "VIEW" || t === "MSAG" || t === "DEVC") { return "sql"; }
      return "abap";
    },

    _loadSourceCode: function (sObjType, sObjName, sServerType, oM) {
      var that = this;
      var oApp = this._app();

      function setProp(sKey, v) {
        oM.setProperty("/" + sKey, v);
        if (oApp && oApp !== oM) {
          oApp.setProperty("/" + sKey, v);
        }
      }

      var oOdm = this.getOwnerComponent().getModel("objModel");
      if (!oOdm) {
        setProp("viewSourceMessage", "Mock data loaded");
        setProp("viewSourceHash", "MOCK_HASH_123");
        that._pendingSourceCode = "* Mock ABAP code\nREPORT z_test.";
        that._renderCodeHost(that._pendingSourceCode, sObjType);
        return;
      }

      // Check if viewing Target for a LOCAL_ONLY object
      var oMetaData = oM.getProperty("/viewSourceMetaData") || {};
      if (sServerType === "T" && oMetaData.ExistenceStatus === "LOCAL_ONLY") {
        setProp("viewSourceMessage", "Not available in Target (LOCAL_ONLY)");
        setProp("viewSourceHash", "");
        that._pendingSourceCode = "* ==========================================================================\n* NOT AVAILABLE ON TARGET SERVER\n* ==========================================================================\n*\n* Object: " + sObjType + " " + sObjName + "\n* Status: LOCAL_ONLY\n*\n* This object has NOT been released or applied to the Target repository yet.\n* Please release the associated Transport Request to create a snapshot on Target.\n* ==========================================================================";
        that._renderCodeHost(that._pendingSourceCode, sObjType);
        return;
      }
      if (sServerType === "L" && oMetaData.ExistenceStatus === "TARGET_ONLY") {
        setProp("viewSourceMessage", "Not available in Local (TARGET_ONLY)");
        setProp("viewSourceHash", "");
        that._pendingSourceCode = "* ==========================================================================\n* NOT AVAILABLE ON LOCAL SERVER\n* ==========================================================================\n*\n* Object: " + sObjType + " " + sObjName + "\n* Status: TARGET_ONLY\n*\n* This object only exists in the Target repository snapshot and is not in TADIR.\n* ==========================================================================";
        that._renderCodeHost(that._pendingSourceCode, sObjType);
        return;
      }

      function fetchActive() {
        var sActiveUrl = that._objServiceUri() + "SourceCodeView?$filter=ServerType eq '" + sServerType +
          "' and ObjectType eq '" + sObjType +
          "' and ObjectName eq '" + sObjName.replace(/'/g, "''") + "'";
        ValueHelp.fetchJson(sActiveUrl, 15000).then(function (aItems) {
          if (aItems && aItems.length) {
            var sActiveMsg = (sVN === "99998" || sVN === "ACTIVE") ? "Active Version" : null;
            that._processSourceCodeData(aItems[0], sObjType, sServerType, oM, sActiveMsg);
          } else {
            var sPath = "/SourceCodeView(ServerType='" + sServerType +
              "',ObjectType='" + sObjType +
              "',ObjectName='" + sObjName.replace(/'/g, "''") + "')";
            var oContext = oOdm.bindContext(sPath);
            oContext.requestObject().then(function (oData) {
              var sActiveMsg = (sVN === "99998" || sVN === "ACTIVE") ? "Active Version" : null;
              that._processSourceCodeData(oData, sObjType, sServerType, oM, sActiveMsg);
            }).catch(function (oErr) {
              setProp("viewSourceMessage", "Error: " + (oErr.message || oErr));
              setProp("viewSourceHash", "");
              that._pendingSourceCode = "/* Error loading source */";
              that._renderCodeHost(that._pendingSourceCode, sObjType);
            });
          }
        }).catch(function () {
          var sPath = "/SourceCodeView(ServerType='" + sServerType +
            "',ObjectType='" + sObjType +
            "',ObjectName='" + sObjName.replace(/'/g, "''") + "')";
          var oContext = oOdm.bindContext(sPath);
          oContext.requestObject().then(function (oData) {
            var sActiveMsg = (sVN === "99998" || sVN === "ACTIVE") ? "Active Version" : null;
            that._processSourceCodeData(oData, sObjType, sServerType, oM, sActiveMsg);
          }).catch(function (oErr) {
            setProp("viewSourceMessage", "Error: " + (oErr.message || oErr));
            setProp("viewSourceHash", "");
            that._pendingSourceCode = "/* Error loading source */";
            that._renderCodeHost(that._pendingSourceCode, sObjType);
          });
        });
      }

      // Check if viewing a specific version or historical version for a Released TR
      var sVN = that.padVers(oMetaData.VersionNo);
      if (sVN && sVN !== "ACTIVE" && sVN !== "99998") {
        var sVersUrl = that._objServiceUri() + "SourceCodeView?$filter=ServerType eq '" + sServerType + "' and ObjectType eq '" + sObjType + "' and ObjectName eq '" + sObjName.replace(/'/g, "''") + "' and VersionNo eq '" + sVN + "'";
        ValueHelp.fetchJson(sVersUrl, 10000).then(function (aItems) {
          if (aItems && aItems.length) {
            var sLineCount = aItems[0].LineCount ? " (" + aItems[0].LineCount + " lines)" : "";
            var sMsg = aItems[0].Message ? ("Version " + sVN + " — " + aItems[0].Message) : ("Version " + sVN + sLineCount);
            that._processSourceCodeData(aItems[0], sObjType, sServerType, oM, sMsg);
          } else {
            setProp("viewSourceMessage", "Version " + sVN + " not found or unreadable");
            setProp("viewSourceHash", "");
            that._pendingSourceCode = "";
            that._renderCodeHost(that._pendingSourceCode, sObjType);
          }
        }).catch(function (oErr) {
          setProp("viewSourceMessage", "Error loading Version " + sVN + ": " + (oErr && oErr.message ? oErr.message : oErr));
          setProp("viewSourceHash", "");
          that._pendingSourceCode = "";
          that._renderCodeHost(that._pendingSourceCode, sObjType);
        });
        return;
      }

      if (sServerType === "L" && (oMetaData.Trkorr || oMetaData.ParentTrkorr) && oMetaData.TrStatus === "R") {
        var sReqTrkorr = oMetaData.Trkorr || oMetaData.ParentTrkorr;
        var sVUrl = that._mainServiceUri() + "Version?$filter=ServerType eq 'L' and ObjectType eq '" + sObjType + "' and ObjectName eq '" + sObjName.replace(/'/g, "''") + "'";
        ValueHelp.fetchJson(sVUrl, 10000).then(function (aVers) {
          var oMapped = (aVers || []).find(function (v) {
            return (oMetaData.Trkorr && v.Korrnum === oMetaData.Trkorr) ||
                   (oMetaData.ParentTrkorr && v.Korrnum === oMetaData.ParentTrkorr);
          });
          if (oMapped && oMapped.VersionNo && oMapped.VersionNo !== "99998") {
            var sMappedVN = that.padVers(oMapped.VersionNo);
            setProp("viewSourceVersionNo", sMappedVN);
            setProp("viewSourceRawVersionNo", sMappedVN);
            var sSrcUrl = that._objServiceUri() + "SourceCodeView?$filter=ServerType eq 'L' and ObjectType eq '" + sObjType + "' and ObjectName eq '" + sObjName.replace(/'/g, "''") + "' and VersionNo eq '" + sMappedVN + "'";
            ValueHelp.fetchJson(sSrcUrl, 10000).then(function (aSrc) {
              if (aSrc && aSrc.length) {
                var sNote = "Version " + sMappedVN + " (Snapshot mapped to Released TR " + (oMapped.Korrnum || sReqTrkorr) + ")";
                that._processSourceCodeData(aSrc[0], sObjType, sServerType, oM, sNote);
              } else {
                fetchActive();
              }
            }).catch(fetchActive);
          } else {
            fetchActive();
          }
        }).catch(fetchActive);
        return;
      }

      fetchActive();
    },

    /**
     * Process and display loaded source code data across views.
     * @private
     */
    _processSourceCodeData: function (oData, sObjType, sServerType, oM, sCustomMessage) {
      var that = this;
      var oApp = this._app();
      function setProp(sKey, v) {
        oM.setProperty("/" + sKey, v);
        if (oApp && oApp !== oM) {
          oApp.setProperty("/" + sKey, v);
        }
      }

      var aNotSupportedTypes = ["TRAN", "NROB", "WAPA", "SSFO", "SHLP"];
      var bNotSupported = aNotSupportedTypes.indexOf(sObjType) !== -1 || (oData && oData.Message === "NOT_SUPPORTED");

      if (bNotSupported) {
        setProp("viewSourceMessage", "NOT_SUPPORTED");
        setProp("viewSourceHash", "");
        that._pendingSourceCode = "";
      } else {
        setProp("viewSourceMessage", sCustomMessage || (oData ? oData.Message : "") || "OK");
        setProp("viewSourceHash", (oData ? oData.SrcHash : "") || "");
        that._pendingSourceCode = (oData ? oData.SourceCodeText : "") || "";
      }
      that._pendingObjType = sObjType;

      var bIsStructure = sObjType === "TABL" && (
        (that._pendingSourceCode && (that._pendingSourceCode.indexOf("define structure") !== -1 || that._pendingSourceCode.indexOf("#STRUCTURE") !== -1)) ||
        (oData && oData.Message && oData.Message.indexOf("structure") !== -1)
      );
      setProp("viewSourceIsStructure", bIsStructure);
      setProp("viewSourceSubCategory", bIsStructure ? "Structure" : (sObjType === "TABL" ? "Database Table" : ""));

      if (sObjType === "DOMA") {
        var oDomaData = AdtFormParser.parseDomain(that._pendingSourceCode);
        if (that._oSourceDialog) {
          that._oSourceDialog.setModel(new JSONModel(oDomaData), "adtDomain");
        }
      } else if (sObjType === "DTEL") {
        var oDtelData = AdtFormParser.parseDataElement(that._pendingSourceCode);
        if (that._oSourceDialog) {
          that._oSourceDialog.setModel(new JSONModel(oDtelData), "adtDtel");
        }
      } else if (sObjType === "MSAG") {
        var oMsagData = AdtFormParser.parseMessageClass(that._pendingSourceCode);
        if (that._oSourceDialog) {
          that._oSourceDialog.setModel(new JSONModel(oMsagData), "adtMsag");
        }
      } else if (sObjType === "DEVC") {
        var oMetaForDevc = (oM && oM.getProperty("/viewSourceMetaData")) || {};
        var oDevcData = AdtFormParser.parsePackage(that._pendingSourceCode, oMetaForDevc);
        if (that._oSourceDialog) {
          that._oSourceDialog.setModel(new JSONModel(oDevcData), "adtDevc");
        }
      } else if (sObjType === "TTYP") {
        var oTtypData = AdtFormParser.parseTableType(that._pendingSourceCode);
        if (that._oSourceDialog) {
          that._oSourceDialog.setModel(new JSONModel(oTtypData), "adtTtyp");
        }
      } else if (sObjType === "TABL") {
        if (!bIsStructure && oData && oData.MetadataText) {
          that._renderViewSourceTableData(oData.MetadataText);
        }
      } else if (sObjType === "CLAS") {
        var aClassComponents = null;
        if (oData && oData.MetadataText) {
          try {
            aClassComponents = JSON.parse(oData.MetadataText);
          } catch (e) {
            aClassComponents = null;
          }
        }
        var sVersRaw = that.padVers(oM.getProperty("/viewSourceRawVersionNo") || oM.getProperty("/viewSourceVersionNo"));
        var bIsHistorical = sVersRaw && sVersRaw !== "ACTIVE" && sVersRaw !== "99998";
        that._fullClassSource = bIsHistorical ? null : that._pendingSourceCode;
        setProp("viewSourceClassComponents", aClassComponents || []);
        var sInitialComp = (oM && oM.getProperty("/viewSourceMetaData") && oM.getProperty("/viewSourceMetaData").preferredComponent) || "CP";
        setProp("viewSourceActiveComponent", sInitialComp);
        if (Array.isArray(aClassComponents) && aClassComponents.length > 0) {
          var oChosen = aClassComponents.find(function (c) { return c.id === sInitialComp; }) || aClassComponents[0];
          setProp("viewSourceComponentHasContent", oChosen.hasContent !== false && !!oChosen.source);
          if (sInitialComp === "CP") {
            that._pendingSourceCode = (oChosen && oChosen.source) || (bIsHistorical ? "" : that._fullClassSource) || "";
          } else {
            that._pendingSourceCode = (oChosen && oChosen.source) || "";
          }
        } else {
          setProp("viewSourceComponentHasContent", !!that._pendingSourceCode);
        }

        if (bIsHistorical && !that._pendingSourceCode) {
          that._pendingSourceCode = "";
          setProp("viewSourceComponentHasContent", false);
        }

        var oClassTabs = null;
        if (that._oSourceDialog && that._oSourceDialog.findAggregatedObjects) {
          var aTabs = that._oSourceDialog.findAggregatedObjects(false, function (oCtrl) {
            return oCtrl && oCtrl.getId && oCtrl.getId().indexOf("idViewSourceClassTabs") !== -1;
          });
          if (aTabs && aTabs.length > 0) {
            oClassTabs = aTabs[0];
          }
        }
        if (oClassTabs && oClassTabs.setSelectedKey) {
          oClassTabs.setSelectedKey(sInitialComp);
        }
      }

      var oTabBar = null;
      if (that.getView && that.getView().byId) {
        oTabBar = that.getView().byId("idViewSourceIconTabBar");
      }
      if (!oTabBar && that._oSourceDialog && that._oSourceDialog.findAggregatedObjects) {
        var aBars = that._oSourceDialog.findAggregatedObjects(false, function (oCtrl) {
          return oCtrl && oCtrl.getId && oCtrl.getId().indexOf("idViewSourceIconTabBar") !== -1;
        });
        if (aBars && aBars.length > 0) {
          oTabBar = aBars[0];
        }
      }
      if (oTabBar && oTabBar.setSelectedKey) {
        if (bNotSupported) {
          oTabBar.setSelectedKey("metadata");
        } else if (sObjType === "DOMA" || sObjType === "DTEL" || sObjType === "MSAG" || sObjType === "DEVC" || sObjType === "TTYP") {
          oTabBar.setSelectedKey("adtForm");
        } else {
          oTabBar.setSelectedKey("source");
        }
      }

      setProp("viewSourceCode", that._pendingSourceCode);

      if (!bNotSupported) {
        that._renderCodeHost(that._pendingSourceCode, sObjType);
      }

      // Fetch metadata if it's missing (e.g. opened from TrSearch where we don't have Package/Author)
      var oOdm = this.getOwnerComponent().getModel("objModel");
      var oMetaData = oM.getProperty("/viewSourceMetaData") || {};
      var sObjName = oM.getProperty("/viewSourceName") || (oMetaData && oMetaData.ObjectName) || "";
      if (oOdm && sObjName && !oMetaData.PackageName && !oMetaData.TadirDevclass && !oMetaData.VersionNo) {
        var sEntity = sServerType === "T" ? "TargetObjects" : "LocalObjects";
        var oListBinding = oOdm.bindList("/" + sEntity, null, null, null, {
          "$filter": "ObjectType eq '" + sObjType + "' and ObjectName eq '" + sObjName.replace(/'/g, "''") + "'"
        });
        oListBinding.requestContexts(0, 1).then(function (aContexts) {
          if (aContexts && aContexts.length > 0) {
            setProp("viewSourceMetaData", aContexts[0].getObject());
          }
        }).catch(function (oErr) {
          // ignore error
        });
      }
    },

    onDialogViewSourceAfterOpen: function () {
      if (this._pendingSourceCode !== null && this._pendingSourceCode !== undefined) {
        this._renderCodeHost(this._pendingSourceCode, this._pendingObjType);
      }
      var oApp = this._app();
      var bIsStructure = oApp && oApp.getProperty("/viewSourceIsStructure");
      if (this._pendingObjType === "TABL" && !bIsStructure) {
        var sDataToRender = this._pendingTableDataJson || (this._aViewSourceTableRows ? JSON.stringify(this._aViewSourceTableRows) : "");
        if (sDataToRender) {
          this._renderViewSourceTableData(sDataToRender);
        }
      }
    },

    onDialogViewSourceTabSelect: function (oEvent) {
      var sKey = oEvent.getParameter("key");
      var that = this;
      if (sKey === "source") {
        setTimeout(function () {
          if (that._pendingSourceCode !== null && that._pendingSourceCode !== undefined) {
            that._renderCodeHost(that._pendingSourceCode, that._pendingObjType);
          }
        }, 50);
      } else if (sKey === "tableData") {
        setTimeout(function () {
          var sDataToRender = (that._aViewSourceTableRows && that._aViewSourceTableRows.length > 0)
            ? JSON.stringify(that._aViewSourceTableRows)
            : that._pendingTableDataJson;
          if (sDataToRender) {
            that._renderViewSourceTableData(sDataToRender);
          }
        }, 50);
      }
    },

    onViewSourceClassTabSelect: function (oEvent) {
      var sKey = oEvent.getParameter("key") || oEvent.getSource().getSelectedKey();
      var oApp = this._app();
      if (!oApp) { return; }

      var aComps = oApp.getProperty("/viewSourceClassComponents") || [];
      var oComp = aComps.find(function (c) { return c.id === sKey; });
      oApp.setProperty("/viewSourceActiveComponent", sKey);

      var sVersRaw = this.padVers(oApp.getProperty("/viewSourceRawVersionNo") || oApp.getProperty("/viewSourceVersionNo"));
      var bIsHistorical = sVersRaw && sVersRaw !== "ACTIVE" && sVersRaw !== "99998";
      var sSource = "";
      var bHasContent = true;
      if (sKey === "CP") {
        sSource = (oComp && oComp.source) || (bIsHistorical ? "" : this._fullClassSource) || "";
        if (!sSource && bIsHistorical) {
          sSource = "* Sub-component Global Class (CP) has no archived source in VRSD for version " + sVersRaw + ".\n";
        }
        bHasContent = !!(oComp && oComp.source);
      } else if (oComp) {
        bHasContent = oComp.hasContent !== false && !!oComp.source;
        sSource = oComp.source || ("* Sub-component " + sKey + " has no archived source in VRSD for version " + sVersRaw + ".\n");
      } else {
        bHasContent = false;
        sSource = "* Sub-component " + sKey + " is not defined or empty in this version.\n";
      }

      oApp.setProperty("/viewSourceComponentHasContent", bHasContent);
      this._pendingSourceCode = sSource;
      oApp.setProperty("/viewSourceCode", sSource);
      this._renderCodeHost(sSource, "CLAS");
    },

    _getViewSourceTable: function () {
      var oTable = null;
      if (this.getView && this.getView().byId) {
        oTable = this.getView().byId("idViewSourceDataTable");
      }
      if (!oTable && this._oSourceDialog && this._oSourceDialog.findAggregatedObjects) {
        var aMatches = this._oSourceDialog.findAggregatedObjects(false, function (oCtrl) {
          return oCtrl && oCtrl.getId && oCtrl.getId().indexOf("idViewSourceDataTable") !== -1;
        });
        if (aMatches && aMatches.length > 0) {
          oTable = aMatches[0];
        }
      }
      return oTable || sap.ui.getCore().byId("idViewSourceDataTable");
    },

    _renderViewSourceTableData: function (sJson) {
      var aData = [];
      this._pendingTableDataJson = sJson;
      try {
        if (sJson) {
          aData = JSON.parse(sJson);
        }
      } catch (e) {
        aData = [];
      }
      this._aViewSourceTableRows = aData;

      var oTable = this._getViewSourceTable();

      var oApp = this._app();
      if (oApp) {
        oApp.setProperty("/viewSourceTableCountText", aData.length ? aData.length + " rows retrieved" : "No data");
      }

      if (!oTable) { return; }

      oTable.destroyColumns();
      if (!aData || aData.length === 0) {
        oTable.setModel(new JSONModel([]), "tblData");
        oTable.bindRows("tblData>/");
        return;
      }

      var oFirst = aData[0];
      var aCols = Object.keys(oFirst);
      aCols.forEach(function (sCol) {
        var oColumn = new sap.ui.table.Column({
          label: new sap.m.Label({ text: sCol }),
          template: new sap.m.Text({ text: "{tblData>" + sCol + "}", wrapping: false }),
          width: "9rem",
          sortProperty: sCol,
          filterProperty: sCol
        });
        oTable.addColumn(oColumn);
      });

      oTable.setModel(new JSONModel(aData), "tblData");
      oTable.bindRows("tblData>/");
    },

    onViewSourceTableLiveSearch: function (oEvent) {
      var sQuery = (oEvent.getParameter("newValue") || "").trim().toLowerCase();
      var aRows = this._aViewSourceTableRows || [];
      var aFiltered = aRows;
      if (sQuery) {
        aFiltered = aRows.filter(function (row) {
          return Object.keys(row).some(function (k) {
            return String(row[k] || "").toLowerCase().indexOf(sQuery) !== -1;
          });
        });
      }
      var oTable = this._getViewSourceTable();
      if (oTable) {
        oTable.setModel(new JSONModel(aFiltered), "tblData");
        oTable.bindRows("tblData>/");
      }
      var oApp = this._app();
      if (oApp) {
        oApp.setProperty("/viewSourceTableCountText", aFiltered.length + " rows (of " + aRows.length + ")");
      }
    },

    _renderCodeHost: function (sCode, sObjType) {
      var that = this;
      var oDialog = this._oSourceDialog;
      var iAttempt = 0;
      var sLang = this._getMonacoLang(sObjType);

      function tryRender() {
        iAttempt += 1;
        var el = null;
        if (oDialog && oDialog.getDomRef) {
          var oDom = oDialog.getDomRef();
          if (oDom) {
            el = oDom.querySelector(".codeHost");
          }
        }
        if (!el) {
          el = document.querySelector(".codeHost");
        }
        if (!el) {
          if (iAttempt < 20) {
            setTimeout(tryRender, 50);
          }
          return;
        }
        if (el.offsetHeight < 40) {
          el.style.minHeight = "60vh";
          el.style.height = "60vh";
        }
        if (!that._oCodeHost) {
          that._oCodeHost = new CodeHost(el);
        } else if (!that._oCodeHost.isAttached() || that._oCodeHost._el !== el) {
          that._oCodeHost.attachTo(el);
        }
        that._oCodeHost.setValue(sCode || "", sLang);
      }

      setTimeout(tryRender, 0);
    },

    onDialogViewSourceAfterClose: function () {
      if (this._oCodeHost) {
        this._oCodeHost.dispose();
        this._oCodeHost = null;
      }
      this._pendingSourceCode = null;
      this._pendingObjType = null;
    },

    onButtonCloseDialogPress: function () {
      if (this._oSourceDialog) {
        this._oSourceDialog.close();
      }
    },

    onButtonCopySourcePress: function () {
      var sCode = this._pendingSourceCode;
      if (!sCode) {
        var oView = this.getView();
        var oM = oView.getModel("objSearch") || oView.getModel("detail") || this._app();
        sCode = oM ? oM.getProperty("/viewSourceCode") : "";
      }
      if (sCode) {
        var el = document.createElement("textarea");
        el.value = sCode;
        document.body.appendChild(el);
        el.select();
        document.execCommand("copy");
        document.body.removeChild(el);
        MessageToast.show("Source code copied to clipboard!");
      } else {
        MessageToast.show("No source code to copy.");
      }
    },

    onToggleSourceAiPanel: function () {
      var oApp = this._app();
      var bShow = !oApp.getProperty("/showSourceAiPanel");
      oApp.setProperty("/showSourceAiPanel", bShow);
      if (bShow) {
        this._runSourceAiAudit();
      }
    },

    onAiModelChange: function (oEvent) {
      var sKey = oEvent.getParameter("selectedItem") ? oEvent.getParameter("selectedItem").getKey() : oEvent.getSource().getSelectedKey();
      var oApp = this._app();
      if (oApp) {
        oApp.setProperty("/aiModel", sKey);
      }
      var oDetail = this.getOwnerComponent().getModel("detail");
      if (oDetail) {
        oDetail.setProperty("/aiModel", sKey);
      }
    },

    onAiExecutionModeChange: function (oEvent) {
      var sKey = oEvent.getParameter("item") ? oEvent.getParameter("item").getKey() : oEvent.getSource().getSelectedKey();
      var oApp = this._app();
      if (oApp) {
        oApp.setProperty("/aiExecutionMode", sKey);
      }
      var oDetail = this.getOwnerComponent().getModel("detail");
      if (oDetail) {
        oDetail.setProperty("/aiExecutionMode", sKey);
      }
    },

    onRunAiSideAudit: function () {
      this._runSourceAiAudit();
    },

    onCloseAiSidePanel: function () {
      this._app().setProperty("/showSourceAiPanel", false);
    },

    _runSourceAiAudit: function () {
      var oApp = this._app();
      var oView = this.getView();
      var oM = oView.getModel("objSearch") || oView.getModel("detail") || oApp;
      var sObjType = oM.getProperty("/viewSourceType") || "";
      var sObjName = oM.getProperty("/viewSourceName") || "";
      var sServerType = oM.getProperty("/viewSourceServer") || "L";
      var sCode = this._pendingSourceCode || oM.getProperty("/viewSourceCode") || "";
      var oMeta = oM.getProperty("/viewSourceMetaData") || {};
      var oI18n = this.getOwnerComponent().getModel("i18n").getResourceBundle();
      var sLocale = (oI18n.sLocale || "en").split("_")[0].toLowerCase();
      var sMode = oApp.getProperty("/aiExecutionMode") || oM.getProperty("/aiExecutionMode") || "BE_SAP";
      var sModel = oApp.getProperty("/aiModel") || oM.getProperty("/aiModel") || "gemini-3.8-flash";
      var oDialog = this._oSourceDialog;

      if (!sCode) {
        MessageToast.show(oI18n.getText("aiReviewNoData") || "Source code not loaded yet.");
        return;
      }

      var byId = function (sId) {
        return Fragment.byId(oView.getId(), Fragment.createId("idSourceAiFrag", sId)) || Fragment.byId(oView.getId(), sId) || oView.byId(sId);
      };

      var oLoading = byId("idSideAiLoading");
      if (oLoading) oLoading.setVisible(true);
      var oError = byId("idSideAiError");
      if (oError) oError.setVisible(false);
      var oResultBox = byId("idSideAiResultBox");
      if (oResultBox) oResultBox.setVisible(false);

      var sLocalCode = sServerType === "T" ? "" : sCode;
      var sTargetCode = sServerType === "T" ? sCode : "";
      var oLocalMeta = sServerType === "T" ? {} : oMeta;
      var oTargetMeta = sServerType === "T" ? oMeta : {};

      AiReview.checkSyntaxAndQuality(
        sObjType,
        sObjName,
        sLocalCode,
        sTargetCode,
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

    formatDate: function (vDate) {
      if (!vDate) { return ""; }
      var s = String(vDate);
      var oDate;
      if (/^\d{4}-\d{2}-\d{2}/.test(s)) {
        oDate = new Date(s);
      } else {
        var sDigits = s.replace(/\D/g, "");
        if (sDigits.length >= 8) {
          var y = sDigits.substring(0, 4);
          var m = parseInt(sDigits.substring(4, 6), 10) - 1;
          var d = sDigits.substring(6, 8);
          oDate = new Date(y, m, d);
        }
      }
      if (oDate && !isNaN(oDate.getTime())) {
        var oFormat = DateFormat.getDateInstance({ style: "medium" });
        return oFormat.format(oDate);
      }
      return s;
    },

    onLanguageMenuSelect: function (oEvent) {
      var oItem = oEvent.getParameter("item");
      var sKey = oItem ? oItem.getKey() : "en";
      this._applyLanguage(sKey);
    },

    onLanguageChange: function (oEvent) {
      var sKey = oEvent.getParameter("item") ? oEvent.getParameter("item").getKey() : (oEvent.getParameter("key") || oEvent.getSource().getSelectedKey());
      this._applyLanguage(sKey || "en");
    },

    _applyLanguage: function (sKey) {
      if (!sKey) { return; }
      var sNorm = sKey.toLowerCase();
      localStorage.setItem("scort_lang", sNorm);
      var oUrl = new URL(window.location.href);
      oUrl.searchParams.set("sap-language", sNorm.toUpperCase());
      window.location.href = oUrl.toString();
    },

    onUserProfilePress: function (oEvent) {
      var oButton = oEvent.getSource();
      var oView = this.getView();
      var that = this;

      if (!this._oUserProfilePopover) {
        var oBundle = this.getOwnerComponent().getModel("i18n").getResourceBundle();

        var oPopoverContent = new sap.m.VBox({
          width: "280px",
          items: [
            new sap.m.HBox({
              alignItems: "Center",
              items: [
                new sap.f.Avatar({
                  initials: "{= (${user>/userId} || 'DEV').substring(0, 3) }",
                  displaySize: "S",
                  displayShape: "Circle"
                }).addStyleClass("sapUiSmallMarginEnd"),
                new sap.m.VBox({
                  items: [
                    new sap.m.Title({ text: "{user>/userId}", level: "H4" }),
                    new sap.m.Text({ text: "{i18n>userRoleLabel}" }).addStyleClass("scortRoleText")
                  ]
                })
              ]
            }).addStyleClass("sapUiSmallMarginBottom"),
            new sap.m.VBox({
              items: [
                new sap.m.HBox({
                  justifyContent: "SpaceBetween",
                  items: [
                    new sap.m.Label({ text: oBundle.getText("userClientLabel") + ":" }),
                    new sap.m.Text({ text: "{user>/client}" })
                  ]
                }).addStyleClass("sapUiTinyMarginBottom"),
                new sap.m.HBox({
                  justifyContent: "SpaceBetween",
                  items: [
                    new sap.m.Label({ text: "System ID:" }),
                    new sap.m.Text({ text: "{user>/systemId} (TUM CIT)" })
                  ]
                }).addStyleClass("sapUiTinyMarginBottom"),
                new sap.m.HBox({
                  justifyContent: "SpaceBetween",
                  items: [
                    new sap.m.Label({ text: oBundle.getText("userLanguageLabel") + ":" }),
                    new sap.m.Text({ text: "{= (${user>/language} || 'en').toUpperCase() }" })
                  ]
                })
              ]
            }).addStyleClass("scortProfileDetailsBox")
          ]
        }).addStyleClass("sapUiContentPadding");

        this._oUserProfilePopover = new sap.m.ResponsivePopover({
          title: oBundle.getText("userProfileTitle"),
          placement: "Bottom",
          content: [oPopoverContent]
        });
        oView.addDependent(this._oUserProfilePopover);
      }

      this._oUserProfilePopover.openBy(oButton);
    },

    /**
     * Normalize version number to 5-digit string or upper-case keyword (e.g. '1' -> '00001', 'ACTIVE').
     * @param {string|number} [v]
     * @returns {string}
     */
    padVers: function (v) {
      var s = String(v === undefined || v === null ? "" : v).trim();
      if (!s) { return ""; }
      if (/^\d+$/.test(s)) { return ("00000" + s).slice(-5); }
      return s.toUpperCase();
    },

    /**
     * Format SAP version number (e.g. '00002' -> '2', '99998' -> 'Active').
     * @param {string} [sVer] Version number string
     * @returns {string} Formatted version string
     */
    formatVersionNo: function (sVer) {
      if (!sVer) return "";
      var s = String(sVer).trim();
      if (s === "99998" || s.toLowerCase() === "active") return "Active";
      var n = parseInt(s, 10);
      return isNaN(n) ? s : String(n);
    },

    /**
     * Get Compare (mainService) OData service URI.
     * @returns {string} Service URI with trailing slash
     */
    _mainServiceUri: function () {
      try {
        var s = this.getOwnerComponent().getManifestEntry("sap.app").dataSources.mainService.uri;
        if (s) { return String(s).replace(/\/?$/, "/"); }
      } catch (e) { /* ignore */ }
      var m = this.getOwnerComponent().getModel();
      return (m && m.getServiceUrl) ? m.getServiceUrl().replace(/\/?$/, "/") : "/sap/opu/odata4/sap/zui_scort_compare_o4/srvd/sap/zsd_scort_compare/0001/";
    },

    /**
     * Get ObjSearch (objService) OData service URI.
     * @returns {string} Service URI with trailing slash
     */
    _objServiceUri: function () {
      try {
        var s = this.getOwnerComponent().getManifestEntry("sap.app").dataSources.objService.uri;
        if (s) { return String(s).replace(/\/?$/, "/"); }
      } catch (e) { /* ignore */ }
      var m = this.getOwnerComponent().getModel("objModel");
      return (m && m.getServiceUrl) ? m.getServiceUrl().replace(/\/?$/, "/") : "/sap/opu/odata4/sap/zui_scort_obj_search_o4/srvd/sap/zsd_scort_obj_search/0001/";
    },

    /**
     * Get TrSearch (trService) OData service URI.
     * @returns {string} Service URI with trailing slash
     */
    _trServiceUri: function () {
      try {
        var s = this.getOwnerComponent().getManifestEntry("sap.app").dataSources.trService.uri;
        if (s) { return String(s).replace(/\/?$/, "/"); }
      } catch (e) { /* ignore */ }
      var m = this.getOwnerComponent().getModel("trModel");
      return (m && m.getServiceUrl) ? m.getServiceUrl().replace(/\/?$/, "/") : "/sap/opu/odata4/sap/zui_scort_tr_search_o4/srvd/sap/zsd_scort_tr_search/0001/";
    },

    /**
     * Get OData service URI fallback.
     * @returns {string} Service URI
     */
    _serviceUri: function () {
      return this._objServiceUri();
    },

    /**
     * Retrieves translated text from resource bundle.
     * @param {string} sKey - i18n text key
     * @param {any[]} [aArgs] - Optional replacement arguments
     * @returns {string} Translated text or fallback key
     */
    _getText: function (sKey, aArgs) {
      var oBundle = this.getOwnerComponent().getModel("i18n") ? this.getOwnerComponent().getModel("i18n").getResourceBundle() : null;
      if (!oBundle) {
        var oView = this.getView();
        if (oView && oView.getModel("i18n")) {
          oBundle = oView.getModel("i18n").getResourceBundle();
        }
      }
      return oBundle ? oBundle.getText(sKey, aArgs || []) : sKey;
    },

    releaseErrorText: function (oErr) {
      if (!oErr) { return "Release failed"; }
      var sMsg = oErr.message || String(oErr);
      try {
        var aDetails = oErr.error && oErr.error.details;
        if (aDetails && aDetails.length) {
          sMsg = aDetails.map(function (d) { return d.message; }).filter(Boolean).join("\n") || sMsg;
        }
      } catch (e) { }
      return sMsg;
    },

    fetchInactiveObjects: function (sTrkorr) {
      if (!sTrkorr) {
        return Promise.resolve([]);
      }
      var sSafeTr = String(sTrkorr).replace(/'/g, "''");
      var sUrl = this._trServiceUri() + "InactiveObjects?$filter=Trkorr eq '" + sSafeTr + "'";
      return ValueHelp.fetchJson(sUrl, 15000).then(function (aData) {
        return Array.isArray(aData) ? aData : [];
      }).catch(function () {
        return [];
      });
    },

    handleReleaseError: function (sTrkorr, vErr, oNode) {
      var sErr = typeof vErr === "string" ? vErr : this.releaseErrorText(vErr);
      var that = this;

      if (/inactive|dwinactiv|object_check|check error|check syntax|active state|077|083/i.test(sErr)) {
        this.fetchInactiveObjects(sTrkorr).then(function (aInactive) {
          if (aInactive && aInactive.length > 0) {
            that.showInactiveObjectsDialog(sTrkorr, aInactive, sErr);
          } else {
            MessageBox.error(sErr);
          }
        }).catch(function () {
          MessageBox.error(sErr);
        });
      } else {
        MessageBox.error(sErr);
      }
    },

    showInactiveObjectsDialog: function (sTrkorr, aInactive, sRawErr) {
      if (!this._oInactiveDialog) {
        this._oInactiveDialog = sap.ui.xmlfragment(
          this.getView().getId(),
          "zscort.app.view.fragment.InactiveObjectsDialog",
          this
        );
        this.getView().addDependent(this._oInactiveDialog);
      }

      var sTitle = (this._getText("titleInactiveObjects", []) || "Check for Inactive Objects") + " (" + sTrkorr + ")";
      var sDesc = this._getText("msgInactiveObjectsDesc", [sTrkorr, aInactive.length]) ||
        ("Transport Request/Task " + sTrkorr + " contains " + aInactive.length + " inactive object(s). Please activate these objects in Eclipse ADT or SAP GUI before releasing.");

      var oModel = new JSONModel({
        trkorr: sTrkorr,
        dialogTitle: sTitle,
        description: sDesc,
        objects: aInactive,
        rawError: sRawErr || "",
        selectedObject: {}
      });
      this._oInactiveDialog.setModel(oModel, "inactiveModel");
      this._oInactiveDialog.open();
    },

    onCloseInactiveObjectsDialog: function () {
      if (this._oInactiveDialog) {
        this._oInactiveDialog.close();
      }
    },

    onShowInactiveObjectDetails: function (oEvent) {
      var oCtx = oEvent.getSource().getBindingContext("inactiveModel");
      if (!oCtx) { return; }
      var oObj = oCtx.getObject();
      var oModel = this._oInactiveDialog ? this._oInactiveDialog.getModel("inactiveModel") : null;
      if (!oModel) { return; }

      var sObjType = oObj.ObjectType || "OBJ";
      var sObjName = oObj.ObjectName || "";
      var sTask = oObj.Trkorr || "";
      var sUser = oObj.Uname || "Unknown";

      var sDiag = this._getText("msgInactiveDiagnosis", [sObjType, sObjName, sTask, sUser]);
      var sStep1 = this._getText("msgInactiveResStep1", [sUser, sObjType, sObjName]);
      var sStep2 = this._getText("msgInactiveResStep2", []);
      var sStep3 = this._getText("msgInactiveResStep3", [sTask]);
      var sResFormatted = sStep1 + "<br/>" + sStep2 + "<br/>" + sStep3;

      var oSelected = Object.assign({}, oObj, {
        Diagnosis: sDiag,
        ResolutionFormatted: sResFormatted
      });

      oModel.setProperty("/selectedObject", oSelected);
      oModel.setProperty("/detailTitle", sObjType + " " + sObjName + " - " + (this._getText("lblInactiveDiagnosis", []) || "Inactive Diagnosis"));

      if (!this._oInactiveDetailDialog) {
        this._oInactiveDetailDialog = sap.ui.xmlfragment(
          this.getView().getId() + "_inactiveDetail",
          "zscort.app.view.fragment.InactiveObjectDetailDialog",
          this
        );
        this.getView().addDependent(this._oInactiveDetailDialog);
      }

      this._oInactiveDetailDialog.setModel(oModel, "inactiveModel");
      this._oInactiveDetailDialog.open();
    },

    onCloseInactiveObjectDetailDialog: function () {
      if (this._oInactiveDetailDialog) {
        this._oInactiveDetailDialog.close();
      }
    },

    onOpenSelectedObjectInSearch: function () {
      var oModel = this._oInactiveDialog ? this._oInactiveDialog.getModel("inactiveModel") : null;
      var oObj = oModel ? oModel.getProperty("/selectedObject") : null;
      if (!oObj) { return; }
      if (this._oInactiveDetailDialog) {
        this._oInactiveDetailDialog.close();
      }
      if (this._oInactiveDialog) {
        this._oInactiveDialog.close();
      }
      var sType = oObj.ObjectType || "";
      if (sType === "METH" || sType === "CPUB" || sType === "CPRI" || sType === "CPRO" || sType === "CLSD") {
        sType = "CLAS";
      }
      this.getOwnerComponent().getRouter().navTo("objSearch", {
        "?query": {
          objectName: oObj.ObjectName || "",
          objectType: sType
        }
      });
    },

    onShowOverallErrorDetails: function () {
      var oModel = this._oInactiveDialog ? this._oInactiveDialog.getModel("inactiveModel") : null;
      var sRawErr = (oModel && oModel.getProperty("/rawError")) || "";
      var aObjs = (oModel && oModel.getProperty("/objects")) || [];
      var sTrkorr = (oModel && oModel.getProperty("/trkorr")) || "";

      var sDiagText = this._getText("msgOverallDiagnosis", [sTrkorr, aObjs.length]);
      var sRecom1 = this._getText("msgOverallRecommended1", []);
      var sRecom2 = this._getText("msgOverallRecommended2", []);
      var sRecom3 = this._getText("msgOverallRecommended3", []);
      var sRecom4 = this._getText("msgOverallRecommended4", []);

      var sText = "Transport Request: " + sTrkorr + "\n" +
                  "Total Inactive Object(s): " + aObjs.length + "\n\n" +
                  (this._getText("lblDiagnosisTitle", []) || "CTS Diagnosis") + ":\n" +
                  sDiagText + "\n\n" +
                  (this._getText("lblResolutionTitle", []) || "Recommended Procedure") + ":\n" +
                  sRecom1 + "\n" +
                  sRecom2 + "\n" +
                  sRecom3 + "\n" +
                  sRecom4;

      if (sRawErr) {
        sText += "\n\nRaw System Return Message:\n" + sRawErr;
      }

      MessageBox.information(sText, {
        title: this._getText("titleOverallDiagnosis", []) || "CTS Release Governance Details",
        styleClass: "sapUiSizeCompact"
      });
    },

    onCopyInactiveObjects: function () {
      var oModel = this._oInactiveDialog ? this._oInactiveDialog.getModel("inactiveModel") : null;
      var aObjs = (oModel && oModel.getProperty("/objects")) || [];
      var sNames = aObjs.map(function (o) { return (o.ObjectType || "") + " " + (o.ObjectName || ""); }).join("\n");
      var sToastMsg = this._getText("msgCopiedToClipboard", []) || "Inactive objects copied to clipboard";
      if (navigator && navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(sNames).then(function () {
          MessageToast.show(sToastMsg);
        }).catch(function () {
          MessageToast.show(sNames);
        });
      } else {
        MessageToast.show(sNames);
      }
    },

    onInactiveObjectNamePress: function (oEvent) {
      var oCtx = oEvent.getSource().getBindingContext("inactiveModel");
      if (!oCtx) { return; }
      var oObj = oCtx.getObject();
      if (this._oInactiveDialog) {
        this._oInactiveDialog.close();
      }
      var sType = oObj.ObjectType || "";
      if (sType === "METH" || sType === "CPUB" || sType === "CPRI" || sType === "CPRO" || sType === "CLSD") {
        sType = "CLAS";
      }
      this.getOwnerComponent().getRouter().navTo("objSearch", {
        "?query": {
          objectName: oObj.ObjectName || "",
          objectType: sType
        }
      });
    }
  });
});
