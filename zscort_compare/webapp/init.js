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
    console.error("[zscort.compare] boot failed", vErr);
    new App({
      pages: [
        new Page({
          title: "SCORT Compare — boot error",
          content: [
            new IllustratedMessage({
              illustrationType: "sapIllus-ErrorScreen",
              title: "App failed to start",
              description: sMsg
            })
          ]
        })
      ]
    }).placeAt("content");
  }

  sap.ui.getCore().attachInit(function () {
    var oBusy = new App({
      pages: [
        new Page({
          title: "SCORT Compare",
          enableScrolling: false,
          content: [
            new IllustratedMessage({
              illustrationType: "sapIllus-BeforeSearch",
              title: "Starting…",
              description: "Loading shell…"
            })
          ]
        })
      ]
    }).placeAt("content");

    sap.ui.require(["sap/ui/core/Component"], function (Component) {
      Component.create({
        name: "zscort.compare",
        id: "zscortCompare",
        manifest: true,
        async: true
      }).then(function (oComponent) {
        oBusy.destroy();
        new ComponentContainer({
          id: "container",
          component: oComponent,
          height: "100%",
          width: "100%"
        }).placeAt("content");
      }).catch(function (vErr) {
        oBusy.destroy();
        showBootError(vErr);
      });
    }, function (vErr) {
      oBusy.destroy();
      showBootError(vErr);
    });
  });
});
