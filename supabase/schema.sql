-- ============================================================================
-- EA Dashboard — Supabase Schema
-- โหมด: ไม่มีระบบ login (ทุกคนที่มีลิงก์เข้าถึงข้อมูลชุดเดียวกันได้หมด)
-- วิธีใช้: เปิด Supabase Dashboard -> SQL Editor -> New query -> วางทั้งไฟล์นี้ -> Run
-- ============================================================================

-- เปิด extension สำหรับสร้าง UUID อัตโนมัติ
create extension if not exists "pgcrypto";

-- ----------------------------------------------------------------------------
-- ตาราง eas: หนึ่งแถว = EA หนึ่งตัว (ทั้ง Top10 เดิม และ EA ที่อัพโหลดเพิ่ม)
-- ----------------------------------------------------------------------------
create table if not exists eas (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,                 -- ชื่อไฟล์ต้นฉบับ เช่น US30_v1.81_RSI5545_ADXRising.mq5
  short_label     text not null,                  -- ชื่อย่อไว้แสดงผล เช่น "v1.81 RSI5545 ADXRising"
  family          text,                           -- กลุ่มเวอร์ชัน เช่น "v1.81.x"
  is_builtin      boolean not null default false, -- true = Top10 เดิมที่มากับระบบ, false = ผู้ใช้อัพโหลดเพิ่ม
  source_code     text,                           -- โค้ด .mq5 เต็ม (เก็บในตารางไว้ให้ค้นหา/แสดงง่าย)
  source_file_path text,                          -- path ในไฟล์ .mq5 ที่เก็บใน Storage bucket ea-sources (สำรอง/ดาวน์โหลดกลับ)
  report_file_path text,                          -- path ไฟล์รายงานผลเทสต้นฉบับ (.htm/.xlsx จาก MT5) ใน bucket backtest-reports
  orig_lot        numeric not null default 0.1,
  orig_deposit    numeric not null default 10000,
  trades          jsonb not null default '[]'::jsonb,  -- [{"t": 1578008763000, "p": 12.34}, ...] เวลา(ms)+กำไรขาดทุนต่อไม้
  flags           jsonb not null default '{}'::jsonb,  -- {"S1":1,"S2":1,"DI12":0,...} ผลตรวจจับ/กำหนด Logic feature
  di_gap_value    numeric,                        -- ค่า DI Gap (points) จริงของ EA ตัวนี้ ถ้ามี
  dismissed       boolean not null default false, -- ซ่อนจากรายการอัพโหลด (ไม่ใช่ลบ ใช้งานต่อได้ปกติ)
  deleted_at      timestamptz,                    -- soft delete (ยังกู้คืนได้) แทนการลบถาวร
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index if not exists idx_eas_deleted_at on eas (deleted_at);
create index if not exists idx_eas_is_builtin on eas (is_builtin);

-- ----------------------------------------------------------------------------
-- ตาราง ea_drafts: ใบสเปค/แผน EA ใหม่ที่สร้างจากเมนู "สร้าง EA ใหม่"
-- ----------------------------------------------------------------------------
create table if not exists ea_drafts (
  id              uuid primary key default gen_random_uuid(),
  base_code       text,        -- รหัส EA ต้นแบบ: อาจเป็นรหัส Top10 ในตัว (เช่น 'E09'), 'MASTER', หรือ id ของ EA ที่อัพโหลด (uuid ในรูป text)
                                -- ไม่ทำเป็น foreign key เพราะต้นแบบไม่ได้อยู่ในตาราง eas เสมอไป (Top10/Master ฝังอยู่ในโค้ดฝั่งหน้าเว็บ)
  base_label      text,        -- ชื่อแสดงผลของ EA ต้นแบบ ณ ตอนสร้างใบสเปค
  name            text not null,
  base_flags      jsonb not null default '{}'::jsonb,
  new_flags       jsonb not null default '{}'::jsonb,
  added_ids       jsonb not null default '[]'::jsonb,   -- รายการ id ฟีเจอร์ที่เพิ่มจากต้นแบบ
  removed_ids     jsonb not null default '[]'::jsonb,    -- รายการ id ฟีเจอร์ที่ตัดออกจากต้นแบบ
  base_source_code text,       -- โค้ดต้นแบบอ้างอิง (ถ้ามี) ไว้แสดงในใบสเปค
  base_mq5_name   text,
  generated_code_path text,    -- ถ้ามีการ generate .mq5 จริง (เฉพาะ Master Template) เก็บ path ใน Storage
  created_at      timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- อัพเดต updated_at อัตโนมัติทุกครั้งที่แก้แถวใน eas
-- ----------------------------------------------------------------------------
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_eas_updated_at on eas;
create trigger trg_eas_updated_at
  before update on eas
  for each row execute function set_updated_at();

-- ----------------------------------------------------------------------------
-- Row Level Security: เปิดใช้แต่อนุญาตให้ทุกคน (anon) อ่าน/เขียนได้หมด
-- เพราะเลือกโหมด "ไม่ต้อง login" — ถ้าอนาคตอยากเพิ่ม login ค่อยมาจำกัดสิทธิ์ตรงนี้เพิ่ม
-- ----------------------------------------------------------------------------
alter table eas enable row level security;
alter table ea_drafts enable row level security;

drop policy if exists "public read eas" on eas;
create policy "public read eas" on eas for select using (true);
drop policy if exists "public write eas" on eas;
create policy "public write eas" on eas for insert with check (true);
drop policy if exists "public update eas" on eas;
create policy "public update eas" on eas for update using (true) with check (true);

drop policy if exists "public read drafts" on ea_drafts;
create policy "public read drafts" on ea_drafts for select using (true);
drop policy if exists "public write drafts" on ea_drafts;
create policy "public write drafts" on ea_drafts for insert with check (true);
drop policy if exists "public update drafts" on ea_drafts;
create policy "public update drafts" on ea_drafts for update using (true) with check (true);
drop policy if exists "public delete drafts" on ea_drafts;
create policy "public delete drafts" on ea_drafts for delete using (true);

-- ============================================================================
-- เสร็จแล้ว — ขั้นตอนต่อไป: ไปตั้งค่า Storage bucket ตามไฟล์ supabase/storage_setup.md
-- ============================================================================
