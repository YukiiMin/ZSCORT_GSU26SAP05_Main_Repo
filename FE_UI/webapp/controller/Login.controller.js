sap.ui.define([
  "zscort/app/controller/BaseController",
  "sap/ui/model/json/JSONModel",
  "sap/m/MessageToast",
  "sap/ui/core/MessageType"
], function (BaseController, JSONModel, MessageToast, MessageType) {
  "use strict";

  return BaseController.extend("zscort.app.controller.Login", {

    onInit: function () {
      var sSavedUser = localStorage.getItem("scort_remember_user") || "DEV-032";
      var sSavedClient = localStorage.getItem("scort_client") || "324";
      var sSavedLang = localStorage.getItem("scort_lang") || "en";
      var bRemember = localStorage.getItem("scort_remember_flag") !== "false";

      var oLoginModel = new JSONModel({
        username: sSavedUser,
        password: "",
        client: sSavedClient,
        language: sSavedLang,
        rememberMe: bRemember,
        busy: false
      });
      this.getView().setModel(oLoginModel, "login");

      var oRouter = this.getRouter();
      if (oRouter) {
        if (oRouter.getRoute("login")) {
          oRouter.getRoute("login").attachPatternMatched(this._onRouteMatched, this);
        }
        if (oRouter.getRoute("home")) {
          oRouter.getRoute("home").attachPatternMatched(this._onRouteMatched, this);
        }
      }
    },

    _onRouteMatched: function () {
      var isRunningInFLP = !!(window.sap && sap.ushell && sap.ushell.Container);
      var isSapServer = window.location.hostname.indexOf("localhost") === -1 && window.location.hostname.indexOf("127.0.0.1") === -1;
      var bLoggedOff = sessionStorage.getItem("scort_logged_off") === "true";
      if ((isRunningInFLP || isSapServer) && !bLoggedOff) {
        this._autoLoginFromFlp();
        return;
      }

      var sSession = sessionStorage.getItem("scort_session");
      if (sSession) {
        try {
          var oSessionData = JSON.parse(sSession);
          if (oSessionData && oSessionData.isLoggedIn) {
            this._applyUserDataAndNavigate(oSessionData);
            return;
          }
        } catch (e) {
          sessionStorage.removeItem("scort_session");
        }
      }

      this._hideMessage();
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
      var bRemember = oLoginData.rememberMe;

      var oBundle = this.getResourceBundle();

      if (!sUser || !sPass) {
        this._showMessage(oBundle.getText("loginErrEmpty"), MessageType.Error);
        return;
      }

      this.getView().getModel("login").setProperty("/busy", true);

      if (bRemember) {
        localStorage.setItem("scort_remember_user", sUser);
        localStorage.setItem("scort_client", sClient);
        localStorage.setItem("scort_remember_flag", "true");
      } else {
        localStorage.removeItem("scort_remember_user");
        localStorage.setItem("scort_remember_flag", "false");
      }
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

      setTimeout(function () {
        this.getView().getModel("login").setProperty("/busy", false);
        this._applyUserDataAndNavigate(oUserData);
        MessageToast.show(oBundle.getText("loginSuccessMsg"));
      }.bind(this), 300);
    },

    _autoLoginFromFlp: function () {
      var sUserId = "DEV-032";
      try {
        if (sap.ushell.Container.getUser()) {
          sUserId = sap.ushell.Container.getUser().getId() || "DEV-032";
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
      }

      this.getRouter().navTo("objSearch", {}, true);
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
