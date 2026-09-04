sap.ui.define([], function () {
  "use strict";

  return {
    /**
     * Parse DOMA DDL text into structured JSON model for ADT Form binding
     * @param {string} sDdlText
     * @returns {object}
     */
    parseDomain: function (sDdlText) {
      if (!sDdlText || typeof sDdlText !== "string") {
        return null;
      }

      var oData = {
        name: "",
        label: "",
        dataType: "",
        length: "",
        outputLength: "",
        conversionRoutine: "",
        caseSensitive: false,
        valueTable: "",
        fixedValues: []
      };

      // Header properties
      var mName = sDdlText.match(/define\s+domain\s+([a-zA-Z0-9_]+)/i);
      if (mName) {
        oData.name = mName[1].toUpperCase();
      }

      var mLabel = sDdlText.match(/@EndUserText\.label\s*:\s*'([^']*)'/i);
      if (mLabel) {
        oData.label = mLabel[1];
      }

      var mType = sDdlText.match(/@AbapCatalog\.domain\.dataType\s*:\s*#([a-zA-Z0-9_]+)/i);
      if (mType) {
        oData.dataType = mType[1];
      }

      var mLen = sDdlText.match(/@AbapCatalog\.domain\.length\s*:\s*(\d+)/i);
      if (mLen) {
        oData.length = mLen[1];
      }

      var mOutLen = sDdlText.match(/@AbapCatalog\.domain\.outputLength\s*:\s*(\d+)/i);
      if (mOutLen) {
        oData.outputLength = mOutLen[1];
      }

      var mConv = sDdlText.match(/@AbapCatalog\.domain\.conversionRoutine\s*:\s*'([^']*)'/i);
      if (mConv) {
        oData.conversionRoutine = mConv[1];
      }

      var mCase = sDdlText.match(/@AbapCatalog\.domain\.caseSensitive\s*:\s*(true|false)/i);
      if (mCase) {
        oData.caseSensitive = mCase[1].toLowerCase() === "true";
      }

      var mValTab = sDdlText.match(/@AbapCatalog\.domain\.valueTable\s*:\s*'([^']*)'/i);
      if (mValTab) {
        oData.valueTable = mValTab[1].toUpperCase();
      }

      // Fixed values inside braces { 'VAL' : 'Text', ... }
      var mBlock = sDdlText.match(/\{([\s\S]*?)\}/);
      if (mBlock && mBlock[1]) {
        var rVal = /'([^']+)'\s*:\s*'([^']*)'/g;
        var mItem;
        while ((mItem = rVal.exec(mBlock[1])) !== null) {
          oData.fixedValues.push({
            value: mItem[1],
            description: mItem[2]
          });
        }
      }

      return oData;
    },

    /**
     * Parse DTEL DDL text into structured JSON model for ADT Form binding
     * @param {string} sDdlText
     * @returns {object}
     */
    parseDataElement: function (sDdlText) {
      if (!sDdlText || typeof sDdlText !== "string") {
        return null;
      }

      var oData = {
        name: "",
        label: "",
        category: "Domain",
        typeName: "",
        dataType: "",
        length: "",
        decimals: "",
        fieldLabels: {
          short: { length: 10, text: "" },
          medium: { length: 20, text: "" },
          long: { length: 40, text: "" },
          heading: { length: 55, text: "" }
        },
        searchHelp: { name: "", parameter: "" },
        parameterId: "",
        changeDocumentLogging: false,
        inputHistory: false
      };

      var mName = sDdlText.match(/define\s+data\s+element\s+([a-zA-Z0-9_]+)/i);
      if (mName) {
        oData.name = mName[1].toUpperCase();
      }

      var mLabel = sDdlText.match(/@EndUserText\.label\s*:\s*'([^']*)'/i);
      if (mLabel) {
        oData.label = mLabel[1];
      }

      var mCat = sDdlText.match(/@AbapCatalog\.dataElement\.category\s*:\s*#([a-zA-Z0-9_]+)/i);
      if (mCat) {
        oData.category = mCat[1] === "PREDEFINED_TYPE" ? "Predefined Type" : "Domain";
      }

      var mTypeNam = sDdlText.match(/@AbapCatalog\.dataElement\.typeName\s*:\s*'([^']*)'/i);
      if (mTypeNam) {
        oData.typeName = mTypeNam[1].toUpperCase();
      }

      var mType = sDdlText.match(/@AbapCatalog\.dataElement\.dataType\s*:\s*#([a-zA-Z0-9_]+)/i);
      if (mType) {
        oData.dataType = mType[1];
      }

      var mLen = sDdlText.match(/@AbapCatalog\.dataElement\.length\s*:\s*(\d+)/i);
      if (mLen) {
        oData.length = mLen[1];
      }

      var mDec = sDdlText.match(/@AbapCatalog\.dataElement\.decimals\s*:\s*(\d+)/i);
      if (mDec) {
        oData.decimals = mDec[1];
      }

      // Field labels
      var mShort = sDdlText.match(/@AbapCatalog\.dataElement\.fieldLabel\.short\s*:\s*\{\s*length\s*:\s*(\d+)\s*,\s*text\s*:\s*'([^']*)'/i);
      if (mShort) {
        oData.fieldLabels.short = { length: parseInt(mShort[1], 10), text: mShort[2] };
      }

      var mMed = sDdlText.match(/@AbapCatalog\.dataElement\.fieldLabel\.medium\s*:\s*\{\s*length\s*:\s*(\d+)\s*,\s*text\s*:\s*'([^']*)'/i);
      if (mMed) {
        oData.fieldLabels.medium = { length: parseInt(mMed[1], 10), text: mMed[2] };
      }

      var mLong = sDdlText.match(/@AbapCatalog\.dataElement\.fieldLabel\.long\s*:\s*\{\s*length\s*:\s*(\d+)\s*,\s*text\s*:\s*'([^']*)'/i);
      if (mLong) {
        oData.fieldLabels.long = { length: parseInt(mLong[1], 10), text: mLong[2] };
      }

      var mHead = sDdlText.match(/@AbapCatalog\.dataElement\.fieldLabel\.heading\s*:\s*\{\s*length\s*:\s*(\d+)\s*,\s*text\s*:\s*'([^']*)'/i);
      if (mHead) {
        oData.fieldLabels.heading = { length: parseInt(mHead[1], 10), text: mHead[2] };
      }

      // Search help
      var mShlp = sDdlText.match(/@AbapCatalog\.dataElement\.searchHelp\s*:\s*\{\s*name\s*:\s*'([^']*)'\s*,\s*parameter\s*:\s*'([^']*)'/i);
      if (mShlp) {
        oData.searchHelp = { name: mShlp[1], parameter: mShlp[2] };
      }

      var mPid = sDdlText.match(/@AbapCatalog\.dataElement\.parameterId\s*:\s*'([^']*)'/i);
      if (mPid) {
        oData.parameterId = mPid[1];
      }

      var mLog = sDdlText.match(/@AbapCatalog\.dataElement\.changeDocumentLogging\s*:\s*(true|false)/i);
      if (mLog) {
        oData.changeDocumentLogging = mLog[1].toLowerCase() === "true";
      }

      var mHist = sDdlText.match(/@AbapCatalog\.dataElement\.inputHistory\s*:\s*(true|false)/i);
      if (mHist) {
        oData.inputHistory = mHist[1].toLowerCase() === "true";
      }

      return oData;
    },

    /**
     * Parse MSAG DDL text into structured JSON model for ADT Form binding
     * @param {string} sDdlText
     * @returns {object}
     */
    parseMessageClass: function (sDdlText) {
      if (!sDdlText || typeof sDdlText !== "string") {
        return null;
      }

      var oData = {
        name: "",
        label: "",
        masterLanguage: "",
        responsible: "",
        lastChanged: "",
        messages: []
      };

      var mName = sDdlText.match(/define\s+message\s+class\s+([a-zA-Z0-9_]+)/i);
      if (mName) {
        oData.name = mName[1].toUpperCase();
      }

      var mLabel = sDdlText.match(/@EndUserText\.label\s*:\s*'([^']*)'/i);
      if (mLabel) {
        oData.label = mLabel[1];
      }

      var mLang = sDdlText.match(/@AbapCatalog\.messageClass\.masterLanguage\s*:\s*'([^']*)'/i);
      if (mLang) {
        oData.masterLanguage = mLang[1];
      }

      var mResp = sDdlText.match(/@AbapCatalog\.messageClass\.responsible\s*:\s*'([^']*)'/i);
      if (mResp) {
        oData.responsible = mResp[1];
      }

      var mLastChanged = sDdlText.match(/@AbapCatalog\.messageClass\.lastChanged\s*:\s*'([^']*)'/i);
      if (mLastChanged) {
        var sRaw = mLastChanged[1];
        // T100A LASTUP is stored as YYYYMMDD — format to YYYY-MM-DD for display
        if (/^\d{8}$/.test(sRaw)) {
          oData.lastChanged = sRaw.slice(0, 4) + "-" + sRaw.slice(4, 6) + "-" + sRaw.slice(6, 8);
        } else {
          oData.lastChanged = sRaw;
        }
      }

      // Extract message entries: '001' : 'Text of message',
      var mBlock = sDdlText.match(/\{([\s\S]*?)\}/);
      if (mBlock && mBlock[1]) {
        var rMsg = /'(\d{3})'\s*:\s*'((?:[^']|'')*)'/g;
        var mItem;
        while ((mItem = rMsg.exec(mBlock[1])) !== null) {
          var sText = mItem[2].replace(/''/g, "'");
          oData.messages.push({
            number: mItem[1],
            text: sText,
            selfExpl: false,
            changedBy: oData.responsible || "",
            changedOn: oData.lastChanged || ""
          });
        }
      }

      return oData;
    },

    /**
     * Parse DEVC DDL text into structured JSON model for ADT Form binding
     * @param {string} sDdlText
     * @returns {object}
     */
    parsePackage: function (sDdlText) {
      if (!sDdlText || typeof sDdlText !== "string") {
        return null;
      }

      var oData = {
        name: "",
        label: "",
        softwareComponent: "",
        applicationComponent: "",
        transportLayer: "",
        superPackage: "",
        responsible: "",
        packageType: "Development",
        encapsulated: false,
        noObjectAddition: false,
        subpackages: [],
        hierarchy: []
      };

      var mName = sDdlText.match(/define\s+package\s+([a-zA-Z0-9_]+)/i);
      if (mName) {
        oData.name = mName[1].toUpperCase();
      }

      var mLabel = sDdlText.match(/@EndUserText\.label\s*:\s*'([^']*)'/i);
      if (mLabel) {
        oData.label = mLabel[1];
      }

      var mSwc = sDdlText.match(/@AbapCatalog\.package\.softwareComponent\s*:\s*'([^']*)'/i);
      if (mSwc) {
        oData.softwareComponent = mSwc[1];
      }

      var mAppComp = sDdlText.match(/@AbapCatalog\.package\.applicationComponent\s*:\s*'([^']*)'/i);
      if (mAppComp) {
        oData.applicationComponent = mAppComp[1];
      }

      var mTlayer = sDdlText.match(/@AbapCatalog\.package\.transportLayer\s*:\s*'([^']*)'/i);
      if (mTlayer) {
        oData.transportLayer = mTlayer[1];
      }

      var mSuper = sDdlText.match(/@AbapCatalog\.package\.superPackage\s*:\s*'([^']*)'/i);
      if (mSuper) {
        oData.superPackage = mSuper[1];
      }

      var mResp = sDdlText.match(/@AbapCatalog\.package\.responsible\s*:\s*'([^']*)'/i);
      if (mResp) {
        oData.responsible = mResp[1];
      }

      var mType = sDdlText.match(/@AbapCatalog\.package\.packageType\s*:\s*'([^']*)'/i);
      if (mType) {
        oData.packageType = mType[1];
      }

      var mEnc = sDdlText.match(/@AbapCatalog\.package\.encapsulated\s*:\s*'([^']*)'/i);
      if (mEnc) {
        oData.encapsulated = mEnc[1].toLowerCase() === "true";
      }

      var mNoAdd = sDdlText.match(/@AbapCatalog\.package\.noObjectAddition\s*:\s*'([^']*)'/i);
      if (mNoAdd) {
        oData.noObjectAddition = mNoAdd[1].toLowerCase() === "true";
      }

      // Subpackages: subpackage name : 'description';
      var rSub = /subpackage\s+([a-zA-Z0-9_]+)\s*:\s*'((?:[^']|'')*)';/gi;
      var mSub;
      while ((mSub = rSub.exec(sDdlText)) !== null) {
        oData.subpackages.push({
          name: mSub[1].toUpperCase(),
          description: mSub[2].replace(/''/g, "'")
        });
      }

      // Hierarchy: level N : name;
      var rHier = /level\s+(\d+)\s*:\s*([a-zA-Z0-9_]+);/gi;
      var mHier;
      while ((mHier = rHier.exec(sDdlText)) !== null) {
        var iLevel = parseInt(mHier[1], 10);
        var sPkgName = mHier[2].toUpperCase();
        var sRole = "";
        if (iLevel === 0) {
          sRole = "Superpackage";
        } else if (iLevel === 1) {
          sRole = "Current Package";
        } else {
          sRole = "Subpackage";
        }
        oData.hierarchy.push({
          level: iLevel,
          name: sPkgName,
          role: sRole,
          indent: iLevel * 20
        });
      }

      return oData;
    }
  };
});
