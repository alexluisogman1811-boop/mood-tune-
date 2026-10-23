/**
 * MoodScape LINE auto-reply bot (free).
 *
 * A Google Apps Script web app that receives messages from a LINE Official
 * Account (Messaging API webhook) and answers common questions in Thai or
 * English: prices, how to pay, how to sign up, download links, photos,
 * refunds. Payment slips, account emails and anything it does not understand
 * are left for the owner to answer in LINE Official Account Manager; the bot
 * then stays quiet for that customer for a while so it does not talk over you.
 *
 * Replies use LINE's reply API, which does not use up the free monthly
 * message quota. Setup: see README.md in this folder.
 *
 * Script properties (Project Settings › Script properties):
 *   LINE_CHANNEL_ACCESS_TOKEN  required, from LINE Developers › Messaging API
 *   PAYMENT_INFO               optional, e.g. "พร้อมเพย์ 08x-xxx-xxxx (ชื่อ ...)"
 */

// ---- Things you may want to change ----------------------------------------

/** Polite ending for Thai replies: 'ค่ะ' or 'ครับ'. */
var PARTICLE = 'ค่ะ';

/** How long the bot stays quiet for a customer after handing over to you. */
var QUIET_MINUTES = 120;

var LINKS = {
  site: 'https://alexluisogman1811-boop.github.io/moodscape/buy/',
  app: 'https://alexluisogman1811-boop.github.io/moodscape/',
  apk: 'https://alexluisogman1811-boop.github.io/moodscape/MoodScape.apk',
};

// ---- Answers --------------------------------------------------------------

var ANSWERS = {
  hello: {
    th: 'สวัสดี{p} 👋 ยินดีต้อนรับสู่ MoodScape แอปจัดเพลย์ลิสต์ตามอารมณ์และบรรยากาศรอบตัว\n\nพิมพ์ถามได้เลย เช่น "ราคา" "วิธีจ่าย" "ดาวน์โหลด" หรือกดปุ่มด้านล่าง{p}',
    en: 'Hi 👋 Welcome to MoodScape, the app that builds a playlist for your mood and surroundings.\n\nAsk anything, e.g. "price", "how to pay", "download", or tap a button below.',
  },
  price: {
    th: 'แพ็กเกจ MoodScape{p}\n\n• ฟรี: วันละ 3 เพลย์ลิสต์ เพลย์ลิสต์ละ 10 เพลง\n• รายเดือน: $2.99 (≈109 ฿) / 30 วัน\n• รายปี: $24.99 (≈899 ฿) / 365 วัน ⭐ คุ้มที่สุด\n• ตลอดชีพ: $39.99 (≈1,449 ฿) จ่ายครั้งเดียว\n\nPremium = เพลย์ลิสต์ไม่จำกัด + วิเคราะห์จากรูป + เพลย์ลิสต์ 20/30 เพลง\nสนใจแพ็กเกจไหน พิมพ์ "วิธีจ่าย" ได้เลย{p}',
    en: 'MoodScape plans:\n\n• Free: 3 playlists a day, 10 songs each\n• Monthly: $2.99 (≈109 ฿) for 30 days\n• Yearly: $24.99 (≈899 ฿) for 365 days ⭐ best value\n• Lifetime: $39.99 (≈1,449 ฿), pay once\n\nPremium = unlimited playlists + photo analysis + 20/30-song playlists.\nType "how to pay" when you are ready.',
  },
  pay: {
    th: 'วิธีอัปเกรดเป็น Premium{p}\n\n1. สมัครบัญชีฟรีในแอปก่อน (ถ้ายังไม่มี)\n2. ชำระเงินตามแพ็กเกจที่เลือก\n{payment}\n3. ส่งสลิป + อีเมลที่ใช้สมัครในแชทนี้\n4. แอดมินเปิดใช้ให้ ปกติภายใน 1 วัน{p}',
    en: 'How to get Premium:\n\n1. Create a free account in the app (if you have not yet)\n2. Pay for the plan you want\n{payment}\n3. Send the payment slip + your account email in this chat\n4. We switch Premium on, usually within a day.',
  },
  free: {
    th: 'ใช้ฟรีได้ตลอดไป{p} วันละ 3 เพลย์ลิสต์ เพลย์ลิสต์ละ 10 เพลง ไม่ต้องใช้บัตร\nเริ่มได้ที่ ' + LINKS.app,
    en: 'Free forever: 3 playlists a day, 10 songs each, no card needed.\nStart here: ' + LINKS.app,
  },
  download: {
    th: 'ใช้งานได้ 2 แบบ{p}\n\n🌐 เปิดในเบราว์เซอร์ (iPhone/Android/คอม):\n' + LINKS.app + '\n\n📱 แอป Android:\n' + LINKS.apk + '\n(ติดตั้งแล้วถ้ามือถือเตือน "แอปที่ไม่รู้จัก" ให้กดอนุญาต เพราะแอปยังไม่ได้อยู่ใน Play Store)',
    en: 'Two ways to use it:\n\n🌐 In your browser (iPhone/Android/computer):\n' + LINKS.app + '\n\n📱 Android app:\n' + LINKS.apk + '\n(Your phone may warn about an unknown app because it is not on the Play Store yet; allow it to install.)',
  },
  account: {
    th: 'เรื่องบัญชี{p}\n\n• สมัคร: เปิดแอป › "Create a new account / สร้างบัญชีใหม่" แล้วกดยืนยันในอีเมล\n• ลืมรหัสผ่าน: หน้าเข้าสู่ระบบ › "ลืมรหัสผ่าน" ระบบจะส่งลิงก์ไปที่อีเมล\n• ไม่เห็นอีเมล: ลองดูในโฟลเดอร์ Spam/Junk\n\nยังติดปัญหา พิมพ์ "แอดมิน" ได้เลย{p}',
    en: 'Account help:\n\n• Sign up: open the app › "Create a new account", then confirm the email we send\n• Forgot password: on the sign-in page tap "Forgot password?" for a reset link\n• No email? Check your Spam/Junk folder\n\nStill stuck? Type "admin".',
  },
  photo: {
    th: 'การวิเคราะห์จากรูปเป็นฟีเจอร์ Premium{p} 📷\nแอปอ่านแสง สี และสภาพอากาศของภาพ ไม่ดูใบหน้าคน และรูปไม่ถูกอัปโหลดหรือเก็บไว้{p}',
    en: 'Photo analysis is a Premium feature 📷\nThe app reads light, colour and weather in the scene, not faces, and photos are not uploaded or stored.',
  },
  how: {
    th: 'ใช้งานง่ายๆ 3 ขั้นตอน{p}\n1. เลือกกิจกรรม (อ่านหนังสือ ออกกำลังกาย ติว พักผ่อน…)\n2. บอกอารมณ์ตอนนี้ (Premium ถ่ายรูปบรรยากาศได้ด้วย)\n3. รับเพลย์ลิสต์ แต่ละเพลงมีคะแนนและเหตุผลว่าทำไมเข้ากับคุณ\nเปิดฟังต่อใน Spotify หรือ YouTube ได้เลย{p}',
    en: 'It takes 3 steps:\n1. Pick your activity (reading, workout, study, relax…)\n2. Tell it your mood (Premium can also read a photo of your surroundings)\n3. Get a playlist; each song shows a match score and why it fits.\nThen open the songs in Spotify or YouTube.',
  },
  refund: {
    th: 'ถ้า Premium ไม่ตอบโจทย์ แจ้งในแชทนี้ภายใน 7 วันหลังชำระเงินได้เลย{p} แอดมินจะช่วยดูให้',
    en: 'If Premium does not work for you, tell us in this chat within 7 days of paying and we will sort it out.',
  },
  renew: {
    th: 'รายเดือนและรายปีไม่ตัดเงินอัตโนมัติ{p} หมดอายุแล้วบัญชีจะกลับเป็นแบบฟรี ไม่มีอะไรถูกลบ ต่ออายุเมื่อไหร่ เวลาที่เหลือจะถูกบวกเพิ่มให้{p}',
    en: 'Monthly and Yearly never renew or charge automatically. When they end your account goes back to Free and nothing is deleted. If you renew early, the new time is added on top.',
  },
  slip: {
    th: 'ได้รับแล้ว{p} 🙏 ถ้ายังไม่ได้ส่ง รบกวนพิมพ์อีเมลที่ใช้สมัครบัญชีด้วยนะ{p} แอดมินจะตรวจและเปิดใช้ Premium ให้ ปกติภายใน 1 วัน',
    en: 'Got it, thank you 🙏 If you have not yet, please type the email of your MoodScape account. We will check and switch Premium on, usually within a day.',
  },
  email: {
    th: 'ได้รับอีเมลแล้ว{p} ✅ แอดมินจะตรวจสอบการชำระเงินและเปิดใช้ Premium ให้ ปกติภายใน 1 วัน แล้วเปิดแอปใหม่เพื่อดูแพ็กเกจ{p}',
    en: 'Email received ✅ We will check your payment and switch Premium on, usually within a day. Reopen the app to see your plan.',
  },
  human: {
    th: 'รับทราบ{p} แอดมินจะตอบกลับในแชทนี้โดยเร็วที่สุด 🙏',
    en: 'Sure, a person will reply in this chat as soon as possible 🙏',
  },
  thanks: {
    th: 'ยินดี{p} 😊 ขอให้สนุกกับเพลง',
    en: 'You are welcome 😊 Enjoy the music!',
  },
  fallback: {
    th: 'ขอบคุณที่ทักมา{p} 🙏 แอดมินจะตอบกลับเร็วๆ นี้\nระหว่างนี้กดปุ่มด้านล่างเพื่อดูคำตอบที่พบบ่อยได้{p}',
    en: 'Thanks for your message 🙏 A person will reply soon.\nMeanwhile, tap a button below for common answers.',
  },
};

/**
 * Keywords per answer, checked in this order (first match wins), lower case.
 * Thai has no spaces between words, so these match anywhere in the message.
 */
var RULES = [
  ['human', ['แอดมิน', 'admin', 'คุยกับคน', 'ติดต่อคน', 'เจ้าหน้าที่', 'human', 'real person', 'talk to someone']],
  ['refund', ['คืนเงิน', 'refund', 'money back']],
  ['renew', ['ต่ออายุ', 'ยกเลิก', 'หมดอายุ', 'ตัดเงิน', 'renew', 'cancel', 'expire', 'subscription']],
  ['slip', ['สลิป', 'โอนแล้ว', 'จ่ายแล้ว', 'ชำระแล้ว', 'slip', 'paid', 'receipt', 'transferred']],
  ['pay', ['วิธีจ่าย', 'จ่าย', 'ชำระ', 'โอน', 'พร้อมเพย์', 'promptpay', 'เลขบัญชี', 'paypal', 'truemoney', 'ซื้อ', 'สั่งซื้อ', 'อัปเกรด', 'อัพเกรด', 'pay', 'buy', 'purchase', 'upgrade', 'bank']],
  ['price', ['ราคา', 'เท่าไหร่', 'เท่าไร', 'กี่บาท', 'แพ็กเกจ', 'แพคเกจ', 'แพ็คเกจ', 'รายเดือน', 'รายปี', 'ตลอดชีพ', 'premium', 'พรีเมียม', 'price', 'cost', 'how much', 'plan', 'monthly', 'yearly', 'lifetime']],
  ['account', ['สมัคร', 'ล็อกอิน', 'ล็อคอิน', 'เข้าสู่ระบบ', 'รหัสผ่าน', 'ลืมรหัส', 'ยืนยันอีเมล', 'บัญชีผู้ใช้', 'sign up', 'signup', 'register', 'login', 'log in', 'sign in', 'password', 'verify', 'account']],
  ['download', ['ดาวน์โหลด', 'โหลด', 'ติดตั้ง', 'ลิงก์', 'ลิ้งค์', 'ลิงค์', 'แอป', 'แอพ', 'iphone', 'ไอโฟน', 'android', 'แอนดรอยด์', 'apk', 'download', 'install', 'link', 'app store', 'play store', 'website']],
  ['photo', ['รูป', 'กล้อง', 'ถ่าย', 'photo', 'camera', 'picture', 'image']],
  ['free', ['ฟรี', 'free', 'trial', 'ทดลอง']],
  ['how', ['ใช้ยังไง', 'ใช้งาน', 'ทำงานยังไง', 'วิธีใช้', 'ทำอะไรได้', 'how does', 'how to use', 'what is', 'what does', 'คืออะไร']],
  ['thanks', ['ขอบคุณ', 'ขอบใจ', 'thank', 'thx', 'ty']],
  ['hello', ['สวัสดี', 'หวัดดี', 'ดีค่ะ', 'ดีครับ', 'hello', 'hi', 'hey', 'good morning', 'good evening']],
];

/** After these answers a person takes over, so the bot goes quiet. */
var HANDOVER = { human: true, slip: true, email: true, refund: true, fallback: true };

var EMAIL_RE = /[^\s@]+@[^\s@]+\.[^\s@]+/;

// ---- Pure logic (tested in test.js) ---------------------------------------

function isThai(text) {
  return /[฀-๿]/.test(text || '');
}

/** Which answer fits this message text: a key of ANSWERS. */
function intentFor(text) {
  var t = String(text || '').toLowerCase().trim();
  if (!t) return 'fallback';
  if (EMAIL_RE.test(t)) return 'email';
  for (var i = 0; i < RULES.length; i++) {
    var words = RULES[i][1];
    for (var j = 0; j < words.length; j++) {
      if (matches(t, words[j])) return RULES[i][0];
    }
  }
  return 'fallback';
}

/** English words match whole words only (so "hi" is not found in "this"). */
function matches(text, word) {
  if (/[฀-๿]/.test(word)) return text.indexOf(word) !== -1;
  var escaped = word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return new RegExp('(^|[^a-z])' + escaped + '($|[^a-z])').test(text);
}

/** The reply text for an answer key in 'th' or 'en'. */
function replyText(intent, lang, paymentInfo) {
  var a = ANSWERS[intent] || ANSWERS.fallback;
  var payment = paymentInfo
    ? '   ' + paymentInfo
    : lang === 'th'
      ? '   (แอดมินจะส่งเลขพร้อมเพย์ / บัญชีธนาคาร / PayPal ให้ในแชทนี้)'
      : '   (we will send PromptPay / bank / PayPal details in this chat)';
  return a[lang].split('{p}').join(lang === 'th' ? PARTICLE : '').split('{payment}').join(payment);
}

/** Buttons under a reply, so customers can tap instead of type. */
function quickReplies(lang) {
  var items = lang === 'th'
    ? [['ราคา', 'ราคา'], ['วิธีจ่าย', 'วิธีจ่าย'], ['ดาวน์โหลดแอป', 'ดาวน์โหลด'], ['ใช้งานยังไง', 'ใช้ยังไง'], ['คุยกับแอดมิน', 'แอดมิน']]
    : [['Prices', 'price'], ['How to pay', 'how to pay'], ['Download', 'download'], ['How it works', 'how to use'], ['Talk to a person', 'admin']];
  return {
    items: items.map(function (it) {
      return { type: 'action', action: { type: 'message', label: it[0], text: it[1] } };
    }),
  };
}

/**
 * What to send back for one LINE event, or null for nothing.
 * `quietUntil` is when this customer's quiet time ends (ms), 0 if none.
 */
function planReply(event, now, quietUntil, paymentInfo) {
  var intent, lang;
  if (event.type === 'follow') {
    intent = 'hello';
    lang = 'th';
  } else if (event.type === 'message' && event.message.type === 'text') {
    lang = isThai(event.message.text) ? 'th' : 'en';
    intent = intentFor(event.message.text);
  } else if (event.type === 'message' && event.message.type === 'image') {
    intent = 'slip'; // usually a payment slip
    lang = 'th';
  } else {
    return null;
  }
  // While a person is handling this chat, answer only clear questions.
  if (now < quietUntil && (intent === 'fallback' || intent === 'hello' || intent === 'thanks')) {
    return null;
  }
  var message = { type: 'text', text: replyText(intent, lang, paymentInfo) };
  if (!HANDOVER[intent] || intent === 'fallback') message.quickReply = quickReplies(lang);
  return { intent: intent, messages: [message], quiet: !!HANDOVER[intent] };
}

// ---- LINE webhook (Apps Script) -------------------------------------------

function doPost(e) {
  var body = JSON.parse((e && e.postData && e.postData.contents) || '{}');
  var props = PropertiesService.getScriptProperties();
  var token = props.getProperty('LINE_CHANNEL_ACCESS_TOKEN');
  var paymentInfo = props.getProperty('PAYMENT_INFO') || '';
  var now = Date.now();

  (body.events || []).forEach(function (event) {
    if (!event.replyToken || !token) return;
    var userId = (event.source && event.source.userId) || '';
    var key = 'quiet_' + userId;
    var quietUntil = Number(props.getProperty(key) || 0);
    var plan = planReply(event, now, quietUntil, paymentInfo);
    if (!plan) return;
    if (plan.quiet && userId) {
      props.setProperty(key, String(now + QUIET_MINUTES * 60 * 1000));
    }
    UrlFetchApp.fetch('https://api.line.me/v2/bot/message/reply', {
      method: 'post',
      contentType: 'application/json',
      headers: { Authorization: 'Bearer ' + token },
      payload: JSON.stringify({ replyToken: event.replyToken, messages: plan.messages }),
      muteHttpExceptions: true,
    });
  });

  return ContentService.createTextOutput('OK');
}

/** Opening the web app URL in a browser shows that it is running. */
function doGet() {
  var ok = !!PropertiesService.getScriptProperties().getProperty('LINE_CHANNEL_ACCESS_TOKEN');
  return ContentService.createTextOutput(
    ok ? 'MoodScape LINE bot is running.' : 'Add LINE_CHANNEL_ACCESS_TOKEN in Project Settings › Script properties.'
  );
}

/** Run this from the editor to see answers without LINE. */
function tryIt() {
  ['ราคาเท่าไหร่คะ', 'โอนแล้วค่ะ', 'how do I pay?', 'ดาวน์โหลดยังไง', 'อยากคุยกับแอดมิน'].forEach(function (q) {
    var lang = isThai(q) ? 'th' : 'en';
    Logger.log(q + '\n→ ' + replyText(intentFor(q), lang, '') + '\n');
  });
}
