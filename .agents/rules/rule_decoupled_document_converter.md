---
description: Decoupled Document Architecture & PDF to DOCX 100% Fidelity Standard
---

# Quy chuẩn Chuyển đổi Tài liệu (Decoupled Document Architecture Standards)

## 1. Nguyên tắc cốt lõi: PDF → DOCX đạt chuẩn 100% trước tiên
- Chuyển đổi từ DOCX sang Markdown rất dễ dàng khi cấu trúc DOCX đã chuẩn.
- **Tiên quyết**: Quá trình chuyển đổi từ **PDF sang DOCX** phải đạt độ chính xác 100% về cả dữ liệu (không mất bullet, không mất cell/nội dung bảng) lẫn định dạng (màu heading `#C00000`, màu nền header bảng `#FFE8E0`, lề trang, dot leader tab stop).
- Tuyệt đối không nhảy cóc qua Markdown khi file DOCX nền móng chưa đạt chuẩn đối chiếu với PDF gốc.

## 2. Kiến trúc phân tách 2 tầng (Decoupled Data vs Presentation Layer)
Tương tự mô hình **HTML + CSS**:
1. **Data Layer (`[name].md`)**:
   - Chứa cấu trúc ngữ nghĩa và dữ liệu thuần túy (Headings `#`, Lists `- `, Tables GFM `| Col 1 | Col 2 |`, Text paragraphs, Media `![alt](path)`).
   - Tuyệt đối sạch sẽ, không chứa YAML Frontmatter hay thẻ `<style>` làm bẩn dữ liệu.
2. **Style Layer (`[name].style.yaml`)**:
   - Đóng vai trò như file stylesheet (CSS), lưu trữ:
     - `geometry`: lề trang (`top`, `bottom`, `left`, `right`), khổ giấy (`page_size`).
     - `typography`: kiểu font (`font_family`), cỡ chữ (`font_size`), màu chữ, khoảng cách dòng.
     - `headings`: màu sắc (`#C00000`), kích thước H1-H4.
     - `tables`: màu nền tiêu đề bảng (`header_background: '#FFE8E0'`), viền bảng (`border_color`), đệm ô.
     - `lists`: ký hiệu bullet, khoảng cách đoạn trước/sau.

## 3. Quy chuẩn bộ biên dịch 3 tầng (Bidirectional Compiler)
- **Tầng 1 (PDF -> DOCX v6)**: Sử dụng `smart_post_processor.py` trên nền OpenXML:
  - Đổ màu Peach `#FFE8E0` (`<w:shd>`) cho hàng 0 của 100% bảng.
  - Tách triệt để các đoạn văn bản gộp đa dòng (`\n`), bảo toàn đủ số lượng bullet items (`w:numPr`).
  - Chuẩn hóa toàn bộ dòng TOC thành Tab Stop căn phải có dot leader native.
- **Tầng 2 (Bóc tách)**:
  - Lệnh chuyển sang MD tự động sinh cặp file song song `[name].md` và `[name].style.yaml`.
- **Tầng 3 (Biên dịch tái tạo)**:
  - Tự động nạp file `[name].style.yaml` cùng tên (hoặc qua cờ `--style`) để tái tạo DOCX/PDF chuẩn xác 100% như tài liệu gốc.

## 4. Quy chuẩn Bảng biểu OpenXML (Word Table Invariants)
Bất kỳ bảng nào được tạo mới, chuyển đổi hoặc cập nhật trong tài liệu Word (`.docx`) đều phải tuân thủ nghiêm ngặt 4 quy tắc sau:
1. **Chống vỡ hàng qua trang (`<w:cantSplit/>`)**:
   - 100% các hàng (`trPr`) trong bảng phải có thẻ `<w:cantSplit/>`.
   - Tuyệt đối không để xảy ra hiện tượng 1 hàng bị cắt đôi giữa 2 trang văn bản. Nếu hàng không vừa ở cuối trang, toàn bộ hàng phải được chuyển sang đầu trang mới.
2. **Lặp lại hàng tiêu đề qua trang (`<w:tblHeader/>`)**:
   - Hàng 0 (`trPr`) của mọi bảng phải có thẻ `<w:tblHeader/>`.
   - Khi bảng kéo dài qua nhiều trang, tiêu đề cột phải tự động lặp lại ở đầu trang tiếp theo.
3. **Canh giữa toàn bộ text trong các ô theo chiều dọc (`<w:vAlign w:val="center"/>`)**:
   - 100% các ô (`tcPr`) phải có `<w:vAlign w:val="center"/>` và `cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER`.
   - Chữ ngắn (như tên Feature, trạng thái, ID) không bao giờ được dính sát mép trên mà phải nằm cân đối chính giữa ô theo chiều dọc.
4. **Quy chuẩn canh lề ngang (Horizontal Alignment)**:
   - Cột STT / Index (`#`): Canh giữa (`WD_ALIGN_PARAGRAPH.CENTER`).
   - Cột nội dung / mô tả / tên màn hình: Canh trái (`WD_ALIGN_PARAGRAPH.LEFT`).

## 5. Quy chuẩn Thiết kế Sơ đồ Kỹ thuật Mermaid (Mermaid Technical Diagram Styling)
Khi tạo sơ đồ luồng người dùng (Screen Flow), kiến trúc hệ thống hoặc quy trình nghiệp vụ:
1. **Hướng luồng Left-to-Right (`flowchart LR`)**:
   - Ưu tiên cấu trúc rẽ nhánh hình cây (Tree Fan-out) từ Trái qua Phải: Entry/Auth (Trái) -> Central Hub (Giữa) -> Feature Modules/Details/Profile (Phải).
   - Duy trì tỷ lệ khung hình cân đối từ 1.6:1 đến 2.0:1 (chiều rộng chuẩn 14.0cm, chiều cao 5-8cm trên trang dọc A4) để chữ to rõ và lấp đầy trang in.
2. **Đường nối trực giao vuông góc 90 độ (`curve: 'stepAfter'`)**:
   - Tuyệt đối không dùng đường cong spline làm dây nối chéo đè lên nhau. Dùng cấu hình trực giao gập chữ L (`curve: 'stepAfter'`).
   - Mọi kết nối chuyển trạng thái/màn hình phải có nhãn hành động rõ ràng (ví dụ: `|"Tap 'Profile' Tab"|`, `|"Valid Creds"|`).
3. **Phân cấp đường nét và kiểu dáng Node**:
   - Màn hình chính/quan trọng (`thickBox`): Nền trắng, viền đen nét đậm `stroke-width: 2.5px`, font chữ in đậm.
   - Màn hình phụ/thông thường (`default`): Nền trắng, viền đen nét chuẩn `stroke-width: 1.5px`.
   - Modal / Toast / Fallback (`modalBox`): Nền trắng, viền nét đứt `stroke-width: 1.5px, stroke-dasharray: 4 4`.
4. **Độ phân giải chuẩn in ấn (`scale: 3`)**:
   - Mermaid CLI (`mmdc`) khi xuất PNG phải luôn truyền cờ `-s 3` (tối thiểu 300-400 DPI) để ảnh sắc nét, không bị vỡ hạt khi chèn vào Word và xuất PDF.

