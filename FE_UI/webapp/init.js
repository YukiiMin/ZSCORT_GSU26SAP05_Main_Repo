sap.ui.define([
  "sap/ui/core/ComponentContainer",
  "sap/m/IllustratedMessage",
  "sap/m/Page",
  "sap/m/App"
], function (ComponentContainer, IllustratedMessage, Page, App) {
  "use strict";

  function showBootError(vErr) {
    var sMsg = (vErr && vErr.message) ? vErr.message : String(vErr || "Unknown boot error");
    // eslint-disable-next-line no-console
    console.error("[zscort.app] boot failed", vErr);
    new App({
      pages: [
        new Page({
          title: "SCORT — boot error",
          content: [
            new IllustratedMessage({
              illustrationType: "sapIllus-ErrorScreen",
              title: "App failed to start",
              description: sMsg +
                "\n\nCheck DevTools → Console/Network. " +
                "OData: /sap/opu/odata4/sap/ui_scort_obj_search_o4/..."
            })
          ]
        })
      ]
    }).placeAt("content");
  }

  sap.ui.getCore().attachInit(function () {
    sap.ui.require(["sap/ui/core/Component"], function (Component) {
      Component.create({
        name: "zscort.app",
        id: "zscortApp",
        manifest: true,
        async: true
      }).then(function (oComponent) {
        new ComponentContainer({
          id: "container",
          component: oComponent,
          height: "100%",
          settings: { id: "zscortApp" }
        }).placeAt("content");
      }).catch(showBootError);
    }, showBootError);
  });
});
