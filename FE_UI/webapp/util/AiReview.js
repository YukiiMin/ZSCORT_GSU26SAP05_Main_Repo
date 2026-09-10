/**
 * AiReview.js — SAP SCORT AI Service (100% Backend Routed)
 * Architecture: All AI requests route strictly via SAP SICF endpoint /sap/bc/zscort_ai
 * Handler: ZCL_SCORT_AI_HTTP_HANDLER -> ZCL_SCORT_AI_ASSISTANT
 * Security: Zero client-side API keys; no direct external Google AI API calls from browser.
 */
;(function (global, factory) {
  'use strict'
  if (typeof sap !== 'undefined' && sap.ui && sap.ui.define) {
    sap.ui.define([], factory)
  } else {
    global.AiReview = factory()
  }
})(this, function () {
  'use strict'

  var SUPPORTED_MODELS = [
    'gemini-3.5-flash',
    'gemini-3-flash',
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'antigravity',
  ]

  // ─── ROBUST JSON EXTRACTION & UNWRAPPING ──────────────────────────────────
  function _extractFieldsFromPartialJson(sText) {
    if (!sText || typeof sText !== 'string') return null
    var oResult = {}

    var mMode = sText.match(/"mode"\s*:\s*"([^"]+)"/i)
    if (mMode) oResult.mode = mMode[1]

    var mStatus = sText.match(/"syntax_status"\s*:\s*"([^"]+)"/i)
    if (mStatus) oResult.syntax_status = mStatus[1]

    var mScore = sText.match(/"syntax_score"\s*:\s*"([^"]+)"/i)
    if (mScore) oResult.syntax_score = mScore[1]

    var mTargetScore = sText.match(/"target_score"\s*:\s*"([^"]+)"/i)
    if (mTargetScore) oResult.target_score = mTargetScore[1]

    var mVerdict = sText.match(/"clean_abap_verdict"\s*:\s*"([^"]+)"/i)
    if (mVerdict) oResult.clean_abap_verdict = mVerdict[1]

    var mBetterSide = sText.match(/"better_side"\s*:\s*"([^"]+)"/i)
    if (mBetterSide) oResult.better_side = mBetterSide[1]

    var mBetterReason = sText.match(
      /"better_side_reason"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"/i
    )
    if (mBetterReason)
      oResult.better_side_reason = mBetterReason[1].replace(/\\"/g, '"')

    var mBestRec = sText.match(
      /"best_version_recommendation"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"/i
    )
    if (mBestRec)
      oResult.best_version_recommendation = mBestRec[1].replace(/\\"/g, '"')

    var mRec = sText.match(/"recommendation"\s*:\s*"([^"]+)"/i)
    if (mRec) oResult.recommendation = mRec[1]

    var mImpact = sText.match(/"impact_level"\s*:\s*"([^"]+)"/i)
    if (mImpact) oResult.impact_level = mImpact[1]

    var mReason = sText.match(/"reason"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"/i)
    if (mReason) oResult.reason = mReason[1].replace(/\\"/g, '"')

    var mSummary = sText.match(/"summary"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"/i)
    if (mSummary) {
      oResult.summary = mSummary[1].replace(/\\"/g, '"')
    } else {
      var mPartialSummary = sText.match(/"summary"\s*:\s*"([^"\\]*)$/i)
      if (mPartialSummary) {
        oResult.summary = mPartialSummary[1].trim()
      }
    }

    if (Object.keys(oResult).length > 0) {
      if (!oResult.findings) oResult.findings = []
      if (!oResult.risks) oResult.risks = []
      if (!oResult.notes) oResult.notes = []
      return oResult
    }
    return null
  }

  function _extractJsonFromText(sText) {
    if (!sText || typeof sText !== 'string') {
      return null
    }
    var sClean = sText.trim()

    // 1. Strip markdown code block wrappers
    sClean = sClean
      .replace(/^```[a-zA-Z]*\r?\n?/m, '')
      .replace(/\r?\n?```\s*$/m, '')
      .trim()

    // 2. Locate first '{' and last '}'
    var iFirst = sClean.indexOf('{')
    var iLast = sClean.lastIndexOf('}')
    if (iFirst > -1 && iLast > iFirst) {
      sClean = sClean.substring(iFirst, iLast + 1).trim()
    }

    // 3. First parse attempt
    try {
      return JSON.parse(sClean)
    } catch (e1) {
      // 4. Try sanitizing unescaped control chars if any
      try {
        var sSanitized = sClean.replace(
          /[\u0000-\u001F\u007F-\u009F]/g,
          function (c) {
            if (c === '\n') return '\\n'
            if (c === '\r') return '\\r'
            if (c === '\t') return '\\t'
            return ''
          }
        )
        return JSON.parse(sSanitized)
      } catch (e2) {
        // 5. Fallback for partial or truncated JSON
        return _extractFieldsFromPartialJson(sText)
      }
    }
  }

  function _normalizeAiResponse(oRaw) {
    if (!oRaw) {
      return { summary: 'No response received.' }
    }

    // A. If oRaw is a String
    if (typeof oRaw === 'string') {
      var oFromStr = _extractJsonFromText(oRaw)
      if (oFromStr) return _normalizeAiResponse(oFromStr)
      return {
        summary: oRaw,
        recommendation: 'REVIEW_REQUIRED',
        syntax_status: 'WARNING',
      }
    }

    // B. If oRaw is a Gemini API wrapper: { candidates: [ { content: { parts: [ { text: "..." } ] } } ] }
    if (
      oRaw.candidates &&
      oRaw.candidates[0] &&
      oRaw.candidates[0].content &&
      oRaw.candidates[0].content.parts
    ) {
      var sPartText = oRaw.candidates[0].content.parts[0].text
      var oFromGemini = _extractJsonFromText(sPartText)
      if (oFromGemini) return _normalizeAiResponse(oFromGemini)
      return {
        summary: sPartText || 'AI returned empty text.',
        recommendation: 'REVIEW_REQUIRED',
        syntax_status: 'WARNING',
      }
    }

    // C. If oRaw is already a structured payload object
    if (
      oRaw.syntax_status ||
      oRaw.recommendation ||
      oRaw.syntax_score ||
      oRaw.findings ||
      oRaw.risks ||
      oRaw.overall_verdict
    ) {
      if (
        typeof oRaw.summary === 'string' &&
        oRaw.summary.trim().charAt(0) === '{'
      ) {
        var oNested = _extractJsonFromText(oRaw.summary)
        if (
          oNested &&
          (oNested.syntax_status || oNested.recommendation || oNested.summary)
        ) {
          return oNested
        }
      }
      return oRaw
    }

    // D. If oRaw has error message
    if (oRaw.error) {
      return {
        summary:
          typeof oRaw.error === 'string'
            ? oRaw.error
            : oRaw.error.message || JSON.stringify(oRaw.error),
        recommendation: 'REVIEW_REQUIRED',
        syntax_status: 'ERROR',
      }
    }

    return oRaw
  }

  // ─── BACKEND SAP CALL (/sap/bc/zscort_ai) ─────────────────────────────────
  function _callSapBackend(
    sAction,
    sType,
    sName,
    sLocalCode,
    sTargetCode,
    sLang,
    sModel
  ) {
    var sUrl = '/sap/bc/zscort_ai'
    var oPayload = {
      action: sAction,
      objectType: sType,
      objectName: sName,
      localCode: sLocalCode || '',
      targetCode: sTargetCode || '',
      language: sLang || 'en',
      model: sModel || 'gemini-3.5-flash',
    }

    return fetch(sUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(oPayload),
    })
      .then(function (oRes) {
        if (!oRes.ok) {
          throw new Error(
            'SAP Backend HTTP ' +
              oRes.status +
              ' (' +
              oRes.statusText +
              '). ZCL_SCORT_AI_ASSISTANT service is not reachable.'
          )
        }
        return oRes.json()
      })
      .then(function (oJson) {
        return _normalizeAiResponse(oJson)
      })
  }

  // ─── METADATA & NAMING CONVENTION AUDITOR ────────────────────────────────
  function auditMetadataAndNaming(sObjType, sObjName, oLocalMeta, oTargetMeta, sLang) {
    oLocalMeta = oLocalMeta || {}
    oTargetMeta = oTargetMeta || {}
    var sType = (sObjType || '').toUpperCase().trim()
    var sName = (sObjName || '').toUpperCase().trim()
    var sLocale = (sLang || 'en').toLowerCase().split('_')[0]

    var aIssues = []
    var aDiffs = []
    var bNamespaceOk =
      sName.startsWith('Z') || sName.startsWith('Y') || sName.startsWith('/')
    if (!bNamespaceOk && sName) {
      var sMsg = 'Object name does not follow SAP Customer Namespace (must start with Z or Y): ' + sName
      if (sLocale === 'vi') {
        sMsg = 'Tên đối tượng không tuân thủ Customer Namespace chuẩn SAP (phải bắt đầu bằng Z hoặc Y): ' + sName
      } else if (sLocale === 'ja') {
        sMsg = 'オブジェクト名がSAPカスタム名前空間（ZまたはYで始まる必要があります）に従っていません: ' + sName
      } else if (sLocale === 'de') {
        sMsg = 'Objektname entspricht nicht dem SAP-Kunden-Namensraum (muss mit Z oder Y beginnen): ' + sName
      } else if (sLocale === 'zh') {
        sMsg = '对象名称不符合SAP客户命名空间规范（必须以Z或Y开头）: ' + sName
      }
      aIssues.push({
        type: 'WARNING',
        category: 'NAMING',
        message: sMsg,
      })
    }

    var sPrefixExpected = ''
    var bPrefixOk = true
    if (sType === 'CLAS') {
      bPrefixOk =
        sName.startsWith('ZCL_') ||
        sName.startsWith('YCL_') ||
        sName.startsWith('ZCX_') ||
        sName.startsWith('YCX_') ||
        sName.startsWith('ZBP_') ||
        sName.startsWith('YBP_') ||
        sName.startsWith('ZCL026_') ||
        sName.startsWith('ZCL')
      sPrefixExpected =
        'ZCL_ (Class), ZCX_ (Exception), or ZBP_ (Behavior Pool)'
    } else if (sType === 'INTF') {
      bPrefixOk =
        sName.startsWith('ZIF_') ||
        sName.startsWith('YIF_') ||
        sName.startsWith('ZIF')
      sPrefixExpected = 'ZIF_'
    } else if (sType === 'DDLS') {
      bPrefixOk =
        sName.startsWith('ZI_') ||
        sName.startsWith('ZC_') ||
        sName.startsWith('ZR_') ||
        sName.startsWith('ZIR_') ||
        sName.startsWith('ZCR_') ||
        sName.startsWith('ZCE_') ||
        sName.startsWith('Z')
      sPrefixExpected = 'ZI_ / ZC_ / ZR_ / ZIR_ / ZCR_ / ZCE_'
    } else if (sType === 'PROG') {
      bPrefixOk = sName.startsWith('Z') || sName.startsWith('Y')
      sPrefixExpected = 'Z... / Y...'
    }

    if (!bPrefixOk && sName) {
      var sMsgPrefix = 'Object naming: Standard prefix expected ' + sPrefixExpected + ' for type ' + sType + ', got ' + sName
      if (sLocale === 'vi') {
        sMsgPrefix = 'Chuẩn đặt tên đối tượng: Kỳ vọng tiền tố ' + sPrefixExpected + ' cho loại ' + sType + ', thực tế là ' + sName
      } else if (sLocale === 'ja') {
        sMsgPrefix = 'オブジェクト命名規約: タイプ ' + sType + ' に期待されるプレフィックス ' + sPrefixExpected + '、実際: ' + sName
      } else if (sLocale === 'de') {
        sMsgPrefix = 'Objekt-Namenskonvention: Erwartetes Standard-Präfix ' + sPrefixExpected + ' für Typ ' + sType + ', erhalten: ' + sName
      } else if (sLocale === 'zh') {
        sMsgPrefix = '对象命名规范: 类型 ' + sType + ' 应使用前缀 ' + sPrefixExpected + '，实际为 ' + sName
      }
      aIssues.push({
        type: 'WARNING',
        category: 'NAMING',
        message: sMsgPrefix,
      })
    }

    var sLocPkg =
      oLocalMeta.LocalPackage ||
      oLocalMeta.PackageName ||
      oLocalMeta.Devclass ||
      oLocalMeta.TadirDevclass ||
      ''
    var sTgtPkg =
      oTargetMeta.TargetPackage ||
      oTargetMeta.PackageName ||
      oTargetMeta.Devclass ||
      ''

    if (sLocPkg && sLocPkg.toUpperCase() === '$TMP') {
      var sMsgTmp = 'Local object resides in temporary package $TMP (un-transportable).'
      if (sLocale === 'vi') {
        sMsgTmp = 'Đối tượng cục bộ thuộc Package tạm thời $TMP (không thể đóng gói vào Transport Request).'
      } else if (sLocale === 'ja') {
        sMsgTmp = 'ローカルオブジェクトは一時パッケージ $TMP に属しています（移送不可）。'
      } else if (sLocale === 'de') {
        sMsgTmp = 'Lokales Objekt befindet sich im temporären Paket $TMP (nicht transportierbar).'
      } else if (sLocale === 'zh') {
        sMsgTmp = '本地对象属于临时包 $TMP（无法创建传输请求）。'
      }
      aIssues.push({
        type: 'WARNING',
        category: 'METADATA',
        message: sMsgTmp,
      })
    }

    if (sLocPkg && sTgtPkg && sLocPkg.toUpperCase() !== sTgtPkg.toUpperCase()) {
      var sMsgPkgDiff = 'Package mismatch: Local (' + sLocPkg + ') vs Target (' + sTgtPkg + ')'
      if (sLocale === 'vi') {
        sMsgPkgDiff = 'Khác biệt Package: Cục bộ (' + sLocPkg + ') vs Kho đích (' + sTgtPkg + ')'
      } else if (sLocale === 'ja') {
        sMsgPkgDiff = 'パッケージ不一致: ローカル (' + sLocPkg + ') vs ターゲット (' + sTgtPkg + ')'
      } else if (sLocale === 'de') {
        sMsgPkgDiff = 'Paket-Abweichung: Lokal (' + sLocPkg + ') vs Ziel (' + sTgtPkg + ')'
      }
      aDiffs.push(sMsgPkgDiff)
    }

    var sLocAuthor =
      oLocalMeta.LocalAuthor ||
      oLocalMeta.PersonResponsible ||
      oLocalMeta.Author ||
      oLocalMeta.Owner ||
      ''
    var sTgtAuthor =
      oTargetMeta.TargetAuthor ||
      oTargetMeta.PersonResponsible ||
      oTargetMeta.Author ||
      ''
    if (
      sLocAuthor &&
      sTgtAuthor &&
      sLocAuthor.toUpperCase() !== sTgtAuthor.toUpperCase()
    ) {
      var sMsgAuthorDiff = 'Author/Owner mismatch: Local (' + sLocAuthor + ') vs Target (' + sTgtAuthor + ')'
      if (sLocale === 'vi') {
        sMsgAuthorDiff = 'Khác biệt Người phụ trách: Cục bộ (' + sLocAuthor + ') vs Kho đích (' + sTgtAuthor + ')'
      } else if (sLocale === 'ja') {
        sMsgAuthorDiff = '担当者不一致: ローカル (' + sLocAuthor + ') vs ターゲット (' + sTgtAuthor + ')'
      } else if (sLocale === 'de') {
        sMsgAuthorDiff = 'Verantwortlicher-Abweichung: Lokal (' + sLocAuthor + ') vs Ziel (' + sTgtAuthor + ')'
      }
      aDiffs.push(sMsgAuthorDiff)
    }

    var sStatus = aIssues.length === 0 ? 'COMPLIANT' : 'WARNING'
    var iScore = 100 - aIssues.length * 15
    if (iScore < 40) iScore = 40

    return {
      status: sStatus,
      score: iScore + '/100',
      namespace_ok: bNamespaceOk,
      prefix_ok: bPrefixOk,
      issues: aIssues,
      diffs: aDiffs,
      local_pkg: sLocPkg || 'N/A',
      target_pkg: sTgtPkg || 'N/A',
      local_author: sLocAuthor || 'N/A',
      target_author: sTgtAuthor || 'N/A',
    }
  }

  // ─── PUBLIC API ──────────────────────────────────────────────────────────
  return {
    SUPPORTED_MODELS: SUPPORTED_MODELS,

    /**
     * Helper: Audit naming convention and metadata consistency
     */
    auditMetadataAndNaming: auditMetadataAndNaming,

    /**
     * Action 1: Audit syntax, syntax errors, obsolete statements, and Clean ABAP.
     * Dispatched 100% via SAP Backend /sap/bc/zscort_ai
     */
    checkSyntaxAndQuality: function (
      sObjectType,
      sObjectName,
      sLocalCode,
      sTargetCode,
      sUiLang,
      sMode,
      oLocalMeta,
      oTargetMeta,
      sModel
    ) {
      var oMetaAudit = auditMetadataAndNaming(
        sObjectType,
        sObjectName,
        oLocalMeta,
        oTargetMeta,
        sUiLang
      )
      sModel = sModel || 'gemini-3.5-flash'

      return _callSapBackend(
        'SYNTAX',
        sObjectType,
        sObjectName,
        sLocalCode,
        sTargetCode,
        sUiLang,
        sModel
      ).then(function (oResult) {
        if (oResult) {
          oResult.metadata_audit = oMetaAudit
        }
        return oResult
      })
    },

    /**
     * Action 2: Transport recommendation, risk analysis, and change summary.
     * Dispatched 100% via SAP Backend /sap/bc/zscort_ai
     */
    reviewTransport: function (
      sObjectType,
      sObjectName,
      sLocalCode,
      sTargetCode,
      sUiLang,
      sMode,
      sModel
    ) {
      sModel = sModel || 'gemini-3.5-flash'
      return _callSapBackend(
        'TRANSPORT',
        sObjectType,
        sObjectName,
        sLocalCode,
        sTargetCode,
        sUiLang,
        sModel
      )
    },

    /**
     * Backward-compatible alias for reviewTransport
     */
    reviewCode: function (
      sObjectType,
      sObjectName,
      sLocalCode,
      sTargetCode,
      sUiLang,
      sMode
    ) {
      return this.reviewTransport(
        sObjectType,
        sObjectName,
        sLocalCode,
        sTargetCode,
        sUiLang,
        sMode
      )
    },

    /**
     * Pre-flight Risk Assessment & Selective Apply Advice for TR
     * Dispatched 100% via SAP Backend /sap/bc/zscort_ai
     */
    analyzeApplyToTargetRisk: function (sTrkorr, aObjects, sUiLang, sMode, sModel) {
      var aObjSummaries = (aObjects || []).map(function (o, idx) {
        var sType = o.ObjectType || o.ObjType || ''
        var sName = o.ObjectName || o.ObjName || ''
        var sPkg = o.PackageName || o.Package || 'N/A'
        var sCmp = o.CompareStatus || 'N/A'
        var sAct = o.Action || (o.ObjectStatus === 'DELETED' ? 'DELETE' : 'APPLY')
        var sMsg = o.Message || ''
        return (
          idx +
          1 +
          '. [' +
          sType +
          '] ' +
          sName +
          ' | Pkg: ' +
          sPkg +
          ' | Compare: ' +
          sCmp +
          ' | Action: ' +
          sAct +
          ' | Msg: ' +
          sMsg
        )
      })

      sModel = sModel || 'gemini-3.5-flash'

      return _callSapBackend(
        'TRANSPORT',
        'TR',
        sTrkorr,
        aObjSummaries.join('\n'),
        '',
        sUiLang,
        sModel
      ).then(function (oRes) {
        if (!oRes) {
          return {
            overall_verdict: 'PARTIAL_RECOMMENDED',
            summary: 'Empty response from backend AI service.',
            recommendations: [],
            general_advice: '',
          }
        }

        // If backend already returned structured overall_verdict
        if (oRes.overall_verdict && Array.isArray(oRes.recommendations)) {
          return oRes
        }

        // Map transport recommendation to apply verdict
        var sVerdict = 'READY_TO_APPLY'
        var sRec = (oRes.recommendation || '').toUpperCase()
        if (sRec === 'DO_NOT_TRANSPORT') {
          sVerdict = 'BLOCK_RECOMMENDED'
        } else if (sRec === 'REVIEW_REQUIRED') {
          sVerdict = 'PARTIAL_RECOMMENDED'
        }

        var aRecs = (aObjects || []).map(function (obj) {
          var sRisk = (oRes.impact_level || 'LOW').toUpperCase()
          return {
            object: obj.ObjectType || obj.ObjType || '',
            obj_name: obj.ObjectName || obj.ObjName || '',
            should_apply: sVerdict !== 'BLOCK_RECOMMENDED',
            risk_level: sRisk,
            reason: oRes.reason || oRes.summary || '',
          }
        })

        return {
          overall_verdict: sVerdict,
          summary: oRes.summary || '',
          recommendations: aRecs,
          general_advice: oRes.reason || '',
        }
      })
    },
  }
})
