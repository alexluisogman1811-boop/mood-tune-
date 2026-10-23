"""Builds the admin website: web_admin/index.html plus the Firebase settings.

    py tool/build_admin.py config/prod.json build/admin
    py tool/build_admin.py config/emulator.json build/admin_emulator

The Firebase web settings are not secret (the web app ships them too), but
they live in the git-ignored config files, so they are added at build time.
Access is controlled by firestore.rules: only verified ADMIN_EMAILS can read.
"""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def main() -> None:
    config_path, out_dir = Path(sys.argv[1]), Path(sys.argv[2])
    c = json.loads(config_path.read_text(encoding="utf-8"))
    settings = {
        "apiKey": c["FIREBASE_API_KEY"],
        "appId": c["FIREBASE_APP_ID"],
        "projectId": c["FIREBASE_PROJECT_ID"],
        "messagingSenderId": c.get("FIREBASE_MESSAGING_SENDER_ID", ""),
        "authDomain": c.get("FIREBASE_AUTH_DOMAIN", ""),
        "adminEmails": c.get("ADMIN_EMAILS", ""),
        "emulators": str(c.get("USE_FIREBASE_EMULATORS", "")).lower() == "true",
    }
    page = (ROOT / "web_admin" / "index.html").read_text(encoding="utf-8")
    page = page.replace("/*CONFIG*/null", json.dumps(settings))
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "index.html").write_text(page, encoding="utf-8", newline="\n")
    print(f"wrote {out_dir / 'index.html'}")


if __name__ == "__main__":
    main()
