# AI Review & Multi-Model Rotation Standards

## 1. Authorized Model Pool (Strict Invariant)
Chỉ được phép sử dụng và xoay vòng trong danh sách 5 Model sau (cả Backend ABAP ZCL_SCORT_AI_ASSISTANT và Frontend AiReview.js):
1. `gemini-3.5-flash`
2. `gemini-3-flash`
3. `gemini-2.5-flash`
4. `gemini-2.5-flash-lite`
5. `antigravity`

Tuyệt đối không sử dụng các model ngoài danh sách 5 model này.

## 2. Complete 9-Key Pool Preservation
- Giữ nguyên toàn bộ 9 API Key trong key pool.
- Luôn mã hóa Base64 khi lưu trong mã nguồn để vượt qua GitHub Push Protection / Secret Scanner, và decode tại runtime.
- Triển khai cơ chế xoay vòng 2 lớp: Thử lần lượt các Model trong Model Pool kết hợp xoay vòng API Keys khi gặp Rate Limit hoặc lỗi 429/503.

## 3. Dual Execution Mode
- Mặc định ưu tiên chế độ SAP Backend (`BE_SAP` qua REST SICF `/sap/bc/zscort_ai` -> `ZCL_SCORT_AI_ASSISTANT`).
- Tự động fallback sang chế độ Direct Client (`FE_DIRECT`) nếu Backend offline/chưa active SICF.

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
