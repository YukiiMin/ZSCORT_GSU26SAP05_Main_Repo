---
description: Strict Git Workflow Standards - Prohibition of Autonomous Git Commit & Push
---

# Git Workflow & Remote Repository Standards

## 1. Absolute Prohibition on Autonomous Git Commit & Push (Strict Invariant)
- **NEVER execute `git commit` OR `git push` autonomously.**
- Running `git commit` and `git push` is **STRICTLY PROHIBITED** during any workflow, debugging, deployment, or execution loop unless the user explicitly gives a direct command in their prompt (e.g., *"commit cho tôi"*, *"push git nhé"*, *"commit và push lên github"*).
- Khi hoàn thành việc sửa mã nguồn, build, hoặc test:
  - Agent CHỈ kiểm tra trạng thái (`git status`, `git diff`).
  - Báo cáo kết quả rõ ràng cho người dùng.
  - **GIỮ NGUYÊN trạng thái uncommitted**, TUYỆT ĐỐI KHÔNG tự động `git add .`, `git commit` hay `git push` nếu người dùng chưa yêu cầu.

## 2. Permitted Read-Only Git Operations
- Agent được phép tự do sử dụng các lệnh đọc/kiểm tra trạng thái:
  - `git status`, `git diff`, `git log`
- Never include credentials, tokens, or unverified secrets in git commits.
