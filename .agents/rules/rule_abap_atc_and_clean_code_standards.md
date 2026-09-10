---
description: Comprehensive ATC, SLIN, SAP Table Buffering, and Clean ABAP Standards
---

# ABAP ATC, Table Buffering & Clean Code Quality Standards

## 1. SAP Table Buffer Optimization & Bypass Prevention (CL_CI_TEST_BUFF_ACCESS)

### 1.1. Single-Record Buffered Tables (`TADIR`, `T100`, `T100U`, `TDEVC`, `TDEVCT`, `USR02`, `ENLFDIR`)
1. **Full Primary Key Requirement:**
   - Single-Record Buffering chỉ hoạt động khi dùng `SELECT SINGLE` và cung cấp **100% tất cả các trường khóa chính** (ví dụ: `SPRAS` + `DEVCLASS` cho `TDEVCT`, `SPRSL` + `ARBGB` cho `T100T`, `BNAME` cho `USR02`).
   - Thiếu bất kỳ trường khóa nào sẽ khiến Open SQL bypass bộ đệm và truy vấn thẳng xuống Database Engine.
2. **Table Splitting + SELECT SINGLE Pattern (Khuyến nghị ưu tiên):**
   - Khi cần đọc dữ liệu văn bản/mô tả kèm tập hợp bản ghi chính (ví dụ danh sách package hoặc danh mục message), **không dùng `LEFT OUTER JOIN`**:
     ```abap
     " Tách truy vấn đọc danh sách khóa:
     SELECT devclass FROM tdevc WHERE parentcl = @lv_parent INTO TABLE @DATA(lt_devc). "#EC CI_SGLSELECT

     " Đọc mô tả qua SELECT SINGLE với đủ khóa chính để tận dụng 100% Buffer:
     LOOP AT lt_devc INTO DATA(ls_d).
       SELECT SINGLE ctext FROM tdevct
         WHERE spras = @sy-langu AND devclass = @ls_d-devclass
         INTO @lv_ctext.
     ENDLOOP.
     ```
3. **Intentional Multi-Row / Fuzzy Search Suppression:**
   - Khi bắt buộc phải tìm kiếm mờ (`LIKE 'Z%'`), phân trang, hoặc đọc danh mục nhiều dòng từ bảng Single-Record Buffer qua `INTO TABLE`:
   - Bắt buộc gắn pseudo-comment chính thống của SAP Code Inspector ở cuối câu lệnh:
     ```abap
     SELECT msgnr, text FROM t100
       WHERE sprsl = @sy-langu AND arbgb = @lv_arbgb
       ORDER BY msgnr
       INTO TABLE @DATA(lt_msgs). "#EC CI_SGLSELECT
     ```

### 1.2. Buffered Tables in a JOIN
1. **Cơ chế:** Việc viết `JOIN` (INNER hay LEFT OUTER) liên quan đến bất kỳ bảng nào có cấu hình Buffering trong DDIC sẽ tự động bypass buffer Application Server.
2. **Giải pháp:**
   - Với quan hệ cha - con nhỏ: Tách 2 câu lệnh độc lập và ghép trên bộ nhớ ABAP bằng `HASHED TABLE` ($O(1)$).
   - Với các truy vấn tìm kiếm phức tạp bắt buộc phải JOIN trên Database (ví dụ `ENLFDIR` JOIN `TADIR` theo `FUGR`): Gắn pseudo-comment:
     ```abap
     SELECT f~funcname, t~devclass FROM enlfdir AS f
       INNER JOIN tadir AS t ON ...
       INTO TABLE @DATA(lt_data). "#EC CI_BUFFJOIN
     ```

### 1.3. DISTINCT on Buffered Tables
- Không dùng `SELECT DISTINCT` trên bảng có cấu hình Buffer vì Open SQL sẽ bypass bộ đệm.
- **Giải pháp:** Bỏ `DISTINCT` trong câu lệnh SQL, sau đó lọc trùng trên bộ nhớ ABAP:
  ```abap
  SELECT area FROM enlfdir WHERE ... INTO TABLE @DATA(lt_areas). "#EC CI_SGLSELECT
  SORT lt_areas BY area.
  DELETE ADJACENT DUPLICATES FROM lt_areas COMPARING area.
  ```

---

## 2. Modern HANA Pushdown vs FOR ALL ENTRIES (FAE Transformation)

1. **Thay thế FAE 2 bước bằng Relational INNER JOIN:**
   - Cảnh báo ATC: `SELECT * FOR ALL statement can be joined with SELECT statement`.
   - Trên nền tảng SAP HANA columnar database, phép `INNER JOIN` được đẩy trực tiếp xuống database engine, nhanh hơn và tiết kiệm RAM hơn việc kéo một mảng vào ABAP rồi chạy FAE.
   - Khi 2 bảng không bị ràng buộc bộ đệm (ví dụ `E070` và `E071`), luôn gộp thành 1 câu `INNER JOIN`:
     ```abap
     " Thay vì: SELECT trkorr FROM e071 ... rồi SELECT ... FROM e070 FOR ALL ENTRIES IN ...
     SELECT DISTINCT h~trkorr, h~strkorr
       FROM e070 AS h
       INNER JOIN e071 AS o ON o~trkorr = h~trkorr
       WHERE o~obj_name LIKE @lv_pattern
       INTO TABLE @DATA(lt_results).
     ```

---

## 3. Field Usage Optimization (Problematic SELECT * Statements)

1. **Cảnh báo ATC:** `Select-Statement can be transformed. X% of fields used`.
2. **Quy chuẩn:**
   - Tuyệt đối không dùng `SELECT *` hoặc `SELECT SINGLE *` khi logic phía sau chỉ sử dụng 1 vài trường (ví dụ chỉ lấy `current_version` từ `za05_scort_t` hoặc chỉ lấy `trkorr` từ `e070`).
   - Luôn định nghĩa cấu trúc dữ liệu tường minh hoặc dùng inline data với danh sách cột tường minh:
     ```abap
     SELECT SINGLE current_version FROM za05_scort_t
       WHERE pgmid = @ls_obj-pgmid AND object = @ls_obj-object AND obj_name = @ls_obj-obj_name
       INTO @DATA(lv_cur_ver).
     ```

---

## 4. Extended Program Check (SLIN) & Activation Invariants

1. **Cấu trúc DDIC hợp lệ:**
   - Không tồn tại cấu trúc `ABAPTXT` trong SAP DDIC chuẩn; kiểu dòng mã nguồn chuẩn là **`ABAPTXT255`**.
2. **Tuân thủ chữ ký Function Module chuẩn:**
   - `RPY_FUNCTIONMODULE_READ`: Bắt buộc truyền đủ 6 bảng `TABLES`: `import_parameter`, `changing_parameter`, `export_parameter`, `tables_parameter`, `exception_list`, `documentation`.
   - `TR_RELEASE_REQUEST`: Không tự ý khai báo exception tùy tiện (`CANCELLED`, `REPEAT_UNABLE`). Chỉ xử lý các exception chính thức hoặc `OTHERS = n`.
   - `SVRS_GET_VERSION`: Là Master API hợp nhất cho toàn bộ kho lưu trữ Version Database (VRS). Không viết các đoạn fallback gọi FM nội bộ với tham số suy đoán khi `SVRS_GET_VERSION` đã trả về lỗi (phiên bản không tồn tại).
3. **RAP Behavioral Implementation Types:**
   - Trong các Local Types của RAP Behavior Pool (`ZBP_IR_*`), khi gán dữ liệu cho kết quả `READ RESULT`, bắt buộc dùng:
     ```abap
     DATA ls_src LIKE LINE OF result.
     ```
     Không dùng kiểu Projected Entity (`zcr_scort_obj_src`) để tránh cảnh báo tương thích kiểu `MESSAGE GFW`.
