# SCORT — Fiori UI5 Compare (VS Code)

App: `zscort.compare` · BSP: `ZSCORT_COMPARE` · Binding: `ZUI_SCORT_COMPARE_O4`

FCL: Master (`TrCmp`) + Detail (Monaco Diff từ `Compare.TargetCode` / `SourceCode`).

---

## 0. Cài trên máy

1. [Node.js LTS](https://nodejs.org/) (18+)
2. [VS Code](https://code.visualstudio.com/)
3. Extension gợi ý:
   - **SAP Fiori tools - Extension Pack** (hoặc tối thiểu *UI5 Language Assistant*)
   - *ESLint* (tuỳ chọn)

---

## 1. Mở project

Trong VS Code:

**File → Open Folder** → chọn:

```
…/SAP05-SCORT/docs/ui5/zscort_compare
```

(Không mở cả monorepo nếu muốn terminal/`npm` đứng đúng thư mục app.)

Terminal VS Code (`Ctrl+`` `):

```bash
npm install
```

---

## 2. Nối OData S40 (bắt buộc trước `npm start`)

### 2.1 Proxy local — `ui5.yaml`

```yaml
baseUri: https://s40lp1.ucc.cit.tum.de/sap
```

Đổi host nếu S40 của bạn khác. Browser gọi `http://localhost:8080/sap/...` → proxy sang S40.

### 2.2 Service URI — `webapp/manifest.json`

Hiện (tên có `Z` trên S40):

```
/sap/opu/odata4/sap/zui_scort_compare_o4/srvd/sap/zsd_scort_compare/0001/
```

Khớp đúng **Service Binding** + **Service Definition** đã Publish trong ADT.  
Copy URI từ ADT Binding → *Service URL* (bỏ phần `$metadata`).

### 2.3 Deploy (sau này) — `ui5-deploy.yaml`

| Field | Điền |
|-------|------|
| `target.url` | `https://s40lp1.ucc.cit.tum.de` |
| `target.client` | `021` |
| `app.package` | package ABAP của bạn |
| `app.transport` | TR đang mở |

---

## 3. Chạy local

```bash
npm start
```

Mở `http://localhost:8080/index.html`.

Lần đầu gọi OData sẽ hỏi **login S40** (Basic Auth qua proxy).  
Không vào được OData → app có mock để smoke UI (không có data thật).

Kiểm tra nhanh trong DevTools → Network:

```
GET …/TrCmp?$filter=Trkorr eq 'S40K919492'
GET …/Compare?$filter=ObjectType eq 'PROG' and ObjectName eq 'Z021_DEMO_HELLO' and …
```

---

## 4. Cấu trúc code (sửa ở đâu)

| File | Việc |
|------|------|
| `webapp/view/Master.view.xml` | Filter TR, list object, badge status |
| `webapp/controller/Master.controller.js` | Load `TrCmp`, F4, navigate Detail |
| `webapp/view/Detail.view.xml` | Mode / Version Left-Right, chỗ gắn Monaco |
| `webapp/controller/Detail.controller.js` | Gọi `Compare` + `Version`, đẩy 2 chuỗi vào Diff |
| `webapp/monaco/DiffHost.js` | Monaco Diff Editor |
| `webapp/util/ValueHelp.js` | F4 → `VHTrkorr`, `VHObjType`, `Version`, … |
| `webapp/manifest.json` | Routing + OData model |
| `webapp/i18n/i18n.properties` | Text UI |

Entity set backend (đã xong):

`TrCmp` · `Compare` · `Version` · `ObjectSource` · `VHTrkorr` · `VHObjType` · `VHObjName` · `VHCompareMode` · `VHCompareStatus` · `VHServerId` · `VHServerType`

---

## 5. Luồng FE cần giữ

1. Master: nhập **TR Released** → Load → `TrCmp` (badge vs `ZA05_SCORT_T` / `T_SRC`)
2. Click dòng → Detail mode `L_VS_T`
3. Chọn **Target ZA05 version** (`/Version` + `ServerType eq 'T'`) rồi `Compare`
4. Monaco: trái = Target `TargetCode` (decompress), phải = Local Active `SourceCode`
5. `VER_VS_VER` (tuỳ chọn): F4 `/Version` `ServerType eq 'L'` — Local VRSD vs Local VRSD

---

## 6. Deploy lên S40 (BSP)

Local (`npm start` + proxy) chỉ để dev. Lên hệ thống thật = upload BSP qua ADT deploy.

### 6.1 Sửa `ui5-deploy.yaml`

| Field | Ví dụ | Ghi chú |
|-------|--------|---------|
| `target.url` | `https://s40lp1.ucc.cit.tum.de` | Host S40 |
| `target.client` | `021` | Client |
| `app.name` | `ZSCORT_COMPARE` | Tên BSP (≤15 ký tự) |
| `app.package` | `ZSCORT_SAP05` | Package ABAP của team (không `$TMP` nếu cần TR) |
| `app.transport` | `S40K9xxxxx` | **TR đang mở** của bạn |

`manifest.json` giữ URI relative `/sap/opu/odata4/sap/zui_scort_compare_o4/...` — trên S40 không cần proxy.

### 6.2 Lệnh (trong thư mục `docs/ui5/zscort_compare`)

Trước hết điền `app.transport` (TR đang mở) trong `ui5-deploy.yaml`.

```bash
npm run deploy-test   # build → dist, rồi testMode (không ghi BSP)
npm run deploy        # build → dist, rồi upload BSP qua deploy-to-abap
```

Terminal hỏi **user / password** S40.

### 6.3 Mở app trên S40

```
https://s40lp1.ucc.cit.tum.de/sap/bc/ui5_ui5/sap/zscort_compare/index.html?sap-client=021
```

Hoặc SE80 / BSP Application `ZSCORT_COMPARE` → Test.

### 6.4 Sau deploy

1. Hard refresh browser (Ctrl+Shift+R) — tránh cache BSP cũ  
2. Login S40 → Load TR Released → Compare  
3. Nếu 404 BSP: kiểm tra `app.name` / quyền `/sap/bc/ui5_ui5`  
4. Nếu OData 404: Binding `ZUI_SCORT_COMPARE_O4` đã Publish chưa

---

## 7. Checklist lỗi thường gặp

| Hiện tượng | Xử lý |
|------------|--------|
| 401/403 proxy | Login S40; kiểm tra VPN/host |
| 404 OData | Sai URI Binding — sửa `manifest.json` |
| List trống | TR chưa Release / filter Status sai |
| Monaco trắng | CDN bị chặn — xem README mục Monaco vendor |
| F4 không data | Binding chưa expose `VH*` / chưa Publish |
| **Web trắng sau login** | F12 → Console: xem lỗi đỏ. Hard refresh (`Ctrl+Shift+R`). Metadata OData 401/404 → sai URI/proxy. App đã có `init.js` hiện IllustratedMessage nếu boot fail |

Bước tiếp theo: `npm install` → sửa `ui5.yaml` + `manifest.json` nếu host/URI khác → `npm start` → Load TR `S40K919492` → mở Detail `Z021_DEMO_HELLO`.
