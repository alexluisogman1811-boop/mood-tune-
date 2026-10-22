/**
 * MoodScape feedback backend + admin dashboard (free, Google Apps Script).
 *
 * - POST (from the app): saves one feedback entry as a row in this sheet.
 * - GET ?key=PASSWORD: shows the admin dashboard (ratings, charts, comments).
 *
 * Setup: see tool/feedback_backend/README.md.
 */

// CHANGE THIS before deploying. Anyone with the password can see feedback.
const ADMIN_PASSWORD = 'change-me';

const SHEET_NAME = 'Feedback';
const HEADERS = [
  'Time', 'Overall', 'Songs fit', 'Easy to use', 'Recommend',
  'Improve', 'Comment', 'Language', 'Platform', 'App version', 'Install id',
];
const IMPROVE_LABELS = {
  moreSongs: 'เพลงเพิ่มขึ้น',
  betterMatches: 'เลือกเพลงให้ตรงขึ้น',
  moreLanguages: 'ภาษาเพิ่มขึ้น',
  moreActivities: 'กิจกรรมเพิ่มขึ้น',
  photo: 'การวิเคราะห์รูป',
  spotify: 'บันทึกลง Spotify',
  design: 'หน้าตาและดีไซน์',
  speed: 'ความเร็ว',
};
const RECOMMEND_LABELS = { yes: 'แนะนำ', maybe: 'อาจจะ', no: 'ไม่แนะนำ' };

function sheet_() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sh = ss.getSheetByName(SHEET_NAME);
  if (!sh) {
    sh = ss.insertSheet(SHEET_NAME);
    sh.appendRow(HEADERS);
    sh.setFrozenRows(1);
  }
  return sh;
}

function json_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

function stars_(v) {
  const n = Number(v);
  return Number.isInteger(n) && n >= 1 && n <= 5 ? n : '';
}

function text_(v, max) {
  return typeof v === 'string' ? v.slice(0, max) : '';
}

/** Receives feedback from the app. Validates everything it stores. */
function doPost(e) {
  try {
    const d = JSON.parse(e.postData.contents);
    const overall = stars_(d.overall);
    if (overall === '') return json_({ ok: false, error: 'overall' });
    const improve = Array.isArray(d.improvements)
      ? d.improvements.filter((k) => k in IMPROVE_LABELS).join(',')
      : '';
    const lock = LockService.getScriptLock();
    lock.waitLock(10000);
    try {
      sheet_().appendRow([
        new Date(), overall, stars_(d.songMatch), stars_(d.easeOfUse),
        d.recommend in RECOMMEND_LABELS ? d.recommend : '',
        improve,
        // A leading ' stops a comment being read as a spreadsheet formula.
        d.comment ? "'" + text_(d.comment, 500) : '',
        text_(d.language, 5), text_(d.platform, 20), text_(d.appVersion, 20),
        text_(d.installId, 32),
      ]);
    } finally {
      lock.releaseLock();
    }
    return json_({ ok: true });
  } catch (err) {
    return json_({ ok: false, error: 'bad request' });
  }
}

/** The admin dashboard. */
function doGet(e) {
  const key = (e.parameter && e.parameter.key) || '';
  const page = key === ADMIN_PASSWORD && ADMIN_PASSWORD !== 'change-me'
    ? dashboard_()
    : login_(key !== '');
  return HtmlService.createHtmlOutput(page)
    .setTitle('MoodScape · ผู้ดูแล')
    .addMetaTag('viewport', 'width=device-width, initial-scale=1');
}

function esc_(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[c]));
}

const STYLE = `<style>
  body{margin:0;background:#0E0C1A;color:#F3F0FF;font-family:system-ui,
    'Sarabun',sans-serif}
  main{max-width:1000px;margin:0 auto;padding:24px 16px 48px}
  h1{font-size:28px;margin:0 0 4px} h2{font-size:18px;margin:0 0 12px;color:#B6A8FF}
  .muted{color:#9C94C4;font-size:14px}
  .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));
    gap:12px;margin:20px 0}
  .card{background:#1B1730;border:1px solid #3A3260;border-radius:16px;padding:16px}
  .big{font-size:40px;font-weight:700;color:#B6A8FF}
  .row{display:flex;align-items:center;gap:10px;margin:6px 0}
  .row .l{width:150px;font-size:14px} .row .n{width:48px;text-align:right}
  .bar{flex:1;height:14px;background:#2A2448;border-radius:7px;overflow:hidden}
  .bar i{display:block;height:100%;background:#7C6CF2}
  table{width:100%;border-collapse:collapse;font-size:14px}
  td,th{padding:8px;border-bottom:1px solid #3A3260;text-align:left;vertical-align:top}
  input,button{font:inherit;padding:10px 12px;border-radius:10px;border:1px solid #3A3260}
  button{background:#7C6CF2;color:#0E0C1A;font-weight:700;border:0}
</style>`;

function login_(wrong) {
  const setup = ADMIN_PASSWORD === 'change-me'
    ? '<p class="muted">ตั้งรหัสผ่านใน Code.gs (ADMIN_PASSWORD) ก่อนใช้งาน</p>'
    : '';
  return `${STYLE}<main><h1>MoodScape · ผู้ดูแล</h1>
    <p class="muted">ใส่รหัสผ่านเพื่อดูแดชบอร์ด</p>${setup}
    ${wrong ? '<p style="color:#FF8A80">รหัสผ่านไม่ถูกต้อง</p>' : ''}
    <form method="get" target="_top" action="${ScriptApp.getService().getUrl()}">
      <input type="password" name="key" placeholder="รหัสผ่าน" autofocus>
      <button>เข้าสู่ระบบ</button></form></main>`;
}

function bars_(entries, total) {
  return entries.map(([label, n]) => {
    const pct = total ? Math.round((100 * n) / total) : 0;
    return `<div class="row"><span class="l">${esc_(label)}</span>
      <span class="bar"><i style="width:${pct}%"></i></span>
      <span class="n">${n}</span></div>`;
  }).join('');
}

function avg_(rows, col) {
  const v = rows.map((r) => r[col]).filter((x) => x !== '' && x != null);
  return v.length ? (v.reduce((a, b) => a + Number(b), 0) / v.length) : null;
}

function dashboard_() {
  const values = sheet_().getDataRange().getValues();
  const rows = values.slice(1);
  const total = rows.length;
  const fmt = (x) => (x == null ? '–' : x.toFixed(1));

  const starCounts = [5, 4, 3, 2, 1].map((s) => [
    '★'.repeat(s), rows.filter((r) => Number(r[1]) === s).length,
  ]);
  const improve = {};
  rows.forEach((r) => String(r[5] || '').split(',').filter(String)
    .forEach((k) => { improve[k] = (improve[k] || 0) + 1; }));
  const improveSorted = Object.entries(improve).sort((a, b) => b[1] - a[1])
    .map(([k, n]) => [IMPROVE_LABELS[k] || k, n]);
  const rec = { yes: 0, maybe: 0, no: 0 };
  rows.forEach((r) => { if (r[4] in rec) rec[r[4]]++; });
  const recTotal = rec.yes + rec.maybe + rec.no;
  const count = (col) => {
    const m = {};
    rows.forEach((r) => { const k = r[col] || '–'; m[k] = (m[k] || 0) + 1; });
    return Object.entries(m).sort((a, b) => b[1] - a[1]);
  };
  const week = Date.now() - 7 * 24 * 3600 * 1000;
  const lastWeek = rows.filter((r) => new Date(r[0]).getTime() >= week).length;
  const comments = rows.filter((r) => r[6]).slice(-50).reverse();
  const tz = Session.getScriptTimeZone();

  return `${STYLE}<main>
  <h1>MoodScape · แดชบอร์ดความคิดเห็น</h1>
  <p class="muted">อัปเดตเมื่อเปิดหน้านี้ · ข้อมูลไม่ระบุตัวตน ·
    <a style="color:#B6A8FF" href="${SpreadsheetApp.getActiveSpreadsheet().getUrl()}"
    target="_blank">เปิด Google Sheet</a></p>
  <div class="grid">
    <div class="card"><h2>คำตอบทั้งหมด</h2><div class="big">${total}</div>
      <div class="muted">7 วันล่าสุด: ${lastWeek}</div></div>
    <div class="card"><h2>คะแนนรวมเฉลี่ย</h2>
      <div class="big">${fmt(avg_(rows, 1))} ★</div><div class="muted">จาก 5</div></div>
    <div class="card"><h2>เพลงตรงใจ</h2>
      <div class="big">${fmt(avg_(rows, 2))}</div><div class="muted">จาก 5</div></div>
    <div class="card"><h2>ใช้งานง่าย</h2>
      <div class="big">${fmt(avg_(rows, 3))}</div><div class="muted">จาก 5</div></div>
    <div class="card"><h2>จะแนะนำให้เพื่อน</h2>
      <div class="big">${recTotal ? Math.round((100 * rec.yes) / recTotal) : 0}%</div>
      <div class="muted">อาจจะ ${rec.maybe} · ไม่แนะนำ ${rec.no}</div></div>
  </div>
  <div class="grid">
    <div class="card"><h2>การให้ดาว</h2>${bars_(starCounts, total)}</div>
    <div class="card"><h2>สิ่งที่ควรปรับปรุง</h2>
      ${improveSorted.length ? bars_(improveSorted, total) : '<p class="muted">ยังไม่มี</p>'}</div>
  </div>
  <div class="grid">
    <div class="card"><h2>ภาษาแอป</h2>${bars_(count(7), total)}</div>
    <div class="card"><h2>อุปกรณ์</h2>${bars_(count(8), total)}</div>
    <div class="card"><h2>เวอร์ชัน</h2>${bars_(count(9), total)}</div>
  </div>
  <div class="card"><h2>ความคิดเห็นล่าสุด</h2>
    ${comments.length ? `<table><tr><th>เวลา</th><th>ดาว</th><th>ความคิดเห็น</th></tr>
      ${comments.map((r) => `<tr><td>${esc_(Utilities.formatDate(new Date(r[0]), tz,
        'd MMM HH:mm'))}</td><td>${'★'.repeat(Number(r[1]) || 0)}</td>
        <td>${esc_(String(r[6]).replace(/^'/, ''))}</td></tr>`).join('')}</table>`
      : '<p class="muted">ยังไม่มีความคิดเห็น</p>'}
  </div></main>`;
}
