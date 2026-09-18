sap.ui.define(
  [
    'sap/ui/core/UIComponent',
    'sap/ui/model/json/JSONModel',
    'sap/f/library',
    'sap/ui/Device',
  ],
  function (UIComponent, JSONModel, fLibrary, Device) {
    'use strict'

    var LayoutType = fLibrary.LayoutType

    return UIComponent.extend('zscort.app.Component', {
      metadata: {
        manifest: 'json',
      },

      getContentDensityClass: function () {
        if (!this._sContentDensityClass) {
          if (!Device.support.touch) {
            this._sContentDensityClass = 'sapUiSizeCompact'
          } else {
            this._sContentDensityClass = 'sapUiSizeCozy'
          }
        }
        return this._sContentDensityClass
      },

      init: function () {
        var sSavedLang = localStorage.getItem('scort_lang') || 'en'
        try {
          if (sap.ui.getCore && sap.ui.getCore().getConfiguration) {
            sap.ui.getCore().getConfiguration().setLanguage(sSavedLang)
          }
        } catch (e) {
          // ignore fallback error
        }

        UIComponent.prototype.init.apply(this, arguments)

        var oAppModel = new JSONModel({
          currentLanguage: sSavedLang,
          currentModule: 'objSearch',
          layout: LayoutType.OneColumn,
          trkorr: '',
          serverId: 'TGT',
          busy: false,
          filterStatus: '',
          compareMode: 'L_VS_T',
          versionNo: '',
          versionNoRight: '99998',
          versions: [],
          targetVersions: [],
          noDataText: 'Enter TR and press Load',
          hasLoaded: false,
          actionButtonsInfo: {
            midColumn: { fullScreen: false },
            endColumn: { fullScreen: false },
          },
          aiModel: 'gemini-3.5-flash',
          aiExecutionMode: 'BE_SAP',
        })
        var oMainModel = this.getModel()
        this.setModel(oAppModel, 'appView')
        this.setModel(
          new JSONModel({
            aiModel: 'gemini-3.5-flash',
            aiExecutionMode: 'BE_SAP',
          }),
          'detail'
        )

        var isRunningInFLP = !!(
          window.sap &&
          sap.ushell &&
          sap.ushell.Container
        )
        var isSapServer =
          window.location.hostname.indexOf('localhost') === -1 &&
          window.location.hostname.indexOf('127.0.0.1') === -1
        var bLoggedOff = sessionStorage.getItem('scort_logged_off') === 'true'
        var oUserData = null
        var sInitialUser =
          localStorage.getItem('scort_remember_user') || 'SAP User'

        if ((isRunningInFLP || isSapServer) && !bLoggedOff) {
          if (isRunningInFLP && sap.ushell.Container.getUser()) {
            sInitialUser =
              sap.ushell.Container.getUser().getId() || sInitialUser
          }
          oUserData = {
            userId: sInitialUser.toUpperCase(),
            client: '324',
            language: sSavedLang,
            systemId: 'S40',
            role: 'ABAP Developer',
            isLoggedIn: true,
            loginTime: new Date().toLocaleTimeString(),
          }
          sessionStorage.setItem('scort_session', JSON.stringify(oUserData))
        } else {
          var sSession = sessionStorage.getItem('scort_session')
          if (sSession) {
            try {
              oUserData = JSON.parse(sSession)
            } catch (e) {
              oUserData = null
            }
          }
          if (!oUserData || !oUserData.isLoggedIn) {
            oUserData = {
              userId: sInitialUser.toUpperCase(),
              client: localStorage.getItem('scort_client') || '324',
              language: sSavedLang,
              systemId: 'S40',
              role: 'ABAP Developer',
              isLoggedIn: false,
              loginTime: '',
            }
          }
        }
        var oUserModel = new JSONModel(oUserData)
        this.setModel(oUserModel, 'user')

        var that = this
        if (isSapServer) {
          fetch('/sap/bc/ui2/start_up')
            .then(function (res) {
              return res.ok ? res.json() : null
            })
            .then(function (data) {
              if (data && data.id) {
                var sRealUser = data.id.toUpperCase()
                oUserModel.setProperty('/userId', sRealUser)
                oUserModel.setProperty('/client', data.client || '324')
                oUserModel.setProperty('/systemId', data.system || 'S40')
                var sCur = sessionStorage.getItem('scort_session')
                if (sCur) {
                  try {
                    var oParsed = JSON.parse(sCur)
                    oParsed.userId = sRealUser
                    oParsed.client = data.client || '324'
                    sessionStorage.setItem(
                      'scort_session',
                      JSON.stringify(oParsed)
                    )
                  } catch (e) {}
                }
              }
            })
            .catch(function () {})
        }

        var oObjModel = this.getModel('objModel')
        var oTrModel = this.getModel('trModel')

        var oDdicModel = new JSONModel({})
        this.setModel(oDdicModel, 'ddic')

        var fetchLabel = function (oOdm, sEntity, sProp) {
          if (!oOdm) return
          var sPath =
            '/' +
            sEntity +
            '/' +
            sProp +
            '@com.sap.vocabularies.Common.v1.Label'
          oOdm
            .getMetaModel()
            .requestObject(sPath)
            .then(function (sLabel) {
              if (sLabel) {
                oDdicModel.setProperty('/' + sEntity + '/' + sProp, sLabel)
              }
            })
            .catch(function () {})
        }

        if (oObjModel) {
          ;[
            'ObjectType',
            'ObjectName',
            'PackageName',
            'PersonResponsible',
            'CreatedOn',
          ].forEach(function (p) {
            fetchLabel(oObjModel, 'LocalObjects', p)
            fetchLabel(oObjModel, 'TargetObjects', p)
          })
          ;[
            'Pgmid',
            'ObjectType',
            'ObjectName',
            'LocalPackage',
            'TargetPackage',
            'LocalAuthor',
            'TargetAuthor',
            'ExistenceStatus',
          ].forEach(function (p) {
            fetchLabel(oObjModel, 'CompareMatrix', p)
          })
        }

        if (oTrModel) {
          ;['Trkorr', 'NodeType', 'Owner', 'Description'].forEach(function (p) {
            fetchLabel(oTrModel, 'TrTree', p)
          })
        }

        if (oMainModel) {
          ;['As4user', 'As4date'].forEach(function (p) {
            fetchLabel(oMainModel, 'ZCE_SCORT_TR_VH', p)
          })
          ;['ObjectType', 'ObjectName', 'CompareStatus'].forEach(function (p) {
            fetchLabel(oMainModel, 'TrCmp', p)
          })
        }

        this._initRouterWhenReady()
      },

      _initRouterWhenReady: function () {
        var oRouter = this.getRouter()
        if (!oRouter) {
          return
        }

        var that = this
        function startRouter() {
          try {
            oRouter.initialize()
            var oUser = that.getModel('user')
            var bLoggedIn = oUser && oUser.getProperty('/isLoggedIn')
            var isRunningInFLP = !!(
              window.sap &&
              sap.ushell &&
              sap.ushell.Container
            )
            var isSapServer =
              window.location.hostname.indexOf('localhost') === -1 &&
              window.location.hostname.indexOf('127.0.0.1') === -1
            var bLoggedOff =
              sessionStorage.getItem('scort_logged_off') === 'true'
            if (!bLoggedIn && !isRunningInFLP && (!isSapServer || bLoggedOff)) {
              oRouter.navTo('login', {}, true)
            }
          } catch (oErr) {
            // ignore
          }
        }

        var oRoot = this.getRootControl && this.getRootControl()
        if (oRoot && typeof oRoot.loaded === 'function') {
          oRoot
            .loaded()
            .then(startRouter)
            .catch(function () {
              startRouter()
            })
        } else {
          startRouter()
        }
      },
    })
  }
)
