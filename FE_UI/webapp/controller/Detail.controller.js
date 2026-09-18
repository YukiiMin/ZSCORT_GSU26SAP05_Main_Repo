sap.ui.define([
  "zscort/app/controller/BaseController",
  "sap/ui/model/json/JSONModel",
  "sap/m/MessageToast",
  "sap/m/MessageBox",
  "sap/ui/core/ValueState",
  "sap/f/library",
  "sap/ui/core/Fragment",
  "zscort/app/util/ValueHelp",
  "zscort/app/util/AiReview"
], function (BaseController, JSONModel, MessageToast, MessageBox, ValueState, fLibrary, Fragment, ValueHelp, AiReview) {
  "use strict";

  var LayoutType = fLibrary.LayoutType;

  return BaseController.extend("zscort.app.controller.Detail", {

    onInit: function () {
      var oViewModel = new JSONModel({
        trkorr: "",
        nodeType: "",
        parentTrkorr: "",
        owner: "",
        description: "",
        as4date: "",
        trStatus: "",
        isUnreleased: true,
        busy: false,
        objects: [],
        parentObjects: [],
        parentObjectsCount: 0,
        activeTasks: [],
        activeTasksCount: 0,
        logSteps: [],
        logStepsCount: 0,
        selectedLog: null,
        selectedLogFormattedHtml: "",
        logBusy: false,
        message: "",
        applyObjects: [],
        applySelectedCount: 0,
        applyTotalCount: 0,
        aiApplyBusy: false,
        aiApplyResult: null
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
      oViewModel.setProperty("/nodeType", "");
      oViewModel.setProperty("/parentTrkorr", "");
      oViewModel.setProperty("/owner", "");
      oViewModel.setProperty("/description", "");
      oViewModel.setProperty("/logSteps", []);
      oViewModel.setProperty("/logStepsCount", 0);
      oViewModel.setProperty("/selectedLog", null);
      oViewModel.setProperty("/selectedLogFormattedHtml", "");

      this._loadTrHeader(sTrkorr);
      this._loadObjects(sTrkorr);
      this._loadTransportLogs(sTrkorr);

      var sTargetTab = this._app().getProperty("/navToTab");
      if (sTargetTab) {
        this._app().setProperty("/navToTab", "");
        var oTabBar = this.byId("idParentTrTabBar");
        if (oTabBar) {
          oTabBar.setSelectedKey(sTargetTab);
        }
      }
    },



    _loadTrHeader: function (sTrkorr) {
      var oM = this.getView().getModel("detail");
      // Use $filter query — fetchJson always returns array (oJson.value).
      // Read-by-key on a custom RAP entity returns the same collection format.
      var sSafe = String(sTrkorr).replace(/'/g, "''");
      var sUrl = this._trServiceUri() + "TrTree?$filter=Trkorr eq '" + sSafe + "'&$top=50";
      ValueHelp.fetchJson(sUrl, 10000).then(function (aData) {
        if (!aData || !aData.length) { return; }
        // Find the TR-level node (TreeLevel=0 or NodeType='TR'). Fall back to first item.
        var oTr = aData.find(function (n) {
          return n.NodeType === "TR" || n.TreeLevel === 0;
        }) || aData[0];
        if (!oTr) { return; }
        if (oTr.As4date) {
          oM.setProperty("/as4date", oTr.As4date);
        }
        oM.setProperty("/nodeType", oTr.NodeType || "");
        oM.setProperty("/parentTrkorr", oTr.ParentTrkorr || "");
        oM.setProperty("/owner", oTr.Owner || "");
        oM.setProperty("/description", oTr.Description || "");
        oM.setProperty("/trStatus", oTr.TrStatus || "");
        oM.setProperty("/isUnreleased", (oTr.TrStatus === "D" || oTr.TrStatus === "L" || !oTr.TrStatus));
      }).catch(function () {
        // silently ignore error if header cannot be loaded
      });
    },

    /**
     * Enrich TR objects with PackageName, PersonResponsible, and CreatedOn from LocalObjects and TrObjectSearch.
     */
    _deduplicateObjects: function (aList) {
      if (!aList || !aList.length) { return []; }
      var mSeen = {};
      var aUnique = [];
      aList.forEach(function (o) {
        var sPgmid = String(o.Pgmid || "").trim().toUpperCase();
        var sType = String(o.ObjectType || o.ObjType || "").trim().toUpperCase();
        var sName = String(o.ObjectName || o.ObjName || "").trim().toUpperCase();
        if (!sType || !sName) { return; }
        var sKey = (sPgmid ? sPgmid + "_" : "") + sType + "_" + sName;
        if (!mSeen[sKey]) {
          mSeen[sKey] = true;
          aUnique.push(o);
        }
      });
      return aUnique;
    },

    _enrichObjectsMetadata: function (aObjects, sTrkorr) {
      if (!aObjects || !aObjects.length) {
        return Promise.resolve(aObjects);
      }
      aObjects = this._deduplicateObjects(aObjects);
      var sTrUri = this._trServiceUri();
      var sObjUri = this._objServiceUri();
      var sTrObjFilter = "(Trkorr eq '" + String(sTrkorr).replace(/'/g, "''") + "' or ParentTrkorr eq '" + String(sTrkorr).replace(/'/g, "''") + "')";
      var sTrObjUrl = sTrUri + "TrObjectSearch?$filter=" + encodeURIComponent(sTrObjFilter);

      var aFilterObjs = aObjects.filter(function (o) {
        var sP = String(o.Pgmid || "").trim().toUpperCase();
        var sT = String(o.ObjectType || o.ObjType || "").trim().toUpperCase();
        return sP !== "CORR" && sP !== "*" && sT !== "RELE" && sT !== "COMM" && sT !== "NOTE";
      });

      var iChunkSize = 20;
      var aChunks = [];
      for (var i = 0; i < aFilterObjs.length; i += iChunkSize) {
        var aSlice = aFilterObjs.slice(i, i + iChunkSize);
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

      var that = this;
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

        return that._deduplicateObjects(aObjects);
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
      var sUrl =
        this._mainServiceUri() +
        "TrCmp?$filter=" +
        encodeURIComponent(sFilter);

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
          var sObjFilter = "(Trkorr eq '" + String(sTrkorr).replace(/'/g, "''") + "' or ParentTrkorr eq '" + String(sTrkorr).replace(/'/g, "''") + "')";
          var sObjUrl = that._trServiceUri() +
            "TrObjectSearch?$filter=" + encodeURIComponent(sObjFilter);
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
                CompareStatus: "MODIFIABLE",
                Message: "TR Modifiable (Unreleased)"
              });
            });
            var aUniqueFormatted = that._deduplicateObjects(aFormatted);
            that._enrichObjectsMetadata(aUniqueFormatted, sTrkorr).then(function (aEnriched) {
              var aDedupEnriched = that._deduplicateObjects(aEnriched);
              that._loadActiveTasks(sTrkorr);
              oM.setProperty("/parentObjects", aDedupEnriched);
              oM.setProperty("/parentObjectsCount", aDedupEnriched.length);
              oM.setProperty("/objects", aDedupEnriched);
              oM.setProperty("/busy", false);
            });
          }).catch(function () {
            that._loadActiveTasks(sTrkorr);
            oM.setProperty("/parentObjects", []);
            oM.setProperty("/parentObjectsCount", 0);
            oM.setProperty("/objects", []);
            oM.setProperty("/busy", false);
          });
          return;
        }

        oM.setProperty("/isUnreleased", false);
        if (!aData.length) {
          that._loadActiveTasks(sTrkorr);
          oM.setProperty("/objects", []);
          oM.setProperty("/busy", false);
          oM.setProperty("/message", "No objects for this TR (or empty E071).");
          MessageToast.show(oM.getProperty("/message"));
          return;
        }

        var aUniqueData = that._deduplicateObjects(aData);
        that._enrichObjectsMetadata(aUniqueData, sTrkorr).then(function (aEnriched) {
          aEnriched = that._deduplicateObjects(aEnriched);
          that._loadActiveTasks(sTrkorr);
          oM.setProperty("/parentObjects", aEnriched);
          oM.setProperty("/parentObjectsCount", aEnriched.length);
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
          that._loadActiveTasks(sTrkorr);
          oM.setProperty("/parentObjects", aUniqueData);
          oM.setProperty("/parentObjectsCount", aUniqueData.length);
          oM.setProperty("/objects", aUniqueData);
          oM.setProperty("/busy", false);
        });
      }).catch(function (oErr) {
        oM.setProperty("/busy", false);
        oM.setProperty("/message", "TrCmp error: " + (oErr.message || oErr));
        MessageBox.warning(oM.getProperty("/message"));
      });
    },

    _loadActiveTasks: function (sTrkorr) {
      var oM = this.getView().getModel("detail");
      var sFilter = "ParentTrkorr eq '" + String(sTrkorr).replace(/'/g, "''") + "'";
      var sUrl = this._trServiceUri() + "TrTree?$filter=" + sFilter;

      return ValueHelp.fetchJson(sUrl, 10000).then(function (aData) {
        aData = aData || [];
        var aActive = [];
        var mSeen = {};
        aData.forEach(function (r) {
          var sPkg = "";
          var mPkg = (r.Description || "").match(/\[(.*?)\]/);
          if (mPkg && mPkg[1]) {
            sPkg = mPkg[1];
          }
          aActive.push({
            Trkorr: r.Trkorr || "",
            ParentTrkorr: r.ParentTrkorr || sTrkorr,
            Owner: r.Owner || "",
            ObjectType: r.ObjType || r.ObjectType || "",
            ObjectName: r.ObjName || r.ObjectName || (r.Description || ""),
            PackageName: sPkg,
            TrStatus: r.TrStatus || "D",
            Description: r.Description || "",
            As4date: r.As4date || ""
          });
          if (r.Trkorr) {
            mSeen[r.Trkorr] = true;
          }
        });

        oM.setProperty("/activeTasks", aActive);
        var iActiveCount = Object.keys(mSeen).length || aActive.length;
        oM.setProperty("/activeTasksCount", iActiveCount);
        return aActive;
      }).catch(function () {
        oM.setProperty("/activeTasks", []);
        oM.setProperty("/activeTasksCount", 0);
        return [];
      });
    },

    _invokeTrTreeAction: function (sActionName, sKey) {
      var oOdm = this.getOwnerComponent().getModel("trModel");
      if (!oOdm) {
        return Promise.reject(new Error("TR service (trModel) not available"));
      }
      sKey = String(sKey || "").toUpperCase().replace(/'/g, "''");
      var sNs = "com.sap.gateway.srvd.zsd_scort_tr_search.v0001";
      var sPath = "/TrTree('" + sKey + "')/" + sNs + "." + sActionName + "(...)";
      return oOdm.bindContext(sPath).execute();
    },

    _partitionTrObjects: function (aAllObjs, sParentTr) {
      var aParent = [];
      var aActive = [];
      (aAllObjs || []).forEach(function (o) {
        var bIsActiveTask = (o.Trkorr && o.Trkorr !== sParentTr && o.TrStatus !== "R");
        if (bIsActiveTask) {
          aActive.push(o);
        } else {
          aParent.push(o);
        }
      });
      return {
        parentObjects: this._deduplicateObjects(aParent),
        activeTasks: aActive
      };
    },

    onReleaseTrInDetail: function () {
      var sTrkorr = this.getView().getModel("detail").getProperty("/trkorr");
      if (!sTrkorr) { return; }
      var that = this;
      var oM = this.getView().getModel("detail");
      var sNodeType = oM.getProperty("/nodeType");
      var bIsParentTr = (sNodeType === "TR" || !oM.getProperty("/parentTrkorr"));
      oM.setProperty("/busy", true);
      MessageToast.show("Releasing " + (bIsParentTr ? "TR " : "Task ") + sTrkorr + "…");
      this._invokeTrTreeAction("ReleaseRequest", sTrkorr).then(function () {
        oM.setProperty("/busy", false);
        MessageToast.show((bIsParentTr ? "TR " : "Task ") + sTrkorr + " released successfully.");
        that._loadObjects(sTrkorr);
      }).catch(function (oError) {
        oM.setProperty("/busy", false);
        MessageBox.error("Release failed: " + (oError.message || oError));
      });
    },

    onReleaseChildTaskPress: function (oEvent) {
      var oCtx = oEvent.getSource().getBindingContext("detail");
      if (!oCtx) { return; }
      var sTask = oCtx.getProperty("Trkorr");
      if (!sTask) { return; }
      var that = this;
      var oM = this.getView().getModel("detail");
      var sParentTr = oM.getProperty("/trkorr");

      MessageBox.confirm("Release task " + sTask + "?", {
        title: "Release Task",
        onClose: function (sAction) {
          if (sAction !== MessageBox.Action.OK) { return; }
          oM.setProperty("/busy", true);
          that._invokeTrTreeAction("ReleaseRequest", sTask).then(function () {
            oM.setProperty("/busy", false);
            MessageToast.show("Task " + sTask + " released successfully.");
            that._loadObjects(sParentTr);
          }).catch(function (oErr) {
            oM.setProperty("/busy", false);
            MessageBox.error("Release task failed: " + (oErr.message || oErr));
          });
        }
      });
    },

    onReleaseButtonPress: function () {
      this.onReleaseTrInDetail();
    },

    onApplyToTargetButtonPress: function () {
      var sTrkorr = this.getView().getModel("detail").getProperty("/trkorr");
      if (!sTrkorr) { return; }

      var oM = this.getView().getModel("detail");
      var aObjects = oM.getProperty("/objects") || [];
      if (!aObjects.length) {
        MessageBox.information(this._getText("msgNoObjectsToApply", []));
        return;
      }

      var aApplyObjs = aObjects.map(function (o) {
        var sComp = (o.CompareStatus || "").toUpperCase();
        var sObjStatus = (o.ObjectStatus || "").toUpperCase();
        var sAction = "MODIFY";
        if (sObjStatus === "DELETED" || sComp === "DELETED") {
          sAction = "DELETE";
        } else if (sComp === "NEW_AT_TARGET" || sComp === "SOURCE_MISSING") {
          sAction = "CREATE";
        }

        return {
          selected: true,
          ObjectType: o.ObjectType || o.ObjType || "",
          ObjectName: o.ObjectName || o.ObjName || "",
          VersionNo: o.VersionNo || o.Versno || o.TargetVers || "Active",
          PackageName: o.PackageName || o.TadirDevclass || "",
          Action: sAction,
          CompareStatus: o.CompareStatus || "MODIFIABLE",
          ObjectStatus: o.ObjectStatus || "",
          Message: o.Message || "",
          aiAdvice: "",
          aiRisk: "NONE"
        };
      });

      oM.setProperty("/applyObjects", aApplyObjs);
      oM.setProperty("/applySelectedCount", aApplyObjs.length);
      oM.setProperty("/applyTotalCount", aApplyObjs.length);
      oM.setProperty("/aiApplyBusy", false);
      oM.setProperty("/aiApplyResult", null);

      this._openApplyPreviewDialog();
    },

    _openApplyPreviewDialog: function () {
      var oView = this.getView();

      if (!this._pApplyPreviewDialog) {
        this._pApplyPreviewDialog = Fragment.load({
          id: oView.getId(),
          name: "zscort.app.view.fragment.ApplyPreviewDialog",
          controller: this
        }).then(function (oDialog) {
          oView.addDependent(oDialog);
          return oDialog;
        });
      }

      this._pApplyPreviewDialog.then(function (oDialog) {
        oDialog.open();
      });
    },

    onCloseApplyPreviewDialog: function () {
      if (this._pApplyPreviewDialog) {
        this._pApplyPreviewDialog.then(function (oDialog) {
          oDialog.close();
        });
      }
    },

    onApplySelectAll: function () {
      var oM = this.getView().getModel("detail");
      var aList = oM.getProperty("/applyObjects") || [];
      aList.forEach(function (item) {
        item.selected = true;
      });
      oM.setProperty("/applyObjects", aList);
      oM.setProperty("/applySelectedCount", aList.length);
    },

    onApplyDeselectAll: function () {
      var oM = this.getView().getModel("detail");
      var aList = oM.getProperty("/applyObjects") || [];
      aList.forEach(function (item) {
        item.selected = false;
      });
      oM.setProperty("/applyObjects", aList);
      oM.setProperty("/applySelectedCount", 0);
    },

    onApplyCheckboxSelect: function () {
      var oM = this.getView().getModel("detail");
      var aList = oM.getProperty("/applyObjects") || [];
      var iSelected = aList.filter(function (item) {
        return !!item.selected;
      }).length;
      oM.setProperty("/applySelectedCount", iSelected);
    },

    onRunAiApplyAssessment: function () {
      var oM = this.getView().getModel("detail");
      var sTrkorr = oM.getProperty("/trkorr");
      var aList = oM.getProperty("/applyObjects") || [];
      if (!sTrkorr || !aList.length) { return; }

      var sLang = sap.ui.getCore().getConfiguration().getLanguage() || "en";
      var that = this;

      oM.setProperty("/aiApplyBusy", true);
      MessageToast.show(this._getText("msgRunningAiAssessment", []));

      AiReview.analyzeApplyToTargetRisk(sTrkorr, aList, sLang, "BE_SAP", "gemini-2.5-flash")
        .then(function (oResult) {
          oM.setProperty("/aiApplyBusy", false);
          if (!oResult) {
            MessageBox.warning("AI Pre-check returned empty response.");
            return;
          }

          oM.setProperty("/aiApplyResult", oResult);

          if (Array.isArray(oResult.recommendations)) {
            var mRecs = {};
            oResult.recommendations.forEach(function (r) {
              var sKey = String(r.object || "").toUpperCase() + "_" + String(r.obj_name || "").toUpperCase();
              mRecs[sKey] = r;
            });

            var aUpdated = aList.map(function (item) {
              var sKey = String(item.ObjectType || "").toUpperCase() + "_" + String(item.ObjectName || "").toUpperCase();
              var oRec = mRecs[sKey];
              if (oRec) {
                item.aiAdvice = oRec.reason || "";
                item.aiRisk = (oRec.risk_level || "LOW").toUpperCase();
              }
              return item;
            });
            oM.setProperty("/applyObjects", aUpdated);
          }

          MessageToast.show(that._getText("msgAiAssessmentComplete", []));
        })
        .catch(function (oErr) {
          oM.setProperty("/aiApplyBusy", false);
          MessageBox.error("AI Pre-check failed: " + (oErr.message || oErr));
        });
    },

    onApplyAiRecommendationToSelection: function () {
      var oM = this.getView().getModel("detail");
      var oAiResult = oM.getProperty("/aiApplyResult");
      var aList = oM.getProperty("/applyObjects") || [];

      if (!oAiResult || !Array.isArray(oAiResult.recommendations)) {
        MessageToast.show(this._getText("msgNoAiRecommendations", []));
        return;
      }

      var mRecs = {};
      oAiResult.recommendations.forEach(function (r) {
        var sKey = String(r.object || "").toUpperCase() + "_" + String(r.obj_name || "").toUpperCase();
        mRecs[sKey] = r;
      });

      var iSelected = 0;
      var aUpdated = aList.map(function (item) {
        var sKey = String(item.ObjectType || "").toUpperCase() + "_" + String(item.ObjectName || "").toUpperCase();
        var oRec = mRecs[sKey];
        if (oRec) {
          item.selected = !!oRec.should_apply;
        } else if (oAiResult.overall_verdict === "BLOCK_RECOMMENDED") {
          item.selected = false;
        } else {
          item.selected = true;
        }
        if (item.selected) {
          iSelected++;
        }
        return item;
      });

      oM.setProperty("/applyObjects", aUpdated);
      oM.setProperty("/applySelectedCount", iSelected);
      MessageToast.show(this._getText("msgAiSelectionApplied", [iSelected]));
    },

    onConfirmApplySelected: function () {
      var oM = this.getView().getModel("detail");
      var sTrkorr = oM.getProperty("/trkorr");
      var aList = oM.getProperty("/applyObjects") || [];
      var aSelected = aList.filter(function (item) { return !!item.selected; });

      if (!aSelected.length) {
        MessageBox.warning(this._getText("msgSelectAtLeastOneObj", []));
        return;
      }

      this.onCloseApplyPreviewDialog();

      var that = this;
      oM.setProperty("/busy", true);
      MessageToast.show("Applying " + aSelected.length + " object(s) of " + sTrkorr + "…");

      this._invokeTrTreeAction("ApplyToTarget", sTrkorr).then(function () {
        oM.setProperty("/busy", false);
        that._loadObjects(sTrkorr);
        MessageToast.show("Apply OK: " + aSelected.length + " object(s) of " + sTrkorr);
      }).catch(function (oError) {
        oM.setProperty("/busy", false);
        MessageBox.error("Apply failed: " + (oError.message || oError));
      });
    },

    formatAiVerdictState: function (sVerdict) {
      switch ((sVerdict || "").toUpperCase()) {
        case "READY_TO_APPLY": return ValueState.Success;
        case "PARTIAL_RECOMMENDED": return ValueState.Warning;
        case "BLOCK_RECOMMENDED": return ValueState.Error;
        default: return ValueState.None;
      }
    },

    formatAiVerdictIcon: function (sVerdict) {
      switch ((sVerdict || "").toUpperCase()) {
        case "READY_TO_APPLY": return "sap-icon://sys-enter-2";
        case "PARTIAL_RECOMMENDED": return "sap-icon://alert";
        case "BLOCK_RECOMMENDED": return "sap-icon://error";
        default: return "sap-icon://hint";
      }
    },

    formatApplyActionState: function (sAction) {
      switch ((sAction || "").toUpperCase()) {
        case "CREATE": return ValueState.Information;
        case "MODIFY": return ValueState.Warning;
        case "DELETE": return ValueState.Error;
        default: return ValueState.None;
      }
    },

    formatApplyActionIcon: function (sAction) {
      switch ((sAction || "").toUpperCase()) {
        case "CREATE": return "sap-icon://add-document";
        case "MODIFY": return "sap-icon://edit";
        case "DELETE": return "sap-icon://delete";
        default: return "sap-icon://document";
      }
    },

    formatAiRiskState: function (sRisk) {
      switch ((sRisk || "").toUpperCase()) {
        case "LOW": return ValueState.Success;
        case "MEDIUM": return ValueState.Warning;
        case "HIGH":
        case "CRITICAL": return ValueState.Error;
        default: return ValueState.None;
      }
    },

    formatAiRiskIcon: function (sRisk) {
      switch ((sRisk || "").toUpperCase()) {
        case "LOW": return "sap-icon://sys-enter-2";
        case "MEDIUM": return "sap-icon://alert";
        case "HIGH": return "sap-icon://warning2";
        case "CRITICAL": return "sap-icon://error";
        default: return "";
      }
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
      var oM = this.getView().getModel("detail");
      var sTrkorr = oM ? oM.getProperty("/trkorr") : "";
      var bIsUnreleased = oM ? oM.getProperty("/isUnreleased") : false;
      var oItem = Object.assign({}, oCtx.getObject());
      if (sTrkorr && !bIsUnreleased) {
        oItem.Trkorr = sTrkorr;
        oItem.TrStatus = "R";
      }
      this._openSourceDialog(sObjectType, sObjectName, "L", oItem);
    },

    onTableObjectRowSelectionChange: function () { /* reserved */ },

    formatCompareStatus: function (sStatus) {
      switch ((sStatus || "").toUpperCase()) {
        case "IDENTICAL": return ValueState.Success;
        case "DIFFERENT": return ValueState.Error;
        case "NEW_AT_TARGET": return ValueState.Information;
        case "SOURCE_MISSING": return ValueState.Error;
        case "MODIFIABLE": return ValueState.Warning;
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
        case "MODIFIABLE": return "sap-icon://edit";
        case "NOT_SUPPORTED": return "sap-icon://sys-help-2";
        default: return "sap-icon://status-inactive";
      }
    },

    onNavToTransportLogsTab: function () {
      var oTabBar = this.byId("idParentTrTabBar");
      if (oTabBar) {
        oTabBar.setSelectedKey("transportLogs");
      }
      var sTrkorr = this.getView().getModel("detail").getProperty("/trkorr");
      if (sTrkorr) {
        this._loadTransportLogs(sTrkorr);
      }
    },

    onExpandAllLogSteps: function () {
      var oTree = this.byId("idTrLogStepsTreeTable");
      if (oTree && oTree.expandToLevel) {
        oTree.expandToLevel(3);
      }
    },

    onCollapseAllLogSteps: function () {
      var oTree = this.byId("idTrLogStepsTreeTable");
      if (oTree && oTree.collapseAll) {
        oTree.collapseAll();
      }
    },

    _loadTransportLogs: function (sTrkorr) {
      var oM = this.getView().getModel("detail");
      var that = this;
      if (!sTrkorr) { return; }

      oM.setProperty("/logBusy", true);
      var sSafe = String(sTrkorr).replace(/'/g, "''");
      var sUrl = this._trServiceUri() + "TrLog?$filter=Trkorr eq '" + sSafe + "'";

      ValueHelp.fetchJson(sUrl, 15000).then(function (aData) {
        oM.setProperty("/logBusy", false);
        aData = aData || [];
        oM.setProperty("/logSteps", aData);
        oM.setProperty("/logStepsCount", aData.length);

        // Build hierarchical tree structure for sap.ui.table.TreeTable
        var aTree = [];
        var mSystems = {};

        aData.forEach(function (row) {
          if (row.NodeType === "SYSTEM") {
            var oSys = Object.assign({}, row);
            oSys.children = [];
            mSystems[row.SystemId] = oSys;
            aTree.push(oSys);
          }
        });

        aData.forEach(function (row) {
          if (row.NodeType === "STEP") {
            var oSys = mSystems[row.SystemId];
            if (oSys) {
              oSys.children.push(Object.assign({}, row));
            } else {
              aTree.push(Object.assign({}, row));
            }
          }
        });

        if (aTree.length === 0 && aData.length > 0) {
          aTree = aData;
        }

        oM.setProperty("/logTree", aTree);

        if (aData.length > 0) {
          var oSelected = aData.find(function (n) { return n.NodeType === "STEP"; }) || aData[0];
          that._selectLogStep(oSelected);

          setTimeout(function () {
            var oTreeTable = that.byId("idTrLogStepsTreeTable");
            if (oTreeTable && oTreeTable.expandToLevel) {
              oTreeTable.expandToLevel(2);
            }
          }, 100);
        } else {
          oM.setProperty("/selectedLog", null);
          oM.setProperty("/selectedLogFormattedHtml", "<pre class=\"scortLogPre\">No transport logs exist for request " + sSafe + ".</pre>");
        }
      }).catch(function (oErr) {
        oM.setProperty("/logBusy", false);
        oM.setProperty("/logSteps", []);
        oM.setProperty("/logTree", []);
        oM.setProperty("/logStepsCount", 0);
        oM.setProperty("/selectedLog", null);
        oM.setProperty("/selectedLogFormattedHtml", "<pre class=\"scortLogPre\">Failed to load transport logs: " + (oErr && oErr.message ? oErr.message : oErr) + "</pre>");
      });
    },

    _selectLogStep: function (oStep) {
      var oM = this.getView().getModel("detail");
      if (!oStep) {
        oM.setProperty("/selectedLog", null);
        oM.setProperty("/selectedLogFormattedHtml", "");
        return;
      }
      oM.setProperty("/selectedLog", oStep);
      var sHtml = this._formatLogTextToHtml(oStep.LogContent || "");
      oM.setProperty("/selectedLogFormattedHtml", sHtml);
    },

    _formatLogTextToHtml: function (sText) {
      if (!sText) {
        return "<pre class=\"scortLogPre\">No log content available for this step.</pre>";
      }
      var aLines = sText.split(/\r?\n/);
      var aHtml = ["<pre class=\"scortLogPre\">"];
      aLines.forEach(function (sLine) {
        var sEscaped = sLine.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        if (sLine.indexOf("--> ERROR") !== -1 || sLine.indexOf("Return Code: ===> 8") !== -1 || sLine.indexOf("Return Code: ===> 12") !== -1) {
          aHtml.push("<span class=\"scortLogLineError\">" + sEscaped + "</span>");
        } else if (sLine.indexOf("--> WARN") !== -1 || sLine.indexOf("Return Code: ===> 4") !== -1) {
          aHtml.push("<span class=\"scortLogLineWarn\">" + sEscaped + "</span>");
        } else if (sLine.indexOf("--> START") !== -1 || sLine.indexOf("--> STEP") !== -1 || sLine.indexOf("--> EXPORT") !== -1 || sLine.indexOf("--> IMPORT") !== -1) {
          aHtml.push("<span class=\"scortLogLineStep\">" + sEscaped + "</span>");
        } else if (sLine.indexOf("--> STOP") !== -1 || sLine.indexOf("Return Code: ===> 0") !== -1) {
          aHtml.push("<span class=\"scortLogLineSuccess\">" + sEscaped + "</span>");
        } else if (sLine.indexOf("======") !== -1 || sLine.indexOf("------") !== -1) {
          aHtml.push("<span class=\"scortLogLineBorder\">" + sEscaped + "</span>");
        } else {
          aHtml.push(sEscaped);
        }
      });
      aHtml.push("</pre>");
      return aHtml.join("\n");
    },

    onLogStepSelectionChange: function (oEvent) {
      var oTable = oEvent.getSource();
      var iIdx = oTable.getSelectedIndex();
      if (iIdx < 0) { return; }
      var oCtx = oTable.getContextByIndex(iIdx);
      if (oCtx) {
        var oStep = oCtx.getObject();
        if (oStep) {
          if (oStep.NodeType === "SYSTEM" && Array.isArray(oStep.children) && oStep.children.length > 0 && !oStep.LogContent) {
            this._selectLogStep(oStep.children[0]);
          } else {
            this._selectLogStep(oStep);
          }
        }
      }
    },

    onReloadTransportLogs: function () {
      var sTrkorr = this.getView().getModel("detail").getProperty("/trkorr");
      if (sTrkorr) {
        this._loadTransportLogs(sTrkorr);
        MessageToast.show("Reloading transport logs...");
      }
    },

    onCopyLogText: function () {
      var oLog = this.getView().getModel("detail").getProperty("/selectedLog");
      var sText = oLog ? oLog.LogContent : "";
      if (!sText) {
        MessageToast.show("No log text to copy");
        return;
      }
      var oTextArea = document.createElement("textarea");
      oTextArea.value = sText;
      document.body.appendChild(oTextArea);
      oTextArea.select();
      document.execCommand("copy");
      document.body.removeChild(oTextArea);
      MessageToast.show("Log content copied to clipboard!");
    }

  });
});
