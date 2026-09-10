# AI Review & Multi-Model Rotation Standards

## 1. Authorized Model Pool (Strict Invariant)
Chỉ được phép sử dụng và xoay vòng trong danh sách 5 Model sau (được điều phối bởi Backend ABAP `ZCL_SCORT_AI_ASSISTANT`):
1. `gemini-3.5-flash`
2. `gemini-3-flash`
3. `gemini-2.5-flash`
4. `gemini-2.5-flash-lite`
5. `antigravity`

Tuyệt đối không sử dụng các model ngoài danh sách 5 model này.

## 2. Backend-Exclusive Key Storage & Zero FE API Keys
- Toàn bộ 9 API Key và cơ chế xoay tua chìa khóa (Key Rotation) được lưu trữ và thực thi ĐỘC QUYỀN tại Backend ABAP (`ZCL_SCORT_AI_ASSISTANT`).
- **TUYỆT ĐỐI KHÔNG** lưu trữ bất kỳ API Key nào (kể cả mã hóa Base64) trong mã nguồn Frontend (`AiReview.js`, UI5 Controllers).
- Frontend **KHÔNG BAO GIỜ** gọi trực tiếp tới endpoint bên ngoài của Google (`generativelanguage.googleapis.com`).

## 3. Strictly Backend-Driven AI Architecture
- 100% yêu cầu AI từ giao diện Fiori UI5 phải được định tuyến qua SAP SICF REST Handler: `/sap/bc/zscort_ai` (`ZCL_SCORT_AI_HTTP_HANDLER`).
- Áp dụng cho cả 3 tác vụ AI:
  1. `action: 'SYNTAX'` (Kiểm tra cú pháp, Clean ABAP audit).
  2. `action: 'TRANSPORT'` (Đánh giá khuyến nghị vận chuyển Transport).
  3. Pre-flight Selective Apply Risk Analysis (Phân tích rủi ro đóng gói TR Apply).
- Không triển khai cơ chế client-side fallback ra ngoài Internet để đảm bảo an toàn dữ liệu doanh nghiệp và tuân thủ kiểm định an ninh SAP.

## 4. Multilingual & SAP System Language Resolution (`sy-langu`)
- **Tự động nhận diện ngôn ngữ ở ABAP Backend:**
  - Tham số `iv_lang` của các method AI review mặc định là `space`.
  - Khi `iv_lang` để trống (`space`), Backend tự động đọc biến hệ thống SAP `sy-langu` (ngôn ngữ phiên đăng nhập Fiori Launchpad / SAP GUI / RFC) và ánh xạ sang ISO code tương ứng (`V` -> `vi`, `E` -> `en`, `D` -> `de`, `J` -> `ja`, `C`/`M` -> `zh`, `F` -> `fr`, `S` -> `es`, `P` -> `pt`, `K` -> `ko`, `I` -> `it`, `N` -> `nl`, `R` -> `ru`, `T` -> `tr`, `H` -> `th`).
  - Nếu Frontend truyền `iv_lang` cụ thể, giá trị này sẽ đóng vai trò ghi đè (override).
- **Quy chuẩn chỉ dẫn ngôn ngữ trong Prompt:**
  - Yêu cầu AI phản hồi hoàn toàn bằng ngôn ngữ đích của người dùng.
  - Luôn giữ nguyên các thuật ngữ kỹ thuật chuyên ngành SAP/ABAP (tên bảng, data element, cú pháp, keywords) bằng tiếng Anh để đảm bảo tính chuẩn xác và dễ hiểu cho Developer.

## 5. Model Selection UI Synchronization
- Cung cấp dropdown `<Select>` cho phép người dùng chủ động chọn 1 trong 5 Model cho phiên phân tích.
- Giá trị model được truyền xuyên suốt qua `sModel` / `iv_model` từ Frontend xuống Backend và làm điểm bắt đầu cho vòng lặp failover.
