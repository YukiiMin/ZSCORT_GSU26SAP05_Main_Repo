sap.ui.define([
  "sap/ui/core/mvc/Controller",
  "sap/ui/model/json/JSONModel",
  "sap/f/library"
], function (Controller, JSONModel, fLibrary) {
  "use strict";

  return Controller.extend("zscort.app.controller.App", {

    onInit: function () {
      // Shared appView model — layout, busy, compareMode, etc.
      var oAppModel = new JSONModel({
        layout: fLibrary.LayoutType.OneColumn,
        busy: false,
        compareMode: "L_VS_T",
        filterStatus: "",
        trkorr: "",
        serverId: "TARGET",
        hasLoaded: false,
        noDataText: "Enter search criteria and press Load",
        currentModule: "objSearch"
      });
      this.getOwnerComponent().setModel(oAppModel, "appView");

      this._oRouter = this.getOwnerComponent().getRouter();
      this._oRouter.initialize();
    }
  });
});
