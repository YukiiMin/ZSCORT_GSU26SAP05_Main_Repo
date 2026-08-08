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

      // Shared appView model — used by all screens via appView> binding
      var oAppModel = new JSONModel({
        // Navigation
        currentModule:  "objSearch",
        // FCL layout (used by Compare screen)
        layout: LayoutType.OneColumn,
        // Compare screen state
        trkorr:         "",
        serverId:       "TARGET",
        busy:           false,
        filterStatus:   "",
        compareMode:    "L_VS_T",
        versionNo:      "",
        versionNoRight: "99998",
        versions:       [],
        targetVersions: [],
        noDataText:     "Enter TR and press Load",
        hasLoaded:      false
      });
      this.setModel(oAppModel, "appView");
      this.setModel(new JSONModel({}), "detail");

      try {
        this.getRouter().initialize();
      } catch (oErr) {
        Log.error("Router init failed", oErr, "zscort.app.Component");
        throw oErr;
      }

      // Default route: always start at Object Search screen
      this.getRouter().navTo("objSearch", {}, true);
    }
  });
});
