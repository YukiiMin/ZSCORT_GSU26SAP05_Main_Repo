sap.ui.define([
  "zscort/app/controller/BaseController",
  "sap/ui/model/Filter",
  "sap/ui/model/FilterOperator"
], function (BaseController, Filter, FilterOperator) {
  "use strict";

  return BaseController.extend("zscort.app.controller.Master", {

    onInit: function () {
      this.getOwnerComponent().getRouter().getRoute("master").attachPatternMatched(this._onRouteMatched, this);
    },

    _onRouteMatched: function () {
      this._app().setProperty("/currentModule", "master");
      this._app().setProperty("/layout", "OneColumn");
    },

    onSearchFieldSearch: function (oEvent) {
      var sQuery = oEvent.getParameter("query");
      var oList = this.byId("idTrList");
      var oBinding = oList.getBinding("items");

      if (sQuery) {
        // Search by Trkorr or Description
        var oFilter = new Filter({
          filters: [
            new Filter("Trkorr", FilterOperator.Contains, sQuery.toUpperCase()),
            new Filter("Description", FilterOperator.Contains, sQuery)
          ],
          and: false
        });
        oBinding.filter([oFilter]);
      } else {
        oBinding.filter([]);
      }
    },

    onVHTrkorrListSelectionChange: function (oEvent) {
      this._navToDetail(oEvent.getParameter("listItem") || oEvent.getSource());
    },

    onObjectListItemPress: function (oEvent) {
      this._navToDetail(oEvent.getSource());
    },

    _navToDetail: function (oItem) {
      var oCtx = oItem.getBindingContext();
      if (!oCtx) return;

      var sTrkorr = oCtx.getProperty("Trkorr");

      // Navigate to Detail route with selected TR
      this.getOwnerComponent().getRouter().navTo("detail", {
        trkorr: encodeURIComponent(sTrkorr)
      });
    },

    formatDate: function (sDate) {
      if (!sDate || sDate.length < 8) return sDate || "";
      return sDate.substring(0, 4) + "-" + sDate.substring(4, 6) + "-" + sDate.substring(6, 8);
    }

  });
});
