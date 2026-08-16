# ตั้งค่า Supabase Storage (สำหรับเก็บไฟล์ .mq5 และรายงานผลเทส)

ทำหลังจากรัน `schema.sql` เรียบร้อยแล้ว

## 1. สร้าง Bucket

ไปที่ Supabase Dashboard → **Storage** → **New bucket** สร้าง 2 buckets:

| ชื่อ Bucket | Public? | ใช้เก็บอะไร |
|---|---|---|
| `ea-sources` | Public | ไฟล์ `.mq5` ต้นฉบับของ EA แต่ละตัว |
| `backtest-reports` | Public | ไฟล์รายงานผลเทสต้นฉบับจาก MT5 (`.htm`, `.xlsx`) |

ตั้งเป็น **Public** เพราะเลือกโหมด "ไม่ต้อง login" — ไฟล์ที่อัพโหลดจะเปิดดู/ดาวน์โหลดได้ผ่านลิงก์ตรงๆ โดยไม่ต้องยืนยันตัวตน (เหมาะกับ workspace ส่วนตัว/ทีมเล็กที่ไว้ใจกัน — ถ้าอนาคตอยากปิดเป็น private + login ค่อยปรับทีหลังได้)

## 2. ตั้ง Storage Policy (ให้ทุกคนอัพโหลด/อ่านได้)

ไปที่ **Storage → Policies** สำหรับแต่ละ bucket แล้วเพิ่ม policy ใหม่ (หรือรันผ่าน SQL Editor ก็ได้):

```sql
-- อนุญาตให้ทุกคนอ่านไฟล์ได้ (ทั้ง 2 bucket)
create policy "public read ea-sources"
  on storage.objects for select
  using (bucket_id = 'ea-sources');

create policy "public read backtest-reports"
  on storage.objects for select
  using (bucket_id = 'backtest-reports');

-- อนุญาตให้ทุกคนอัพโหลดไฟล์ได้
create policy "public upload ea-sources"
  on storage.objects for insert
  with check (bucket_id = 'ea-sources');

create policy "public upload backtest-reports"
  on storage.objects for insert
  with check (bucket_id = 'backtest-reports');
```

## 3. โครงสร้างไฟล์ในแต่ละ Bucket

แนะนำให้ตั้งชื่อไฟล์แบบมี EA id นำหน้า เพื่อไม่ให้ชื่อไฟล์ชนกัน:

```
ea-sources/
  └── {ea_id}/US30_v1.81_RSI5545_ADXRising.mq5

backtest-reports/
  └── {ea_id}/ReportTester-12345.htm
```

โค้ดฝั่ง frontend (`assets/js/api.js`) จะสร้าง path แบบนี้ให้อัตโนมัติตอนอัพโหลด ไม่ต้องตั้งเอง

## 4. เอา URL + Anon Key มาใส่ในโค้ด

ไปที่ **Project Settings → API** จะเห็น 2 ค่านี้:

- **Project URL** เช่น `https://xxxxxxxxxxxx.supabase.co`
- **anon public key** (กุญแจสาธารณะ ใช้ฝั่ง frontend ได้ปลอดภัย เพราะถูกจำกัดสิทธิ์ด้วย RLS policy ที่ตั้งไว้แล้ว)

เอา 2 ค่านี้มาใส่ในไฟล์ `assets/js/supabaseClient.js` ตามที่ระบุใน README.md
