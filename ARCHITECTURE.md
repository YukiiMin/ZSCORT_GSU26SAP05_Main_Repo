# ARCHITECTURE.md — ZSCORT_GSU26_SAP05

## Tổng quan
**SCORT** — SAP Cross-system Object Replication Toolkit  
Kiến trúc: **SAP RAP (RESTful Application Programming Model)**, 3-Tier.

---

## 3-Tier Mapping ↔ Folder

| Tier SAP RAP | Folder dự án | Nội dung chính |
|---|---|---|
| Data Modeling & Behavior | `DB_CORE/` | CDS Entity, BDEF, ABAP Class (Behavior Pool, Query Provider, Helper, Utility) |
| Business Services Provisioning | `API/` | CDS Projection, BDEF Projection, Service Definition, Service Binding |
| Service Consumption | `FE_UI/` | SAP Fiori UI5 App (manifest.json, Component.js, Views, Controllers) |

---

## Cấu trúc Folder chi tiết

```
DB_CORE/
├── CDS/                        # CDS View Entities (Root & Normal)
├── BDEF-Behavior_Definition/   # Behavior Definitions (.bdef.asbdef)
├── DDIC-Data_Dictionary/       # Custom Tables, Data Elements, Table Types, Structures
└── LOGIC/                      # ABAP Classes: Behavior Pool, Query Provider, Helper, Utility

API/
├── PROJECTION_CDS/             # CDS Projection Views (ZCR_*, ZC_*)
├── PROJECTION_BDEF/            # BDEF Projections
├── SERVICE_DEFINITION/         # Service Definitions (SD_*)
└── SERVICE_BINDING/            # Service Bindings (UI_*_O4)

FE_UI/
└── (Fiori UI5 App structure)
```

---

## Naming Conventions (theo Convention.csv)

| Object Type | Prefix/Rule | Ví dụ |
|---|---|---|
| Root CDS Entity (DB layer) | `ZIR_` | `ZIR_SCORT_OBJ_L` |
| Normal/Child CDS Entity | `ZI_` | `ZI_SCORT_TR_OBJ_SEARCH` |
| Custom Entity (Query Provider) | `ZCR_` (Root) hoặc `ZCE_` | `ZCR_SCORT_OBJ_SRC`, `ZCE_SCORT_TR_TREE` |
| Abstract Entity | `ZI_` | `ZI_SCORT_TR_TREE_PARAM` |
| Root Projection View | `ZCR_` | `ZCR_SCORT_OBJ_L` |
| Normal/Child Projection View | `ZC_` | `ZC_SCORT_TR_TREE` |
| Behavior Definition (BDEF) | Trùng tên Root Entity | `ZIR_SCORT_OBJ_L` |
| Behavior Pool (ABAP Class) | `ZBP_IR_` | `ZBP_IR_SCORT_OBJ_L` |
| ABAP Class (Query Provider) | `ZCL_` | `ZCL_SCORT_R_SRC` |
| ABAP Class (Helper) | `ZCL_` | `ZCL_SCORT_L_READER` |
| ABAP Class (Utility) | `ZCL_` | `ZCL_SCORT_COMPRESSION_UTL` |
| Service Definition | `SD_` | `SD_SCORT_OBJ_SEARCH` |
| Service Binding (UI OData V4) | `UI_` + `_O4` | `UI_SCORT_OBJ_SEARCH_O4` |
| Custom Table | `ZA_` | `ZA_SCORT_T`, `ZA_SCORT_T_SRC` |
| Data Element | `ZDE_` | `ZDE_SCORT_NODE_ID` |

---

## Business Objects Registry — REQ1

### Tier 1: Data Modeling & Behavior (DB_CORE)

#### CDS Entities
| Object Name | Type | Source | Purpose |
|---|---|---|---|
| `ZIR_SCORT_OBJ_L` | Root View Entity | TADIR (pgmid='R3TR') | List objects on Local server |
| `ZIR_SCORT_OBJ_T` | Root View Entity | ZA_SCORT_T | List objects on Target (simulated) |
| `ZIR_SCORT_OBJ_M` | Root View Entity | TADIR LEFT JOIN ZA_SCORT_T | Compare matrix BOTH/LOCAL_ONLY/TARGET_ONLY |
| `ZCR_SCORT_OBJ_SRC` | Root Custom Entity | ZCL_SCORT_R_SRC | Read source code & metadata |
| `ZCE_SCORT_TR_TREE` | Root Custom Entity | ZCL_SCORT_TR_TREE_QUERY | TR hierarchy tree Lv0/1/2 |
| `ZI_SCORT_TR_TREE_PARAM` | Abstract Entity | — | Filter params for TR Tree |
| `ZI_SCORT_TR_OBJ_SEARCH` | Root View Entity | E071 + E070 | Flat list of objects in TR |

#### BDEF
| Object Name | For Entity | Behavior |
|---|---|---|
| `ZIR_SCORT_OBJ_L` | ZIR_SCORT_OBJ_L | lock master; read only |
| `ZIR_SCORT_OBJ_T` | ZIR_SCORT_OBJ_T | lock master; read only |
| `ZIR_SCORT_OBJ_M` | ZIR_SCORT_OBJ_M | read only + action checkDiff |
| `ZCE_SCORT_TR_TREE` | ZCE_SCORT_TR_TREE | read only |

#### ABAP Classes (LOGIC)
| Class Name | Type | Role |
|---|---|---|
| `ZCL_SCORT_R_SRC` | Query Provider | Gate: routes to L/T reader based on ServerType |
| `ZCL_SCORT_L_READER` | Helper | Reads source code from Local SAP APIs |
| `ZCL_SCORT_T_READER` | Helper | Reads compressed source from ZA_SCORT_T_SRC |
| `ZCL_SCORT_COMPRESSION_UTL` | Utility (Stateless) | GZIP encode/decode source code |
| `ZCL_SCORT_TR_TREE_QUERY` | Query Provider | Builds TR hierarchy tree from E070/E071/E07T |
| `ZBP_IR_SCORT_OBJ_L` | Behavior Pool (RAP auto-gen) | Empty CCIMP (read-only) |
| `ZBP_IR_SCORT_OBJ_T` | Behavior Pool (RAP auto-gen) | Empty CCIMP (read-only) |
| `ZBP_IR_SCORT_OBJ_M` | Behavior Pool | CCIMP: checkDiff action using CL_ABAP_DIFF |

#### DDIC
| Object Name | Type | Purpose |
|---|---|---|
| `ZA_SCORT_T` | Custom Table | Metadata of Target objects (simulated server) |
| `ZA_SCORT_T_SRC` | Custom Table | Compressed source code by version |
| `ZDE_SCORT_NODE_ID` | Data Element | CHAR40, unique tree node ID |
| `ZDE_SCORT_PARENT_NODE_ID` | Data Element | CHAR40, parent node reference |
| `ZDE_SCORT_TREE_LEVEL` | Data Element | INT1 (0/1/2) |
| `ZDE_SCORT_CURRENT_MANAGING_TR` | Data Element | TRKORR domain — computed field |

---

### Tier 2: Business Services Provisioning (API)

#### CDS Projections
| Object Name | Projects From | UI Purpose |
|---|---|---|
| `ZCR_SCORT_OBJ_L` | ZIR_SCORT_OBJ_L | Search/Filter Local objects — List Report |
| `ZCR_SCORT_OBJ_T` | ZIR_SCORT_OBJ_T | Search/Filter Target objects — List Report |
| `ZCR_SCORT_OBJ_M` | ZIR_SCORT_OBJ_M | Compare Matrix + checkDiff action |
| `ZC_SCORT_TR_TREE` | ZCE_SCORT_TR_TREE | Tree Table UI (Lv0→Lv1→Lv2) |
| `ZC_SCORT_TR_OBJ_SEARCH` | ZI_SCORT_TR_OBJ_SEARCH | Flat List Report for Object in TR |

#### BDEF Projections
| Object Name | Behavior |
|---|---|
| `ZCR_SCORT_OBJ_L` | use readonly |
| `ZCR_SCORT_OBJ_T` | use readonly |
| `ZCR_SCORT_OBJ_M` | use readonly; use action checkDiff |
| `ZC_SCORT_TR_TREE` | use readonly |
| `ZC_SCORT_TR_OBJ_SEARCH` | use readonly |

#### Service Definitions
| Object Name | Exposes |
|---|---|
| `SD_SCORT_OBJ_SEARCH` | ZCR_SCORT_OBJ_L, ZCR_SCORT_OBJ_T, ZCR_SCORT_OBJ_M, ZCR_SCORT_OBJ_SRC |
| `SD_SCORT_TR_SEARCH` | ZC_SCORT_TR_TREE, ZC_SCORT_TR_OBJ_SEARCH |

#### Service Bindings
| Object Name | Protocol | For |
|---|---|---|
| `UI_SCORT_OBJ_SEARCH_O4` | OData V4 – UI | Object search screens |
| `UI_SCORT_TR_SEARCH_O4` | OData V4 – UI | TR search screens |

---

## Key Technical Decisions
1. **ZIR_SCORT_OBJ_L** — 3 Keys: `PGMID`, `OBJECT`, `OBJ_NAME`; WHERE pgmid = 'R3TR' hardcoded.
2. **ZIR_SCORT_OBJ_M** — Uses `with parameters P_ServerType : abap.char(1)` ('L' or 'T').
3. **ZCR_SCORT_OBJ_SRC** — Custom Entity (not ZIR_); annotation `@ObjectModel.query.implementedBy: 'ZCL_SCORT_R_SRC'`.
4. **ZCE_SCORT_TR_TREE** — Custom Entity; annotation `@ObjectModel.query.implementedBy: 'ZCL_SCORT_TR_TREE_QUERY'`.
5. **ZCL_SCORT_COMPRESSION_UTL** — Stateless utility: `encode_source_to_hex` (GZIP compress) + `decode_hex_to_text` (GZIP decompress).
6. **ZBP_IR_SCORT_OBJ_M** — Only Behavior Pool with real logic; calls `CL_ABAP_DIFF` in `checkDiff` action.
7. **File format**: ABAPGit-style — each object has a code file + `.xml` metadata sidecar.
8. **Service naming**: `SD_SCORT_...` for definitions, `UI_SCORT_..._O4` for bindings.
