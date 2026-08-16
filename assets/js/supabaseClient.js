/* ============================================================================
   Supabase client init
   ตั้งค่า 2 ค่านี้ให้ตรงกับโปรเจกต์ของคุณ (Project Settings -> API ใน Supabase Dashboard)
   ============================================================================ */
const SUPABASE_URL = 'https://xiuxcbeqwkxhfypveyfe.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_RU4Xi3fsYKjzWN27k5FjYA_q-O3MjRS';

// ต้องโหลด supabase-js จาก CDN ก่อนไฟล์นี้ใน index.html:
// <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js"></script>
const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
