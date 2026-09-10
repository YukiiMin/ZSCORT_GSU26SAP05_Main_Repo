---
description: Standards for Automated Fiori Deployment, FLP Security, and UI5 Runtime Compatibility
---

# SAP Fiori Deployment, FLP Security & UI5 Compatibility Standards

## 1. Headless UI5 Deployment Automation (`@sap/ux-ui5-tooling`)
1. **Interactive Prompt Prevention:**
   - Lệnh `fiori deploy` mặc định sẽ hỏi xác nhận `(Y/n)?` và thông tin đăng nhập `Username / Password`, làm treo tiến trình chạy tự động trong agent/terminal.
   - Bắt buộc truyền cờ `--yes` (`-y`) để tự động chấp thuận triển khai.
2. **Credential Handshake via Environment Variables:**
   - Sử dụng cờ `--username <VAR_NAME> --password <VAR_NAME>` kết hợp nạp biến môi trường trong PowerShell:
     ```powershell
     $env:SAP_USER="<USER>"; $env:SAP_PASSWORD="<PASSWORD>"; npx fiori deploy --config ui5-deploy.yaml --yes --username SAP_USER --password SAP_PASSWORD
     ```
   - Xác thực trước bằng cờ `--testMode true` để đảm bảo gói Package và Transport Request hợp lệ trước khi ghi đè thực tế.

## 2. SAPUI5 Runtime Compatibility on NetWeaver ABAP
1. **No Modern UI5 1.118+ Module Dependencies in Legacy Environments:**
   - Tuyệt đối không import các module chỉ có trên UI5 đời mới như `sap/base/i18n/Localization`, vì máy chủ NetWeaver sẽ trả về `404 Not Found` và gây lỗi crash Component (`Failed to resolve dependencies of Component.js`).
   - Sử dụng API cấu hình tương thích ngược phổ quát:
     ```javascript
     if (sap.ui.getCore && sap.ui.getCore().getConfiguration) {
       sap.ui.getCore().getConfiguration().setLanguage(sLanguage);
     }
     ```

## 3. SAP PFCG Role & Fiori Launchpad User Assignment Invariants
1. **No Wildcards in PFCG User Tab:**
   - Bảng `User Assignments` trong transaction `PFCG` KHÔNG hỗ trợ ký tự đại diện (wildcard `*`). Gõ `DEV*` sẽ bị hệ thống xem là một tài khoản có tên thật là `"DEV*"`.
   - Phân quyền hàng loạt (Mass Assignment) cho nhóm người dùng bắt buộc phải dùng transaction **`SU10`** (User Mass Maintenance).
2. **SU10 Search Help Hit Limit Awareness:**
   - Cửa sổ F4 Search Help trong `SU10` mặc định giới hạn 500 dòng (`500 Entries found`).
   - Cần thu hẹp bộ lọc (ví dụ `DEV-0*`) hoặc sử dụng tính năng **Selection Criteria** (`F5`) với ngưỡng Max Hits mở rộng để không bỏ sót tài khoản.
3. **Mandatory Authorization Profile Generation (`S_START`):**
   - Khi gán OData V4 Service (`G4BA`) vào tab Menu của Role, hệ thống sinh ra đối tượng kiểm tra quyền `S_START`.
   - Tab **Authorizations** sẽ ở trạng thái đèn ĐỎ (Profile not generated) cho đến khi người quản trị mở màn hình phân quyền và bấm **Generate (`Shift + F5`)**.
   - Nếu Profile chưa được sinh, người dùng mở app sẽ gặp lỗi `HTTP 403 Forbidden` / `No authorization to execute service`.
4. **FLP Cache Invalidation:**
   - Sau khi deploy giao diện mới hoặc gán Role Catalog/Group mới, luôn thực thi transaction **`/UI2/INVAL_CACHES`** (Client-wide) hoặc bổ sung URL parameter `&sap-cache=false` để Fiori Launchpad lập tức hiển thị thay đổi mà không bị lưu cache cũ.
