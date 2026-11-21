# หน้าเว็บเก็บฟีดแบ็ก MoodScape

หน้าเว็บอยู่ที่ [`web/feedback/index.html`](../../web/feedback/index.html)
เสิร์ฟที่ **https://alexluisogman1811-boop.github.io/moodscape/feedback/**

หน้านี้ส่งคำตอบเข้า **Google Form** ของคุณ แล้วคำตอบลงไปอยู่ใน Google Sheet
ที่คุณเปิดดูได้ ฟรีถาวร ไม่จำกัดจำนวน ไม่ต้องมีเซิร์ฟเวอร์ และคนตอบ
**ไม่ต้องล็อกอินอะไรเลย**

ทำไมไม่ใช้ Apps Script เดิม: Apps Script ตอบ POST ด้วย redirect และไม่ตอบ
CORS preflight ทำให้เบราว์เซอร์กับแอปส่งเข้าไม่ถึง ส่วน Google Form รับ POST
ตรง ๆ จากฟอร์ม HTML ได้อยู่แล้ว

---

## ขั้นที่ 1 — สร้าง Google Form

เปิด https://docs.google.com/forms → **Blank form**

ตั้งชื่อฟอร์มอะไรก็ได้ เช่น `MoodScape feedback`

ใน **Settings** ให้ตั้งค่าแบบนี้:

| ตั้งค่า | ค่า |
|---|---|
| Collect email addresses | **ปิด** (คำตอบต้องไม่ระบุตัวตน) |
| Limit to 1 response | **ปิด** |
| Restrict to users in your organisation | **ปิด** (ถ้ามี) |

แล้วเพิ่มคำถาม **7 ข้อ ตามลำดับนี้** ทุกข้อตั้งเป็น **ไม่บังคับ**
(ปล่อย Required ปิดไว้ทั้งหมด — หน้าเว็บบังคับข้อแรกเองแล้ว)

> **สำคัญ:** ตัวเลือกต้องพิมพ์เป็น **ภาษาอังกฤษตรงตามนี้ทุกตัวอักษร**
> เพราะหน้าเว็บส่งค่าอังกฤษไปเสมอ ไม่ว่าผู้ใช้จะดูหน้าเว็บเป็นภาษาไทยหรืออังกฤษ
> คอลัมน์ใน Sheet จะได้ไม่ปนสองภาษา และเทียบกับข้อมูลที่แอปส่งได้ตรงกัน
> (ส่วน **ชื่อคำถาม** พิมพ์ภาษาไทยได้ตามใจ ไม่มีผลกับการส่ง)

### ข้อ 1 — Overall rating
- ชนิด: **Linear scale**
- จาก **1** ถึง **5**

### ข้อ 2 — Do the songs fit you?
- ชนิด: **Linear scale**
- จาก **1** ถึง **5**

### ข้อ 3 — Is the app easy to use?
- ชนิด: **Linear scale**
- จาก **1** ถึง **5**

### ข้อ 4 — What should we improve?
- ชนิด: **Checkboxes**
- ตัวเลือก (8 ข้อ พิมพ์ตรงตามนี้):
  ```
  More songs
  Better song choices
  More languages
  More activities
  Photo analysis
  Saving to Spotify
  Look and design
  Speed
  ```

### ข้อ 5 — Where do you use MoodScape?
- ชนิด: **Multiple choice**
- ตัวเลือก:
  ```
  Android
  iPhone
  Web
  ```

### ข้อ 6 — Would you recommend MoodScape to a friend?
- ชนิด: **Multiple choice**
- ตัวเลือก:
  ```
  Yes
  Maybe
  No
  ```

### ข้อ 7 — Anything else you want to tell us?
- ชนิด: **Paragraph**

---

## ขั้นที่ 2 — เอา pre-filled link

1. ในฟอร์ม กดเมนู **⋮** (มุมขวาบน) → **Get pre-filled link**
2. ตอบทุกข้อ ตอบอะไรก็ได้ แต่ **ข้อ 4 ให้ติ๊กแค่ 1 ช่อง**
3. กด **Get link** → **COPY LINK**

ลิงก์ที่ได้จะหน้าตาแบบนี้:

```
https://docs.google.com/forms/d/e/1FAIpQLSdXXXXXXXXXXXXXXXXXXXX/viewform?usp=pp_url
  &entry.1234567=4
  &entry.2345678=5
  &entry.3456789=3
  &entry.4567890=More+songs
  &entry.5678901=Android
  &entry.6789012=Yes
  &entry.7890123=hello
```

**ส่งลิงก์นี้มาให้ Claude ได้เลย** จะกรอกโค้ดให้เอง
หรือกรอกเองตามขั้นที่ 3

---

## ขั้นที่ 3 — กรอกเลข 2 ที่ในหน้าเว็บ

เปิด `web/feedback/index.html` แก้บล็อกนี้ (อยู่ใน `<script>` ใกล้ ๆ บรรทัดบน)

```js
var FORM = {
  id: "1FAIpQLSdXXXXXXXXXXXXXXXXXXXX",   // ส่วนที่อยู่ระหว่าง /d/e/ กับ /viewform
  fields: {
    overall:      "entry.1234567",
    songMatch:    "entry.2345678",
    easeOfUse:    "entry.3456789",
    improvements: "entry.4567890",
    device:       "entry.5678901",
    recommend:    "entry.6789012",
    comment:      "entry.7890123"
  }
};
```

ลำดับ `entry.` ในลิงก์ = ลำดับคำถามในฟอร์ม ข้อ 1 → `overall` ไปจนข้อ 7 → `comment`

จนกว่าจะกรอก `FORM.id` หน้าเว็บจะขึ้นกล่องเตือนสีเหลืองและปิดปุ่มส่งไว้
เพื่อไม่ให้คำตอบของใครหายไปเงียบ ๆ

---

## ขั้นที่ 4 — อัปขึ้นเว็บ

หน้านี้อยู่ใน `web/` ซึ่ง Flutter คัดลอกเข้า build ทุกครั้ง จึงไม่หายเวลา build ใหม่

```powershell
flutter build web --release --dart-define-from-file=config/prod.json --base-href /moodscape/
```

`--base-href /moodscape/` **ต้องมี** ไม่ใส่แล้วทั้งเว็บจะขึ้นหน้าว่าง

> รัน build ผ่าน **PowerShell** ไม่ใช่ Git Bash — Git Bash แปลง `/moodscape/`
> เป็น `C:/Program Files/Git/moodscape/` แล้ว build เงียบ ๆ ไม่สำเร็จ
> แต่ยังคืน exit code 0

แล้ว copy `build/web/` ไปที่ repo ของ GitHub Pages และ push

---

## ดูคำตอบ

ในฟอร์ม แท็บ **Responses** → ไอคอน Sheets สีเขียว → สร้าง Google Sheet
คำตอบใหม่จะไหลเข้า Sheet เองทันที แต่ละแถวคือ 1 คน
เอาไปทำกราฟในบทที่ 4 ของโครงงานได้เลย
