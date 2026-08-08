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
        currentModule: "master",
        actionButtonsInfo: {
          midColumn: {
            fullScreen: false
          },
          endColumn: {
            fullScreen: false
          }
        }
      });
      this.getOwnerComponent().setModel(oAppModel, "appView");

      this._oRouter = this.getOwnerComponent().getRouter();
      this._oRouter.attachRouteMatched(this.onRouteMatched, this);
      this._oRouter.initialize();
    },

    onRouteMatched: function (oEvent) {
      var sRouteName = oEvent.getParameter("name");
      var oAppModel = this.getOwnerComponent().getModel("appView");

      if (sRouteName === "master" || sRouteName === "home") {
        oAppModel.setProperty("/layout", fLibrary.LayoutType.OneColumn);
        oAppModel.setProperty("/currentModule", "master");
      } else if (sRouteName === "detail") {
        oAppModel.setProperty("/layout", fLibrary.LayoutType.TwoColumnsMidExpanded);
      } else if (sRouteName === "compare") {
        // Expand the compare view fully for maximum coding space
        oAppModel.setProperty("/layout", fLibrary.LayoutType.ThreeColumnsEndExpanded);
      }
    },

    onFlexibleColumnLayoutStateChange: function (oEvent) {
      var bIsNavigationArrow = oEvent.getParameter("isNavigationArrow"),
        sLayout = oEvent.getParameter("layout");

      // Replace URL with new layout string if navigated via FCL arrows
      if (bIsNavigationArrow) {
        this.getOwnerComponent().getModel("appView").setProperty("/layout", sLayout);
      }
    }
  });
});
