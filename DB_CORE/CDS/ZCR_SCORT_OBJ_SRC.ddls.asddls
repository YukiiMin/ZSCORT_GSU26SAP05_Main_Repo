@EndUserText.label: 'SCORT: View Object Source Code & Metadata'
@ObjectModel.query.implementedBy: 'ZCL_SCORT_R_SRC'
@AccessControl.authorizationCheck: #NOT_REQUIRED
/*
  Custom Entity — Query Provider Pattern.
  ZCL_SCORT_R_SRC implements IF_RAP_QUERY_PROVIDER.
  Branches on ServerType:
    'L' → ZCL_SCORT_L_READER (reads from SAP native APIs)
    'T' → ZCL_SCORT_T_READER (reads compressed source from ZA_SCORT_T_SRC)
*/
define custom entity ZCR_SCORT_OBJ_SRC
{
  @EndUserText.label: 'Server Type (L=Local, T=Target)'
  key ServerType       : abap.char(1);

  @EndUserText.label: 'Object Type'
  key ObjectType       : tadir-object;

  @EndUserText.label: 'Object Name'
  key ObjectName       : tadir-obj_name;

  @EndUserText.label: 'Source Code (full text, newline-separated)'
  SourceCodeText       : abap.string(0);

  @EndUserText.label: 'Metadata (JSON string)'
  MetadataText         : abap.string(0);

  @EndUserText.label: 'Package'
  PackageName          : tadir-devclass;

  @EndUserText.label: 'Author / Person Responsible'
  Author               : tadir-author;

  @EndUserText.label: 'Description / Short Text'
  Description          : abap.char(80);
}
