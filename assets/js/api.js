/* ============================================================================
   api.js — ฟังก์ชันกลางทั้งหมดที่คุยกับ Supabase แทนที่ CUSTOM/IndexedDB เดิม
   หน้า dashboard (app.js) จะเรียกฟังก์ชันพวกนี้แทนการอ่าน/เขียน local state ตรงๆ
   ทุกฟังก์ชันเป็น async — ต้องใช้ await หรือ .then() ตอนเรียกใช้
   ============================================================================ */

/** ดึงรายชื่อ EA ที่อัพโหลดทั้งหมด รวมตัวที่ลบไว้ด้วย (หน้าเว็บจะกรอง/แยกแสดงเองฝั่ง client
    เพื่อให้ปุ่ม "กู้คืน" ยังเห็นข้อมูลของ EA ที่ถูกลบไว้ได้) */
async function apiListEAs(){
  const { data, error } = await sb
    .from('eas')
    .select('*')
    .order('created_at', { ascending: true });
  if (error) throw error;
  return data;
}

/** ดึง EA ตัวเดียวแบบเต็ม (รวม trades) ตาม id */
async function apiGetEA(id){
  const { data, error } = await sb.from('eas').select('*').eq('id', id).single();
  if (error) throw error;
  return data;
}

/**
 * อัพโหลด EA ใหม่: insert แถวข้อมูล metadata + trades ลงตาราง eas ก่อน
 * แล้วถ้ามีไฟล์ .mq5 แนบมาด้วย (mq5File ไม่ใช่ null) ค่อยอัพขึ้น Storage bucket ea-sources ต่อ
 * @param {File|null} mq5File - ไฟล์ .mq5 ต้นฉบับ (ไม่บังคับ — ส่ง null ได้ถ้าไม่มีไฟล์แนบ)
 * @param {object} meta - { name, short_label, family, orig_lot, orig_deposit, trades, flags, di_gap_value, source_code }
 */
async function apiUploadEA(mq5File, meta){
  // 1) insert แถว metadata ก่อนเพื่อเอา id มาใช้ตั้งชื่อไฟล์ใน storage
  const { data: row, error: insertErr } = await sb
    .from('eas')
    .insert({
      name: meta.name,
      short_label: meta.short_label,
      family: meta.family || null,
      is_builtin: false,
      source_code: meta.source_code,
      orig_lot: meta.orig_lot,
      orig_deposit: meta.orig_deposit,
      trades: meta.trades,
      flags: meta.flags,
      di_gap_value: meta.di_gap_value ?? null,
    })
    .select()
    .single();
  if (insertErr) throw insertErr;

  if (!mq5File) return row;

  // 2) อัพโหลดไฟล์ .mq5 จริงขึ้น Storage bucket โดยใช้ id เป็นชื่อโฟลเดอร์กันชนกัน
  const path = `${row.id}/${mq5File.name}`;
  const { error: uploadErr } = await sb.storage.from('ea-sources').upload(path, mq5File, { upsert: true });
  if (uploadErr) throw uploadErr;

  // 3) อัพเดต path ไฟล์กลับเข้าแถวข้อมูล
  const { data: updated, error: updateErr } = await sb
    .from('eas')
    .update({ source_file_path: path })
    .eq('id', row.id)
    .select()
    .single();
  if (updateErr) throw updateErr;

  return updated;
}

/** อัพโหลดไฟล์รายงานผลเทสต้นฉบับ (.htm/.xlsx) ผูกกับ EA ที่มีอยู่แล้ว */
async function apiUploadReport(eaId, file){
  const path = `${eaId}/${file.name}`;
  const { error: uploadErr } = await sb.storage.from('backtest-reports').upload(path, file, { upsert: true });
  if (uploadErr) throw uploadErr;
  const { data, error } = await sb.from('eas').update({ report_file_path: path }).eq('id', eaId).select().single();
  if (error) throw error;
  return data;
}

/** ลบแบบ soft-delete (ยังกู้คืนได้ ไม่ได้ลบไฟล์ใน storage) */
async function apiSoftDeleteEA(id){
  const { error } = await sb.from('eas').update({ deleted_at: new Date().toISOString() }).eq('id', id);
  if (error) throw error;
}

/** กู้คืน EA ที่ลบไว้ */
async function apiRestoreEA(id){
  const { error } = await sb.from('eas').update({ deleted_at: null }).eq('id', id);
  if (error) throw error;
}

/** ซ่อน/เลิกซ่อน chip แสดงผล (ไม่กระทบการใช้งานจริงของ EA) */
async function apiSetDismissed(id, dismissed){
  const { error } = await sb.from('eas').update({ dismissed }).eq('id', id);
  if (error) throw error;
}

/** ดึงใบสเปค (draft) ทั้งหมด */
async function apiListDrafts(){
  const { data, error } = await sb.from('ea_drafts').select('*').order('created_at', { ascending: false });
  if (error) throw error;
  return data;
}

/** สร้างใบสเปค EA ใหม่ */
async function apiCreateDraft(draft){
  const { data, error } = await sb.from('ea_drafts').insert(draft).select().single();
  if (error) throw error;
  return data;
}

/** ลบใบสเปค */
async function apiDeleteDraft(id){
  const { error } = await sb.from('ea_drafts').delete().eq('id', id);
  if (error) throw error;
}
