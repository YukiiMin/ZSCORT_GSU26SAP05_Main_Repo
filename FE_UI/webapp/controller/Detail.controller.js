sap.ui.define([
  "zscort/app/controller/BaseController",
  "sap/ui/model/json/JSONModel",
  "sap/m/MessageToast",
  "sap/m/MessageBox",
  "sap/ui/core/ValueState",
  "sap/f/library",
  "zscort/app/util/ValueHelp"
], function (BaseController, JSONModel, MessageToast, MessageBox, ValueState, fLibrary, ValueHelp) {
  "use strict";

  var LayoutType = fLibrary.LayoutType;

  return BaseController.extend("zscort.app.controller.Detail", {

    onInit: function () {
      var oViewModel = new JSONModel({
        trkorr: "",
        busy: false,
        objects: [],
        message: ""
      });
      this.getView().setModel(oViewModel, "detail");

      this.getOwnerComponent().getRouter().getRoute("detail").attachPatternMatched(this._onRouteMatched, this);
    },

    _onRouteMatched: function (oEvent) {
      var oArgs = oEvent.getParameter("arguments");
      var sTrkorr = decodeURIComponent((oArgs && oArgs.trkorr) || "");
      if (!sTrkorr || sTrkorr === "DUMMY") {
        this.getOwnerComponent().getRouter().navTo("trSearch");
        return;
      }

      var oViewModel = this.getView().getModel("detail");
      var sPrevTrkorr = oViewModel.getProperty("/trkorr");
      var aExistingObjs = oViewModel.getProperty("/objects");

      oViewModel.setProperty("/trkorr", sTrkorr);
      this._app().setProperty("/currentModule", "detail");
      this._app().setProperty("/trkorr", sTrkorr);
      this._app().setProperty("/currentTR", sTrkorr);
      this._app().setProperty("/layout", LayoutType.TwoColumnsMidExpanded);

      if (sPrevTrkorr === sTrkorr && aExistingObjs && aExistingObjs.length > 0) {
        return;
      }

      oViewModel.setProperty("/as4date", "");

      this._loadTrHeader(sTrkorr);
      this._loadObjects(sTrkorr);
    },

    _trServiceUri: function () {
      var sUri = this.getOwnerComponent().getManifestEntry("sap.app").dataSources.trService.uri;
      return String(sUri || "").replace(/\/?$/, "/");
    },

    _loadTrHeader: function (sTrkorr) {
      var oM = this.getView().getModel("detail");
      var sUrl = this._trServiceUri() + "TrTree('" + String(sTrkorr).replace(/'/g, "''") + "')";
      ValueHelp.fetchJson(sUrl, 10000).then(function (oData) {
        if (oData && oData.As4date) {
          oM.setProperty("/as4date", oData.As4date);
        }
      }).catch(function () {
        // silently ignore error if header cannot be loaded
      });
    },

    _serviceUri: function () {
      var oModel = this.getOwnerComponent().getModel();
      var sUri = oModel && oModel.getServiceUrl && oModel.getServiceUrl();
      return sUri || this.getOwnerComponent().getManifestEntry("sap.app").dataSources.mainService.uri;
    },

    /**
     * Enrich TR objects with PackageName, PersonResponsible, and CreatedOn from LocalObjects and TrObjectSearch.
     */
    _enrichObjectsMetadata: function (aObjects, sTrkorr) {
      if (!aObjects || !aObjects.length) {
        return Promise.resolve(aObjects);
      }

      var sTrUri = this._trServiceUri();
      var sObjUri = this.getOwnerComponent().getManifestEntry("sap.app").dataSources.objService.uri.replace(/\/?$/, "/");
      var sTrObjUrl = sTrUri + "TrObjectSearch?$filter=" + encodeURIComponent("Trkorr eq '" + String(sTrkorr).replace(/'/g, "''") + "'");

      var iChunkSize = 20;
      var aChunks = [];
      for (var i = 0; i < aObjects.length; i += iChunkSize) {
        var aSlice = aObjects.slice(i, i + iChunkSize);
        var sFilter = aSlice.map(function (o) {
          var sType = String(o.ObjectType || o.ObjType || "").replace(/'/g, "''");
          var sName = String(o.ObjectName || o.ObjName || "").replace(/'/g, "''");
          return "(ObjectType eq '" + sType + "' and ObjectName eq '" + sName + "')";
        }).join(" or ");
        if (sFilter) {
          aChunks.push(sObjUri + "LocalObjects?$filter=" + encodeURIComponent(sFilter));
        }
      }

      var aPromises = [
        ValueHelp.fetchJson(sTrObjUrl, 10000).catch(function () { return []; })
      ];
      aChunks.forEach(function (sUrl) {
        aPromises.push(ValueHelp.fetchJson(sUrl, 15000).catch(function () { return []; }));
      });

      return Promise.all(aPromises).then(function (aResults) {
        var aTrObjs = aResults[0] || [];
        var mTrMap = {};
        aTrObjs.forEach(function (t) {
          var k = (t.ObjectType || t.ObjType || "") + "_" + (t.ObjectName || t.ObjName || "");
          mTrMap[k] = t;
        });

        var mLocalMap = {};
        for (var j = 1; j < aResults.length; j++) {
          var aLocalChunk = aResults[j] || [];
          aLocalChunk.forEach(function (l) {
            var k = (l.ObjectType || "") + "_" + (l.ObjectName || "");
            mLocalMap[k] = l;
          });
        }

        aObjects.forEach(function (o) {
          var sType = o.ObjectType || o.ObjType || "";
          var sName = o.ObjectName || o.ObjName || "";
          var k = sType + "_" + sName;
          var oLocal = mLocalMap[k] || {};
          var oTr = mTrMap[k] || {};

          o.ObjectType = sType;
          o.ObjectName = sName;
          o.PackageName = oLocal.PackageName || o.PackageName || "";
          o.TadirDevclass = oLocal.PackageName || o.TadirDevclass || "";
          o.Author = oLocal.PersonResponsible || oTr.Owner || o.Author || "";
          o.PersonResponsible = oLocal.PersonResponsible || oTr.Owner || o.PersonResponsible || "";
          o.Datum = oLocal.CreatedOn || oTr.CreatedOn || o.Datum || "";
          o.CreatedOn = oLocal.CreatedOn || oTr.CreatedOn || o.CreatedOn || "";
          o.As4date = oLocal.CreatedOn || oTr.CreatedOn || o.As4date || "";
        });

        return aObjects;
      });
    },

    /**
     * Load TrCmp via fetch into detail>/objects (matches XML binding).
     * Enriches compare rows with package, author, and creation date.
     */
    _loadObjects: function (sTrkorr) {
      var oM = this.getView().getModel("detail");
      var sServerId = this._app().getProperty("/serverId") || "TGT";
      var that = this;

      oM.setProperty("/busy", true);
      oM.setProperty("/objects", []);
      oM.setProperty("/message", "");

      var sFilter = [
        "Trkorr eq '" + String(sTrkorr).replace(/'/g, "''") + "'",
        "ServerId eq '" + String(sServerId).replace(/'/g, "''") + "'"
      ].join(" and ");
      var sUrl = this._serviceUri().replace(/\/?$/, "/") +
        "TrCmp?$filter=" + encodeURIComponent(sFilter);

      ValueHelp.fetchJson(sUrl, 25000).then(function (aData) {
        aData = aData || [];
        // TR-level block only: NOT_SUPPORTED without ObjectName (e.g. unreleased TR).
        var oTrBlocked = aData.find(function (r) {
          return r.CompareStatus === "NOT_SUPPORTED" && !(r.ObjectName || r.ObjectType);
        });
        if (oTrBlocked) {
          oM.setProperty("/isUnreleased", true);
          oM.setProperty(
            "/message",
            oTrBlocked.Message ||
              "TR is not released. Compare is disabled. Please release before comparing."
          );

          // Fallback: Fetch objects from TrObjectSearch for display when TR is unreleased
          var sObjUrl = that._trServiceUri() +
            "TrObjectSearch?$filter=" + encodeURIComponent("Trkorr eq '" + String(sTrkorr).replace(/'/g, "''") + "'");
          ValueHelp.fetchJson(sObjUrl, 10000).then(function (aObjs) {
            aObjs = aObjs || [];
            var aFormatted = aObjs.map(function(o) {
              return Object.assign({}, o, {
                ObjectType: o.ObjectType || o.ObjType,
                ObjectName: o.ObjectName || o.ObjName,
                PackageName: o.PackageName || o.Devclass || o.TadirDevclass || o.Package || "",
                Author: o.PersonResponsible || o.Author || o.Owner || o.As4user || "",
                PersonResponsible: o.PersonResponsible || o.Author || o.Owner || o.As4user || "",
                Datum: o.CreatedOn || o.As4date || o.Datum || "",
                CreatedOn: o.CreatedOn || o.As4date || o.Datum || "",
                As4date: o.CreatedOn || o.As4date || o.Datum || "",
                CompareStatus: "NOT_SUPPORTED",
                Message: "TR Modifiable (Unreleased)"
              });
            });
            that._enrichObjectsMetadata(aFormatted, sTrkorr).then(function (aEnriched) {
              oM.setProperty("/objects", aEnriched);
              oM.setProperty("/busy", false);
            });
          }).catch(function () {
            oM.setProperty("/objects", []);
            oM.setProperty("/busy", false);
          });
          return;
        }

        oM.setProperty("/isUnreleased", false);
        if (!aData.length) {
          oM.setProperty("/objects", []);
          oM.setProperty("/busy", false);
          oM.setProperty("/message", "No objects for this TR (or empty E071).");
          MessageToast.show(oM.getProperty("/message"));
          return;
        }

        that._enrichObjectsMetadata(aData, sTrkorr).then(function (aEnriched) {
          oM.setProperty("/objects", aEnriched);
          oM.setProperty("/busy", false);
          var nOk = aEnriched.filter(function (r) {
            return r.CompareStatus !== "NOT_SUPPORTED";
          }).length;
          var nSkip = aEnriched.length - nOk;
          if (nOk === 0) {
            oM.setProperty("/message", "No comparable objects (CLAS/PROG/INTF/FUNC/FUGR).");
            MessageToast.show(oM.getProperty("/message"));
          } else if (nSkip > 0) {
            oM.setProperty("/message", nOk + " comparable; " + nSkip + " skipped.");
          }
        }).catch(function () {
          oM.setProperty("/objects", aData);
          oM.setProperty("/busy", false);
        });
      }).catch(function (oErr) {
        oM.setProperty("/busy", false);
        oM.setProperty("/message", "TrCmp error: " + (oErr.message || oErr));
        MessageBox.warning(oM.getProperty("/message"));
      });
    },

    _invokeTrTreeAction: function (sActionName, sTrkorr) {
      var oOdm = this.getOwnerComponent().getModel("trModel");
      if (!oOdm) {
        return Promise.reject(new Error("TR service (trModel) not available"));
      }
      var sKey = String(sTrkorr || "").toUpperCase().replace(/'/g, "''");
      var sNs = "com.sap.gateway.srvd.zsd_scort_tr_search.v0001";
      var sPath = "/TrTree('" + sKey + "')/" + sNs + "." + sActionName + "(...)";
      return oOdm.bindContext(sPath).execute();
    },

    onReleaseTrInDetail: function () {
      var sTrkorr = this.getView().getModel("detail").getProperty("/trkorr");
      if (!sTrkorr) { return; }
      var that = this;
      var oM = this.getView().getModel("detail");
      oM.setProperty("/busy", true);
      MessageToast.show("Releasing TR " + sTrkorr + "…");
      this._invokeTrTreeAction("ReleaseRequest", sTrkorr).then(function () {
        oM.setProperty("/busy", false);
        MessageToast.show("Released OK: " + sTrkorr);
        that._loadObjects(sTrkorr);
      }).catch(function (oError) {
        oM.setProperty("/busy", false);
        MessageBox.error("Release failed: " + (oError.message || oError));
      });
    },

    onReleaseButtonPress: function () {
      this.onReleaseTrInDetail();
    },

    onApplyToTargetButtonPress: function () {
      var sTrkorr = this.getView().getModel("detail").getProperty("/trkorr");
      if (!sTrkorr) { return; }
      var that = this;
      var oM = this.getView().getModel("detail");
      oM.setProperty("/busy", true);
      MessageToast.show("Applying " + sTrkorr + "…");
      this._invokeTrTreeAction("ApplyToTarget", sTrkorr).then(function () {
        oM.setProperty("/busy", false);
        that._loadObjects(sTrkorr);
        MessageToast.show("Apply OK: " + sTrkorr);
      }).catch(function (oError) {
        oM.setProperty("/busy", false);
        MessageBox.error("Apply failed: " + (oError.message || oError));
      });
    },

    onButtonRefreshPress: function () {
      var sTrkorr = this.getView().getModel("detail").getProperty("/trkorr");
      if (sTrkorr) {
        this._loadObjects(sTrkorr);
      }
    },

    onButtonNavBackPress: function () {
      this._app().setProperty("/layout", sap.f.LayoutType.OneColumn);
      this.getOwnerComponent().getRouter().navTo("trSearch");
    },

    onButtonCloseDetailPress: function () {
      this.onButtonNavBackPress();
    },

    onButtonFullScreenPress: function () {
      var oApp = this._app();
      var sCurrent = oApp.getProperty("/layout");
      var sTarget = (sCurrent === sap.f.LayoutType.MidColumnFullScreen)
        ? sap.f.LayoutType.TwoColumnsMidExpanded
        : sap.f.LayoutType.MidColumnFullScreen;
      oApp.setProperty("/layout", sTarget);
    },

    onButtonNavObjSearchPress: function () {
      this.onNavObjSearch();
    },

    onButtonComparePress: function (oEvent) {
      var oCtx = oEvent.getSource().getBindingContext("detail");
      if (!oCtx) { return; }

      var sObjectType = oCtx.getProperty("ObjectType");
      var sObjectName = oCtx.getProperty("ObjectName");
      var sTrkorr = this.getView().getModel("detail").getProperty("/trkorr") || this._app().getProperty("/trkorr");
      var oApp = this._app();

      if (sTrkorr && sTrkorr !== "DUMMY") {
        oApp.setProperty("/currentTR", sTrkorr);
        oApp.setProperty("/trkorr", sTrkorr);
      }
      oApp.setProperty("/compareOrigin", "detail");

      this.getOwnerComponent().getRouter().navTo("compare", {
        objectType: sObjectType,
        objectName: encodeURIComponent(sObjectName)
      });
    },

    onButtonViewSourcePress: function (oEvent) {
      var oCtx = oEvent.getSource().getBindingContext("detail");
      if (!oCtx) { return; }
      var sObjectType = oCtx.getProperty("ObjectType");
      var sObjectName = oCtx.getProperty("ObjectName");
      this._openSourceDialog(sObjectType, sObjectName, "L", oCtx.getObject());
    },

    onTableObjectRowSelectionChange: function () { /* reserved */ },

    formatCompareStatus: function (sStatus) {
      switch ((sStatus || "").toUpperCase()) {
        case "IDENTICAL": return ValueState.Success;
        case "DIFFERENT": return ValueState.Error;
        case "NEW_AT_TARGET": return ValueState.Information;
        case "SOURCE_MISSING": return ValueState.Error;
        case "NOT_SUPPORTED": return ValueState.None;
        default: return ValueState.None;
      }
    },

    formatCompareIcon: function (sStatus) {
      switch ((sStatus || "").toUpperCase()) {
        case "IDENTICAL": return "sap-icon://sys-enter-2";
        case "DIFFERENT": return "sap-icon://error";
        case "NEW_AT_TARGET": return "sap-icon://add-document";
        case "SOURCE_MISSING": return "sap-icon://document-text";
        case "NOT_SUPPORTED": return "sap-icon://sys-help-2";
        default: return "sap-icon://status-inactive";
      }
    }

  });
});
