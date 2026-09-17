sap.ui.define([
  "sap/ui/core/UIComponent",
  "sap/ui/model/json/JSONModel",
  "sap/f/library",
  "sap/ui/Device"
], function (UIComponent, JSONModel, fLibrary, Device) {
  "use strict";

  var LayoutType = fLibrary.LayoutType;

  return UIComponent.extend("zscort.app.Component", {
    metadata: {
      manifest: "json"
    },

    getContentDensityClass: function () {
      if (!this._sContentDensityClass) {
        if (!Device.support.touch) {
          this._sContentDensityClass = "sapUiSizeCompact";
        } else {
          this._sContentDensityClass = "sapUiSizeCozy";
        }
      }
      return this._sContentDensityClass;
    },

    init: function () {
      var sSavedLang = localStorage.getItem("scort_lang") || "en";
      try {
        if (sap.ui.getCore && sap.ui.getCore().getConfiguration) {
          sap.ui.getCore().getConfiguration().setLanguage(sSavedLang);
        }
      } catch (e) {
        // ignore fallback error
      }

      UIComponent.prototype.init.apply(this, arguments);

      var oAppModel = new JSONModel({
        currentLanguage: sSavedLang,
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
        },
        aiModel: "gemini-3.5-flash",
        aiExecutionMode: "BE_SAP"
      });
      var oMainModel = this.getModel();
      this.setModel(oAppModel, "appView");
      this.setModel(new JSONModel({
        aiModel: "gemini-3.5-flash",
        aiExecutionMode: "BE_SAP"
      }), "detail");

      var isRunningInFLP = !!(window.sap && sap.ushell && sap.ushell.Container);
      var oUserData = null;
      if (isRunningInFLP) {
        var sFlpUser = "DEV-032";
        try {
          if (sap.ushell.Container.getUser()) {
            sFlpUser = sap.ushell.Container.getUser().getId() || "DEV-032";
          }
        } catch (e) {}
        oUserData = {
          userId: sFlpUser.toUpperCase(),
          client: "324",
          language: sSavedLang,
          systemId: "S40",
          role: "ABAP Developer",
          isLoggedIn: true,
          loginTime: new Date().toLocaleTimeString()
        };
        sessionStorage.setItem("scort_session", JSON.stringify(oUserData));
      } else {
        var sSession = sessionStorage.getItem("scort_session");
        if (sSession) {
          try {
            oUserData = JSON.parse(sSession);
          } catch (e) {
            oUserData = null;
          }
        }
        if (!oUserData || !oUserData.isLoggedIn) {
          oUserData = {
            userId: localStorage.getItem("scort_remember_user") || "DEV-032",
            client: localStorage.getItem("scort_client") || "324",
            language: sSavedLang,
            systemId: "S40",
            role: "ABAP Developer",
            isLoggedIn: false,
            loginTime: ""
          };
        }
      }
      var oUserModel = new JSONModel(oUserData);
      this.setModel(oUserModel, "user");

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
        return;
      }

      var that = this;
      function startRouter() {
        try {
          oRouter.initialize();
          var oUser = that.getModel("user");
          var bLoggedIn = oUser && oUser.getProperty("/isLoggedIn");
          var isRunningInFLP = !!(window.sap && sap.ushell && sap.ushell.Container);
          if (!bLoggedIn && !isRunningInFLP) {
            oRouter.navTo("login", {}, true);
          }
        } catch (oErr) {
          // ignore
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
