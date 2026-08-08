sap.ui.define([
  "sap/m/TableSelectDialog",
  "sap/m/Column",
  "sap/m/ColumnListItem",
  "sap/m/Label",
  "sap/m/Text",
  "sap/ui/model/json/JSONModel",
  "sap/ui/model/Filter",
  "sap/ui/model/FilterOperator",
  "sap/m/MessageToast"
], function (
  TableSelectDialog,
  Column,
  ColumnListItem,
  Label,
  Text,
  JSONModel,
  Filter,
  FilterOperator,
  MessageToast
) {
  "use strict";

  var STATIC = {
    "/VHCompareMode": [
      { CompareMode: "L_VS_T", Description: "REPO Target version vs Local Active" },
      { CompareMode: "VER_VS_VER", Description: "Local VRSD vs Local VRSD" },
      { CompareMode: "ACTIVE_VS_VER", Description: "Local Version vs Local Active" }
    ],
    "/VHCompareStatus": [
      { CompareStatus: "IDENTICAL", Description: "Hashes match" },
      { CompareStatus: "DIFFERENT", Description: "Hashes differ" },
      { CompareStatus: "NEW_AT_TARGET", Description: "No target snapshot" },
      { CompareStatus: "NOT_SUPPORTED", Description: "Type out of scope" },
      { CompareStatus: "SOURCE_MISSING", Description: "Active source missing" },
      { CompareStatus: "BAD_HEX", Description: "SOURCE_HEX corrupt" }
    ],
    "/VHServerId": [
      { ServerId: "TGT", Description: "Default Target server id" }
    ],
    "/VHServerType": [
      { ServerType: "L", Description: "Local / Origin" },
      { ServerType: "T", Description: "Target REPO (ZA026_SCORT_REPO)" }
    ]
  };

  function withTimeout(oPromise, iMs) {
    return Promise.race([
      oPromise,
      new Promise(function (_, reject) {
        setTimeout(function () {
          reject(new Error("Timeout after " + iMs + "ms"));
        }, iMs);
      })
    ]);
  }

  function filtersToOData(aFilters) {
    if (!aFilters || !aFilters.length) {
      return "";
    }
    return aFilters.map(function (oF) {
      var sPath = oF.sPath || oF.getPath && oF.getPath();
      var sOp = oF.sOperator || (oF.getOperator && oF.getOperator());
      var vVal = oF.oValue1 !== undefined ? oF.oValue1 : (oF.getValue1 && oF.getValue1());
      if (!sPath) { return ""; }
      var sEsc = String(vVal).replace(/'/g, "''");
      if (sOp === "EQ" || sOp === FilterOperator.EQ) {
        return sPath + " eq '" + sEsc + "'";
      }
      if (sOp === "StartsWith" || sOp === FilterOperator.StartsWith) {
        return "startswith(" + sPath + ",'" + sEsc + "')";
      }
      if (sOp === "EndsWith" || sOp === FilterOperator.EndsWith) {
        return "endswith(" + sPath + ",'" + sEsc + "')";
      }
      if (sOp === "Contains" || sOp === FilterOperator.Contains) {
        return "contains(" + sPath + ",'" + sEsc + "')";
      }
      return "";
    }).filter(Boolean).join(" and ");
  }

  function fetchJson(sUrl, iTimeoutMs) {
    var oFetch = fetch(sUrl, {
      method: "GET",
      credentials: "same-origin",
      headers: { Accept: "application/json" }
    }).then(function (oRes) {
      if (!oRes.ok) {
        throw new Error("HTTP " + oRes.status);
      }
      return oRes.json();
    }).then(function (oJson) {
      return (oJson && (oJson.value || (oJson.d && oJson.d.results))) || [];
    });
    return withTimeout(oFetch, iTimeoutMs || 12000);
  }

  function fetchAllJson(sUrl, iTimeoutMs) {
    var aAllData = [];
    function fetchNext(sNextUrl) {
      return fetch(sNextUrl, {
        method: "GET",
        credentials: "same-origin",
        headers: { Accept: "application/json" }
      }).then(function (oRes) {
        if (!oRes.ok) { throw new Error("HTTP " + oRes.status); }
        return oRes.json();
      }).then(function (oJson) {
        if (!oJson) { return aAllData; }
        var aData = oJson.value || (oJson.d && oJson.d.results) || [];
        aAllData = aAllData.concat(aData);
        var sNextLink = oJson["@odata.nextLink"] || (oJson.d && oJson.d.__next);
        if (sNextLink) {
          var sAbs = sNextLink;
          try { sAbs = new URL(sNextLink, sNextUrl).href; } catch (e) { /* ignore */ }
          return fetchNext(sAbs);
        }
        return aAllData;
      });
    }
    return withTimeout(fetchNext(sUrl), iTimeoutMs || 60000);
  }

  function loadRows(mOpts) {
    var sSet = mOpts.sEntitySet;
    if (STATIC[sSet] && !mOpts.bForceOData) {
      return Promise.resolve(STATIC[sSet].slice());
    }

    if (mOpts.sFetchUrl) {
      return fetchJson(mOpts.sFetchUrl, mOpts.iTimeoutMs || 12000);
    }

    if (mOpts.sServiceUri && sSet) {
      var sEntity = sSet.replace(/^\//, "");
      var sFilter = filtersToOData(mOpts.aFilters);
      var sUrl = mOpts.sServiceUri + sEntity +
        (sFilter ? ("?$filter=" + encodeURIComponent(sFilter)) : "");
      return fetchJson(sUrl, mOpts.iTimeoutMs || 12000);
    }

    var oModel = mOpts.oModel;
    if (!oModel || !oModel.bindList) {
      return Promise.resolve([]);
    }
    var oList = oModel.bindList(sSet, undefined, undefined, mOpts.aFilters || []);
    return withTimeout(oList.requestContexts(0, 200), mOpts.iTimeoutMs || 12000).then(function (aCtx) {
      return aCtx.map(function (c) {
        return c.getObject();
      });
    });
  }

  function open(mOpts) {
    var sKey = mOpts.sKey;
    var aCols = mOpts.aColumns || [{ key: sKey, label: sKey }];
    var oJson = new JSONModel({ rows: [] });

    var oDlg = new TableSelectDialog({
      title: mOpts.sTitle || "Select",
      multiSelect: false,
      growing: true,
      growingThreshold: 50,
      rememberSelections: false,
      resizable: true,
      draggable: true,
      columns: aCols.map(function (c) {
        return new Column({ header: new Label({ text: c.label }) });
      }),
      items: {
        path: "/rows",
        template: new ColumnListItem({
          type: "Active",
          cells: aCols.map(function (c) {
            return new Text({ text: "{" + c.key + "}" });
          })
        })
      },
      search: function (oEvent) {
        var sQ = oEvent.getParameter("value") || "";
        var oBinding = oDlg.getBinding("items");
        if (!oBinding) {
          return;
        }
        if (!sQ) {
          oBinding.filter([]);
          return;
        }
        oBinding.filter([
          new Filter({
            filters: aCols.map(function (c) {
              return new Filter(c.key, FilterOperator.Contains, sQ);
            }),
            and: false
          })
        ]);
      },
      confirm: function (oEvent) {
        var oItem = oEvent.getParameter("selectedItem");
        if (!oItem) {
          return;
        }
        var oCtx = oItem.getBindingContext();
        var sVal = oCtx.getProperty(sKey);
        var oRow = oCtx.getObject();
        if (sVal && typeof mOpts.fnConfirm === "function") {
          mOpts.fnConfirm(String(sVal), oRow);
        }
      },
      cancel: function () {
        oDlg.close();
      },
      afterClose: function () {
        oDlg.destroy();
      }
    });

    oDlg.setModel(oJson);
    oDlg.setBusy(true);
    oDlg.open();

    function applyRowMap(aRows) {
      var a = aRows || [];
      if (typeof mOpts.aRowsMap === "function") {
        return mOpts.aRowsMap(a) || [];
      }
      return a;
    }

    loadRows(mOpts).then(function (aRows) {
      oJson.setProperty("/rows", applyRowMap(aRows));
      oDlg.setBusy(false);
      if (!aRows || !aRows.length) {
        MessageToast.show("No data for " + mOpts.sEntitySet);
      }
    }).catch(function (oErr) {
      oDlg.setBusy(false);
      if (STATIC[mOpts.sEntitySet]) {
        oJson.setProperty("/rows", applyRowMap(STATIC[mOpts.sEntitySet].slice()));
        MessageToast.show("Local list (OData slow)");
      } else {
        // Version: fallback tối thiểu để thoát dialog
        if (mOpts.sEntitySet === "/Version") {
          oJson.setProperty("/rows", applyRowMap([
            { VersionNo: "00001", Message: "1" },
            { VersionNo: "00002", Message: "2" },
            { VersionNo: "99998", Message: "Active" }
          ]));
          MessageToast.show("Version offline fallback — " + (oErr.message || oErr));
        } else {
          oJson.setProperty("/rows", []);
          MessageToast.show("VH failed: " + (oErr.message || oErr));
        }
      }
    });

    return oDlg;
  }

  return {
    open: open,
    withTimeout: withTimeout,
    fetchJson: fetchJson,
    fetchAllJson: fetchAllJson,
    loadRows: loadRows,
    filtersToOData: filtersToOData
  };
});
