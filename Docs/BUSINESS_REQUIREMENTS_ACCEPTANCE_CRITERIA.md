# SCORT — TÀI LIỆU YÊU CẦU NGHIỆP VỤ & TIÊU CHÍ NGHIỆM THU
## (Business Requirements & Acceptance Criteria Document)
### Dự án: SAP Cross-system Object Replication Toolkit (SCORT)
### Mã dự án: GSU26_SAP05 | Phiên bản: 2.0 (Enterprise Release)

---

## MỤC LỤC
1. [Thông Tin Dự Án & Tóm Tắt Điều Hành (Executive Summary)](#1-thông-tin-dự-án--tóm-tắt-điều-hành)
2. [Phạm Vi Dự Án (Project Scope & Boundaries)](#2-phạm-vi-dự-án)
   - [2.1. Phạm vi thực thi (In-Scope)](#21-phạm-vi-thực-thi-in-scope)
   - [2.2. Phạm vi ngoài dự án (Out-of-Scope)](#22-phạm-vi-ngoài-dự-án-out-of-scope)
   - [2.3. Giả định & Ràng buộc (Assumptions & Constraints)](#23-giả-định--ràng-buộc-assumptions--constraints)
3. [Yêu Cầu Chức Năng Chi Tiết (Functional Requirements - FRs)](#3-yêu-cầu-chức-năng-chi-tiết-functional-requirements)
   - [FR-01: Tra cứu & Lọc Repository Objects Đa Hệ Thống](#fr-01-tra-cứu--lọc-repository-objects-đa-hệ-thống)
   - [FR-02: Quản Lý & Duyệt Cây Phân Cấp Transport Request (TR Search)](#fr-02-quản-lý--duyệt-cây-phân-cấp-transport-request-tr-search)
   - [FR-03: So Sánh Mã Nguồn Đối Soát (Git-Style Side-by-Side Diff)](#fr-03-so-sánh-mã-nguồn-đối-soát-git-style-side-by-side-diff)
   - [FR-04: Quy Trình Release Transport Request An Toàn (Safe TR Release)](#fr-04-quy-trình-release-transport-request-an-toàn-safe-tr-release)
   - [FR-05: Áp Dụng Snapshot Vào Target Giả Lập & Xử Lý Xoá (Apply to Target)](#fr-05-áp-dụng-snapshot-vào-target-giả-lập--xử-lý-xoá-apply-to-target)
   - [FR-06: Trợ Lý AI Đánh Giá Rủi Ro Vận Chuyển (AI Pre-check Assistance)](#fr-06-trợ-lý-ai-đánh-giá-rủi-ro-vận-chuyển-ai-pre-check-assistance)
   - [FR-07: Quốc Tế Hoá & Đa Ngôn Ngữ Giao Diện (i18n Globalization)](#fr-07-quốc-tế-hoá--đa-ngôn-ngữ-giao-diện-i18n-globalization)
4. [Quy Tắc Nghiệp Vụ Chặt Chẽ (Business Rules - BRs)](#4-quy-tắc-nghiệp-vụ-chặt-chẽ-business-rules)
5. [Đầu Ra Kỳ Vọng Theo Nghiệp Vụ (Expected Business Outputs)](#5-đầu-ra-kỳ-vọng-theo-nghiệp-vụ-expected-business-outputs)
6. [Tiêu Chí Nghiệm Thu Đo Lường Được (Measurable Acceptance Criteria - ACs)](#6-tiêu-chí-nghiệm-thu-đo-lường-được-acceptance-criteria)
   - [6.1. Bảng Tiêu chí Nghiệm thu BDD (Given - When - Then)](#61-bảng-tiêu-chí-nghiệm-thu-bdd-given---when---then)
   - [6.2. Checklist Nghiệm thu Chức năng (Functional Verification Checklist)](#62-checklist-nghiệm-thu-chức-năng)
7. [Yêu Cầu Phi Chức Năng (Non-Functional Requirements - NFRs)](#7-yêu-cầu-phi-chức-năng-non-functional-requirements)
8. [Ma Trận Phân Công Trách Nhiệm (RACI Matrix)](#8-ma-trận-phân-công-trách-nhiệm-raci-matrix)

---

## 1. THÔNG TIN DỰ ÁN & TÓM TẮT ĐIỀU HÀNH

### 1.1. Bối cảnh Doanh nghiệp
Trong môi trường doanh nghiệp vận hành hệ thống SAP S/4HANA quy mô lớn với nhiều cảnh quan hệ thống (Development -> Quality Assurance -> Pre-Production -> Production), việc quản lý và đồng bộ mã nguồn giữa các hệ thống (cross-system object synchronization) thường gặp các thách thức nghiêm trọng:
1. **Phụ thuộc hoàn toàn vào SAP Standard CTS (Change and Transport System):** Quy trình xuất/nhập Transport Request (TR) truyền thống thông qua giao dịch `SE09`/`SE10`/`STMS` đòi hỏi sự can thiệp thủ công liên tục của đội ngũ SAP Basis, gây độ trễ lớn (tính theo ngày).
2. **Thiếu công cụ trực quan để đối soát mã nguồn đa hệ thống (Cross-system Diff):** Developer và Quản lý dự án không có công cụ trực quan để so sánh nhanh sự khác biệt giữa mã nguồn đang viết trên Local và mã nguồn đang chạy trên Target trước khi vận chuyển.
3. **Rủi ro xung đột (Conflict) và đè mã nguồn (Overwrite):** Khi nhiều lập trình viên cùng chỉnh sửa trên các Task khác nhau hoặc khi object bị xoá tại Local nhưng vẫn còn tồn lưu tại Target dẫn đến lỗi biên dịch (Syntax Error / Activation Error) khi deploy.
4. **Thiếu cơ chế thẩm định an toàn (Pre-check) thông minh:** Chưa có khả năng kiểm tra tự động trước rủi ro phụ thuộc (dependency), cú pháp và mức độ tương thích trước khi kích hoạt hành động vận chuyển.

### 1.2. Mục tiêu Dự án SCORT
Bộ giải pháp **SCORT (SAP Cross-system Object Replication Toolkit)** được xây dựng nhằm giải quyết triệt để các bài toán trên bằng cách cung cấp một nền tảng quản trị vòng đời đối tượng SAP hiện đại:
- **Tự động hóa & Khép kín:** Cho phép Developer và Release Manager tự tra cứu, kiểm tra đối soát, phát hiện sai khác (Diff), xem trước (Preview), phân tích AI và áp dụng (Apply to Target) trực tiếp trên giao diện SAP Fiori chuẩn mực.
- **Rút ngắn chu kỳ vận chuyển:** Giảm thời gian kiểm tra và chuyển giao đối tượng từ nhiều ngày xuống còn vài phút.
- **Bảo toàn dữ liệu & Kiểm soát phiên bản (Audit Trail):** Mọi thao tác thay đổi hoặc xoá bỏ đều được snapshot và nén GZIP lưu trữ lịch sử theo phiên bản độc lập.

---

## 2. PHẠM VI DỰ ÁN (PROJECT SCOPE & BOUNDARIES)

### 2.1. Phạm vi thực thi (In-Scope)
Bộ tính năng chính thức được triển khai và nghiệm thu trong phiên bản 2.0 bao gồm:
1. **Module 1 - Repository Object Explorer & Search:**
   - Tra cứu đối tượng trên Local Server (đọc từ bảng danh mục hệ thống `TADIR` kết hợp `ENLFDIR`).
   - Tra cứu đối tượng trên Target Server giả lập (đọc từ bảng snapshot `ZA_SCORT_T`).
   - Đối soát đối chiếu trạng thái tồn tại song song (Existence Matrix: `BOTH`, `LOCAL_ONLY`, `TARGET_ONLY`).
   - Xem nhanh mã nguồn trực tiếp (Source Code Viewer) và thông tin cấu hình (Metadata Viewer).
2. **Module 2 - Transport Request Management (TR Search):**
   - Tìm kiếm TR/Task theo số TR (hỗ trợ cả TR Header lẫn Task con), Người tạo (Owner), Trạng thái (`D - Modifiable`, `R - Released`), Khoảng thời gian (Created Date) và Tên đối tượng chứa bên trong.
   - Hiển thị cấu trúc cây phả hệ đa cấp (TreeTable: Level 0 Request Cha -> Level 1 Task Con -> Level 2 Thư mục loại đối tượng -> Level 3 Đối tượng chi tiết).
   - Hiển thị danh sách phẳng (Flat List) hỗ trợ phân trang lớn và lọc đa trường.
3. **Module 3 - Code Compare & Monaco Diff Editor:**
   - So sánh trực quan mã nguồn 2 phía (Local Active Source vs Target Snapshot).
   - Tích hợp trình soạn thảo chuyên nghiệp Monaco Diff Editor với 2 chế độ: Song song (Side-by-Side) và Nội dòng (Inline Diff).
   - Tự động đánh dấu trực quan các dòng được Thêm mới (Added), Bị xoá (Removed) và Giữ nguyên (Unchanged).
4. **Module 4 - Safe TR Release Engine:**
   - Cho phép kích hoạt phát hành (Release) trực tiếp từ giao diện Fiori cho cả Task con và TR cha.
   - Tự động kiểm tra điều kiện tiên quyết: Bắt buộc tất cả các Task con phải được Release (`R`) trước khi cho phép Release TR cha.
   - Cơ chế cô lập Transaction (LUW Isolation) tránh dump hệ thống `CX_RAP_ILLEGAL_STATEMENT`.
5. **Module 5 - Selective Apply to Target & Deletion Audit:**
   - Cửa sổ xem trước (Preview Modal Dialog) hiển thị toàn bộ danh sách đối tượng sẽ được áp dụng sang Target.
   - Tính năng chọn lọc (Selective Apply): Cho phép người dùng đánh dấu chọn hoặc bỏ chọn từng object cụ thể theo nhu cầu deploy một phần.
   - Xử lý đồng bộ thao tác Xoá (Deletion Handling): Tự động phát hiện các đối tượng có cờ xoá (`OBJFUNC = 'D'`, `ACTIVITY = 'D'`, hoặc đã bị xoá trên Local) để xoá bản ghi metadata trên Target (`ZA_SCORT_T`) đồng thời ghi nhận phiên bản lịch sử mang trạng thái `DELETED` vào `ZA_SCORT_T_SRC`.
6. **Module 6 - AI Pre-check Assistant:**
   - Trợ lý AI tích hợp sẵn trên Dialog Apply to Target phân tích rủi ro toàn diện trước khi bấm Áp dụng.
   - Đánh giá phân loại 3 mức độ: `READY_TO_APPLY` (An toàn), `PARTIAL_RECOMMENDED` (Rủi ro trung bình - có thể áp dụng một phần), `BLOCK_RECOMMENDED` (Rủi ro cao - khuyến nghị chặn).
   - Nút hành động "Áp dụng khuyến nghị AI" (Apply AI Recommendation) tự động tích chọn các đối tượng an toàn và bỏ chọn các đối tượng rủi ro.

### 2.2. Phạm vi ngoài dự án (Out-of-Scope)
Các tính năng sau không nằm trong phạm vi nghiệm thu phiên bản hiện tại:
- Trực tiếp sửa đổi mã nguồn (Write/Edit Code) trên môi trường Target thực tế thông qua mạng WAN bên ngoài mà không qua giao thức vận chuyển chuẩn của SAP.
- Tự động giải quyết xung đột mã nguồn 3 chiều (3-way automatic code merge) ở mức dòng lệnh mà không có sự kiểm tra của lập trình viên.
- Phê duyệt quy trình chuyển đổi đa bước (Multi-tier Workflow Approval) qua email hoặc SAP Business Workflow.

### 2.3. Giả định & Ràng buộc (Assumptions & Constraints)
- **Hệ thống mục tiêu:** Hệ sinh thái SAP S/4HANA On-Premise hoặc SAP S/4HANA Private Cloud (kiểm thử trên System S40, Client 324).
- **Môi trường kết nối:** Mạng nội bộ doanh nghiệp hoặc qua kết nối SAP Cloud Connector / VPN bảo mật.
- **Quyền hạn người dùng:** Người dùng thao tác phải được cấp các quyền Authorization chuẩn của SAP về quản lý phát triển (`S_DEVELOP`, `S_TRANSPRT`).

---

## 3. YÊU CẦU CHỨC NĂNG CHI TIẾT (FUNCTIONAL REQUIREMENTS)

### FR-01: Tra cứu & Lọc Repository Objects Đa Hệ Thống
- **Mô tả:** Hệ thống cung cấp bảng điều khiển tra cứu toàn diện các đối tượng phát triển (Programs, Classes, Function Modules, CDS Views, Tables, v.v.).
- **Đầu vào:**
  - `ObjectName`: Tên đối tượng, hỗ trợ ký tự đại diện Wildcard (ví dụ: `ZSCORT*`, `ZCL_*`).
  - `ObjectType`: Loại đối tượng (PROG, CLAS, FUNC, DDLS, TABL, DEVC, v.v.).
  - `Package`: Gói phát triển (`DEVCLASS`), hỗ trợ wildcard (ví dụ: `ZSCORT*`, `$TMP`).
  - `PersonResponsible`: Tên người chịu trách nhiệm (`AS4USER` / `AUTHOR`).
- **Xử lý nghiệp vụ:**
  - Tab 1 (**Local - TADIR**): Đọc trực tiếp từ bảng `TADIR` hệ thống và `ENLFDIR` (cho Function Modules). Bắt buộc tối thiểu 1 tiêu chí tìm kiếm để chống tràn bộ nhớ và treo hệ thống.
  - Tab 2 (**Target - Snapshot**): Đọc từ bảng lưu trữ snapshot Target `ZA_SCORT_T`.
  - Tab 3 (**Existence Matrix**): Gọi Custom Entity `ZCE_SCORT_MATRIX` thực thi thuật toán Merge-Sort 3 trục (`PGMID` -> `OBJECT` -> `OBJ_NAME`) để gắn cờ:
    - `BOTH`: Tồn tại trên cả hai hệ thống.
    - `LOCAL_ONLY`: Chỉ mới có trên Local, chưa đồng bộ sang Target.
    - `TARGET_ONLY`: Chỉ có trên Target, đã bị xoá hoặc chưa có trên Local.
- **Tác vụ trên dòng (Row Actions):**
  - Nút **Compare**: Mở giao diện so sánh trực tiếp đối tượng với Target.
  - Nút **Source/Metadata**: Xem nhanh mã nguồn hoặc thông tin thuộc tính của đối tượng.
  - Nút **Find Assigned TR (Icon xe tải)**: Tự động chuyển hướng sang màn hình TR Search để tìm kiếm các Transport Request đang chứa đối tượng này.

---

### FR-02: Quản Lý & Duyệt Cây Phân Cấp Transport Request (TR Search)
- **Mô tả:** Cung cấp góc nhìn toàn diện về các gói vận chuyển Transport Request và Task con trong hệ thống CTS.
- **Đầu vào tìm kiếm:** Số TR (`TRKORR`), Người sở hữu (`OWNER`), Trạng thái TR (`TRSTATUS`: `D - Modifiable`, `R - Released`), Ngày tạo (`DateFrom`, `DateTo`), Tên Object hoặc Loại Object.
- **Xử lý nghiệp vụ:**
  - Hỗ trợ 2 chế độ hiển thị:
    - **Chế độ TR Tree (Hierarchical TreeTable):**
      - Level 0: Transport Request Cha (Header TR - ví dụ `S40K913364`).
      - Level 1: Development/Correction Task Con (ví dụ `S40K913365`).
      - Level 2: Nhóm thư mục phân loại Object (ví dụ: Function Module, Class Definition, Program).
      - Level 3: Đối tượng cụ thể kèm hành động trực tiếp.
    - **Chế độ Flat List (Danh sách phẳng):** Danh sách chi tiết từng đối tượng gắn với Task và TR quản lý hiện thời (`CurrentManagingTr`).
  - **Tác vụ:**
    - Release nhanh từng Task con hoặc Release toàn bộ TR cha.
    - Mở chi tiết TR (Detail View) để thực hiện đối soát hàng loạt và áp dụng sang Target.
    - Xem nhanh Source Code của từng đối tượng trong cây.

---

### FR-03: So Sánh Mã Nguồn Đối Soát (Git-Style Side-by-Side Diff)
- **Mô tả:** Trực quan hoá sự khác biệt mã nguồn giữa phiên bản đang hoạt động tại Local (Local Active Source) và phiên bản snapshot lưu tại Target.
- **Xử lý nghiệp vụ:**
  - Hỗ trợ các đối tượng text-based: `PROG`, `CLAS`, `FUNC`, `DDLS`, `BDEF`, `TABL`, `INTF`, v.v.
  - Tích hợp trình biên tập **Monaco Diff Editor** độ nét cao.
  - Phân tích và highlight từng dòng:
    - Màu xanh lá cây (**Added**): Dòng mã nguồn mới được bổ sung trên Local.
    - Màu đỏ (**Removed**): Dòng mã nguồn đã bị xoá trên Local so với Target.
    - Màu xám/không đổi (**Unchanged**): Dòng mã nguồn đồng nhất giữa 2 bên.
  - Bảng thống kê tóm tắt: Tổng số dòng Local, Tổng số dòng Target, Trạng thái Hash đồng nhất (`MATCH` / `DIFF`), Trạng thái tổng thể.
  - Xử lý biên (Edge case): Đối tượng chưa từng tồn tại trên Target (`New at Target`) -> Toàn bộ dòng Local được coi là Added mà không gây lỗi thuật toán so khớp.

---

### FR-04: Quy Trình Release Transport Request An Toàn (Safe TR Release)
- **Mô tả:** Kích hoạt chức năng phát hành gói vận chuyển CTS chuẩn từ giao diện Fiori mà không cần truy cập SAP GUI `SE09`.
- **Điều kiện tiên quyết (Pre-validations):**
  - **Quy tắc Task trước TR:** Nếu người dùng yêu cầu Release TR cha, hệ thống phải quét toàn bộ các Task con trực thuộc. Nếu còn bất kỳ Task con nào chưa Release (`TRSTATUS <> 'R'`), hệ thống **chặn ngay lập tức** và thông báo đích danh danh sách Task con đang mở.
  - **Xác thực kết quả thực tế:** Sau khi kích hoạt API phát hành `TR_RELEASE_REQUEST`, hệ thống đọc lại trực tiếp từ bảng `E070` để xác nhận `TRSTATUS` đã chuyển sang `R` (Released) hoặc `N` (Released protected). Nếu vẫn ở trạng thái `D`, hệ thống ghi nhận thất bại và trả thông báo lỗi chi tiết từ SAP CTS (Object check error, Enqueue error, v.v.).
  - **Xử lý tiến trình nền (Export in progress - Status O):** Nếu TR đang trong quá trình export dữ liệu vật lý ra hệ điều hành (`TRSTATUS = 'O'`), hệ thống tự động chờ và poll trạng thái tối đa 8 giây trước khi phản hồi người dùng.

---

### FR-05: Áp Dụng Snapshot Vào Target Giả Lập & Xử Lý Xoá (Apply to Target)
- **Mô tả:** Đồng bộ các đối tượng trong Transport Request vào cơ sở dữ liệu môi trường Target (`ZA_SCORT_T` và `ZA_SCORT_T_SRC`).
- **Quy trình thực hiện:**
  1. Người dùng bấm nút **Apply to Target** trên màn hình chi tiết TR.
  2. Hệ thống hiển thị **Cửa sổ Xem trước & Chọn lọc (Apply to Target Preview & Selection Dialog)**.
  3. Bảng danh sách hiển thị chi tiết từng đối tượng: Loại đối tượng, Tên đối tượng, Gói (Package), Trạng thái so sánh (Compare Status: NEW, DIFF, IDENTICAL), và Hành động dự kiến (UPDATE, INSERT, DELETE).
  4. Người dùng có quyền:
     - Chọn toàn bộ đối tượng (Select All).
     - Bỏ chọn các đối tượng chưa muốn áp dụng (Selective Exclusion).
     - Nhấn nút **"Áp dụng khuyến nghị AI"** để tự động tích chọn các đối tượng an toàn theo tư vấn của AI.
  5. Khi người dùng bấm **Confirm Apply**:
     - Với các đối tượng chỉnh sửa/tạo mới: Hệ thống đọc mã nguồn Local, nén chuẩn GZIP, cập nhật phiên bản mới nhất vào `ZA_SCORT_T` và lưu chuỗi nhị phân nén vào `ZA_SCORT_T_SRC`.
     - Với các đối tượng bị xoá (`OBJFUNC = 'D'`, `ACTIVITY = 'D'`, hoặc đã bị xoá trên Local): Hệ thống thực hiện xoá bản ghi metadata trên `ZA_SCORT_T` và ghi nhận một phiên bản lịch sử mang trạng thái `DELETED` vào `ZA_SCORT_T_SRC` để bảo toàn vết kiểm toán (Audit Trail).

---

### FR-06: Trợ Lý AI Đánh Giá Rủi Ro Vận Chuyển (AI Pre-check Assistance)
- **Mô tả:** Tích hợp mô hình ngôn ngữ lớn (LLM) hỗ trợ thẩm định rủi ro kỹ thuật trước khi đồng bộ đối tượng sang Target.
- **Nội dung thẩm định:**
  - Kiểm tra rủi ro phụ thuộc chéo (Cross-object Dependency Risk).
  - Đánh giá khả năng xung đột mã nguồn (Conflict & Overwrite Risk).
  - Phát hiện các bất thường về cấu trúc hoặc xóa nhầm đối tượng dùng chung.
- **Phân loại kết quả:**
  - `READY_TO_APPLY` (Màu xanh - Safe): Toàn bộ đối tượng an toàn, cú pháp hoàn chỉnh, có thể đồng bộ ngay 100%.
  - `PARTIAL_RECOMMENDED` (Màu vàng - Warning): Một số đối tượng có cảnh báo rủi ro (ví dụ chưa hoàn thiện hoặc có sự chênh lệch lớn); khuyến nghị chỉ đồng bộ các đối tượng an toàn.
  - `BLOCK_RECOMMENDED` (Màu đỏ - Danger): Phát hiện lỗi cú pháp nghiêm trọng hoặc thiếu hụt dependency; khuyến nghị dừng toàn bộ quy trình để khắc phục trước.
- **Tác vụ tương tác:** Nút **"Apply AI Recommendation"** trên giao diện tự động bật/tắt các checkbox trên bảng đối tượng đúng theo danh sách `should_apply = true/false` do AI đề xuất.

---

### FR-07: Quốc Tế Hoá & Đa Ngôn Ngữ Giao Diện (i18n Globalization)
- **Mô tả:** Ứng dụng hỗ trợ trải nghiệm người dùng toàn cầu với menu chuyển đổi ngôn ngữ thời gian thực ngay trên thanh tiêu đề ứng dụng (Header Bar).
- **Danh sách ngôn ngữ hỗ trợ đầy đủ:**
  - 🇬🇧 Tiếng Anh (`en` / `en_US` - Mặc định).
  - 🇻🇳 Tiếng Việt (`vi`).
  - 🇯🇵 Tiếng Nhật (`ja`).
  - 🇨🇳 Tiếng Trung (`zh`).
  - 🇩🇪 Tiếng Đức (`de`).
- **Phạm vi dịch:** 100% nhãn giao diện (Labels), thông báo thành công/cảnh báo/lỗi (Messages, MessageToast, MessageBox), tooltip, tiêu đề bảng và nội dung phản hồi của Trợ lý AI.

---

## 4. QUY TẮC NGHIỆP VỤ CHẶT CHẼ (BUSINESS RULES)

| Mã Quy Tắc | Tên Quy Tắc | Mô Tả Chi Tiết & Ràng Buộc Kỹ Thuật |
|---|---|---|
| **BR-01** | **Phân cấp CTS Task-Request** | Mọi thay đổi mã nguồn trong SAP CTS bắt buộc phải nằm trong **Task con** (`E071-TRKORR = Task`). Header TR (`E070-TRKORR`) chỉ đóng vai trò bao đóng quản lý. Khi tìm kiếm TR theo số Request, hệ thống phải tự động truy vấn cả Task con và Header TR. |
| **BR-02** | **Thứ tự Release Bắt Buộc** | Nghiêm cấm phát hành Header TR khi vẫn còn ít nhất một Task con trực thuộc ở trạng thái Modifiable (`TRSTATUS <> 'R'`). Hành động cố tình Release TR cha sẽ bị hệ thống huỷ bỏ ngay từ tầng validation trước khi gọi SAP Kernel. |
| **BR-03** | **Cô lập LUW trong Action** | Mọi lời gọi API của SAP CTS (`TR_RELEASE_REQUEST`) hoặc thao tác lưu trữ Target có câu lệnh `COMMIT WORK` bắt buộc phải được bọc trong Function Module RFC-enabled gọi qua `DESTINATION 'NONE'`. Tuyệt đối không thực thi `COMMIT WORK` trực tiếp trong transactional buffer của RAP Action để ngăn chặn triệt để lỗi dump `CX_RAP_ILLEGAL_STATEMENT`. |
| **BR-04** | **Bảo toàn Audit Trail khi Xoá** | Khi một đối tượng bị xoá khỏi hệ thống, Target không được phép xoá sạch lịch sử. Metadata tại `ZA_SCORT_T` được dọn dẹp để phản ánh đúng hiện trạng, nhưng bảng lưu trữ phiên bản `ZA_SCORT_T_SRC` bắt buộc phải ghi nhận bản ghi phiên bản mới mang cờ `DELETED` kèm định danh TR, người xoá và thời gian thực thi. |
| **BR-05** | **Toàn vẹn Nén GZIP** | Mọi nội dung mã nguồn lưu trữ trong bảng `ZA_SCORT_T_SRC` phải được mã hoá nén chuẩn GZIP nhị phân thông qua tiện ích không trạng thái `ZCL_SCORT_COMPRESSION_UTL` để tiết kiệm tối thiểu 70% dung lượng database. |
| **BR-06** | **Quyền Phủ Quyết của Người Dùng** | Đánh giá và khuyến nghị của Trợ lý AI mang tính chất tư vấn và hỗ trợ ra quyết định. Người dùng có toàn quyền bật/tắt thủ công bất kỳ checkbox đối tượng nào trong Dialog Preview trước khi bấm xác nhận Apply. |
| **BR-07** | **Lọc Tối Thiểu để Bảo Vệ DB** | Màn hình tìm kiếm Repository Object và TR Search bắt buộc người dùng phải cung cấp ít nhất một tiêu chí lọc (Tên, Loại, Gói, Người tạo hoặc Số TR). Tuyệt đối không cho phép quét toàn bộ bảng (`SELECT *`) không điều kiện để bảo vệ hiệu năng hệ thống máy chủ SAP. |
| **BR-08** | **Nguyên tắc Merge-Sort 3 Trục** | Việc đối soát trạng thái tồn tại (Existence Matrix) giữa Local và Target phải được xử lý thông qua thuật toán Merge-Sort đồng thời 3 trường định danh (`PGMID -> OBJECTTYPE -> OBJECTNAME`) để đảm bảo không bị sót các đối tượng con như `LIMU FUNC` thuộc các Function Group `R3TR FUGR`. |

---

## 5. ĐẦU RA KỲ VỌNG THEO NGHIỆP VỤ (EXPECTED BUSINESS OUTPUTS)

| Chức Năng | Hành Động Của Người Dùng | Đầu Ra Kỳ Vọng Trên Giao Diện (UI Output) | Đầu Ra Dữ Liệu & Hệ Thống (System Output) |
|---|---|---|---|
| **Tìm kiếm Object** | Nhập `ZSCORT*` và bấm [Search] | Bảng Grid Table hiển thị danh sách các object phù hợp kèm Badge trạng thái existence (Xanh: Both, Vàng: Local Only, Đỏ: Target Only). | OData trả về danh sách đối tượng tối đa 500 dòng phân trang nhanh dưới 1.5 giây. |
| **Xem Diff Mã Nguồn** | Bấm nút [Compare] trên dòng đối tượng | Màn hình mở rộng sang cột thứ 3 (EndColumn FCL), nạp Monaco Editor hiển thị mã nguồn Local bên trái, Target bên phải kèm highlight sai khác. | API `ZSD_SCORT_COMPARE` đọc mã nguồn Local qua SAP API và giải nén phiên bản Target từ `ZA_SCORT_T_SRC`. |
| **Release Task Con** | Bấm nút [Release] tại dòng Task `S40K913365` | Hiển thị thông báo Toast "Task S40K913365 released successfully". Icon dòng Task đổi sang dấu tích xanh. | Trạng thái của Task trong bảng `E070-TRSTATUS` chuyển thành `R`. |
| **Release TR Cha (Hợp lệ)** | Tất cả Task con đã `R`, bấm [Release] trên dòng TR cha `S40K913364` | Hiển thị thông báo "Transport Request S40K913364 released successfully". Icon TR đổi sang tích xanh. | `E070-TRSTATUS` của TR chuyển thành `R`. CTS tạo file cúc vận chuyển vật lý trong thư mục `cofiles` và `data`. |
| **Release TR Cha (Không hợp lệ)** | Còn Task con `S40K913365` đang Modifiable `D`, bấm [Release] TR cha | Hộp thoại lỗi xuất hiện: "Release task first: S40K913365 (status D)". Quy trình dừng lập tức. | Không có thay đổi nào trong `E070`. Không phát sinh file transport lỗi. |
| **Preview Apply to Target** | Bấm [Apply to Target] trên Detail view của TR | Dialog modal xuất hiện: Bảng danh sách đối tượng, checkbox lựa chọn, thẻ đánh giá AI ban đầu. | Hệ thống nạp danh sách đối tượng từ `E071`, đọc Compare Status hiện thời của từng object. |
| **Kích hoạt Phân Tích AI** | Bấm nút [Analyze with AI] trong Dialog | Thẻ AI hiển thị biểu tượng Loading, sau đó hiển thị Verdict (Ready/Partial/Block), tóm tắt phân tích và lý do kỹ thuật. | Frontend gửi danh sách đối tượng tới endpoint `/sap/bc/zscort_ai`, nhận JSON kết quả đánh giá phân tầng. |
| **Áp Dụng Khuyến Nghị AI** | Bấm nút [Apply AI Recommendation] | Các checkbox của đối tượng an toàn được tự động đánh dấu tích; các đối tượng rủi ro bị bỏ dấu tích. | Client-side JSONModel cập nhật trạng thái `selected = true/false` cho từng hàng. |
| **Xác Nhận Apply to Target** | Bấm nút [Confirm Apply] | Hiển thị ProgressBar/BusyIndicator, sau đó thông báo thành công: "Applied X object(s) to Target successfully". Dialog đóng lại. | Bảng `ZA_SCORT_T` được cập nhật metadata; `ZA_SCORT_T_SRC` ghi nhận version mới nén GZIP; object xoá có version 'DELETED'. |

---

## 6. TIÊU CHÍ NGHIỆM THU ĐO LƯỜNG ĐƯỢC (ACCEPTANCE CRITERIA)

### 6.1. Bảng Tiêu chí Nghiệm thu BDD (Given - When - Then)

#### Kịch bản 1: Release Task con thành công
- **Given:** Người dùng đang ở màn hình TR Search (Tree View) và nhìn thấy Task con `S40K913365` đang ở trạng thái Modifiable (`D`).
- **When:** Người dùng bấm nút **Release** trên dòng Task `S40K913365` và xác nhận trên hộp thoại.
- **Then:**
  - Hệ thống gọi hàm `Z_SCORT_TR_RELEASE_LOCAL` với `DESTINATION 'NONE'`.
  - Hệ thống đọc lại `E070` xác nhận `TRSTATUS = 'R'`.
  - Giao diện Fiori hiển thị MessageToast thông báo thành công và cập nhật trạng thái dòng thành `Released`.

#### Kịch bản 2: Chặn Release TR cha khi còn Task con mở (Unhappy Case)
- **Given:** Transport Request `S40K913364` có 2 Task con: `S40K913365` (đã `R`) và `S40K913366` (vẫn `D`).
- **When:** Người dùng bấm nút **Release** trên dòng TR cha `S40K913364`.
- **Then:**
  - Tầng BDEF validation quét bảng `E070` phát hiện Task `S40K913366` chưa hoàn thành.
  - Hệ thống trả về lỗi thông báo tường minh: *"Release task first: S40K913366 (status D)"*.
  - Tuyệt đối không gọi lệnh phát hành SAP CTS và không làm thay đổi trạng thái của TR cha.

#### Kịch bản 3: Áp dụng chọn lọc (Selective Apply) sang Target
- **Given:** Cửa sổ Preview hiển thị 3 đối tượng trong TR: `ZCL_A` (DIFF), `ZCL_B` (NEW), `ZPROG_C` (DIFF).
- **When:** Người dùng bỏ tích chọn `ZPROG_C`, chỉ giữ tích chọn `ZCL_A` và `ZCL_B`, sau đó bấm **Confirm Apply**.
- **Then:**
  - Hệ thống gửi danh sách mảng đối tượng đã chọn (`it_selected_objects`) xuống backend `ZCL026_SCORT_TARGET_APPLY`.
  - Backend chỉ cập nhật snapshot cho `ZCL_A` và `ZCL_B` vào bảng `ZA_SCORT_T` và `ZA_SCORT_T_SRC`.
  - Đối tượng `ZPROG_C` hoàn toàn không bị tác động trên Target.

#### Kịch bản 4: Xử lý đối tượng xoá khi Apply to Target
- **Given:** TR chứa đối tượng `ZFUNC_OLD` mang cờ xoá (`OBJFUNC = 'D'`). Trên Target `ZA_SCORT_T` hiện đang có bản ghi của `ZFUNC_OLD`.
- **When:** Người dùng thực hiện Apply to Target cho TR này.
- **Then:**
  - Hệ thống tự động phát hiện cờ xoá.
  - Bản ghi metadata của `ZFUNC_OLD` trong bảng `ZA_SCORT_T` bị xoá bỏ (`DELETE`).
  - Bảng phiên bản `ZA_SCORT_T_SRC` được chèn một bản ghi mới với số version tăng lên và trường `AUTHOR` hoặc trạng thái mang nhãn `DELETED`.

#### Kịch bản 5: Trợ lý AI khuyến nghị chặn Apply khi có rủi ro nghiêm trọng
- **Given:** TR chứa đối tượng `ZCL_CORE` đang có lỗi cú pháp nghiêm trọng (Syntax Error) chưa kích hoạt được.
- **When:** Người dùng mở Dialog Apply Preview và bấm **Analyze with AI**.
- **Then:**
  - AI phân tích và trả về Verdict: `BLOCK_RECOMMENDED`.
  - Thẻ AI hiển thị cảnh báo viền đỏ, liệt kê chi tiết nguy cơ lỗi biên dịch trên môi trường đích.
  - Nút **Apply AI Recommendation** tự động vô hiệu hoá tích chọn của đối tượng bị lỗi.

---

### 6.2. Checklist Nghiệm thu Chức năng (Functional Verification Checklist)

| STT | Hạng Mục Kiểm Tra | Kết Quả Mong Đợi | Trạng Thái Đạt |
|:---:|---|---|:---:|
| 1 | Tìm kiếm Object với Wildcard `Z*` | Trả về danh sách chính xác không vượt quá giới hạn và không treo trình duyệt | [x] Đạt |
| 2 | Chuyển đổi qua lại giữa 3 Tab: Local, Target, Matrix | Dữ liệu chuyển đổi mượt mà, Matrix hiển thị chuẩn 3 trạng thái BOTH, LOCAL_ONLY, TARGET_ONLY | [x] Đạt |
| 3 | Mở Monaco Diff Editor cho Class/Program | Mã nguồn hiển thị 2 cột chuẩn xác, dòng thêm/xoá được đánh dấu màu rõ ràng | [x] Đạt |
| 4 | Tìm kiếm TR theo tên Object gán trong Task | Tìm thấy chính xác TR cha và Task con chứa object, không bị phụ thuộc vào độ tuổi của TR | [x] Đạt |
| 5 | Release Task con độc lập | Task chuyển trạng thái `R` thành công, `E070-TRSTATUS` cập nhật chuẩn | [x] Đạt |
| 6 | Validation chặn Release TR cha khi Task mở | Báo lỗi đích danh Task con chưa release, không làm hỏng dữ liệu CTS | [x] Đạt |
| 7 | Hiển thị Dialog Preview trước khi Apply | Bảng đối tượng liệt kê đầy đủ Tên, Loại, Gói, Compare Status và Action | [x] Đạt |
| 8 | Chọn lọc đối tượng Apply (Selective Apply) | Chỉ những đối tượng được đánh dấu checkbox mới được đồng bộ sang Target | [x] Đạt |
| 9 | Đồng bộ đối tượng xoá sang Target | Metadata trên Target bị xoá, version lịch sử ghi nhận trạng thái 'DELETED' | [x] Đạt |
| 10 | Đánh giá rủi ro bằng Trợ lý AI | Phân loại chuẩn 3 mức (Ready/Partial/Block), nút Apply AI Recommendation hoạt động chuẩn | [x] Đạt |
| 11 | Chuyển đổi 5 ngôn ngữ giao diện (EN, VI, JA, ZH, DE) | 100% nhãn và thông báo chuyển đổi đúng ngữ nghĩa thời gian thực | [x] Đạt |

---

## 7. YÊU CẦU PHI CHỨC NĂNG (NON-FUNCTIONAL REQUIREMENTS - NFRs)

1. **Hiệu Năng (Performance):**
   - Thời gian phản hồi cho tác vụ tìm kiếm danh sách đối tượng: $\le 1.5\text{ giây}$ cho 500 bản ghi đầu tiên.
   - Thời gian tải và hiển thị Monaco Diff Editor cho file mã nguồn $\le 2,000\text{ dòng}$: $\le 1.0\text{ giây}$.
   - Thời gian giải nén và nạp snapshot từ cơ sở dữ liệu: $\le 0.5\text{ giây}$.
2. **Độ Tin Cậy & Tính Toàn Vẹn Dữ Liệu (Reliability & Integrity):**
   - 100% các thao tác ghi dữ liệu có nguy cơ commit ngầm đều được cô lập qua RFC LUW, đảm bảo **tỷ lệ dump hệ thống bằng 0%**.
   - Cơ sở dữ liệu luôn ở trạng thái nhất quán (Consistent State) ngay cả khi tiến trình mạng bị ngắt quãng giữa chừng.
3. **An Toàn & Bảo Mật (Security & Authorizations):**
   - Tuân thủ nghiêm ngặt cơ chế phân quyền Role-Based Access Control (RBAC) của SAP.
   - Chỉ người dùng có quyền `S_DEVELOP` và `S_TRANSPRT` mới được phép kích hoạt Release hoặc Apply to Target.
   - Các API Key của AI được mã hoá và xoay tua an toàn trong Secure Store / Environment Variables, không lộ ra phía Client.
4. **Khả Năng Tương Thích & Mở Rộng (Extensibility):**
   - Kiến trúc xây dựng trên chuẩn SAP RAP và SAPUI5 1.120+, sẵn sàng nâng cấp lên SAP S/4HANA các phiên bản mới nhất mà không cần viết lại mã nguồn.

---

## 8. MA TRẬN PHÂN CÔNG TRÁCH NHIỆM (RACI MATRIX)

| Tác Vụ / Quy Trình Nghiệp Vụ | Developer (Lập trình viên) | Release Manager (Quản trị phát hành) | SAP Basis Admin (Quản trị hệ thống) | QA / QC Tester (Kiểm thử) |
|---|:---:|:---:|:---:|:---:|
| Tra cứu Object & So sánh Diff mã nguồn | **R / A** | **C** | **I** | **R** |
| Chỉnh sửa và gán Object vào Task con | **R / A** | **I** | **I** | **I** |
| Release Task con sau khi hoàn tất dev | **R / A** | **I** | **I** | **C** |
| Thẩm định rủi ro bằng AI Pre-check | **C** | **R / A** | **I** | **C** |
| Quyết định lựa chọn Selective Apply | **C** | **R / A** | **I** | **I** |
| Xác nhận Apply to Target sang môi trường giả lập | **I** | **R / A** | **C** | **I** |
| Release Header TR để chuyển cảnh quan thật | **I** | **R / A** | **A** | **I** |
| Kiểm thử nghiệm thu các tiêu chí (AC Checklist) | **C** | **A** | **I** | **R** |

> *Ghi chú:*
> - **R (Responsible):** Người trực tiếp thực hiện công việc.
> - **A (Accountable):** Người chịu trách nhiệm phê duyệt cuối cùng cho kết quả.
> - **C (Consulted):** Người được tham vấn ý kiến chuyên môn.
> - **I (Informed):** Người được thông báo khi công việc hoàn thành.
