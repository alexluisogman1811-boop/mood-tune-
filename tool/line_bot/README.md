# บอทตอบลูกค้าใน LINE (ฟรี) / LINE auto-reply bot (free)

บอทนี้ตอบคำถามที่พบบ่อยใน LINE ให้อัตโนมัติ ทั้งภาษาไทยและอังกฤษ:
ราคา, วิธีจ่าย, สมัคร/ลืมรหัสผ่าน, ลิงก์ดาวน์โหลด, เรื่องรูป, คืนเงิน, ต่ออายุ
พร้อมปุ่มกดด่วนใต้ข้อความ

- **สลิป / อีเมล / คำถามที่บอทไม่เข้าใจ / ลูกค้าพิมพ์ "แอดมิน"** → บอทตอบรับสั้นๆ
  แล้ว **เงียบ 2 ชั่วโมงสำหรับลูกค้าคนนั้น** ให้คุณตอบเองใน LINE OA โดยไม่พูดแทรก
  (ถ้าลูกค้าถามคำถามชัดๆ เช่น "ราคา" บอทยังตอบให้)
- บอท **ไม่เปิด Premium ให้เอง**: คุณยังตรวจสลิปแล้วกดเปิดในหน้า Admin dashboard ของแอปเหมือนเดิม
- ค่าใช้จ่าย **0 บาท**: ใช้ Google Apps Script (ฟรี) และตอบด้วย reply message ของ LINE
  ซึ่งไม่นับโควตาข้อความฟรีรายเดือน

> LINE ส่วนตัวต่อบอทไม่ได้ ต้องใช้ **LINE Official Account** (สมัครฟรี)

## ขั้นตอนติดตั้ง (ประมาณ 15 นาที)

### 1. สร้าง LINE Official Account (ฟรี)
1. เข้า <https://manager.line.biz> › เข้าสู่ระบบด้วย LINE ของคุณ
2. **สร้างบัญชี LINE Official Account** ตั้งชื่อเช่น *MoodScape*, หมวดหมู่ *แอปพลิเคชัน/ซอฟต์แวร์*
3. จด **LINE ID** ของบัญชีใหม่ (ขึ้นต้นด้วย `@` เช่น `@123abcde`)

### 2. เปิด Messaging API
1. ใน LINE OA Manager › **ตั้งค่า (Settings)** › **Messaging API** › **ใช้ Messaging API**
   › สร้าง Provider ชื่อเช่น *MoodScape*
2. เข้า <https://developers.line.biz/console> › เลือก Provider › ช่อง (channel) ของ OA
   › แท็บ **Messaging API**
3. เลื่อนลงล่างสุด **Channel access token (long-lived)** › กด **Issue** › คัดลอกไว้
   (เป็นรหัสลับ ห้ามส่งให้ใคร)

### 3. วางโค้ดบอทใน Google Apps Script
1. เข้า <https://script.new> ตั้งชื่อโปรเจกต์ *MoodScape LINE bot*
2. ลบโค้ดเดิม แล้ววางโค้ดทั้งหมดจาก `Code.gs` › กดบันทึก
   (ถ้าต้องการลงท้าย "ครับ" แก้บรรทัด `var PARTICLE = 'ค่ะ';`)
3. **Project Settings** (ไอคอนเฟือง) › **Script properties** › **Add script property**
   - `LINE_CHANNEL_ACCESS_TOKEN` = token จากขั้นที่ 2
   - (ไม่บังคับ) `PAYMENT_INFO` = ข้อมูลรับเงิน เช่น `พร้อมเพย์ 08x-xxx-xxxx ชื่อ ...`
     ถ้าไม่ใส่ บอทจะบอกลูกค้าว่าแอดมินจะส่งเลขบัญชีให้ในแชท
4. **Deploy › New deployment** › ประเภท **Web app**
   - Execute as: **Me** · Who has access: **Anyone**
   - กด Deploy › อนุญาตสิทธิ์ › คัดลอก **Web app URL** (ลงท้าย `/exec`)
5. ลองเปิด URL นั้นในเบราว์เซอร์ ต้องเห็น `MoodScape LINE bot is running.`

### 4. ต่อ LINE เข้ากับบอท
1. LINE Developers › แท็บ **Messaging API** › **Webhook URL** › วาง URL `/exec` › Update
2. เปิด **Use webhook**
   (ปุ่ม Verify อาจขึ้น error เพราะ Google redirect ไม่เป็นไร ให้ทดสอบด้วยการส่งข้อความจริง)
3. LINE OA Manager › **ตั้งค่าการตอบกลับ (Response settings)**:
   - **แชท (Chat): เปิด**: ให้คุณยังตอบลูกค้าเองได้
   - **Webhook: เปิด**
   - **ข้อความตอบกลับอัตโนมัติ (Auto-response): ปิด** และ **ข้อความทักทาย (Greeting): ปิด**
     (บอทส่งข้อความต้อนรับเอง)

### 5. ทดสอบ
เพิ่มเพื่อน OA ใหม่ด้วยมือถือ แล้วลองพิมพ์ `ราคา`, `วิธีจ่าย`, `ดาวน์โหลด`,
`how to pay`, ส่งรูปสลิป, พิมพ์อีเมล

### 6. เปลี่ยน LINE ID ในเว็บ แอป และโฆษณา
ตอนนี้ทุกที่ใช้ `company181113` (LINE ส่วนตัว) บอก ID ใหม่ (`@...`) แล้วจะเปลี่ยนให้ทั้งหมด

## แก้คำตอบ
คำตอบอยู่ใน `ANSWERS` และคำค้นอยู่ใน `RULES` ใน `Code.gs` แก้แล้วกด
**Deploy › Manage deployments › แก้ไข (ดินสอ) › Version: New version › Deploy**
(URL เดิมใช้ต่อได้)

ทดสอบคำตอบบนคอมโดยไม่ต้องใช้ LINE: `node test.js`

## English summary
`Code.gs` is a Google Apps Script web app used as the Messaging API webhook of a
LINE Official Account. It matches Thai/English keywords to fixed answers
(prices, payment steps, sign-up help, download links, photo privacy, refunds,
renewals), adds quick-reply buttons, and hands slips, account emails, "admin"
requests and unknown questions to the owner, staying quiet for that user for
`QUIET_MINUTES`. It never changes plans. Secrets live in Script properties,
not in the code. Apps Script cannot read request headers, so the
`X-Line-Signature` is not checked: a forged request can only make the bot try
to reply with a fake reply token, which LINE rejects.
