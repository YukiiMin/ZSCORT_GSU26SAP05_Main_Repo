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
| `ZIR_SCORT_OBJ_L` | Root View Entity | TADIR (pgmid='R3TR') + ENLFDIR | List objects on Local server (supports R3TR and LIMU FUNC) |
| `ZIR_SCORT_OBJ_T` | Root View Entity | ZA_SCORT_T | List objects on Target (simulated) |
| `ZCE_SCORT_MATRIX` | Root Custom Entity | ZCL_SCORT_MATRIX_QUERY | Compare matrix BOTH/LOCAL_ONLY/TARGET_ONLY (Replaces legacy ZIR_SCORT_OBJ_M) |
| `ZCR_SCORT_OBJ_SRC` | Root Custom Entity | ZCL_SCORT_R_SRC | Read source code & metadata |
| `ZCE_SCORT_TR_TREE` | Root Custom Entity | ZCL_SCORT_TR_TREE_QUERY | TR hierarchy tree Lv0/1/2 |
| `ZI_SCORT_TR_TREE_PARAM` | Abstract Entity | — | Filter params for TR Tree |
| `ZI_SCORT_TR_OBJ_SEARCH` | Root View Entity | E071 + E070 | Flat list of objects in TR |

#### BDEF
| Object Name | For Entity | Behavior |
|---|---|---|
| `ZIR_SCORT_OBJ_L` | ZIR_SCORT_OBJ_L | lock master; read only |
| `ZIR_SCORT_OBJ_T` | ZIR_SCORT_OBJ_T | lock master; read only |
| `ZCE_SCORT_TR_TREE` | ZCE_SCORT_TR_TREE | read only |

#### ABAP Classes (LOGIC)
| Class Name | Type | Role |
|---|---|---|
| `ZCL_SCORT_R_SRC` | Query Provider | Gate: routes to L/T reader based on ServerType |
| `ZCL_SCORT_L_READER` | Helper | Reads source code from Local SAP APIs |
| `ZCL_SCORT_T_READER` | Helper | Reads compressed source from ZA_SCORT_T_SRC |
| `ZCL_SCORT_COMPRESSION_UTL` | Utility (Stateless) | GZIP encode/decode source code |
| `ZCL_SCORT_MATRIX_QUERY` | Query Provider | 3-key Merge-Sort (PGMID, OBJECTTYPE, OBJECTNAME), SQL push-down filtering, dynamic UI5 sorting, and paging for ZCE_SCORT_MATRIX |
| `ZCL_SCORT_TR_TREE_QUERY` | Query Provider | Builds TR hierarchy tree from E070/E071/E07T |
| `ZCL_SCORT_AI_ASSISTANT` | Utility / AI Service | Dual-action AI Assistant: Syntax audit + Transport recommendation (Gemini Key Rotation & SAP AI Core BTP Destination adapter) |
| `ZCL_SCORT_AI_HTTP_HANDLER` | ICF HTTP Handler | REST Endpoint handler for /sap/bc/zscort_ai |
| `ZCL026_SCORT_RELEASE_SERVICE` | Business Service | Direct TR release service (TR_RELEASE_REQUEST) using ZCM_SCORT messages |
| `ZCL026_SCORT_TARGET_APPLY` | Business Service | Target apply snapshot & GZIP compression using ZCM_SCORT messages |
| `ZCM_SCORT` | RAP Message Class (CLAS) | Official SAP RAP Message Class (IF_T100_MESSAGE, IF_ABAP_BEHV_MESSAGE) used across 8 classes |
| `ZBP_IR_SCORT_OBJ_L` | Behavior Pool | CCIMP: read Local source via ZCL_SCORT_L_READER with ZCM_SCORT error handling |
| `ZBP_IR_SCORT_OBJ_T` | Behavior Pool | CCIMP: read Target source via ZCL_SCORT_T_READER with ZCM_SCORT error handling |

#### Texts (Message Classes)
| Object Name | Type | Purpose |
|---|---|---|
| `ZCM_SCORT` | Message Class (T100 - MSAG) | Multi-language translatable messages for Release, Apply, Diff & AI |

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
| `ZC_SCORT_TR_TREE` | ZCE_SCORT_TR_TREE | Tree Table UI (Lv0→Lv1→Lv2) |
| `ZC_SCORT_TR_OBJ_SEARCH` | ZI_SCORT_TR_OBJ_SEARCH | Flat List Report for Object in TR |

#### BDEF Projections
| Object Name | Behavior |
|---|---|
| `ZCR_SCORT_OBJ_L` | use readonly |
| `ZCR_SCORT_OBJ_T` | use readonly |
| `ZC_SCORT_TR_TREE` | use readonly |
| `ZC_SCORT_TR_OBJ_SEARCH` | use readonly |

#### Service Definitions
| Object Name | Exposes |
|---|---|
| `ZSD_SCORT_OBJ_SEARCH` | ZCR_SCORT_OBJ_L, ZCR_SCORT_OBJ_T, ZCE_SCORT_MATRIX (CompareMatrix), ZCR_SCORT_OBJ_SRC (SourceCodeView), Value Help views |
| `SD_SCORT_TR_SEARCH` | ZC_SCORT_TR_TREE, ZC_SCORT_TR_OBJ_SEARCH |

#### Service Bindings
| Object Name | Protocol | For |
|---|---|---|
| `UI_SCORT_OBJ_SEARCH_O4` | OData V4 – UI | Object search screens |
| `UI_SCORT_TR_SEARCH_O4` | OData V4 – UI | TR search screens |

---

## Key Technical Decisions
1. **ZIR_SCORT_OBJ_L** — 3 Keys: `PGMID`, `OBJECT`, `OBJ_NAME`. Tích hợp `UNION ALL` với `ENLFDIR` để hỗ trợ cả `R3TR` (TADIR) và `LIMU FUNC` (Function Modules).
2. **ZCE_SCORT_MATRIX & ZCL_SCORT_MATRIX_QUERY** — Custom Entity thay thế cho `ZIR_SCORT_OBJ_M`. Loại bỏ hoàn toàn lỗi SADL Dump (`CX_SADL_DUMP_APPL_MODEL_ERROR`) trên `UNION ALL` có tham số, hỗ trợ thuật toán Merge-Sort 3 trục (`PGMID -> OBJECTTYPE -> OBJECTNAME`), đẩy bộ lọc xuống database (SQL Push-down) và hỗ trợ sort động trên header UI5.
3. **ZCR_SCORT_OBJ_SRC** — Custom Entity; annotation `@ObjectModel.query.implementedBy: 'ABAP:ZCL_SCORT_R_SRC'`.
4. **ZCE_SCORT_TR_TREE** — Custom Entity; annotation `@ObjectModel.query.implementedBy: 'ABAP:ZCL_SCORT_TR_TREE_QUERY'`.
5. **ZCL_SCORT_COMPRESSION_UTL** — Stateless utility: `encode_source_to_hex` (GZIP compress) + `decode_hex_to_text` (GZIP decompress).
6. **Code Diff & AI Review Architecture** — Thay thế các RAP Action cũ (`checkDiff`, `aiReview`) bằng Monaco Diff Editor trực tiếp trên UI5 và dịch vụ AI độc lập qua REST SICF Endpoint `/sap/bc/zscort_ai` (`ZCL_SCORT_AI_HTTP_HANDLER` -> `ZCL_SCORT_AI_ASSISTANT`) kèm failover trực tiếp tới Gemini API.
7. **File format**: ABAPGit-style — mỗi object có 1 file code + file `.xml` metadata sidecar.
8. **Service naming**: `ZSD_SCORT_...` cho definitions, `UI_SCORT_..._O4` cho bindings.

---

## Lịch sử kiến trúc & Lý do loại bỏ ZIR_SCORT_OBJ_M (Legacy Matrix)

Nhóm đối tượng `ZIR_SCORT_OBJ_M` (bao gồm CDS View Entity, BDEF, Behavior Pool `ZBP_IR_SCORT_OBJ_M` và Projection `ZCR_SCORT_OBJ_M`) đã chính thức bị **LOẠI BỎ KHỎI HỆ THỐNG** vì các lý do kỹ thuật sau:

1. **Lỗi SADL Engine Runtime Dump (`CX_SADL_DUMP_APPL_MODEL_ERROR`):**
   - Ban đầu, `ZIR_SCORT_OBJ_M` được xây dựng bằng CDS View Entity với mệnh đề `UNION ALL` kết hợp parameter (`with parameters P_ServerType : abap.char(1)`).
   - Khi expose qua OData V4, SADL Engine của SAP không thể phân tích cây biểu thức SQL (SQL Expression Tree) đối với các trường tính toán (`case when ... end as ExistenceStatus`) và các hàm lọc chuỗi OData (`startswith`, `contains`, v.v.). Điều này dẫn đến `HTTP 500 / RAISE_SHORTDUMP` ngay khi người dùng lọc dữ liệu.

2. **Chuyển đổi sang RAP Custom Entity (`ZCE_SCORT_MATRIX`):**
   - Thay vì ép SADL xử lý `UNION ALL` phức tạp ở database layer, hệ thống áp dụng kiến trúc chuẩn của SAP RAP cho các trường hợp đối soát dữ liệu đa nguồn: **Custom Entity + Query Provider** (`ZCL_SCORT_MATRIX_QUERY`).
   - Query Provider thực hiện đọc dữ liệu tối thiểu qua SQL Push-down filter, sau đó thực thi thuật toán Merge-Sort 3 trục (`PGMID -> OBJECTTYPE -> OBJECTNAME`) trong bộ nhớ với độ phức tạp $O(N + M)$, loại bỏ 100% rủi ro SADL dump.

3. **Hiện đại hóa Diff & AI Review:**
   - Các action cũ `checkDiff` và `aiReview` trong `ZBP_IR_SCORT_OBJ_M` trước đây yêu cầu gọi qua RAP Action OData V4 với cấu trúc trả lời hạn chế.
   - Kiến trúc mới tách bạch: Diff mã nguồn được hiển thị trực tiếp qua Monaco Diff Editor trên trình duyệt, còn AI Review được phục vụ qua REST Handler `/sap/bc/zscort_ai` với khả năng xoay tua key, đa ngôn ngữ (`sy-langu`) và linh hoạt chọn mô hình AI.

4. **Danh sách các artifact đã xóa dọn dẹp:**
   - `DB_CORE/CDS/ZIR_SCORT_OBJ_M.ddls.asddls` & `.ddls.xml`
   - `DB_CORE/BDEF-Behavior_Definition/ZIR_SCORT_OBJ_M.bdef.asbdef` & `.bdef.xml`
   - `DB_CORE/LOGIC/ZBP_IR_SCORT_OBJ_M.clas.abap`, `.clas.locals_imp.abap` & `.clas.xml`
   - `API/PROJECTION_CDS/ZCR_SCORT_OBJ_M.ddls.asddls` & `.ddls.xml`
   - `API/PROJECTION_BDEF/ZCR_SCORT_OBJ_M.bdef.asbdef` & `.bdef.xml`
