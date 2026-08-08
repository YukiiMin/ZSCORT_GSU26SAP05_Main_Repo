sap.ui.define([
  "sap/ui/core/UIComponent",
  "sap/ui/model/json/JSONModel",
  "sap/f/library",
  "sap/base/Log"
], function (UIComponent, JSONModel, fLibrary, Log) {
  "use strict";

  var LayoutType = fLibrary.LayoutType;

  return UIComponent.extend("zscort.compare.Component", {
    metadata: {
      manifest: "json"
    },

    init: function () {
      try {
        if (typeof window !== "undefined" && window.location &&
            /#\/?detail\//i.test(window.location.hash || "")) {
          window.history.replaceState(
            null,
            document.title || "",
            window.location.pathname + (window.location.search || "")
          );
        }
      } catch (oIgnore) {
        // ignore
      }

      UIComponent.prototype.init.apply(this, arguments);

      var oAppModel = new JSONModel({
        layout: LayoutType.OneColumn,
        trkorr: "",
        serverId: "TGT",
        busy: false,
        filterStatus: "",
        compareMode: "L_VS_T",
        versionNo: "",
        versionNoRight: "99998",
        versions: [],
        targetVersions: [],
        noDataText: "Enter TR and press Load",
        hasLoaded: false
      });
      this.setModel(oAppModel, "appView");
      this.setModel(new JSONModel({}), "detail");

      var oRouter = this.getRouter();
      if (oRouter) {
        oRouter.attachBeforeRouteMatched(this._onBeforeRouteMatched, this);
      }

      this._initRouterWhenReady();
    },

    _onBeforeRouteMatched: function (oEvent) {
      var oApp = this.getModel("appView");
      if (!oApp) {
        return;
      }
      var sName = oEvent.getParameter("name");
      oApp.setProperty(
        "/layout",
        sName === "detail" ? LayoutType.TwoColumnsMidExpanded : LayoutType.OneColumn
      );
    },

    _initRouterWhenReady: function () {
      var oRouter = this.getRouter();
      if (!oRouter) {
        // eslint-disable-next-line no-console
        console.error("[zscort.compare] no router");
        return;
      }

      var startRouter = function () {
        try {
          oRouter.initialize();
          // eslint-disable-next-line no-console
          console.info("[zscort.compare] router initialized");
        } catch (oErr) {
          // eslint-disable-next-line no-console
          console.error("[zscort.compare] router initialize failed", oErr);
          Log.error("Router initialize failed", oErr, "zscort.compare.Component");
        }
      };

      var oRoot = this.getRootControl && this.getRootControl();
      if (oRoot && typeof oRoot.loaded === "function") {
        oRoot.loaded().then(startRouter).catch(function (oErr) {
          // eslint-disable-next-line no-console
          console.error("[zscort.compare] root view failed", oErr);
          startRouter();
        });
      } else {
        startRouter();
      }
    },

    getServiceUri: function () {
      return this.getManifestEntry("sap.app").dataSources.mainService.uri;
    },

    ensureODataModel: function () {
      if (this.getModel()) {
        return this.getModel();
      }
      var that = this;
      sap.ui.require(["sap/ui/model/odata/v4/ODataModel"], function (ODataModel) {
        if (that.getModel()) {
          return;
        }
        try {
          that.setModel(new ODataModel({
            serviceUrl: that.getServiceUri(),
            synchronizationMode: "None",
            autoExpandSelect: true,
            earlyRequests: false
          }));
        } catch (oErr) {
          Log.warning("ODataModel create skipped", oErr, "zscort.compare.Component");
        }
      });
      return this.getModel();
    }
  });
});
