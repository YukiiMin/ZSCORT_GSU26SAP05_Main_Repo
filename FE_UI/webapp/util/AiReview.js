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
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-flash'
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
    'QUl6YVN5QjFzRjJRdGlTLVRSalFQVGxMdHVYMlc0RkkxQ3NObWYw'
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
    if (sLang === 'vi') return 'Tra loi HOAN TOAN bang tieng Viet.'
    if (sLang === 'ja') return 'すべて日本語で回答してください。'
    if (sLang === 'zh') return '请全部用中文回答。'
    if (sLang === 'de') return 'Antworte vollständig auf Deutsch.'
    return 'Reply strictly in English.'
  }

  // ─── PROMPT 1: SYNTAX & CODE QUALITY AUDIT ─────────────────────────────────
  function _buildSyntaxPrompt(sType, sName, sLocalCode, sTargetCode, sLang) {
    var sLangInstruct = _getLangInstruction(sLang)
    var bHasLocal = !!(sLocalCode && sLocalCode.trim() && sLocalCode !== '(empty)')
    var bHasTarget = !!(sTargetCode && sTargetCode.trim() && sTargetCode !== '(empty)')

    if (bHasLocal && bHasTarget) {
      return [
        'You are a Principal SAP ABAP Compiler and Senior Static Code Analysis Auditor. ' + sLangInstruct,
        '',
        '## Task: Dual-Side ABAP Syntax, Code Quality & Comparative Audit',
        'The object exists on BOTH Local (Active) and Target (Snapshot) systems.',
        'You MUST perform separate evaluations for Local Code AND Target Code, determine which side is better designed, and provide an expert best-practice synthesis to achieve optimal quality.',
        '',
        '## Focus Areas for Deep Audit:',
        '1. Syntax & Compilation: Invalid keywords, missing periods, unmatched control structures (ENDIF, ENDLOOP, ENDMETHOD).',
        '2. Obsolete Syntax: Detect obsolete constructs (CONCATENATE -> string templates |...|, MOVE TO, TABLES, FORM/PERFORM, OCCURS, RANGES).',
        '3. Clean ABAP Standards: Inline declarations (DATA/FINAL), constructor expressions (VALUE, COND, REDUCE), DRY principle, Single Responsibility, modern OOP.',
        '4. Performance & Reliability: SELECT in LOOP (N+1 queries), missing WHERE clauses, unchecked sy-subrc, unhandled exceptions.',
        '5. Comparative Quality: Assess which codebase (LOCAL vs TARGET) has higher quality, fewer violations, and better architecture.',
        '',
        '## Object Info: ' + sType + ' ' + sName,
        '',
        '## Local Code (Active Version):',
        '```abap',
        sLocalCode,
        '```',
        '',
        '## Target Code (Baseline Version):',
        '```abap',
        sTargetCode,
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
        '      "line_or_snippet": "Exact code line or statement",',
        '      "message": "Detailed explanation of the violation",',
        '      "suggestion": "Concrete refactored code replacement according to Clean ABAP"',
        '    }',
        '  ]',
        '}'
      ].join('\n')
    } else if (bHasLocal && !bHasTarget) {
      return [
        'You are a Principal SAP ABAP Compiler and Senior Static Code Analysis Auditor. ' + sLangInstruct,
        '',
        '## Task: Deep ABAP Syntax & Clean Code Quality Audit (Local New Object)',
        'This is a NEW object that exists ONLY on the LOCAL development system.',
        'Perform an exhaustive, audit-grade static analysis of the LOCAL code against SAP Clean ABAP guidelines and system stability.',
        '',
        '## Focus Areas for Deep Audit:',
        '1. Syntax & Compilation: Invalid keywords, missing periods, unmatched control structures.',
        '2. Obsolete Syntax: Detect obsolete constructs (CONCATENATE -> string templates |...|, MOVE TO, TABLES, FORM/PERFORM).',
        '3. Clean ABAP Standards: Inline declarations (DATA/FINAL), constructor expressions (VALUE, COND, REDUCE), DRY principle.',
        '4. Performance & Reliability: SELECT in LOOP, missing WHERE clauses, unchecked sy-subrc.',
        '',
        '## Object Info: ' + sType + ' ' + sName,
        '',
        '## Local Code (Active Version):',
        '```abap',
        sLocalCode || '(empty)',
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
        '      "line_or_snippet": "Exact code line or statement",',
        '      "message": "Detailed explanation of the violation",',
        '      "suggestion": "Concrete refactored code replacement according to Clean ABAP"',
        '    }',
        '  ]',
        '}'
      ].join('\n')
    } else {
      return [
        'You are a Principal SAP ABAP Compiler and Senior Static Code Analysis Auditor. ' + sLangInstruct,
        '',
        '## Task: Deep ABAP Syntax & Clean Code Quality Audit (Target Baseline Object)',
        'This object exists ONLY on the TARGET system (missing or deleted on Local).',
        'Perform an exhaustive static analysis of the TARGET code baseline against SAP Clean ABAP guidelines.',
        '',
        '## Focus Areas for Deep Audit:',
        '1. Syntax & Compilation: Invalid keywords, missing periods, unmatched control structures.',
        '2. Obsolete Syntax: Detect obsolete constructs (CONCATENATE -> string templates |...|, MOVE TO, TABLES).',
        '3. Clean ABAP Standards: Modern OOP, constructor expressions, DRY principle.',
        '',
        '## Object Info: ' + sType + ' ' + sName,
        '',
        '## Target Code (Baseline):',
        '```abap',
        sTargetCode || '(empty)',
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
        '      "line_or_snippet": "Exact code line or statement",',
        '      "message": "Detailed explanation of the violation",',
        '      "suggestion": "Concrete refactored code replacement according to Clean ABAP"',
        '    }',
        '  ]',
        '}'
      ].join('\n')
    }
  }

  // ─── PROMPT 2: TRANSPORT RECOMMENDATION & RISK ANALYSIS ────────────────────
  function _buildTransportPrompt(sType, sName, sLocalCode, sTargetCode, sLang) {
    var sLangInstruct = _getLangInstruction(sLang)
    return [
      'You are a Principal SAP Architect and Release Manager with 15+ years experience. ' + sLangInstruct,
      '',
      '## Task: Transport Recommendation & Comprehensive Risk Assessment',
      'Compare LOCAL vs TARGET code thoroughly to formulate an audit-grade Transport Decision for Apply to Target.',
      '',
      '## Evaluation Dimensions:',
      '1. Security & Compliance: AUTHORITY-CHECK before mutations, hardcoded credentials, SQL injection vulnerability.',
      '2. Concurrency & Locks: Proper enqueue/dequeue locks before UPDATE/MODIFY, deadlocks prevention.',
      '3. Interface & Dependency Breaking Changes: Public method signature alteration, parameter removal, incompatible type changes, missing dependent CDS/tables.',
      '4. Release Risk: Overall production risk classification and transport feasibility.',
      '5. Pre & Post-Import Precautions (Notes): Critical deployment notes, dependent TR sequences, manual SPRO configurations, cache/buffer resets, SICF activations, or regression testing steps.',
      '',
      '## Object Info: ' + sType + ' ' + sName,
      '',
      '## Local Code (Source):',
      '```abap',
      sLocalCode || '(empty — object does not exist on local system)',
      '```',
      '',
      '## Target Code (Destination):',
      '```abap',
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
      '}'
    ].join('\n')
  }

  // ─── CORE GEMINI CALL WITH KEY ROTATION & MODEL FALLBACK ───────────────────
  function _callGemini(sPrompt, iModelIdx, iKeyRetry) {
    iModelIdx = iModelIdx || 0
    iKeyRetry = iKeyRetry || 0

    if (iModelIdx >= GEMINI_MODELS.length) {
      iModelIdx = 0
    }

    var sModel = GEMINI_MODELS[iModelIdx]
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
        responseMimeType: 'application/json'
      }
    }

    return fetch(sUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(oBody)
    })
      .then(function (oRes) {
        if (!oRes.ok) {
          if (oRes.status === 403 || oRes.status === 429 || oRes.status === 503) {
            if (iKeyRetry < API_KEYS.length) {
              return _callGemini(sPrompt, iModelIdx, iKeyRetry + 1)
            }
          }
          if (oRes.status === 404) {
            if (iModelIdx + 1 < GEMINI_MODELS.length) {
              return _callGemini(sPrompt, iModelIdx + 1, iKeyRetry)
            }
          }
          return oRes.json().then(function (e) {
            throw new Error(
              'Gemini API error ' +
                oRes.status +
                ': ' +
                ((e.error && e.error.message) || 'unknown')
            )
          })
        }
        return oRes.json()
      })
      .then(function (oJson) {
        return _normalizeAiResponse(oJson);
      });
  }

  // ─── ROBUST JSON EXTRACTION & UNWRAPPING ──────────────────────────────────
  function _extractFieldsFromPartialJson(sText) {
    if (!sText || typeof sText !== 'string') return null;
    var oResult = {};

    var mMode = sText.match(/"mode"\s*:\s*"([^"]+)"/i);
    if (mMode) oResult.mode = mMode[1];

    var mStatus = sText.match(/"syntax_status"\s*:\s*"([^"]+)"/i);
    if (mStatus) oResult.syntax_status = mStatus[1];

    var mScore = sText.match(/"syntax_score"\s*:\s*"([^"]+)"/i);
    if (mScore) oResult.syntax_score = mScore[1];

    var mTargetScore = sText.match(/"target_score"\s*:\s*"([^"]+)"/i);
    if (mTargetScore) oResult.target_score = mTargetScore[1];

    var mVerdict = sText.match(/"clean_abap_verdict"\s*:\s*"([^"]+)"/i);
    if (mVerdict) oResult.clean_abap_verdict = mVerdict[1];

    var mBetterSide = sText.match(/"better_side"\s*:\s*"([^"]+)"/i);
    if (mBetterSide) oResult.better_side = mBetterSide[1];

    var mBetterReason = sText.match(/"better_side_reason"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"/i);
    if (mBetterReason) oResult.better_side_reason = mBetterReason[1].replace(/\\"/g, '"');

    var mBestRec = sText.match(/"best_version_recommendation"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"/i);
    if (mBestRec) oResult.best_version_recommendation = mBestRec[1].replace(/\\"/g, '"');

    var mRec = sText.match(/"recommendation"\s*:\s*"([^"]+)"/i);
    if (mRec) oResult.recommendation = mRec[1];

    var mImpact = sText.match(/"impact_level"\s*:\s*"([^"]+)"/i);
    if (mImpact) oResult.impact_level = mImpact[1];

    var mReason = sText.match(/"reason"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"/i);
    if (mReason) oResult.reason = mReason[1].replace(/\\"/g, '"');

    var mSummary = sText.match(/"summary"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"/i);
    if (mSummary) {
      oResult.summary = mSummary[1].replace(/\\"/g, '"');
    } else {
      var mPartialSummary = sText.match(/"summary"\s*:\s*"([^"\\]*)$/i);
      if (mPartialSummary) {
        oResult.summary = mPartialSummary[1].trim();
      }
    }

    if (Object.keys(oResult).length > 0) {
      if (!oResult.findings) oResult.findings = [];
      if (!oResult.risks) oResult.risks = [];
      if (!oResult.notes) oResult.notes = [];
      return oResult;
    }
    return null;
  }

  function _extractJsonFromText(sText) {
    if (!sText || typeof sText !== 'string') {
      return null;
    }
    var sClean = sText.trim();

    // 1. Strip markdown code block wrappers
    sClean = sClean.replace(/^```[a-zA-Z]*\r?\n?/m, '').replace(/\r?\n?```\s*$/m, '').trim();

    // 2. Locate first '{' and last '}'
    var iFirst = sClean.indexOf('{');
    var iLast = sClean.lastIndexOf('}');
    if (iFirst > -1 && iLast > iFirst) {
      sClean = sClean.substring(iFirst, iLast + 1).trim();
    }

    // 3. First parse attempt
    try {
      return JSON.parse(sClean);
    } catch (e1) {
      // 4. Try sanitizing unescaped control chars if any
      try {
        var sSanitized = sClean
          .replace(/[\u0000-\u001F\u007F-\u009F]/g, function (c) {
            if (c === '\n') return '\\n';
            if (c === '\r') return '\\r';
            if (c === '\t') return '\\t';
            return '';
          });
        return JSON.parse(sSanitized);
      } catch (e2) {
        // 5. Resilient fallback for partial or truncated JSON
        return _extractFieldsFromPartialJson(sText);
      }
    }
  }

  function _normalizeAiResponse(oRaw) {
    if (!oRaw) {
      return { summary: 'No response received.' };
    }

    // A. If oRaw is a String
    if (typeof oRaw === 'string') {
      var oFromStr = _extractJsonFromText(oRaw);
      if (oFromStr) return _normalizeAiResponse(oFromStr);
      return { summary: oRaw, recommendation: 'REVIEW_REQUIRED', syntax_status: 'WARNING' };
    }

    // B. If oRaw is a Gemini API wrapper: { candidates: [ { content: { parts: [ { text: "..." } ] } } ] }
    if (oRaw.candidates && oRaw.candidates[0] && oRaw.candidates[0].content && oRaw.candidates[0].content.parts) {
      var sPartText = oRaw.candidates[0].content.parts[0].text;
      var oFromGemini = _extractJsonFromText(sPartText);
      if (oFromGemini) return _normalizeAiResponse(oFromGemini);
      return { summary: sPartText || 'Gemini returned empty parts.', recommendation: 'REVIEW_REQUIRED', syntax_status: 'WARNING' };
    }

    // C. If oRaw is already a structured payload object
    if (oRaw.syntax_status || oRaw.recommendation || oRaw.syntax_score || oRaw.findings || oRaw.risks) {
      // Edge-case safeguard: if summary itself is a raw JSON string
      if (typeof oRaw.summary === 'string' && oRaw.summary.trim().charAt(0) === '{') {
        var oNested = _extractJsonFromText(oRaw.summary);
        if (oNested && (oNested.syntax_status || oNested.recommendation || oNested.summary)) {
          return oNested;
        }
      }
      return oRaw;
    }

    // D. If oRaw has error message
    if (oRaw.error) {
      return {
        summary: typeof oRaw.error === 'string' ? oRaw.error : (oRaw.error.message || JSON.stringify(oRaw.error)),
        recommendation: 'REVIEW_REQUIRED',
        syntax_status: 'ERROR'
      };
    }

    return oRaw;
  }

  // ─── BACKEND SAP CALL (/sap/bc/zscort_ai) ─────────────────────────────────
  function _callSapBackend(sAction, sType, sName, sLocalCode, sTargetCode, sLang) {
    var sUrl = '/sap/bc/zscort_ai';
    var oPayload = {
      action: sAction,
      objectType: sType,
      objectName: sName,
      localCode: sLocalCode || '',
      targetCode: sTargetCode || '',
      language: sLang || 'en'
    };

    return fetch(sUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(oPayload)
    })
      .then(function (oRes) {
        if (!oRes.ok) {
          throw new Error('SAP Backend HTTP ' + oRes.status + ' (' + oRes.statusText + '). ZCL_SCORT_AI_ASSISTANT service is not active on this host.');
        }
        return oRes.json();
      })
      .then(function (oJson) {
        return _normalizeAiResponse(oJson);
      });
  }

  // ─── PUBLIC API ──────────────────────────────────────────────────────────
  return {
    /**
     * Action 1: Audit syntax, syntax errors, obsolete statements, and Clean ABAP.
     */
    checkSyntaxAndQuality: function (
      sObjectType,
      sObjectName,
      sLocalCode,
      sTargetCode,
      sUiLang,
      sMode
    ) {
      if (sMode === 'BE_SAP') {
        return _callSapBackend(
          'SYNTAX',
          sObjectType,
          sObjectName,
          sLocalCode,
          sTargetCode,
          sUiLang
        )
      }
      var sPrompt = _buildSyntaxPrompt(
        sObjectType,
        sObjectName,
        sLocalCode,
        sTargetCode,
        sUiLang || 'en'
      )
      return _callGemini(sPrompt, 0, 0)
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
      sMode
    ) {
      if (sMode === 'BE_SAP') {
        return _callSapBackend(
          'TRANSPORT',
          sObjectType,
          sObjectName,
          sLocalCode,
          sTargetCode,
          sUiLang
        )
      }
      var sPrompt = _buildTransportPrompt(
        sObjectType,
        sObjectName,
        sLocalCode,
        sTargetCode,
        sUiLang || 'en'
      )
      return _callGemini(sPrompt, 0, 0)
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
    }
  }
})
