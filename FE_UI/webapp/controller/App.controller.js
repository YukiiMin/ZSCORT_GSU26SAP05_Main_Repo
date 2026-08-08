sap.ui.define([
  "sap/ui/core/mvc/Controller",
  "sap/f/library"
], function (Controller, fLibrary) {
  "use strict";

  var LayoutType = fLibrary.LayoutType;

  return Controller.extend("zscort.app.controller.App", {

    onInit: function () {
      this._oRouter = this.getOwnerComponent().getRouter();
      this._oRouter.attachRouteMatched(this.onRouteMatched, this);
    },

    onRouteMatched: function (oEvent) {
      var sRouteName = oEvent.getParameter("name");
      var oAppModel = this.getOwnerComponent().getModel("appView");

      switch (sRouteName) {
        case "master":
        case "home":
          oAppModel.setProperty("/layout", LayoutType.OneColumn);
          oAppModel.setProperty("/currentModule", "master");
          break;
        case "detail":
          oAppModel.setProperty("/layout", LayoutType.TwoColumnsMidExpanded);
          oAppModel.setProperty("/currentModule", "detail");
          break;
        case "compare":
          // TR-flow: Master + Detail + Compare (end column)
          oAppModel.setProperty("/layout", LayoutType.ThreeColumnsEndExpanded);
          oAppModel.setProperty("/currentModule", "compare");
          break;
        case "objCompare":
          // Direct compare from Object/TR Search: Begin + Mid only
          oAppModel.setProperty("/layout", LayoutType.TwoColumnsMidExpanded);
          oAppModel.setProperty("/currentModule", "compare");
          break;
        case "objSearch":
          // Full-width search — collapse any leftover Compare mid column
          oAppModel.setProperty("/layout", LayoutType.OneColumn);
          oAppModel.setProperty("/currentModule", "objSearch");
          break;
        case "trSearch":
          // Same: must reset layout or TrSearch stays hidden behind Compare mid column
          oAppModel.setProperty("/layout", LayoutType.OneColumn);
          oAppModel.setProperty("/currentModule", "trSearch");
          break;
        default:
          break;
      }
    },

    onFlexibleColumnLayoutStateChange: function (oEvent) {
      var bIsNavigationArrow = oEvent.getParameter("isNavigationArrow");
      var sLayout = oEvent.getParameter("layout");
      if (bIsNavigationArrow) {
        this.getOwnerComponent().getModel("appView").setProperty("/layout", sLayout);
      }
    }
  });
});
