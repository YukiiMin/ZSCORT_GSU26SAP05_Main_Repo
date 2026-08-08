- When a fault, error, or build failure occurs:
  - Attempt a MAXIMUM of 1 fix attempt at a time.
  - Validate the result immediately.
  - If the fix fails or creates new errors, STOP execution, explain the root cause, and wait for feedback. Do NOT recursively guess or rewrite code blindly.
  - Before modifying or creating any files:
  1. Scan existing workspace structure and code style.
  2. Outline a concise step-by-step implementation plan.
  3. Identify potential side effects or breaking changes before calling any write/edit tools.
  - Do NOT apologize for errors or include conversational fluff. Be direct and technical.
- Do NOT truncate code blocks with placeholders like "// rest of code remains unchanged" when replacing file contents.
- Prefer functional paradigms, strong typing, and guard clauses (early returns) to prevent nested code.
- For tasks requiring more than 3 steps, maintain a .agent_scratchpad.md file at the workspace root.
- Structure of scratchpad:
  - Current Goal
  - Progress / Completed Steps
  - Key Decisions Made
  - Remaining TODOs
- Read this file at the start of every iteration and update it before finishing your response.
- ALWAYS refer to ARCHITECTURE.md before creating new files or restructuring existing modules to ensure architectural consistency.
