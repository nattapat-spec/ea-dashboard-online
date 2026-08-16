-- ============================================================================
-- Phase 2 migration — รันไฟล์นี้เพิ่มใน SQL Editor (ครั้งเดียว)
-- ปรับโครงสร้างตาราง ea_drafts ให้รองรับ Phase 2
-- (ปลอดภัย รันได้เลย เพราะตอนนี้ยังไม่มีข้อมูลอยู่ในตารางนี้)
-- ============================================================================

drop table if exists ea_drafts;

create table ea_drafts (
  id              uuid primary key default gen_random_uuid(),
  base_code       text,
  base_label      text,
  name            text not null,
  base_flags      jsonb not null default '{}'::jsonb,
  new_flags       jsonb not null default '{}'::jsonb,
  added_ids       jsonb not null default '[]'::jsonb,
  removed_ids     jsonb not null default '[]'::jsonb,
  base_source_code text,
  base_mq5_name   text,
  generated_code_path text,
  created_at      timestamptz not null default now()
);

alter table ea_drafts enable row level security;

drop policy if exists "public read drafts" on ea_drafts;
create policy "public read drafts" on ea_drafts for select using (true);
drop policy if exists "public write drafts" on ea_drafts;
create policy "public write drafts" on ea_drafts for insert with check (true);
drop policy if exists "public update drafts" on ea_drafts;
create policy "public update drafts" on ea_drafts for update using (true) with check (true);
drop policy if exists "public delete drafts" on ea_drafts;
create policy "public delete drafts" on ea_drafts for delete using (true);
