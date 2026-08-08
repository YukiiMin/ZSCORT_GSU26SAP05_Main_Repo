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
      var oMainModel = this.getModel("");
      this.setModel(oAppModel, "appView");
      this.setModel(new JSONModel({}), "detail");
      var oObjModel = this.getModel("objModel");
      var oTrModel = this.getModel("trModel");

      var oDdicModel = new JSONModel({});
      this.setModel(oDdicModel, "ddic");

      var fetchLabel = function(oOdm, sEntity, sProp) {
        if (!oOdm) return;
        var sPath = "/" + sEntity + "/" + sProp + "@com.sap.vocabularies.Common.v1.Label";
        oOdm.getMetaModel().requestObject(sPath).then(function(sLabel) {
          if (sLabel) {
             oDdicModel.setProperty("/" + sEntity + "/" + sProp, sLabel);
          }
        }).catch(function(){});
      };

      if (oObjModel) {
        ["ObjectType", "ObjectName", "PackageName", "PersonResponsible", "CreatedOn"].forEach(function(p){
          fetchLabel(oObjModel, "LocalObjects", p);
          fetchLabel(oObjModel, "TargetObjects", p);
        });
        ["Pgmid", "ObjectType", "ObjectName", "LocalPackage", "TargetPackage", "LocalAuthor", "TargetAuthor", "ExistenceStatus"].forEach(function(p){
          fetchLabel(oObjModel, "CompareMatrix", p);
        });
      }

      if (oTrModel) {
        ["Trkorr", "NodeType", "Owner", "Description"].forEach(function(p){
          fetchLabel(oTrModel, "TrTree", p);
        });
      }

      if (oMainModel) {
        ["As4user", "As4date"].forEach(function(p){
          fetchLabel(oMainModel, "ZCE_SCORT_TR_VH", p);
        });
        ["ObjectType", "ObjectName", "CompareStatus"].forEach(function(p){
          fetchLabel(oMainModel, "TrCmp", p);
        });
      }

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
