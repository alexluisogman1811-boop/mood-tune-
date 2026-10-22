# Feedback backend and admin dashboard (free)

The app's **Feedback** screen sends anonymous answers (stars, what to
improve, a comment) to a Google Sheet through this Apps Script. The same
script shows a password-protected **admin dashboard**.

## Set it up once (about 5 minutes)

1. Go to <https://sheets.new> and name the sheet **MoodScape Feedback**.
2. **Extensions › Apps Script**. Delete what is there and paste all of
   `Code.gs`.
3. Change `ADMIN_PASSWORD = 'change-me'` to your own password. Save.
4. **Deploy › New deployment › Select type: Web app**:
   - Execute as: **Me**
   - Who has access: **Anyone**
5. Click **Deploy**, allow the permissions it asks for (it only uses this
   sheet), and copy the **Web app URL** (ends in `/exec`).

## Connect the app

Build with the URL:

```bash
flutter build web --release --base-href /moodscape/ --dart-define=FEEDBACK_URL=https://script.google.com/macros/s/XXXX/exec
```

(or add `"FEEDBACK_URL"` to `config/dev.json`). Without it, answers are kept
on the phone and sent once a build with the URL is installed.

## Open the dashboard

Open the Web app URL in any browser and enter your password, or go straight
to `…/exec?key=YOUR_PASSWORD`. It shows the total answers, average stars,
"songs fit" and "easy to use" scores, % who would recommend the app, what
people want improved, app language, device and version, and the latest
comments. The raw answers are in the Google Sheet.

After changing `Code.gs`, use **Deploy › Manage deployments › Edit › New
version** so the URL stays the same.
