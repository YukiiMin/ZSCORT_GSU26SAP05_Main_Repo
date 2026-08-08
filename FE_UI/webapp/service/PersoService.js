sap.ui.define(['sap/ui/thirdparty/jquery'],
	function(jQuery) {
	"use strict";

	var PersoService = {

		oData : {
			_persoSchemaVersion: "1.0",
			aColumns : []
		},

		getPersData : function () {
			var oDeferred = new jQuery.Deferred();
			if (!this._oBundle) {
				this._oBundle = this.oData;
			}
			var oBundle = this._oBundle;
			oDeferred.resolve(oBundle);
			return oDeferred.promise();
		},

		setPersData : function (oBundle) {
			var oDeferred = new jQuery.Deferred();
			this._oBundle = oBundle;
			oDeferred.resolve();
			return oDeferred.promise();
		},

		resetPersData : function () {
			var oDeferred = new jQuery.Deferred();
			this._oBundle = {
				_persoSchemaVersion: "1.0",
				aColumns : []
			};
			oDeferred.resolve();
			return oDeferred.promise();
		},

		getCaption : function (oColumn) {
			if (oColumn.getHeader() && oColumn.getHeader().getText) {
				if (oColumn.getHeader().getText() === "Actions") {
					return "Actions";
				}
			}
			return null;
		},

		getGroup : function(oColumn) {
			if( oColumn.getId().indexOf('productCol') != -1 ||
				oColumn.getId().indexOf('supplierCol') != -1) {
				return "Primary Group";
			}
			return "Secondary Group";
		}
	};

	return PersoService;

});
