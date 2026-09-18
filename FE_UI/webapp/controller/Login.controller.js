sap.ui.define([
  "zscort/app/controller/BaseController",
  "sap/ui/model/json/JSONModel",
  "sap/m/MessageToast",
  "sap/ui/core/MessageType"
], function (BaseController, JSONModel, MessageToast, MessageType) {
  "use strict";

  return BaseController.extend("zscort.app.controller.Login", {

    onInit: function () {
      localStorage.removeItem("scort_remember_user");
      localStorage.removeItem("scort_remember_flag");
      var sSavedClient = localStorage.getItem("scort_client") || "324";
      var sSavedLang = localStorage.getItem("scort_lang") || "en";

      var oLoginModel = new JSONModel({
        username: "",
        password: "",
        client: sSavedClient,
        language: sSavedLang,
        busy: false
      });
      this.getView().setModel(oLoginModel, "login");

      var oRouter = this.getRouter();
      if (oRouter && oRouter.getRoute("login")) {
        oRouter.getRoute("login").attachPatternMatched(this._onRouteMatched, this);
      }
    },

    _onRouteMatched: function () {
      var isRunningInFLP = !!(window.sap && sap.ushell && sap.ushell.Container);
      if (isRunningInFLP) {
        this._autoLoginFromFlp();
        return;
      }

      var oAppModel = this.getOwnerComponent().getModel("appView");
      if (oAppModel) {
        oAppModel.setProperty("/layout", "OneColumn");
        oAppModel.setProperty("/currentModule", "login");
      }

      this._ensureBeginVisible();

      var oLoginModel = this.getView().getModel("login");
      if (oLoginModel) {
        oLoginModel.setProperty("/username", "");
        oLoginModel.setProperty("/password", "");
        oLoginModel.setProperty("/busy", false);
      }

      this._hideMessage();
    },

    _ensureBeginVisible: function () {
      try {
        var oRoot = this.getOwnerComponent().getRootControl();
        var oFcl = oRoot && oRoot.byId && oRoot.byId("fcl");
        if (!oFcl) {
          oFcl = sap.ui.getCore().byId("container-zscort.app---appView--fcl");
        }
        if (oFcl && typeof oFcl.toBeginColumnPage === "function") {
          oFcl.toBeginColumnPage(this.getView());
        }
      } catch (e) {
        console.error("[Login] _ensureBeginVisible failed:", e);
      }
    },

    onLanguageChange: function (oEvent) {
      var sLang = oEvent.getParameter("selectedItem").getKey();
      localStorage.setItem("scort_lang", sLang);
      try {
        if (sap.ui.getCore && sap.ui.getCore().getConfiguration) {
          sap.ui.getCore().getConfiguration().setLanguage(sLang);
        }
      } catch (e) {
        // fallback
      }
      var oAppModel = this.getOwnerComponent().getModel("appView");
      if (oAppModel) {
        oAppModel.setProperty("/currentLanguage", sLang);
      }
    },

    onLogonPress: function () {
      var oLoginData = this.getView().getModel("login").getData();
      var sUser = (oLoginData.username || "").trim();
      var sPass = (oLoginData.password || "").trim();
      var sClient = (oLoginData.client || "").trim() || "324";
      var sLang = oLoginData.language || "en";

      var oBundle = this.getResourceBundle();

      if (!sUser || !sPass) {
        this._showMessage(oBundle.getText("loginErrEmpty") || "Please enter username and password.", MessageType.Error);
        return;
      }

      this._hideMessage();
      this.getView().getModel("login").setProperty("/busy", true);

      var sAuthHeader = "Basic " + btoa(sUser + ":" + sPass);
      var sAuthUrl = "/sap/opu/odata4/sap/zui_scort_obj_search_o4/srvd/sap/zsd_scort_obj_search/0001/$metadata";

      var that = this;
      fetch(sAuthUrl, {
        method: "GET",
        headers: {
          "Authorization": sAuthHeader,
          "sap-client": sClient,
          "sap-language": sLang.toUpperCase()
        }
      }).then(function (response) {
        that.getView().getModel("login").setProperty("/busy", false);
        if (response.ok || response.status === 200) {
          localStorage.removeItem("scort_remember_user");
          localStorage.removeItem("scort_remember_flag");
          localStorage.setItem("scort_client", sClient);
          localStorage.setItem("scort_lang", sLang);

          var oUserData = {
            userId: sUser.toUpperCase(),
            client: sClient,
            language: sLang,
            systemId: "S40",
            role: "ABAP Developer",
            isLoggedIn: true,
            loginTime: new Date().toLocaleTimeString()
          };

          sessionStorage.removeItem("scort_logged_off");
          sessionStorage.setItem("scort_session", JSON.stringify(oUserData));

          that._applyUserDataAndNavigate(oUserData);
          MessageToast.show(oBundle.getText("loginSuccessMsg") || "Login successful!");
        } else {
          var sErrMsg = oBundle.getText("loginErrFailed") || "Invalid SAP credentials.";
          sErrMsg += " (HTTP " + response.status + ": " + response.statusText + ")";
          that._showMessage(sErrMsg, MessageType.Error);
        }
      }).catch(function (error) {
        that.getView().getModel("login").setProperty("/busy", false);
        that._showMessage("Connection error: " + (error && error.message ? error.message : "Unable to reach SAP server."), MessageType.Error);
      });
    },

    _autoLoginFromFlp: function () {
      var sUserId = "SAP_USER";
      try {
        if (sap.ushell.Container.getUser()) {
          sUserId = sap.ushell.Container.getUser().getId() || sUserId;
        }
      } catch (e) {
        // ignore
      }
      var oUserData = {
        userId: sUserId.toUpperCase(),
        client: "324",
        language: localStorage.getItem("scort_lang") || "en",
        systemId: "S40",
        role: "ABAP Developer (FLP)",
        isLoggedIn: true,
        loginTime: new Date().toLocaleTimeString()
      };
      sessionStorage.setItem("scort_session", JSON.stringify(oUserData));
      this._applyUserDataAndNavigate(oUserData);
    },

    _applyUserDataAndNavigate: function (oUserData) {
      var oUserModel = this.getOwnerComponent().getModel("user");
      if (!oUserModel) {
        oUserModel = new JSONModel(oUserData);
        this.getOwnerComponent().setModel(oUserModel, "user");
      } else {
        oUserModel.setData(oUserData);
      }

      var oAppModel = this.getOwnerComponent().getModel("appView");
      if (oAppModel) {
        oAppModel.setProperty("/currentLanguage", oUserData.language);
        oAppModel.setProperty("/currentModule", "objSearch");
        oAppModel.setProperty("/layout", "OneColumn");
      }

      setTimeout(function () {
        var sTargetUrl = window.location.pathname + (window.location.search || "") + "#/objSearch";
        window.location.replace(sTargetUrl);
        window.location.reload();
      }, 250);
    },

    _showMessage: function (sText, sType) {
      var oMsgStrip = this.byId("loginMsgStrip");
      if (oMsgStrip) {
        oMsgStrip.setText(sText);
        oMsgStrip.setType(sType || MessageType.Information);
        oMsgStrip.setVisible(true);
      }
    },

    _hideMessage: function () {
      var oMsgStrip = this.byId("loginMsgStrip");
      if (oMsgStrip) {
        oMsgStrip.setVisible(false);
      }
    }
  });
});
