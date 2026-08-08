sap.ui.define([
  "sap/ui/core/UIComponent",
  "sap/ui/model/json/JSONModel",
  "sap/f/library",
  "sap/base/Log"
], function (UIComponent, JSONModel, fLibrary, Log) {
  "use strict";

  var LayoutType = fLibrary.LayoutType;

  return UIComponent.extend("zscort.app.Component", {
    metadata: {
      manifest: "json"
    },

    init: function () {
      UIComponent.prototype.init.apply(this, arguments);

      var oAppModel = new JSONModel({
        currentModule:  "objSearch",
        layout: LayoutType.OneColumn,
        trkorr:         "",
        serverId:       "TGT",
        busy:           false,
        filterStatus:   "",
        compareMode:    "L_VS_T",
        versionNo:      "",
        versionNoRight: "99998",
        versions:       [],
        targetVersions: [],
        noDataText:     "Enter TR and press Load",
        hasLoaded:      false,
        actionButtonsInfo: {
          midColumn: { fullScreen: false },
          endColumn: { fullScreen: false }
        }
      });
      this.setModel(oAppModel, "appView");
      this.setModel(new JSONModel({}), "detail");

      this._initRouterWhenReady();
    },

    _initRouterWhenReady: function () {
      var oRouter = this.getRouter();
      if (!oRouter) {
        Log.error("No router", null, "zscort.app.Component");
        return;
      }

      function startRouter() {
        try {
          oRouter.initialize();
          oRouter.navTo("objSearch", {}, true);
        } catch (oErr) {
          Log.error("Router initialize failed", oErr, "zscort.app.Component");
        }
      }

      var oRoot = this.getRootControl && this.getRootControl();
      if (oRoot && typeof oRoot.loaded === "function") {
        oRoot.loaded().then(startRouter).catch(function () {
          startRouter();
        });
      } else {
        startRouter();
      }
    }
  });
});
