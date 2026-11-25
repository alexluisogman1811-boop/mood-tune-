# หน้าเว็บเก็บฟีดแบ็ก MoodScape

หน้าเว็บ: [`web/feedback/index.html`](../../web/feedback/index.html)
เสิร์ฟที่ **https://alexluisogman1811-boop.github.io/moodscape/feedback/**

ต่อเข้า Google Form เรียบร้อยแล้ว ใช้งานได้ทันที ไม่ต้องตั้งค่าอะไรอีก

## ลิงก์ที่ต้องใช้

| อะไร | ลิงก์ |
|---|---|
| ดูคำตอบ (Google Sheet) | https://docs.google.com/spreadsheets/d/1TfQAagB5Gr-NGnoaV72JBk4T5ZYYHtiXw99zGehlQcc/edit |
| แก้ฟอร์ม | https://docs.google.com/forms/d/1nbmJRw_kuTnvH8Iwy8fiZlfA_TIOHQrYKJWJrWKfAr4/edit |
| ฟอร์มที่คนตอบเห็น | https://docs.google.com/forms/d/e/1FAIpQLSdpeW-KAPEH4r3hbv9a0OXy0alwIQGH-UCYlOEoAJWfCT_fVQ/viewform |

ตั้งค่าฟอร์มไว้แบบนี้: เปิดรับคำตอบ, ใครมีลิงก์ก็ตอบได้, **ไม่เก็บอีเมล**,
ตอบซ้ำได้ไม่จำกัด คำตอบใหม่ไหลเข้า Sheet เองทันที แต่ละแถวคือ 1 คน

## ทำไมไม่ใช้ Apps Script เดิม

Apps Script ตอบ POST ด้วย redirect และไม่ตอบ CORS preflight ทำให้เบราว์เซอร์
กับแอปส่งเข้าไม่ถึง ส่วน Google Form รับ POST ตรง ๆ จากฟอร์ม HTML ได้อยู่แล้ว
ฟรีถาวร ไม่จำกัดจำนวน และคนตอบไม่ต้องล็อกอินอะไรเลย

## คำถามกับ entry id

หน้าเว็บส่งค่าเป็น **ภาษาอังกฤษเสมอ** ไม่ว่าผู้ใช้จะดูหน้าเว็บเป็นภาษาไทยหรือ
อังกฤษ คอลัมน์ใน Sheet จะได้ไม่ปนสองภาษา และเทียบกับข้อมูลที่แอปส่งได้ตรงกัน

| # | คำถาม | ชนิด | entry id | ค่าที่ส่ง |
|---|---|---|---|---|
| 1 | Overall rating | Linear scale 1–5 | `entry.1906909060` | `1`–`5` |
| 2 | Do the songs fit you? | Linear scale 1–5 | `entry.1176732093` | `1`–`5` |
| 3 | Is the app easy to use? | Linear scale 1–5 | `entry.591524347` | `1`–`5` |
| 4 | What should we improve? | Checkboxes | `entry.1144367209` | ส่งได้หลายค่า |
| 5 | Where do you use MoodScape? | Multiple choice | `entry.1974165989` | `Android` `iPhone` `Web` |
| 6 | Would you recommend MoodScape to a friend? | Multiple choice | `entry.927788562` | `Yes` `Maybe` `No` |
| 7 | Anything else you want to tell us? | Paragraph | `entry.668946540` | ข้อความอิสระ |

ตัวเลือกของข้อ 4: `More songs` · `Better song choices` · `More languages` ·
`More activities` · `Photo analysis` · `Saving to Spotify` · `Look and design` ·
`Speed` — ตรงกับ `Improvement` ใน [`lib/features/feedback/domain/feedback.dart`](../../lib/features/feedback/domain/feedback.dart)

> **ถ้าแก้คำถามในฟอร์ม entry id จะเปลี่ยน** แล้วหน้าเว็บจะส่งไม่เข้า
> ถ้าต้องแก้ ให้เอา pre-filled link ใหม่ (เมนู ⋮ → Get pre-filled link)
> แล้วอัปเดต `FORM.fields` ใน `web/feedback/index.html`

## วิธีส่ง

หน้าเว็บ POST ฟอร์มจริงเข้า iframe ที่ซ่อนไว้ ไม่ใช้ `fetch` เพราะคำตอบของ
Google เป็น cross-origin ที่อ่านไม่ได้ `fetch` จะรู้แค่ว่า "ยิงออกไปแล้ว"
โดยไม่รู้ว่าถึงจริงไหม ส่วน `load` ของ iframe เป็นสัญญาณจริงว่า Google รับแล้ว
ถ้าเกิน 12 วินาทีไม่มีคำตอบ หน้าเว็บจะบอกว่าส่งไม่สำเร็จและเก็บคำตอบไว้ให้กดใหม่

## อัปขึ้นเว็บ

หน้านี้อยู่ใน `web/` ซึ่ง Flutter คัดลอกเข้า build ทุกครั้ง จึงไม่หายเวลา build ใหม่

```powershell
& "C:\src\flutter\bin\flutter.bat" build web --release --dart-define-from-file=config/prod.json --base-href /moodscape/
```

`--base-href /moodscape/` **ต้องมี** ไม่ใส่แล้วทั้งเว็บจะขึ้นหน้าว่าง

> รัน build ผ่าน **PowerShell** ไม่ใช่ Git Bash — Git Bash แปลง `/moodscape/`
> เป็น `C:/Program Files/Git/moodscape/` แล้ว build เงียบ ๆ ไม่สำเร็จ
> แต่ยังคืน exit code 0

แล้ว copy `build/web/` ทับใน repo ของ GitHub Pages
(`../../../moodscape-pages`, remote `alexluisogman1811-boop/moodscape`) แล้ว push
