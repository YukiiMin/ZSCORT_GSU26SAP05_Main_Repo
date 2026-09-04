sap.ui.define([
  "sap/m/StandardListItem"
], function (StandardListItem) {
  "use strict";

  return {
    render: function (oScope, oResult, oI18n) {
      if (!oResult) return;
      var byId = typeof oScope === "function" ? oScope : function (sId) {
        return oScope.byId ? oScope.byId(sId) : null;
      };

      var oLoading = byId("idSideAiLoading");
      if (oLoading) oLoading.setVisible(false);

      var oError = byId("idSideAiError");
      if (oError) oError.setVisible(false);

      var oResultBox = byId("idSideAiResultBox");
      if (oResultBox) oResultBox.setVisible(true);

      // 1. Metadata Audit
      var oMeta = oResult.metadata_audit || {};
      var oMetaStatus = byId("idSideMetaStatus");
      if (oMetaStatus) {
        var sMetaState = oMeta.status === "COMPLIANT" ? "Success" : "Warning";
        oMetaStatus.setState(sMetaState);
        oMetaStatus.setText(oMeta.status || "COMPLIANT");
      }
      var oMetaScore = byId("idSideMetaScore");
      if (oMetaScore) {
        oMetaScore.setText("Naming: " + (oMeta.score || "100/100"));
      }
      var oMetaList = byId("idSideMetaIssuesList");
      if (oMetaList) {
        oMetaList.destroyItems();
        var aIssues = oMeta.issues || [];
        var aDiffs = oMeta.diffs || [];
        if (aIssues.length === 0 && aDiffs.length === 0) {
          oMetaList.addItem(new StandardListItem({
            title: oI18n.getText("aiNamingCompliant") || "Object naming & package conventions are 100% compliant.",
            icon: "sap-icon://sys-enter-2",
            wrapping: true
          }));
        } else {
          aIssues.forEach(function (iss) {
            oMetaList.addItem(new StandardListItem({
              title: "[" + (iss.category || "NAMING") + "] " + iss.message,
              icon: "sap-icon://alert",
              wrapping: true
            }));
          });
          aDiffs.forEach(function (diff) {
            oMetaList.addItem(new StandardListItem({
              title: "[DIFF] " + diff,
              icon: "sap-icon://compare",
              wrapping: true
            }));
          });
        }
      }

      // 2. Syntax Status & Scores
      var mStatusState = { PASSED: "Success", WARNING: "Warning", ERROR: "Error" };
      var mStatusIcon  = { PASSED: "✅", WARNING: "⚠️", ERROR: "🔴" };
      var sStatus = (oResult.syntax_status || "WARNING").toUpperCase();
      var oSyntaxStatus = byId("idSideSyntaxStatus");
      if (oSyntaxStatus) {
        oSyntaxStatus.setState(mStatusState[sStatus] || "Warning");
        oSyntaxStatus.setText((mStatusIcon[sStatus] || "") + " " + (oI18n.getText("aiSyntax_" + sStatus) || sStatus));
      }

      var sScoreText = "Score: " + (oResult.syntax_score || "N/A");
      if (oResult.mode === "DUAL" && oResult.target_score) {
        sScoreText = "Local: " + oResult.syntax_score + " | Target: " + oResult.target_score;
      }
      var oSyntaxScore = byId("idSideSyntaxScore");
      if (oSyntaxScore) oSyntaxScore.setText(sScoreText);

      var sVerdict = oResult.clean_abap_verdict || "Compliant";
      var oVerdictCtrl = byId("idSideCleanVerdict");
      if (oVerdictCtrl) {
        oVerdictCtrl.setText("Clean ABAP: " + sVerdict);
        oVerdictCtrl.setState(sVerdict.indexOf("Compliant") > -1 ? "Success" : "Warning");
      }

      // 3. Better Side & Comparison
      var oBetterSideCtrl = byId("idSideBetterSide");
      var oCompBox = byId("idSideComparisonBox");
      var sBetterSide = (oResult.better_side || "").toUpperCase();
      if (sBetterSide && oBetterSideCtrl) {
        var mBetterText = {
          LOCAL: "🏆 Local is Better",
          TARGET: "🏆 Target is Better",
          EQUIVALENT: "⚖️ Equivalent Quality"
        };
        oBetterSideCtrl.setText(mBetterText[sBetterSide] || ("Better: " + sBetterSide));
        oBetterSideCtrl.setVisible(true);

        if (oResult.better_side_reason || oResult.best_version_recommendation) {
          if (byId("idSideBetterReason")) byId("idSideBetterReason").setText("⚖️ " + (oResult.better_side_reason || ""));
          if (byId("idSideBestRecommendation")) byId("idSideBestRecommendation").setText("💡 " + (oResult.best_version_recommendation || ""));
          if (oCompBox) oCompBox.setVisible(true);
        }
      } else {
        if (oBetterSideCtrl) oBetterSideCtrl.setVisible(false);
        if (oCompBox) oCompBox.setVisible(false);
      }

      // 4. Summary
      var oSummary = byId("idSideSummaryText");
      if (oSummary) oSummary.setText(oResult.summary || "—");

      // 5. Findings List
      var oFindingsList = byId("idSideFindingsList");
      if (oFindingsList) {
        oFindingsList.destroyItems();
        var aFindings = oResult.findings || [];
        if (aFindings.length > 0) {
          aFindings.forEach(function (f) {
            if (typeof f === "string") {
              oFindingsList.addItem(new StandardListItem({ title: f, icon: "sap-icon://hint", wrapping: true }));
              return;
            }
            var sIcon = f.type === "SYNTAX_ERROR" ? "sap-icon://error" : (f.type === "WARNING" ? "sap-icon://alert" : "sap-icon://hint");
            var sSide = f.side ? "[" + f.side.toUpperCase() + "] " : "";
            var sLineNum = f.line_number ? "[Line " + f.line_number + "] " : "";
            var sRawSnippet = (f.line_or_snippet || "").trim();
            
            var sLoc = "";
            if (sRawSnippet) {
              if (sRawSnippet.indexOf("Line") === 0 || sRawSnippet.indexOf("Dòng") === 0 || sRawSnippet.indexOf("[Line") === 0 || sRawSnippet.indexOf("[Dòng") === 0) {
                sLoc = (sRawSnippet.indexOf("[") === 0 ? sRawSnippet : "[" + sRawSnippet + "]") + " ";
              } else {
                sLoc = (sLineNum || "") + "[" + sRawSnippet.replace(/^\[|\]$/g, "") + "] ";
              }
            } else if (sLineNum) {
              sLoc = sLineNum;
            }

            var sTitle = sSide + sLoc + (f.message || "");
            var sSugPrefix = (oI18n && oI18n.getText("aiSuggestionPrefix")) || "💡 Cách sửa / Gợi ý Clean ABAP: ";
            var sDesc = f.suggestion ? sSugPrefix + f.suggestion : "";
            oFindingsList.addItem(new StandardListItem({
              title: sTitle,
              description: sDesc,
              icon: sIcon,
              wrapping: true
            }));
          });
        }
      }
    }
  };
});
