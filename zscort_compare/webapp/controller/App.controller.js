sap.ui.define([
  "sap/ui/core/mvc/Controller",
  "sap/f/library"
], function (Controller, fLibrary) {
  "use strict";

  var LayoutType = fLibrary.LayoutType;

  return Controller.extend("zscort.compare.controller.App", {
    onInit: function () {
      var oApp = this.getOwnerComponent().getModel("appView");
      if (oApp && !oApp.getProperty("/layout")) {
        oApp.setProperty("/layout", LayoutType.OneColumn);
      }
      // eslint-disable-next-line no-console
      console.info("[zscort.compare] App.onInit");
    },

    onAfterRendering: function () {
      var oFcl = this.byId("fcl");
      var iBegin = oFcl && oFcl.getBeginColumnPages ? oFcl.getBeginColumnPages().length : -1;
      // eslint-disable-next-line no-console
      console.info("[zscort.compare] App.afterRendering beginColumnPages=", iBegin);
    },

    onStateChanged: function (oEvent) {
      var sLayout = oEvent.getParameter("layout");
      var oApp = this.getOwnerComponent().getModel("appView");
      if (oApp && sLayout) {
        oApp.setProperty("/layout", sLayout);
      }
    }
  });
});
