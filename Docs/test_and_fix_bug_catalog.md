# Catalog Báo Cáo Test & Fix Bug — Dự Án ZSCORT (SAP RAP & UI5 Toolkit)

> **Tài liệu chuẩn hóa dữ liệu Bug & Evidence** phục vụ nghiệm thu và đồng bộ 100% với workbook [Docs/Test_And_Fix_Bug_Updated.xlsx](file:///d:/Minh/For_myself/ZSCORT_GSU26_SAP05/Docs/Test_And_Fix_Bug_Updated.xlsx).  
> Toàn bộ 7 lỗi dưới đây đều là các lỗi thực tế phát sinh trong quá trình kiểm thử và phát triển hệ thống ZSCORT, đã được khắc phục triệt để, kiểm thử đạt chuẩn (Status = done) và bảo toàn đầy đủ bằng chứng ảnh trực quan (DrawingML) trong từng sheet tương ứng.

---

## Bảng Tổng Hợp Dữ Liệu Sheet "Fix and bugs"

| No | Bug | Details | Expected result | Fix | Evidence Sheet | Assessment |
|:---:|---|---|---|---|:---:|:---:|
| **1** | **Chưa hiển thị đúng version của Class (Class Revisions History)** | When clicking tab 'Version History' for an ABAP Class object (CLAS), the system revealed only the active version (versno = 00000), omitting all historical transport revisions from VRSD. | (16/09/2026) System must display the complete list of revisions as ADT Eclipse shows in Revision History of Class Object, including TR number, release date, author, and description. | (19/09/2026) In `ZCL_SCORT_V_READER.clas.abap`, eliminated the rigid 30-char '=' padding on class name; queried VRSD using LIKE pattern '=%' and ' %' to capture both SAP GUI and ADT include naming; excluded dummy '00000' versions early; implemented E071+E070 fallback for released TRs without VRSD rows; mapped commit messages via E07T; and fixed korrnum reverse lookup in read_version. | `Issue 1` | `done` |
| **2** | **Button "Apply to Target" của TR Tree Object bị sai tác dụng** | Button "Apply to Target" trên giao diện TR Tree không mở pop-up modal "Apply to Target - Preview & Object Selection" mà lại điều hướng nhầm sang màn hình TR Details. | (17/09/2026) Clicking "Apply to Target" on a TR Tree node must open the modal dialog "Apply to Target - Preview & Object Selection" to preview objects before deploying. | (17/09/2026) Re-routed button event handler in `TrSearch.controller.js` / `TrTree.controller.js` to instantiate and display `ApplyToTargetDialog.fragment.xml` with proper context binding and selective object checkboxes. | `Issue 2` | `done` |
| **3** | **AI Review failed on Gemini quota exhaustion without failover** | When the primary Gemini API key exhausted its quota or hit rate limits (HTTP 429/403), AI Code Review stopped completely with service failure instead of switching keys. | (17/09/2026) AI Review service must seamlessly failover to the next available API key in the configured multi-key pool with exponential backoff without crashing user operations. | (18/09/2026) Implemented Failover Key Pool rotation across valid API keys in SICF Handler `/sap/bc/zscort_ai` and `ZCL_SCORT_AI_ASSISTANT` with exponential backoff and cleaned dead keys. | `Issue 3` | `done` |
| **4** | **Frontend exposed direct Google Gemini API calls and API keys** | Frontend previously attempted direct calls to `generativelanguage.googleapis.com`, exposing Google Gemini API keys in browser network traces and violating enterprise security. | (17/09/2026) 100% of AI requests must route through SAP backend proxy handler without exposing credentials or endpoints in client-side JavaScript. | (17/09/2026) Enforced `rule_ai_review_standards.md`: all AI interactions go through SICF `/sap/bc/zscort_ai`; migrated keys to backend Base64 storage and removed all client-side AI keys. | `Issue 4` | `done` |
| **5** | **Monaco Editor collapsed to 0px height inside IconTabFilter** | Placing Monaco diff editor inside `IconTabFilter` caused DOM container to render with 0px height upon tab switching because hidden tabs have zero clientHeight. | (17/09/2026) Editor must dynamically resize and maintain 100% container height when active tab changes. | (17/09/2026) Implemented explicit flexbox layout and attached resize triggers to select event of `IconTabBar` in `Compare.controller.js` and `Detail.controller.js` per `rule_monaco_iframe.md`. | `Issue 5` | `done` |
| **6** | **TrSearch active tasks dialog displayed empty table rows** | Querying sub-tasks of a Transport Request failed to bind child task descriptions and object lists into dialog table due to missing hierarchical query. | (18/09/2026) Opening task dialog must show all sub-tasks (`E070`), task owners, and contained objects (`E071`). | (18/09/2026) Enhanced `_trServiceUri` to recursively retrieve `E070 WHERE strkorr = parent_tr`, mapped `E07T` descriptions, and bound `activeTasks` JSONModel in `TrSearch.controller.js` per `rule_sap_cts_tr_hierarchy.md`. | `Issue 6` | `done` |
| **7** | **AI Pre-check & Model Selection failed due to dead keys in pool** | AI Pre-check TR and Code Review reported 'All Gemini API keys in pool exhausted or network unreachable' due to suspended keys in pool; additionally, frontend lacked model selection for Gemini 3.8/3.7/3.6 Flash. | (19/09/2026) System must execute AI analysis reliably using verified alive API keys and allow switching between supported models (Gemini 3.8 Flash, 3.7 Flash, 3.6 Flash, 3.5 Flash Lite). | (19/09/2026) Cleaned key pool in `ZCL_SCORT_AI_ASSISTANT.clas.abap` with verified live Base64 keys; upgraded default model to Gemini 3.8 Flash; added dynamic model parameter parsing in SICF handler `/sap/bc/zscort_ai`; and added model selector dropdown in `AiSidePanel.fragment.xml` and controllers. | `Issue 7` | `done` |

---

## Chi Tiết Từng Issue & Bằng Chứng Minh Họa (Evidence Sheets)

### Issue 1: Chưa Hiển Thị Đúng Version Của Class (Class Revisions History)
- **Bug**: Khi mở tab *Version History* của đối tượng ABAP Class (`CLAS`), hệ thống chỉ hiển thị đúng 1 dòng version Active (`00000`), không hiển thị danh sách các bản revision từ các Transport Request đã release.
- **Root Cause**: 
  - Trong `ZCL_SCORT_V_READER`, hàm padding chuỗi class name với 30 dấu `=` (`|{ lv_cls_pad }|`) làm sai lệch định dạng lưu trong `VRSD` đối với các include pool (`CP`, `CCDEF`, `CCIMP`).
  - Thiếu cơ chế fallback đọc từ `E071` / `E070` đối với các Transport Request đã release nhưng chưa có snapshot trong `VRSD`.
- **Giải Pháp Khắc Phục**:
  - Chuẩn hóa pattern truy vấn `VRSD` bằng mệnh đề LIKE `=%` và ` %`.
  - Lọc bỏ sớm version rác `00000` trước khi gán dữ liệu.
  - Bổ sung fallback truy vấn `E071 JOIN E070` với điều kiện `trstatus = 'R'` và liên kết `E07T` để lấy commit comment.
  - Sửa lại hàm `read_version` cho phép reverse lookup theo `korrnum`.
- **Bằng Chứng Trong Workbook**: Sheet `Issue 1` (Chứa 2 ảnh minh chứng đối chiếu giữa giao diện Web UI và Eclipse ADT).

---

### Issue 2: Button "Apply to Target" Của TR Tree Object Bị Sai Tác Dụng
- **Bug**: Trên cây Transport Request (`TR Tree`), người dùng bấm nút *"Apply to Target"* nhưng hệ thống không mở modal xem trước danh sách đối tượng cần đồng bộ mà chuyển hướng nhầm vào trang chi tiết TR.
- **Root Cause**: Event handler của button gán nhầm action navigation thay vì gọi controller mở fragment dialog `ApplyToTargetDialog`.
- **Giải Pháp Khắc Phục**:
  - Gán lại action handler trong `TrTree.controller.js` và `TrSearch.controller.js`.
  - Khởi tạo và nạp `ApplyToTargetDialog.fragment.xml`, liên kết danh sách object với checkbox lựa chọn và trạng thái trước khi cho phép kích hoạt `ZCL_SCORT_TARGET_APPLY`.
- **Bằng Chứng Trong Workbook**: Sheet `Issue 2` (Chứa 5 ảnh minh chứng quy trình thao tác và hiển thị modal đối chiếu).

---

### Issue 3: AI Review Failed On Gemini Quota Exhaustion Without Failover
- **Bug**: Khi API key Gemini chính chạm ngưỡng quota limit (HTTP 429 / 403), toàn bộ tính năng AI Code Review và Smart Pre-check bị dừng đột ngột, thông báo lỗi hệ thống.
- **Root Cause**: Quá trình gọi AI từ backend chưa triển khai cơ chế xoay vòng (round-robin failover) tự động khi nhận mã lỗi từ Google AI Gateway.
- **Giải Pháp Khắc Phục**:
  - Triển khai multi-key failover pool trong SICF Handler `/sap/bc/zscort_ai` và `ZCL_SCORT_AI_ASSISTANT`.
  - Tự động bắt mã lỗi HTTP 429, 403, 503 và chuyển tiếp request sang key tiếp theo trong danh sách với thuật toán exponential backoff.
- **Bằng Chứng Trong Workbook**: Sheet `Issue 3` (Chứa 2 ảnh chụp log quota error và phản hồi failover thành công).

---

### Issue 4: Frontend Exposed Direct Google Gemini API Calls And API Keys
- **Bug**: Tệp mã nguồn JavaScript phía Frontend trước đây gọi trực tiếp tới `generativelanguage.googleapis.com`, làm lộ API keys qua DevTools Network tab.
- **Root Cause**: Thiết kế ban đầu kết nối trực tiếp từ trình duyệt đến endpoint public của Google thay vì đi qua lớp backend proxy bảo mật của SAP.
- **Giải Pháp Khắc Phục**:
  - Áp dụng triệt để quy chuẩn `rule_ai_review_standards.md` và `rule_ai_integration_resilience.md`.
  - Chuyển 100% kết nối AI về backend proxy handler `/sap/bc/zscort_ai`. Toàn bộ API keys được mã hóa Base64 lưu tại backend `ZCL_SCORT_AI_ASSISTANT`, tuyệt đối không để lộ ra client-side.
- **Bằng Chứng Trong Workbook**: Sheet `Issue 4` (Chứa 2 ảnh minh chứng: Request trực tiếp bị chặn và Request định tuyến qua SAP SICF).

---

### Issue 5: Monaco Editor Collapsed To 0px Height Inside IconTabFilter
- **Bug**: Trình chỉnh sửa Monaco Diff Editor nhúng bên trong `IconTabFilter` bị co cụm về chiều cao `0px` khi người dùng chuyển đổi qua lại giữa các tab trên giao diện Object Detail & Compare.
- **Root Cause**: Cơ chế lazy render của SAPUI5 `IconTabBar` khiến các container ẩn có `clientHeight = 0`. Khi kích hoạt tab, Monaco không tự động tính toán lại kích thước DOM view.
- **Giải Pháp Khắc Phục**:
  - Cấu trúc layout Flexbox tường minh và bọc Monaco Editor trong iframe sandbox riêng biệt chống xung đột AMD loader (`rule_monaco_iframe.md`).
  - Đăng ký trigger resize tự động lắng nghe sự kiện `select` của `IconTabBar` trong `Compare.controller.js` và `Detail.controller.js`.
- **Bằng Chứng Trong Workbook**: Sheet `Issue 5` (Chứa 2 ảnh chụp màn hình trước khi co cụm và sau khi hiển thị toàn màn hình 100% height).

---

### Issue 6: TrSearch Active Tasks Dialog Displayed Empty Table Rows
- **Bug**: Khi mở dialog xem danh sách các Task con thuộc Transport Request trên màn hình TrSearch, bảng hiển thị các hàng trống không có dữ liệu mô tả và đối tượng.
- **Root Cause**: Thiếu bước truy vấn đệ quy phân cấp CTS (`E070 WHERE strkorr = parent_tr`) để lấy danh sách Task ID và mapping tên Task từ `E07T`.
- **Giải Pháp Khắc Phục**:
  - Nâng cấp service `_trServiceUri` truy vấn đệ quy toàn bộ task con thuộc TR cha.
  - Ánh xạ đầy đủ thông tin Task Owner, Task Type, Description từ `E07T` và danh sách objects từ `E071`.
  - Khởi tạo đầy đủ cấu trúc model `activeTasks` trong `onInit` của `TrSearch.controller.js` (`rule_sap_cts_tr_hierarchy.md`).
- **Bằng Chứng Trong Workbook**: Sheet `Issue 6` (Chứa 2 ảnh minh chứng: Bảng rỗng ban đầu và Bảng hiển thị đầy đủ chi tiết Sub-Tasks).

---

### Issue 7: AI Pre-check & Model Selection Failed Due To Dead Keys In Pool
- **Bug**: Tính năng AI Pre-check TR và AI Assistant báo lỗi `"All Gemini API keys in pool exhausted or network unreachable"` do trong pool có key bị suspend (403); đồng thời người dùng không có tuỳ chọn chuyển đổi linh hoạt các model AI mới nhất (Gemini 3.8/3.7/3.6 Flash).
- **Root Cause**:
  - Pool khóa AI cũ chứa các khóa đã bị Google vô hiệu hóa (403 Forbidden).
  - Endpoint và mã nguồn bị hardcode model cố định, không nhận tham số dynamic model từ giao diện người dùng.
- **Giải Pháp Khắc Phục**:
  - Kiểm thử trực tiếp, thanh lọc pool và nạp các key sống 100% vào `ZCL_SCORT_AI_ASSISTANT.clas.abap`.
  - Thiết lập model mặc định tốc độ cao `gemini-3.8-flash`, đồng thời hỗ trợ `gemini-3.7-flash`, `gemini-3.6-flash` và `gemini-3.5-flash-lite`.
  - Bổ sung Select Model Dropdown trên `AiSidePanel.fragment.xml`, đồng bộ xử lý tham số `model` qua SICF Handler `/sap/bc/zscort_ai` và build UI5 sạch sẽ.
- **Bằng Chứng Trong Workbook**: Sheet `Issue 7` (Chứa 2 ảnh chụp lỗi key pool cũ và giao diện tương tác AI hoàn chỉnh).
