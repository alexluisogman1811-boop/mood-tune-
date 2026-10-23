// Checks the bot's answers without LINE or Google: node test.js
const fs = require('fs');
const vm = require('vm');
const assert = require('assert');

const ctx = {};
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(__dirname + '/Code.gs', 'utf8'), ctx);

const cases = {
  'สวัสดีค่ะ': 'hello',
  'hi there': 'hello',
  'this is nice': 'fallback', // "hi" inside "this" must not count as hello
  'ราคาเท่าไหร่คะ': 'price',
  'how much is premium?': 'price',
  'แพ็กเกจรายปีกี่บาท': 'price',
  'วิธีจ่ายเงิน': 'pay',
  'how to pay': 'pay',
  'จะอัปเกรดต้องทำยังไง': 'pay',
  'โอนแล้วนะคะ': 'slip',
  'I paid already': 'slip',
  'my email is buyer@gmail.com': 'email',
  'buyer@gmail.com': 'email',
  'สมัครบัญชีไม่ได้': 'account',
  'ลืมรหัสผ่าน': 'account',
  'forgot my password': 'account',
  'ดาวน์โหลดแอปที่ไหน': 'download',
  'มีบน iphone ไหม': 'download',
  'ถ่ายรูปแล้วปลอดภัยไหม': 'photo',
  'ใช้ฟรีได้ไหม': 'free',
  'ใช้ยังไง': 'how',
  'ขอคืนเงินได้ไหม': 'refund',
  'ยกเลิกยังไง': 'renew',
  'ขอคุยกับแอดมิน': 'human',
  'ขอบคุณค่ะ': 'thanks',
  'อยากฟังเพลงเศร้า': 'fallback',
  '': 'fallback',
};
for (const [text, want] of Object.entries(cases)) {
  assert.strictEqual(ctx.intentFor(text), want, `"${text}" → ${ctx.intentFor(text)}, want ${want}`);
}

// Every answer exists in both languages and fills its placeholders.
for (const key of Object.keys(ctx.ANSWERS)) {
  for (const lang of ['th', 'en']) {
    const t = ctx.replyText(key, lang, '');
    assert.ok(t.length > 10 && !/\{p\}|\{payment\}/.test(t), `${key}/${lang}`);
    assert.ok(t.length <= 5000, 'LINE text limit');
  }
}
assert.ok(ctx.replyText('pay', 'th', 'พร้อมเพย์ 000').includes('พร้อมเพย์ 000'));
assert.ok(ctx.replyText('price', 'th', '').includes('≈179 ฿'));
assert.ok(ctx.replyText('price', 'en', '').includes('$49.99'));

// LINE allows at most 13 quick-reply buttons with labels up to 20 characters.
for (const lang of ['th', 'en']) {
  const items = ctx.quickReplies(lang).items;
  assert.ok(items.length <= 13);
  items.forEach((i) => assert.ok(i.action.label.length <= 20, i.action.label));
}

// Hand-over: after a slip the bot keeps quiet on chit-chat but still answers questions.
const msg = (text) => ({ type: 'message', replyToken: 'r', message: { type: 'text', text } });
const now = 1_000_000;
const slip = ctx.planReply({ type: 'message', replyToken: 'r', message: { type: 'image' } }, now, 0, '');
assert.strictEqual(slip.intent, 'slip');
assert.strictEqual(slip.quiet, true);
assert.strictEqual(ctx.planReply(msg('โอเคค่ะ'), now, now + 1000, ''), null);
assert.strictEqual(ctx.planReply(msg('ขอบคุณค่ะ'), now, now + 1000, ''), null);
assert.strictEqual(ctx.planReply(msg('ราคาเท่าไหร่'), now, now + 1000, '').intent, 'price');
assert.strictEqual(ctx.planReply(msg('โอเคค่ะ'), now, 0, '').intent, 'fallback');
assert.strictEqual(ctx.planReply({ type: 'follow', replyToken: 'r' }, now, 0, '').intent, 'hello');
assert.strictEqual(ctx.planReply({ type: 'message', replyToken: 'r', message: { type: 'sticker' } }, now, 0, ''), null);

console.log(`All ${Object.keys(cases).length} questions and checks passed.`);
