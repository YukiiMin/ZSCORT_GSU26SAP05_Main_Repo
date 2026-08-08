sap.ui.define([
  "zscort/app/controller/BaseController",
  "sap/ui/model/json/JSONModel",
  "sap/m/MessageToast",
  "sap/f/library",
  "zscort/app/util/ValueHelp"
], function (BaseController, JSONModel, MessageToast, fLibrary, ValueHelp) {
  "use strict";

  var LayoutType = fLibrary.LayoutType;

  return BaseController.extend("zscort.app.controller.Master", {

    onInit: function () {
      this.getView().setModel(new JSONModel({
        busy: false,
        rows: [],
        message: "Loading released TRs…"
      }), "master");
      this.getOwnerComponent().getRouter().getRoute("master").attachPatternMatched(this._onRouteMatched, this);
      this.getOwnerComponent().getRouter().getRoute("home").attachPatternMatched(this._onRouteMatched, this);
    },

    _onRouteMatched: function () {
      this._app().setProperty("/currentModule", "compare");
      this._app().setProperty("/layout", LayoutType.OneColumn);
      this._loadReleasedTrs("");
    },

    _serviceUri: function () {
      var sUri = this.getOwnerComponent().getManifestEntry("sap.app").dataSources.mainService.uri;
      return String(sUri || "").replace(/\/?$/, "/");
    },

    _loadReleasedTrs: function (sQuery) {
      var oM = this.getView().getModel("master");
      var that = this;
      var sQ = (sQuery || "").trim().toUpperCase().replace(/\*/g, "");
      // Only Trkorr on wire — TrStatus $filter can empty custom VH; filter Released in UI.
      var sUrl = this._serviceUri() + "VHTrkorr?$top=200";
      if (sQ) {
        sUrl += "&$filter=" + encodeURIComponent("startswith(Trkorr,'" + sQ.replace(/'/g, "''") + "')");
      }

      oM.setProperty("/busy", true);
      oM.setProperty("/message", "");

      ValueHelp.fetchJson(sUrl, 20000).then(function (aData) {
        var aRows = (aData || []).filter(function (r) {
          return r.TrStatus === "R";
        });
        if (sQ) {
          aRows = aRows.filter(function (r) {
            return String(r.Trkorr || "").toUpperCase().indexOf(sQ) >= 0;
          });
        }
        oM.setProperty("/rows", aRows);
        oM.setProperty("/busy", false);
        if (!aRows.length) {
          oM.setProperty("/message", "No released TR found. Release a TR in TR Search first.");
          MessageToast.show(oM.getProperty("/message"));
        }
      }).catch(function (oErr) {
        oM.setProperty("/busy", false);
        oM.setProperty("/rows", []);
        oM.setProperty("/message", "VHTrkorr error: " + (oErr.message || oErr));
        MessageToast.show(oM.getProperty("/message"));
      });
    },

    onSearchFieldSearch: function (oEvent) {
      this._loadReleasedTrs(oEvent.getParameter("query"));
    },

    onVHTrkorrListSelectionChange: function (oEvent) {
      this._navToDetail(oEvent.getParameter("listItem") || oEvent.getSource());
    },

    onObjectListItemPress: function (oEvent) {
      this._navToDetail(oEvent.getSource());
    },

    _navToDetail: function (oItem) {
      var oCtx = oItem && oItem.getBindingContext("master");
      if (!oCtx) { return; }

      var sStatus = oCtx.getProperty("TrStatus");
      if (sStatus && sStatus !== "R") {
        MessageToast.show("Chỉ so sánh TR đã Released. Hãy Release trước (TR Search).");
        return;
      }

      var sTrkorr = oCtx.getProperty("Trkorr");
      this.getOwnerComponent().getRouter().navTo("detail", {
        trkorr: encodeURIComponent(sTrkorr)
      });
    },

    formatDate: function (vDate) {
      if (!vDate) { return ""; }
      var s = String(vDate);
      // OData V4 may return "2026-08-08" — do not treat as YYYYMMDD
      if (/^\d{4}-\d{2}-\d{2}/.test(s)) {
        return s.substring(0, 10);
      }
      var sDigits = s.replace(/\D/g, "");
      if (sDigits.length >= 8) {
        return sDigits.substring(0, 4) + "-" + sDigits.substring(4, 6) + "-" + sDigits.substring(6, 8);
      }
      return s;
    }

  });
});
