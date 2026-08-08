sap.ui.define([
  "sap/ui/core/mvc/Controller",
  "sap/ui/core/Fragment"
], function (Controller, Fragment) {
  "use strict";

  /**
   * BaseController — shared navigation helpers.
   * All page controllers extend this class.
   */
  return Controller.extend("zscort.app.controller.BaseController", {

    // ─── Navigation helpers ───────────────────────────────────────────────

    onNavObjSearch: function () {
      this._app().setProperty("/currentModule", "objSearch");
      this.getOwnerComponent().getRouter().navTo("objSearch");
    },

    onNavTrSearch: function () {
      this._app().setProperty("/currentModule", "trSearch");
      this.getOwnerComponent().getRouter().navTo("trSearch");
    },

    onNavCompare: function () {
      this._app().setProperty("/currentModule", "compare");
      this.getOwnerComponent().getRouter().navTo("compare");
    },

    onHomePress: function () {
      this.onNavObjSearch();
    },

    onMenuPress: function () {
      this.onNavObjSearch();
    },

    // ─── Internal helpers ─────────────────────────────────────────────────

    _app: function () {
      return this.getOwnerComponent().getModel("appView");
    },

    _i18n: function (sKey) {
      return this.getOwnerComponent().getModel("i18n").getResourceBundle().getText(sKey);
    },

    /**
     * Navigate to Code Compare screen with a specific object pre-selected.
     * Called from ObjectSearch when user clicks on an object row.
     */
    navToCompare: function (sObjectType, sObjectName, sServerId, sCompareStatus) {
      this._app().setProperty("/currentModule", "compare");
      this.getOwnerComponent().getRouter().navTo("compareDetail", {
        objectType: sObjectType,
        objectName: encodeURIComponent(sObjectName),
        query: {
          serverId: sServerId || "TARGET",
          status: sCompareStatus || "BOTH",
          mode: "L_VS_T"
        }
      });
    }
  });
});
