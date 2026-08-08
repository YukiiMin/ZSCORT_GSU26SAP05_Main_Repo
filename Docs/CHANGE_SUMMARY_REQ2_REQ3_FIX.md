# SCORT — Tổng hợp thay đổi REQ2/REQ3 (TR Search, Release, Apply to Target, Code Compare)

> File này tổng hợp: (1) khác biệt so với code BE cũ, (2) cách FE hoạt động, (3) công nghệ sử dụng, (4) hướng dẫn deploy test/thật.

---

## 1. Bối cảnh

Ứng dụng **SCORT** hỗ trợ luồng:

```
Object Search (REQ1) → TR Search: Add object / Release (REQ2)
                     → Code Compare (REQ3, read-only)
                     → Apply to Target (REQ2)
```

Hệ thống backend: **SAP S/4HANA (S40), client 324**, dùng **RAP (RESTful ABAP Programming Model)** + OData V4.
Frontend: **SAPUI5 (OpenUI5 1.120)**, chạy độc lập ngoài SAP GUI (VS Code + `ui5-cli`), gọi 3 OData service.

---

## 2. Vấn đề gốc trước khi sửa

| # | Hiện tượng | Nguyên nhân gốc |
|---|-----------|------------------|
| 1 | Bấm **Release** → toast "OK" nhưng Status TR/Task vẫn `D` | BDEF `ReleaseRequest` không đưa key lỗi vào `failed-trtree`, và không đọc lại `E070-TRSTATUS` sau khi gọi CTS → OData trả 200 dù chưa release thật |
| 2 | Bấm Release → dump `BEHAVIOR_ILLEGAL_STATEMENT` (`$batch failed`) | `TR_RELEASE_REQUEST` (và `ZCL_AUTH_HELPER`) có `RAISE`/`COMMIT` ngầm — **RAP cấm COMMIT/RAISE thay đổi LUW bên trong 1 action handler** |
| 3 | Bấm **Apply to Target** → cùng loại dump `BEHAVIOR_ILLEGAL_STATEMENT` tại `ZCL026_SCORT_TARGET_APPLY` | Class Apply có `COMMIT WORK` trực tiếp, gọi thẳng từ BDEF |
| 4 | Release Task xong, Release TR cha vẫn cho phép dù Task chưa `R` | Chưa có validation "Task phải Release trước TR cha" ở cả BE lẫn FE |
| 5 | Compare báo **"Target REPO version list unavailable"** kèm dump `SYNTAX_ERROR` | `ZCL_SCORT_VERSION_QUERY` tham chiếu field `server_id` không tồn tại trong struct nội bộ `ty_filters` |
| 6 | TR Search "không phản ứng" / HTTP 500 khi tìm theo TR cha | SADL/OData `contains()` trên CDS cây TR gây `CX_SADL_DUMP_APPL_MODEL_ERROR`; filter client-side loại nhầm object thuộc Task con |
| 7 | Sau Release, bấm gì cũng thấy toast "Searching TR…" gây cảm giác "quay vòng" | `_searchTree()` luôn toast + full reload, kể cả khi chỉ cần refresh 1 dòng sau Release |

---

## 3. Những gì đã thay đổi (so với code BE cũ)

### 3.1 Nguyên tắc mới bắt buộc cho RAP action có side-effect ghi ngoài buffer RAP

> **RAP không cho phép `COMMIT WORK`, `ROLLBACK WORK`, hoặc bất kỳ statement nào gây commit ngầm (kể cả `RAISE` trong 1 số BAPI/class cũ) chạy bên trong 1 action handler của BDEF.**
> Giải pháp chuẩn SAP: tách phần có khả năng COMMIT ra **Function Module RFC-enabled riêng**, gọi bằng `CALL FUNCTION ... DESTINATION 'NONE'` → tạo **LUW mới, độc lập** với transactional buffer của RAP.

Áp dụng pattern này cho cả **Release** và **Apply to Target** (trước đó pattern này đã dùng cho Add Object / Send Package ở REQ2 cũ — nay đồng bộ hoá luôn Release & Apply theo đúng chuẩn đó).

### 3.2 File ABAP mới (Function Module wrapper — LUW riêng)

| File | Vai trò |
|------|--------|
| `DB_CORE/LOGIC/Z_SCORT_TR_RELEASE_LOCAL.abap` | FM RFC-enabled, bọc `ZCL026_SCORT_RELEASE_SERVICE=>PROCESS_RELEASE`. Import `IV_TRKORR`, `IV_DIALOG`; Export `EV_SUCCESS`, `EV_MESSAGE` |
| `DB_CORE/LOGIC/Z_SCORT_TR_APPLY_LOCAL.abap` | FM RFC-enabled, bọc `ZCL026_SCORT_TARGET_APPLY=>APPLY_TO_TARGET`. Import `IV_TRKORR`; Export `EV_SUCCESS`, `EV_MESSAGE` |

Cả hai **không viết lại logic nghiệp vụ** — chỉ là lớp vỏ LUW gọi đúng class REQ2 đã có (`ZCL026_SCORT_RELEASE_SERVICE`, `ZCL026_SCORT_TARGET_APPLY`), bắt `cx_root` để không dump ra ngoài FM.

### 3.3 `ZBP_CE_SCORT_TR_TREE.clas.locals_imp.abap` (BDEF implementation) — thay đổi lớn nhất

- **`ReleaseRequest`**:
  - Validate **Task phải Release trước TR cha** (`SELECT` E070 con status ≠ `R`) → nếu còn Task mở, đưa vào `failed-trtree` kèm message rõ tên Task, **không gọi CTS**.
  - Gọi `Z_SCORT_TR_RELEASE_LOCAL DESTINATION 'NONE'` thay vì gọi class trực tiếp.
  - Sau khi gọi, **luôn `SELECT SINGLE TRSTATUS FROM E070` để xác nhận lại** — không tin tưởng mù quáng `sy-subrc` của FM. Nếu status vẫn `D` → coi là **failed thật sự**, đưa key vào `failed-trtree` (trước đây thiếu bước này nên OData trả 200 giả).
  - Nhận biết trạng thái trung gian `O` (Release đã start, đang export) — không báo fail, giải thích rõ cho user chờ SE09.
- **`ApplyToTarget`**: áp dụng đúng pattern tương tự — gọi `Z_SCORT_TR_APPLY_LOCAL DESTINATION 'NONE'`, xác nhận `EV_SUCCESS`, đưa `failed-trtree` khi lỗi.
- Message trả về **không dùng message class ảo `ZSCORT/000`** (gây dump) — dùng `new_message_with_text` thuần text.

### 3.4 `file-ref-REQ2/CLASS zcl026_scort_release_service.txt` (`ZCL026_SCORT_RELEASE_SERVICE`)

- Thêm **CASE map chi tiết** cho từng exception của `TR_RELEASE_REQUEST` (subrc 1–13: enqueue, no_authorization, **object_check_error**, model_check_error, released_with_error…) → message tiếng Việt cụ thể thay vì chỉ "Mã lỗi Subrc: 7".
- Xử lý riêng status `O` (export đang chạy): **poll tối đa 5–8 giây** đọc lại `E070-TRSTATUS`, tránh báo fail giả khi CTS vẫn đang xử lý ngầm.
- Coi `R` và `N` (Released, protected) đều là "đã release" hợp lệ.
- Sửa lỗi tiềm ẩn: `SELECT` phụ (đọc lại status) từng ghi đè `sy-subrc` gốc của `CALL FUNCTION` → tách biến `lv_fm_subrc` lưu riêng trước khi `SELECT` khác chạy.

### 3.5 `ZCL_SCORT_VERSION_QUERY.clas.abap`

- Xoá tham chiếu `rs_filter-server_id` (field không tồn tại trong `ty_filters` cục bộ của method `parse_filters`) — đây là nguyên nhân gây `SYNTAX_ERROR` mỗi khi FE load version list cho Target REPO.

### 3.6 `ZCL_SCORT_TR_TREE_QUERY.clas.abap`, `ZCL_SCORT_TR_CMP_QUERY.clas.abap`, `ZCL_SCORT_T_READER.clas.abap`, `ZCL_SCORT_V_READER.clas.abap`, `ZCL_SCORT_COMPARE_QUERY.clas.abap`

- `TR_TREE_QUERY`: bỏ `contains()` gây SADL dump trên CDS cây TR; thêm paging an toàn (tránh `CX_RAP_QUERY_PAGE_SIZE_OVERRUN`); build cây theo `LIMU` + `R3TR` đúng theo E071.
- `TR_CMP_QUERY`: chỉ mở Compare cho TR **Released**; báo message rõ khi TR chưa Release thay vì trả rỗng im lặng; không xoá bảng kết quả khi 1 object riêng lẻ `NOT_SUPPORTED` (VD: `TABL`).
- `T_READER`: fallback lấy `MAX(version_no)` từ `ZA05_SCORT_T_SRC` khi header `current_version` trống (dữ liệu cũ Apply trước khi có field này); thêm fallback giải nén khi gặp lệch giữa `compress_text` và util UTF-8 nhị phân.
- `V_READER`, `COMPARE_QUERY`: đồng bộ theo các fix trên, và bỏ tham số `iv_server_id` không còn tồn tại ở `ZCL_SCORT_T_READER` (đọc từ bảng single-tenant `ZA05_SCORT_T`, không multi-server).

### 3.7 `ZCR_SCORT_OBJ_M.ddls.asddls`

- Bỏ annotation `ExistenceStatusCriticality` sai gây lỗi CDS activation.

---

## 4. FE hoạt động ra sao

### 4.1 Kiến trúc tổng quan

```
FE_UI/  (SAPUI5 app, id: zscort.app)
├── webapp/
│   ├── Component.js              → khởi tạo models, router
│   ├── manifest.json             → khai báo 3 OData V4 service + routing FCL
│   ├── controller/
│   │   ├── App.controller.js         → FlexibleColumnLayout điều phối 3 cột
│   │   ├── BaseController.js         → helper chung (navigation, toast, lỗi)
│   │   ├── ObjSearch.controller.js   → REQ1: tìm object, thêm vào TR/Task
│   │   ├── TrSearch.controller.js    → REQ2: cây TR→Task→Object, Release
│   │   ├── Master.controller.js      → REQ3: danh sách TR đã Released để Compare
│   │   ├── Detail.controller.js      → REQ3: danh sách object trong TR (TrCmp) + Apply to Target
│   │   └── Compare.controller.js     → REQ3: side-by-side diff (Monaco)
│   ├── view/*.view.xml           → XML views tương ứng từng controller
│   ├── monaco/CodeHost.js        → nhúng Monaco Editor (diff view)
│   └── util/ValueHelp.js         → helper fetch OData JSON + F4 Value Help dùng chung
```

### 4.2 Luồng nghiệp vụ chính trên FE

1. **Object Search** (`ObjSearch`) — tìm Class/Program/Function theo tên/loại, thêm vào 1 Task của TR (tạo TR/Task mới nếu cần) qua `objService`.
2. **TR Search** (`TrSearch`) — hiển thị cây **TR → Task → Object** (bảng cây `sap.ui.table.TreeTable`, dữ liệu build thủ công từ danh sách phẳng trả về bởi CDS, dùng `ParentNodeId` để dựng cây và lọc client-side).
   - Nút **Release** hiện trên dòng TR/Task khi `TrStatus ≠ 'R'`.
   - Bấm Release trên **TR cha**: FE tự kiểm tra các Task con còn `TrStatus ≠ 'R'` → nếu còn, chặn ngay tại client (không gọi OData), báo rõ Task nào cần release trước.
   - Gọi OData action `ReleaseRequest` qua binding: `/TrTree('<Trkorr>')/...ReleaseRequest(...)`.
   - Sau khi Release thành công: **refresh cây "im lặng"** — gọi lại `_searchTree(true)` để cập nhật Status mà **không** hiện lại toast "Searching TR…" (trước đây gây cảm giác lặp vòng UX).
3. **Code Compare** (`Master` + `Detail` + `Compare`):
   - `Master`: liệt kê các TR đã ở trạng thái **Released** (bắt buộc — Compare không mở với TR `Modifiable`).
   - `Detail`: liệt kê object trong TR (entity `TrCmp`), hiện nút **Apply to Target**.
   - `Compare`: chọn 1 object → gọi entity `Compare` (trả 2 chuỗi thô `TargetCode`/`SourceCode`) → render bằng **Monaco Diff Editor** (client-side, LCS/Myers diff hoàn toàn ở trình duyệt — backend không tự dựng mảng diff).
   - Có cơ chế **fallback** khi backend OData dump (`SYNTAX_ERROR`, `CX_SY_*`, rỗng dữ liệu): chuyển sang lấy `SourceCodeView` qua `objService` để vẫn hiển thị được something thay vì màn hình trắng.
4. **Apply to Target**: gọi action `ApplyToTarget` trên `TrTree`, ghi `SOURCE_HEX` (nén GZIP) + `SRC_HASH` vào `ZA05_SCORT_T` / `ZA05_SCORT_T_SRC` (qua FM LUW riêng ở BE) → object trở thành có version ở "đích" để Compare lần sau không còn `NEW_AT_TARGET`.

### 4.3 Nguyên tắc UX đã áp dụng

- Toast ngắn gọn, không show message ABAP dài dòng (ví dụ dump Activate/ST22) trực tiếp lên UI.
- Không tự động mở Compare khi TR chưa Released.
- Compare không chặn Apply to Target (đúng SPEC REQ3 — read-only, optional preview step).
- Sau action ghi dữ liệu (Release/Apply), UI tự refresh phần liên quan thay vì bắt user F5 thủ công.

---

## 5. Công nghệ sử dụng

| Lớp | Công nghệ |
|-----|-----------|
| Backend | SAP S/4HANA, **RAP (RESTful ABAP Programming Model)**: CDS View (Interface + Projection/Consumption), Behavior Definition (BDEF) + `locals_imp`, Service Definition/Binding **OData V4** |
| Backend – nghiệp vụ | ABAP classes thuần (`ZCL_...`), Function Modules RFC-enabled cho phần cần LUW riêng (`DESTINATION 'NONE'`), FM chuẩn SAP (`TR_RELEASE_REQUEST`) |
| Nén/Hash | `CL_ABAP_GZIP` (nén source lưu `SOURCE_HEX`), hash chung `ZCL_SCORT_HASH_UTL` dùng cả REQ2 và REQ3 |
| Frontend | **SAPUI5 / OpenUI5 1.120** (MVC, XML Views), `sap.f.FlexibleColumnLayout` (bố cục 3 cột), `sap.ui.table.TreeTable` |
| Frontend – tooling | **Node.js + `@ui5/cli`** (build/serve), `@sap/ux-ui5-tooling` (Fiori deploy/undeploy CLI), `ui5-middleware-simpleproxy` (proxy OData khi dev local) |
| Diff viewer | **Monaco Editor** (`monaco-editor` npm package) — diff LCS/Myers chạy hoàn toàn phía client |
| Giao tiếp dữ liệu | OData V4 (`sap.ui.model.odata.v4.ODataModel`) cho 3 service: `mainService` (Compare), `objService` (Object Search), `trService` (TR Search/Release/Apply); ngoài ra dùng `fetch()` thuần (qua `util/ValueHelp.js`) để có control tốt hơn khi OData V4 binding không phù hợp (F4, load cây TR, v.v.) |
| Đóng gói FE trên SAP | **BSP Application** (`ZSCORT_APP`), publish qua `fiori deploy` |

---

## 6. Hướng dẫn Deploy

### 6.0 Điều kiện tiên quyết (mỗi lần đổi ABAP)

Vì code ABAP được soạn trong VS Code/docs, **KHÔNG tự động lên S40** — phải copy/paste và **Activate thủ công** trong ADT (Eclipse) trên hệ thống S40:

- `ZCL_SCORT_TR_TREE_QUERY`, `ZBP_CE_SCORT_TR_TREE` (BDEF locals_imp)
- `ZCL026_SCORT_RELEASE_SERVICE`, `ZCL026_SCORT_TARGET_APPLY`
- `Z_SCORT_TR_RELEASE_LOCAL`, `Z_SCORT_TR_APPLY_LOCAL` (Function Group `ZSCORT_FG_LOCAL`)
  - Bắt buộc bật **Attributes → Remote-Enabled Module**, tất cả tham số **Pass Value**, Activate cả FM lẫn Function Group.
- `ZCL_SCORT_T_READER`, `ZCL_SCORT_V_READER`, `ZCL_SCORT_COMPARE_QUERY`, `ZCL_SCORT_TR_CMP_QUERY`, `ZCL_SCORT_VERSION_QUERY`
- CDS `ZCR_SCORT_OBJ_M` nếu có đổi annotation

Sau khi Activate xong toàn bộ ABAP → **hard refresh** trình duyệt FE (`Ctrl+Shift+R`) trước khi test.

### 6.1 Deploy Test (không ghi BSP, chỉ kiểm tra config/kết nối)

```powershell
cd FE_UI
npm install
npm run deploy-test
```

Lệnh này chạy `ui5 build --clean-dest --dest dist` rồi `fiori deploy --config ui5-deploy.yaml --testMode true` — build và giả lập upload nhưng **không ghi** vào BSP thật trên S40. Dùng để xác nhận `ui5-deploy.yaml` (host, client, package, transport) đúng trước khi deploy thật.

### 6.2 Deploy Thật (ghi BSP lên S40)

1. Mở `FE_UI/ui5-deploy.yaml`, xác nhận:
   ```yaml
   target:
     url: https://s40lp1.ucc.cit.tum.de
     client: "324"
   app:
     name: ZSCORT_APP
     package: ZSCORT_SAP05
     transport: S40K9xxxxx   # ← TR đang mở, còn Modifiable
   ```
2. Chạy:
   ```powershell
   npm run deploy
   ```
   (= `ui5 build` rồi `fiori deploy` — upload thật vào BSP `ZSCORT_APP`). Terminal sẽ hỏi **user/password S40**.
3. Mở app đã deploy:
   ```
   https://s40lp1.ucc.cit.tum.de/sap/bc/ui5_ui5/sap/zscort_app/index.html
   ```
   hoặc SE80 → BSP Application `ZSCORT_APP` → Test.
4. **Hard refresh** (`Ctrl+Shift+R`) để tránh cache BSP cũ.

### 6.3 Chạy Dev cục bộ (không deploy, sửa FE nhanh)

```powershell
cd FE_UI
npm start
```

Mở `http://localhost:8080/index.html`. Cấu hình proxy OData sang S40 nằm trong `ui5.yaml` (`baseUri`) — lần gọi OData đầu tiên sẽ hỏi Basic Auth cho S40.

### 6.4 Gỡ app khỏi BSP (nếu cần)

```powershell
npm run undeploy
```

---

## 7. Checklist nhanh khi gặp lỗi tương tự trong tương lai

| Triệu chứng | Kiểm tra trước tiên |
|---|---|
| Dump `BEHAVIOR_ILLEGAL_STATEMENT` khi bấm action trong BDEF | Có `COMMIT WORK`/`RAISE` gọi trực tiếp trong action handler không? → bọc bằng FM `DESTINATION 'NONE'` |
| Toast "OK" nhưng status DB không đổi | BDEF có đọc lại DB xác nhận sau khi gọi service, và có đưa key lỗi vào `failed-<entity>` chưa? |
| `SYNTAX_ERROR` khi Activate class | Kiểm tra field/struct có tồn tại đúng tên trong `TYPES` cục bộ không (dễ xảy ra khi copy code giữa các class có struct khác nhau) |
| Release báo lỗi số (`Subrc: 7`) không rõ nghĩa | Map theo đúng thứ tự `EXCEPTIONS` khai báo tại `CALL FUNCTION` đó (số thứ tự **không phải** hằng số chuẩn toàn hệ thống của SAP) |
| Compare hiện `NEW_AT_TARGET` mãi dù đã Apply | Kiểm tra `Z_SCORT_TR_APPLY_LOCAL` đã Remote-Enabled + Activate; xem `ZA05_SCORT_T`/`_T_SRC` có version mới qua SE16N |
