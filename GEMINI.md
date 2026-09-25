# Git Safety Protocols for AI Agents

**CRITICAL RULE: NEVER LOSE UNCOMMITTED WORK**

Whenever the user asks you to modify code, recover code, or switch branches, you MUST STRICTLY adhere to the following Git safety protocols:

1. **Check for Uncommitted Changes First**: Before running ANY destructive Git commands like `git checkout`, `git reset`, `git clean`, or `git restore`, you MUST run `git status` to check for uncommitted changes.
2. **Mandatory Backup**: If there are uncommitted changes, you MUST NOT proceed with destructive commands. You MUST either:
   - Create a backup copy of the un committed files (e.g., `cp filename filename.backup`).
   - Run `git stash` to safely store the changes.
   - Run `git commit -m "WIP"` to safely persist the changes.
3. **Ask for Permission**: If you are unsure whether the user wants to keep their uncommitted work, STOP and ask the user explicitly: "You have uncommitted changes. Do you want me to stash them, commit them, or discard them?"
4. **No Destructive Restores by Default**: Do not automatically try to restore files from `git log` or check out older commits to "fix" an issue unless the user explicitly commands it and you have verified that no new work will be lost.

By reading this rule, you acknowledge that destroying the user's uncommitted work is the highest severity failure. Always prioritize data preservation.

---

# 🛑 CRITICAL ARCHITECTURAL & SECURITY RULES (STRICTLY ENFORCED)

### 1. Client-Side Only Architecture
- **`hello_app` เป็น Mobile Client App (Flutter) 100%**
- **ห้ามเชื่อมต่อไปยัง Supabase หรือ Database โดยตรงเด็ดขาด!**
- การรับส่งข้อมูลทุกอย่างในแอป **ต้องผ่าน Backend API (`ApiService` / `AppConfig.baseUrl`) เท่านั้น**
- ตัว Backend (Next.js / Node.js) จะเป็นผู้เดียวที่จัดการติดต่อฐานข้อมูล

### 2. Zero Database Credentials in Client Apps
- **ห้ามใส่ Supabase URL, Supabase Keys หรือ Database Secrets ใดๆ ลงใน `.env` หรือโค้ดของ `hello_app` เด็ดขาด:**
  - ❌ `SUPABASE_URL`
  - ❌ `SUPABASE_ANON_KEY`
  - ❌ `SUPABASE_SERVICE_ROLE_KEY`
  - ❌ `DATABASE_URL` หรือรหัสผ่านฐานข้อมูล
- **เหตุผลความปลอดภัย:** ไฟล์ `.env` ของ `hello_app` ถูกลงทะเบียนใน `assets:` ของ `pubspec.yaml` ทำให้ไฟล์นี้ถูกแพ็กเข้าไฟล์ APK โดยตรง หากใส่คีย์ใดๆ ไว้จะกลายเป็นช่องโหว่ให้ถูกแกะ (Decompile) APK ออกมาดูได้ทันที

### 3. Prohibited Packages
- **ห้ามติดตั้งหรือ Import `supabase_flutter` หรือ Supabase SDK ในโปรเจกต์นี้เด็ดขาด**
- การต่อเน็ตเวิร์กของแอปใช้เพียงแพ็กเกจ `http` หรือ REST API client ปกติเท่านั้น
