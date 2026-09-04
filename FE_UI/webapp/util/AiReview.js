/**
 * AiReview.js — Dual-Action & Dual-Mode AI Service for SAP ABAP
 * Action 1: Syntax & Code Quality Checking (Static Code Audit)
 * Action 2: Transport Recommendation & Risk Analysis
 * Mode 1: Direct Client (Gemini API with 9 Rotating Keys)
 * Mode 2: SAP Backend (ABAP Class ZCL_SCORT_AI_ASSISTANT via /sap/bc/zscort_ai)
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

  // ─── CONFIG & FALLBACK MODELS ─────────────────────────────────────────────
  var GEMINI_MODELS = [
    'gemini-3.5-flash',
    'gemini-3-flash',
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'antigravity',
  ]

  // Rotating API keys pool (base64 encoded)
  var API_KEYS = [
    'QUl6YVN5QnFDNG9lZDBTOC02MFpDREd4cmFhWVBqVGo1SHgwS3BB',
    'QVEuQWI4Uk42S2JiQmZCaHpEWlE0dHl0MDN4cWlaX3h4Tl9iSDRENjFvZTBaQWpfVnptVUE=',
    'QVEuQWI4Uk42THdFZ0dpUHJ5RlBJODVkR2VSb21idTFpb2t3R0JqYUtaLUNnRjFJQTRHRVE=',
    'QVEuQWI4Uk42THRSbXdaaWdwT05aNTUyQ1hCQlVTcG5tVmNqY1JrSzZEbldCekF1RlpOc2c=',
    'QVEuQWI4Uk42S1ZHaUdQWXhDZGJUTWhoYm9ydDhRU25jZHRvbDhabTRHR0U2bk40NFZ1M3c=',
    'QVEuQWI4Uk42TGhQeFo2blFHcVJkdnpUQVlaNjByUVVVamhPSDU4Ymxld2UzbkVTU05Kc0E=',
    'QVEuQWI4Uk42SU14MXM3akdJMUpIc1pNZjQ5QkxDd1ZjcEJibFpOSFBHSHpfVmQ1aVJYQ0E=',
    'QVEuQWI4Uk42TG9xcl9MQkdoR3poeG90V3N0VTVlbFpnenVWd2tubi1XTXB3dzdxeUQtTHc=',
    'QUl6YVN5QjFzRjJRdGlTLVRSalFQVGxMdHVYMlc0RkkxQ3NObWYw',
  ].map(function (b64) {
    try {
      return atob(b64)
    } catch (e) {
      return b64
    }
  })
  var _keyIdx = 0

  function _nextKey() {
    var key = API_KEYS[_keyIdx % API_KEYS.length]
    _keyIdx++
    return key
  }

  function _getLangInstruction(sLang) {
    var s = (sLang || 'en').toLowerCase().split('_')[0]
    if (s === 'vi') return 'Tra loi HOAN TOAN bang tieng Viet (Vietnamese). Cac thuat ngu ky thuat SAP/ABAP giu nguyen tieng Anh nhung toan bo giai thich va huong dan phai bang tieng Viet.'
    if (s === 'ja') return 'すべての回答を日本語で記述してください。SAP/ABAP技術用語は英語のままにし、説明は日本語で行ってください。'
    if (s === 'zh') return '请完全用中文（简体）回答。SAP/ABAP技术术语可保留英文，但说明需用中文书写。'
    if (s === 'de') return 'Antworte AUSSCHLIESSLICH auf Deutsch. Technische SAP/ABAP-Begriffe auf Englisch belassen, Erklaerungen auf Deutsch.'
    if (s === 'fr') return 'Repondre ENTIEREMENT en francais. Termes techniques SAP/ABAP en anglais, explications en francais.'
    if (s === 'es') return 'Responde COMPLETAMENTE en espanol. Terminos tecnicos SAP/ABAP en ingles, explicaciones en espanol.'
    if (s === 'pt') return 'Responda COMPLETAMENTE em portugues. Termos tecnicos SAP/ABAP em ingles, explicacoes em portugues.'
    return 'Reply strictly in English.'
  }

  function _addLineNumbers(sCode) {
    if (!sCode || sCode === '(empty)') return sCode || '';
    var aLines = sCode.split('\n');
    return aLines.map(function (line, idx) {
      return (idx + 1) + ': ' + line;
    }).join('\n');
  }

  function _isCdsOrDdic(sType) {
    var t = (sType || '').toUpperCase();
    return t === 'DDLS' || t === 'DCLS' || t === 'BDEF' || t === 'TABL' || t === 'DTEL' || t === 'DOMA';
  }

  // ─── PROMPT 1: SYNTAX & CODE QUALITY AUDIT ─────────────────────────────────
  function _buildSyntaxPrompt(sType, sName, sLocalCode, sTargetCode, sLang) {
    var sLangInstruct = _getLangInstruction(sLang)
    var bCds = _isCdsOrDdic(sType)
    var sCodeFence = bCds ? 'sql' : 'abap'
    var bHasLocal = !!(
      sLocalCode &&
      sLocalCode.trim() &&
      sLocalCode !== '(empty)'
    )
    var bHasTarget = !!(
      sTargetCode &&
      sTargetCode.trim() &&
      sTargetCode !== '(empty)'
    )

    var sNumberedLocal = _addLineNumbers(sLocalCode)
    var sNumberedTarget = _addLineNumbers(sTargetCode)

    var sLineReq = [
      'CRITICAL INSTRUCTION FOR EACH FINDING:',
      '- Every line in the code is numbered (e.g. "26: ...").',
      '- You MUST provide `line_number` (integer, e.g. 26) pointing to the exact line in code.',
      '- You MUST format `line_or_snippet` starting with "Line <line_number>: [exact code snippet]".',
      '- You MUST provide `message` explaining in detail why it is invalid or suboptimal.',
      '- You MUST provide `suggestion` containing a concrete, ready-to-use refactored code replacement.'
    ].join('\n')

    var sPersona = bCds
      ? 'You are a Principal SAP Core Data Services (CDS), RAP Behavior Definition, and SAP DDIC Architect and Static Code Analysis Auditor. ' + sLangInstruct
      : 'You are a Principal SAP ABAP Compiler and Senior Static Code Analysis Auditor. ' + sLangInstruct

    var sFocusAreas = bCds
      ? [
          '## Focus Areas for Deep Audit (CDS / RAP / DDIC):',
          '1. Syntax & Compilation: Valid annotations (@EndUserText, @AccessControl, etc.), matched curly braces { ... }, semicolon statement termination ;, valid data element casting cast(...). Note: CDS/BDEF use semicolons, NOT ABAP periods.',
          '2. Data Modeling & Associations: Clean entity structure, identical association definitions across UNION branches, cardinality consistency, exposed fields integrity.',
          '3. RAP Behavior Compliance: Entity actions, determinations, validations, strict mode compliance, draft enablement checks (if BDEF).',
          '4. Performance & DB Pushdown: Join conditions, avoiding Cartesian products, index utilization for table definitions.',
          '5. Comparative Quality: Assess which codebase (LOCAL vs TARGET) has higher quality, fewer violations, and cleaner modeling.'
        ].join('\n')
      : [
          '## Focus Areas for Deep Audit:',
          '1. Syntax & Compilation: Invalid keywords, missing periods, unmatched control structures (ENDIF, ENDLOOP, ENDMETHOD).',
          '2. Obsolete Syntax: Detect obsolete constructs (CONCATENATE -> string templates |...|, MOVE TO, TABLES, FORM/PERFORM, OCCURS, RANGES).',
          '3. Clean ABAP Standards: Inline declarations (DATA/FINAL), constructor expressions (VALUE, COND, REDUCE), DRY principle, Single Responsibility, modern OOP.',
          '4. Performance & Reliability: SELECT in LOOP (N+1 queries), missing WHERE clauses, unchecked sy-subrc, unhandled exceptions.',
          '5. Comparative Quality: Assess which codebase (LOCAL vs TARGET) has higher quality, fewer violations, and better architecture.'
        ].join('\n')

    if (bHasLocal && bHasTarget) {
      return [
        sPersona,
        '',
        '## Task: Dual-Side Syntax, Code Quality & Comparative Audit',
        'The object exists on BOTH Local (Active) and Target (Snapshot) systems.',
        'You MUST perform separate evaluations for Local Code AND Target Code, determine which side is better designed, and provide an expert best-practice synthesis to achieve optimal quality.',
        '',
        sLineReq,
        '',
        sFocusAreas,
        '',
        '## Object Info: ' + sType + ' ' + sName,
        '',
        '## Local Code (Active Version - Numbered Lines):',
        '```' + sCodeFence,
        sNumberedLocal,
        '```',
        '',
        '## Target Code (Baseline Version - Numbered Lines):',
        '```' + sCodeFence,
        sNumberedTarget,
        '```',
        '',
        '## Required Output Format (Valid JSON only, no markdown fences):',
        '{',
        '  "mode": "DUAL",',
        '  "syntax_status": "PASSED" | "WARNING" | "ERROR",',
        '  "syntax_score": "Score out of 100 for Local (e.g. 60/100)",',
        '  "target_score": "Score out of 100 for Target (e.g. 95/100)",',
        '  "clean_abap_verdict": "Compliant" | "Needs Refactoring" | "Critical Issues",',
        '  "better_side": "LOCAL" | "TARGET" | "EQUIVALENT",',
        '  "better_side_reason": "In-depth technical explanation comparing Local vs Target code quality, readability, and performance.",',
        '  "best_version_recommendation": "Actionable recommendation on which version to keep and concrete refactoring steps to reach 100/100 score.",',
        '  "summary": "Comprehensive 3-5 sentence comparative audit summary.",',
        '  "findings": [',
        '    {',
        '      "side": "LOCAL" | "TARGET" | "BOTH",',
        '      "type": "SYNTAX_ERROR" | "WARNING" | "BEST_PRACTICE",',
        '      "line_number": 20,',
        '      "line_or_snippet": "Line 20: [Exact code line or statement]",',
        '      "message": "Detailed explanation of the violation",',
        '      "suggestion": "Concrete refactored code replacement according to SAP best practices."' ,
        '    }',
        '  ]',
        '}',
      ].join('\n')
    } else if (bHasLocal && !bHasTarget) {
      return [
        sPersona,
        '',
        '## Task: Deep Syntax & Clean Quality Audit (Local New Object)',
        'This is a NEW object that exists ONLY on the LOCAL development system.',
        'Perform an exhaustive, audit-grade static analysis of the LOCAL code against SAP guidelines and system stability.',
        '',
        sLineReq,
        '',
        sFocusAreas,
        '',
        '## Object Info: ' + sType + ' ' + sName,
        '',
        '## Local Code (Active Version - Numbered Lines):',
        '```' + sCodeFence,
        sNumberedLocal || '(empty)',
        '```',
        '',
        '## Required Output Format (Valid JSON only, no markdown fences):',
        '{',
        '  "mode": "LOCAL_ONLY",',
        '  "syntax_status": "PASSED" | "WARNING" | "ERROR",',
        '  "syntax_score": "Score out of 100 (e.g. 85/100)",',
        '  "clean_abap_verdict": "Compliant" | "Needs Refactoring" | "Critical Issues",',
        '  "summary": "Comprehensive 3-5 sentence audit summary of Local code health and architectural quality.",',
        '  "findings": [',
        '    {',
        '      "side": "LOCAL",',
        '      "type": "SYNTAX_ERROR" | "WARNING" | "BEST_PRACTICE",',
        '      "line_number": 20,',
        '      "line_or_snippet": "Line 20: [Exact code line or statement]",',
        '      "message": "Detailed explanation of the violation",',
        '      "suggestion": "Concrete refactored code replacement according to SAP best practices."' ,
        '    }',
        '  ]',
        '}',
      ].join('\n')
    } else {
      return [
        sPersona,
        '',
        '## Task: Deep Syntax & Clean Quality Audit (Target Baseline Object)',
        'This object exists ONLY on the TARGET system (missing or deleted on Local).',
        'Perform an exhaustive static analysis of the TARGET code baseline against SAP guidelines.',
        '',
        sLineReq,
        '',
        sFocusAreas,
        '',
        '## Object Info: ' + sType + ' ' + sName,
        '',
        '## Target Code (Baseline - Numbered Lines):',
        '```' + sCodeFence,
        sNumberedTarget || '(empty)',
        '```',
        '',
        '## Required Output Format (Valid JSON only, no markdown fences):',
        '{',
        '  "mode": "TARGET_ONLY",',
        '  "syntax_status": "PASSED" | "WARNING" | "ERROR",',
        '  "syntax_score": "Score out of 100 (e.g. 90/100)",',
        '  "clean_abap_verdict": "Compliant" | "Needs Refactoring" | "Critical Issues",',
        '  "summary": "Comprehensive 3-5 sentence audit summary of Target baseline code health.",',
        '  "findings": [',
        '    {',
        '      "side": "TARGET",',
        '      "type": "SYNTAX_ERROR" | "WARNING" | "BEST_PRACTICE",',
        '      "line_number": 20,',
        '      "line_or_snippet": "Line 20: [Exact code line or statement]",',
        '      "message": "Detailed explanation of the violation",',
        '      "suggestion": "Concrete refactored code replacement according to SAP best practices."' ,
        '    }',
        '  ]',
        '}',
      ].join('\n')
    }
  }

  // ─── PROMPT 2: TRANSPORT RECOMMENDATION & RISK ANALYSIS ────────────────────
  function _buildTransportPrompt(sType, sName, sLocalCode, sTargetCode, sLang) {
    var sLangInstruct = _getLangInstruction(sLang)
    var bCds = _isCdsOrDdic(sType)
    var sCodeFence = bCds ? 'sql' : 'abap'
    var sDimensions = bCds
      ? [
          '## Evaluation Dimensions (CDS / RAP / DDIC):',
          '1. Schema & Data Integrity: Incompatible field type/length changes, dropped primary keys, table conversion locks in production.',
          '2. Interface & Dependency Breaking Changes: Exposed association alterations, removed elements breaking consumers, dependent CDS entities.',
          '3. Release Risk: Overall production risk classification and transport feasibility.',
          '4. Pre & Post-Import Precautions (Notes): Table activation sequence, database dictionary adjustments (SE14), buffer resets, CDS view cache invalidation.'
        ].join('\n')
      : [
          '## Evaluation Dimensions:',
          '1. Security & Compliance: AUTHORITY-CHECK before mutations, hardcoded credentials, SQL injection vulnerability.',
          '2. Concurrency & Locks: Proper enqueue/dequeue locks before UPDATE/MODIFY, deadlocks prevention.',
          '3. Interface & Dependency Breaking Changes: Public method signature alteration, parameter removal, incompatible type changes, missing dependent CDS/tables.',
          '4. Release Risk: Overall production risk classification and transport feasibility.',
          '5. Pre & Post-Import Precautions (Notes): Critical deployment notes, dependent TR sequences, manual SPRO configurations, cache/buffer resets, SICF activations, or regression testing steps.'
        ].join('\n')

    return [
      'You are a Principal SAP Architect and Release Manager with 15+ years experience. ' +
        sLangInstruct,
      '',
      '## Task: Transport Recommendation & Comprehensive Risk Assessment',
      'Compare LOCAL vs TARGET code thoroughly to formulate an audit-grade Transport Decision for Apply to Target.',
      '',
      sDimensions,
      '',
      '## Object Info: ' + sType + ' ' + sName,
      '',
      '## Local Code (Source):',
      '```' + sCodeFence,
      sLocalCode || '(empty — object does not exist on local system)',
      '```',
      '',
      '## Target Code (Destination):',
      '```' + sCodeFence,
      sTargetCode || '(empty — object does not exist on target system)',
      '```',
      '',
      '## Required Output Format (Valid JSON only, no markdown fences):',
      '{',
      '  "summary": "Comprehensive 3-5 sentence summary explaining exact code differences, additive/destructive nature, and change impact.",',
      '  "risks": [',
      '    "Detailed technical risk with system impact analysis"',
      '  ],',
      '  "notes": [',
      '    "Crucial transport precaution, pre-requisite TR, or post-import step (e.g. buffer clear, SICF activation, manual config, unit test execution)"',
      '  ],',
      '  "recommendation": "TRANSPORT" | "DO_NOT_TRANSPORT" | "REVIEW_REQUIRED",',
      '  "reason": "In-depth technical justification referencing SAP best practices and stability standards.",',
      '  "impact_level": "LOW" | "MEDIUM" | "HIGH" | "CRITICAL"',
      '}',
    ].join('\n')
  }

  // ─── CORE GEMINI CALL WITH KEY ROTATION & MODEL FALLBACK ───────────────────
  function _callGemini(sPrompt, vModel, iKeyRetry) {
    var iModelIdx = 0
    if (typeof vModel === 'number') {
      iModelIdx = vModel
    } else if (typeof vModel === 'string') {
      var foundIdx = GEMINI_MODELS.indexOf(vModel)
      iModelIdx = foundIdx > -1 ? foundIdx : 0
    }
    iKeyRetry = iKeyRetry || 0

    var iTotalAttempts = iModelIdx * API_KEYS.length + iKeyRetry
    var iMaxAttempts = GEMINI_MODELS.length * API_KEYS.length

    if (iTotalAttempts >= iMaxAttempts) {
      return Promise.reject(
        new Error('All authorized Gemini models and API keys exhausted. Please check your network/rate limits.')
      )
    }

    var sModel = GEMINI_MODELS[iModelIdx % GEMINI_MODELS.length]
    var sKey = _nextKey()
    var sUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/' +
      sModel +
      ':generateContent?key=' +
      encodeURIComponent(sKey)

    var oBody = {
      contents: [{ role: 'user', parts: [{ text: sPrompt }] }],
      generationConfig: {
        temperature: 0.2,
        maxOutputTokens: 8192,
        responseMimeType: 'application/json',
      },
    }

    return fetch(sUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(oBody),
    })
      .then(function (oRes) {
        if (!oRes.ok) {
          var iNextKeyRetry = iKeyRetry + 1
          var iNextModelIdx = iModelIdx
          if (iNextKeyRetry >= API_KEYS.length) {
            iNextKeyRetry = 0
            iNextModelIdx = (iModelIdx + 1) % GEMINI_MODELS.length
          }
          return _callGemini(sPrompt, iNextModelIdx, iNextKeyRetry)
        }
        return oRes.json()
      })
      .then(function (oJson) {
        return _normalizeAiResponse(oJson)
      })
  }

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
        // 5. Resilient fallback for partial or truncated JSON
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
        summary: sPartText || 'Gemini returned empty parts.',
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
      oRaw.risks
    ) {
      // Edge-case safeguard: if summary itself is a raw JSON string
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
              '). ZCL_SCORT_AI_ASSISTANT service is not active on this host.'
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
    /**
     * Helper: Audit naming convention and metadata consistency
     */
    auditMetadataAndNaming: auditMetadataAndNaming,

    /**
     * Action 1: Audit syntax, syntax errors, obsolete statements, and Clean ABAP.
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
      sMode = sMode || 'BE_SAP'
      sModel = sModel || 'gemini-3.5-flash'
      var pCall
      if (sMode === 'BE_SAP') {
        pCall = _callSapBackend(
          'SYNTAX',
          sObjectType,
          sObjectName,
          sLocalCode,
          sTargetCode,
          sUiLang,
          sModel
        ).catch(function (oErr) {
          var sPrompt = _buildSyntaxPrompt(
            sObjectType,
            sObjectName,
            sLocalCode,
            sTargetCode,
            sUiLang || 'en'
          )
          return _callGemini(sPrompt, sModel, 0)
        })
      } else {
        var sPrompt = _buildSyntaxPrompt(
          sObjectType,
          sObjectName,
          sLocalCode,
          sTargetCode,
          sUiLang || 'en'
        )
        pCall = _callGemini(sPrompt, sModel, 0)
      }

      return pCall.then(function (oResult) {
        if (oResult) {
          oResult.metadata_audit = oMetaAudit
        }
        return oResult
      })
    },

    /**
     * Action 2: Transport recommendation, risk analysis, and change summary.
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
      sMode = sMode || 'BE_SAP'
      sModel = sModel || 'gemini-3.5-flash'
      if (sMode === 'BE_SAP') {
        return _callSapBackend(
          'TRANSPORT',
          sObjectType,
          sObjectName,
          sLocalCode,
          sTargetCode,
          sUiLang,
          sModel
        ).catch(function (oErr) {
          var sPrompt = _buildTransportPrompt(
            sObjectType,
            sObjectName,
            sLocalCode,
            sTargetCode,
            sUiLang || 'en'
          )
          return _callGemini(sPrompt, sModel, 0)
        })
      }
      var sPrompt = _buildTransportPrompt(
        sObjectType,
        sObjectName,
        sLocalCode,
        sTargetCode,
        sUiLang || 'en'
      )
      return _callGemini(sPrompt, sModel, 0)
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
  }
})
