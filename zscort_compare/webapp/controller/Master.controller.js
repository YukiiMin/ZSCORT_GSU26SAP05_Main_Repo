sap.ui.define([
  "sap/ui/core/mvc/Controller",
  "sap/ui/model/json/JSONModel",
  "sap/ui/model/Filter",
  "sap/ui/model/FilterOperator",
  "sap/m/MessageBox",
  "sap/f/library",
  "sap/ui/core/ValueState",
  "zscort/compare/util/ValueHelp"
], function (Controller, JSONModel, Filter, FilterOperator, MessageBox, fLibrary, ValueState, ValueHelp) {
  "use strict";

  var LayoutType = fLibrary.LayoutType;

  return Controller.extend("zscort.compare.controller.Master", {
    onInit: function () {
      this.getView().setModel(new JSONModel({ objects: [] }), "local");
      var oComp = this.getOwnerComponent();
      this._oRouter = oComp && oComp.getRouter && oComp.getRouter();
      if (this._oRouter) {
        this._oRouter.getRoute("master").attachPatternMatched(this._onMasterMatched, this);
        this._oRouter.getRoute("detail").attachPatternMatched(this._onMasterMatched, this);
      }
      // eslint-disable-next-line no-console
      console.info("[zscort.compare] Master.onInit");
    },

    _onMasterMatched: function () {
      // keep list; layout handled by detail route
    },

    _app: function () {
      return this.getOwnerComponent().getModel("appView");
    },

    _serviceUri: function () {
      var oComp = this.getOwnerComponent();
      return oComp.getServiceUri ? oComp.getServiceUri() :
        oComp.getManifestEntry("sap.app").dataSources.mainService.uri;
    },

    onVHTrkorr: function () {
      var oApp = this._app();
      ValueHelp.open({
        sServiceUri: this._serviceUri(),
        sEntitySet: "/VHTrkorr",
        sKey: "Trkorr",
        sDescriptionKey: "Description",
        sTitle: this._i18n("vhTrkorrTitle"),
        sInitialKey: oApp.getProperty("/trkorr") || "",
        aColumns: [
          { key: "Trkorr", label: "Trkorr" },
          { key: "TrStatus", label: "Status" },
          { key: "As4user", label: "Owner" },
          { key: "As4date", label: "Date" },
          { key: "Description", label: "Text" }
        ],
        fnConfirm: function (sKey) {
          oApp.setProperty("/trkorr", sKey);
        }
      });
    },

    onVHServerId: function () {
      var oApp = this._app();
      ValueHelp.open({
        sServiceUri: this._serviceUri(),
        sEntitySet: "/VHServerId",
        sKey: "ServerId",
        sDescriptionKey: "Description",
        sTitle: this._i18n("vhServerIdTitle"),
        sInitialKey: oApp.getProperty("/serverId") || "TGT",
        aColumns: [
          { key: "ServerId", label: "Server Id" },
          { key: "Description", label: "Description" }
        ],
        fnConfirm: function (sKey) {
          oApp.setProperty("/serverId", sKey);
        }
      });
    },

    onVHCompareMode: function () {
      var oApp = this._app();
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
        }
      });
    },

    onVHCompareStatus: function () {
      var oApp = this._app();
      var that = this;
      ValueHelp.open({
        sServiceUri: this._serviceUri(),
        sEntitySet: "/VHCompareStatus",
        sKey: "CompareStatus",
        sDescriptionKey: "Description",
        sTitle: this._i18n("vhCompareStatus"),
        sInitialKey: oApp.getProperty("/filterStatus") || "",
        aColumns: [
          { key: "CompareStatus", label: "Status" },
          { key: "Description", label: "Description" }
        ],
        fnConfirm: function (sKey) {
          oApp.setProperty("/filterStatus", sKey);
          that._applyClientFilters();
        }
      });
    },

    onLoadTr: function () {
      var oApp = this.getOwnerComponent().getModel("appView");
      var sTrkorr = (oApp.getProperty("/trkorr") || "").trim().toUpperCase();
      var sServer = (oApp.getProperty("/serverId") || "TGT").trim().toUpperCase();
      if (!sTrkorr) {
        MessageBox.error(this._i18n("trkorrRequired"));
        return;
      }
      oApp.setProperty("/busy", true);

      var oModel = this.getOwnerComponent().getModel();
      var that = this;
      var sUri = this.getOwnerComponent().getManifestEntry("sap.app").dataSources.mainService.uri;

      // 1) fetch JSON trực tiếp (tránh treo chờ $metadata OData V4)
      var sUrl = sUri + "TrCmp?$filter=" +
        encodeURIComponent("Trkorr eq '" + sTrkorr.replace(/'/g, "''") + "'");

      var oFetch = fetch(sUrl, {
        method: "GET",
        credentials: "same-origin",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json"
        }
      }).then(function (oRes) {
        if (!oRes.ok) {
          throw new Error("HTTP " + oRes.status + " " + oRes.statusText);
        }
        return oRes.json();
      }).then(function (oJson) {
        var aData = (oJson && (oJson.value || oJson.d && oJson.d.results)) || [];
        aData = aData.map(function (o) {
          if (!o.ServerId) {
            o.ServerId = sServer;
          }
          return o;
        });
        that._setLoadedObjects(aData, sTrkorr);
        oApp.setProperty("/busy", false);
      });

      ValueHelp.withTimeout(oFetch, 20000).catch(function (oErr) {
        // 2) Fallback bindList OData V4 (timeout 15s)
        if (!oModel || !oModel.bindList) {
          oApp.setProperty("/busy", false);
          MessageBox.warning(that._i18n("odataFailMock") + "\n" + (oErr && oErr.message ? oErr.message : oErr), {
            onClose: function () {
              that._loadMock(sTrkorr, sServer);
            }
          });
          return;
        }

        var oListBinding = oModel.bindList("/TrCmp", undefined, undefined, [
          new Filter("Trkorr", FilterOperator.EQ, sTrkorr)
        ]);

        ValueHelp.withTimeout(oListBinding.requestContexts(0, 500), 15000).then(function (aContexts) {
          var aData = aContexts.map(function (oCtx) {
            var o = oCtx.getObject();
            if (!o.ServerId) {
              o.ServerId = sServer;
            }
            return o;
          });
          that._setLoadedObjects(aData, sTrkorr);
          oApp.setProperty("/busy", false);
        }).catch(function (oErr2) {
          oApp.setProperty("/busy", false);
          MessageBox.warning(
            that._i18n("odataFailMock") + "\n" +
            (oErr && oErr.message ? oErr.message : oErr) + "\n" +
            (oErr2 && oErr2.message ? oErr2.message : oErr2),
            {
              onClose: function () {
                that._loadMock(sTrkorr, sServer);
              }
            }
          );
        });
      });
    },

    _setLoadedObjects: function (aData, sTrkorr) {
      var oApp = this.getOwnerComponent().getModel("appView");
      this._aAllObjects = aData || [];
      // Reset filter client để khỏi “nuốt” hết dòng (search/status cũ)
      this._sSearch = "";
      oApp.setProperty("/filterStatus", "");
      oApp.setProperty("/hasLoaded", true);
      this.getView().getModel("local").setProperty("/objects", this._aAllObjects);
      this._applyClientFilters();

      if (!this._aAllObjects.length) {
        oApp.setProperty(
          "/noDataText",
          "No objects for " + sTrkorr + " — check Released + R3TR in E071"
        );
        MessageBox.information(
          "TR " + sTrkorr + " không trả object nào.\n\n" +
          "Kiểm tra:\n" +
          "• TR đã Release (status R)?\n" +
          "• Có object R3TR (PROG/CLAS/INTF/FUGR) trong E071?\n" +
          "• Đúng client S40?"
        );
      } else {
        oApp.setProperty("/noDataText", "No objects match current filters");
        if (this._aAllObjects.length === 1 && !this._aAllObjects[0].ObjectName) {
          MessageBox.information(
            this._aAllObjects[0].Message ||
            ("TR " + sTrkorr + ": " + (this._aAllObjects[0].CompareStatus || ""))
          );
        }
      }
    },

    _loadMock: function (sTrkorr, sServer) {
      var aMock = [
        {
          Trkorr: sTrkorr,
          ObjectType: "PROG",
          ObjectName: "ZSCORT_SAMPLE_PROG",
          CompareStatus: "DIFFERENT",
          OriginLines: 18,
          TargetVers: "00001",
          ServerId: sServer,
          Message: "Mock — connect OData for real data"
        },
        {
          Trkorr: sTrkorr,
          ObjectType: "CLAS",
          ObjectName: "ZCL_SCORT_HASH_UTL",
          CompareStatus: "IDENTICAL",
          OriginLines: 120,
          TargetVers: "00001",
          ServerId: sServer,
          Message: "Mock"
        },
        {
          Trkorr: sTrkorr,
          ObjectType: "TABL",
          ObjectName: "ZASCORT_T",
          CompareStatus: "NOT_SUPPORTED",
          OriginLines: 0,
          ServerId: sServer,
          Message: "Object type not supported"
        }
      ];
      this._aAllObjects = aMock;
      this.getView().getModel("local").setProperty("/objects", aMock);
      this._applyClientFilters();
    },

    onSearch: function (oEvent) {
      this._sSearch = (oEvent.getParameter("newValue") || "").toUpperCase();
      this._applyClientFilters();
    },

    onFilterStatus: function () {
      this._applyClientFilters();
    },

    onModeChange: function (oEvent) {
      // selectedKey đã bind appView>/compareMode — Detail lắng nghe propertyChange và reload.
      // Nếu cùng object: ép nav lại với mode mới (tránh router bỏ qua khi chỉ đổi mode).
      var oItem = oEvent && oEvent.getParameter("item");
      var sMode = oItem ? oItem.getKey() : "";
      var oApp = this.getOwnerComponent().getModel("appView");
      if (sMode) {
        oApp.setProperty("/compareMode", sMode);
      }
      var oList = this.byId("objectList");
      var oSel = oList && oList.getSelectedItem && oList.getSelectedItem();
      if (!oSel || oApp.getProperty("/layout") === LayoutType.OneColumn) {
        return;
      }
      var oCtx = oSel.getBindingContext("local");
      if (!oCtx) {
        return;
      }
      var oObj = oCtx.getObject();
      var sStatus = oObj.CompareStatus || "";
      if (sStatus === "NOT_SUPPORTED" || sStatus === "ORIGIN_MISSING" || sStatus === "SOURCE_MISSING") {
        return;
      }
      this._oRouter.navTo("detail", {
        objectType: oObj.ObjectType,
        objectName: encodeURIComponent(oObj.ObjectName),
        query: {
          serverId: oObj.ServerId || "TGT",
          status: sStatus,
          mode: oApp.getProperty("/compareMode") || "L_VS_T",
          _ts: String(Date.now())
        }
      }, true);
    },

    _applyClientFilters: function () {
      var aAll = this._aAllObjects || [];
      var sStatus = this.getOwnerComponent().getModel("appView").getProperty("/filterStatus") || "";
      var sSearch = this._sSearch || "";
      var aFiltered = aAll.filter(function (o) {
        if (sStatus && o.CompareStatus !== sStatus) {
          return false;
        }
        if (sSearch && (o.ObjectName || "").toUpperCase().indexOf(sSearch) < 0) {
          return false;
        }
        return true;
      });
      this.getView().getModel("local").setProperty("/objects", aFiltered);
    },

    onSelect: function (oEvent) {
      var oItem = oEvent.getParameter("listItem");
      if (!oItem) {
        return;
      }
      var oCtx = oItem.getBindingContext("local");
      var oObj = oCtx.getObject();
      var sStatus = oObj.CompareStatus || "";

      if (sStatus === "NOT_SUPPORTED" || sStatus === "ORIGIN_MISSING" || sStatus === "SOURCE_MISSING") {
        MessageBox.information(this._i18n("cannotOpenDiff") + " (" + sStatus + ")");
        return;
      }

      this.getOwnerComponent().getModel("appView").setProperty("/layout", LayoutType.TwoColumnsMidExpanded);
      var sMode = this.getOwnerComponent().getModel("appView").getProperty("/compareMode") || "L_VS_T";
      this._oRouter.navTo("detail", {
        objectType: oObj.ObjectType,
        objectName: encodeURIComponent(oObj.ObjectName),
        query: {
          serverId: oObj.ServerId || "TGT",
          status: sStatus,
          mode: sMode
        }
      });
    },

    formatInfoState: function (sStatus) {
      switch ((sStatus || "").toUpperCase()) {
        case "DIFFERENT":
        case "BAD_HEX":
          return ValueState.Error;
        case "NEW_AT_TARGET":
          return ValueState.Success;
        case "ORIGIN_MISSING":
        case "SOURCE_MISSING":
          return ValueState.Warning;
        case "NOT_SUPPORTED":
          return ValueState.Information;
        default:
          return ValueState.None;
      }
    },

    _i18n: function (sKey) {
      return this.getOwnerComponent().getModel("i18n").getResourceBundle().getText(sKey);
    }
  });
});
