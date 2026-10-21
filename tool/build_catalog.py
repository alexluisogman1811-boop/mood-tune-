"""Builds MoodScape's built-in song catalogue from free sources.

1. Collect: Apple Music "most played" charts per country plus Deezer
   playlists per language (both free, no account needed).
2. Analyse: download each song's 30-second Deezer preview, measure loudness,
   brightness, tempo, onset density and major/minor key with librosa, and
   turn them into MoodScape's 0-100 energy and valence estimates.
3. Store: write only the metadata and numbers to assets/demo/demo_catalog.json.
   Preview audio is deleted straight after analysis; nothing is redistributed.

The numbers are estimates from a short clip, not ground truth.

Usage (from the project root):
    py -m pip install --user librosa soundfile requests
    py tool/build_catalog.py --per-language 150

Re-running is cheap: API responses and analysis results are cached in
%TEMP%/mscat (delete it to start fresh).
"""

from __future__ import annotations

import argparse
import concurrent.futures as cf
import json
import math
import os
import re
import sys
import tempfile
import time
import unicodedata
import warnings
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "assets" / "demo" / "demo_catalog.json"
CACHE = Path(tempfile.gettempdir()) / "mscat"

# ---- Sources ----------------------------------------------------------------

APPLE_COUNTRIES = {
    "th": "thai", "kr": "korean", "jp": "japanese", "mx": "spanish",
    "es": "spanish", "fr": "french", "br": "portuguese", "us": "english",
    "gb": "english",
}

# Everyday-activity playlists (workout, driving, chill, cleaning, party,
# sleep...) give each language songs for every activity, not just hits.
DEEZER_QUERIES = {
    "thai": ["thai hits", "เพลงไทย", "thai pop", "thai indie", "thai acoustic",
             "thai chill", "thai party", "thai rock", "thai workout",
             "thai love songs", "เพลงชิล", "เพลงฮิต"],
    "korean": ["top k-pop", "k-pop hits", "k-drama ost", "korean ballad",
               "korean indie", "k-pop workout", "k-pop chill", "k-pop party",
               "korean r&b", "k-pop dance"],
    "japanese": ["j-pop hits", "anime hits", "city pop", "japanese acoustic",
                 "j-rock", "anime workout", "j-pop chill", "vocaloid",
                 "japanese drive"],
    "spanish": ["éxitos latinos", "baladas en español", "rock en español",
                "pop en español", "música para entrenar", "reggaeton fiesta",
                "música para manejar", "chill en español",
                "música para limpiar"],
    "french": ["hits français", "chanson française", "variété française",
               "pop française", "rap français", "sport motivation français",
               "chill français", "soirée française", "route française"],
    "portuguese": ["sertanejo", "mpb", "bossa nova", "hits brasil",
                   "fado", "treino brasil", "funk brasileiro",
                   "pagode", "música para dirigir", "chill brasil"],
    "english": ["acoustic chill", "indie folk", "pop hits", "soft rock",
                "workout hits", "gym motivation", "running", "road trip",
                "driving songs", "cleaning music", "party hits",
                "cooking music", "feel good", "chill vibes", "commute"],
    "instrumental": ["piano study", "lofi study beats", "classical focus",
                     "ambient study", "solo piano", "instrumental focus",
                     "deep focus", "sleep piano", "peaceful piano",
                     "work focus instrumental", "chillhop"],
}

# ---- Language rules ---------------------------------------------------------

SCRIPTS = {
    "thai": re.compile(r"[฀-๿]"),
    "korean": re.compile(r"[가-힯ᄀ-ᇿ]"),
    "japanese": re.compile(r"[぀-ヿ]"),
}
CJK = re.compile(r"[一-鿿]")
NON_LATIN = re.compile(r"[Ͱ-᷿⺀-￯]")  # Greek onwards

STOPWORDS = {
    "english": {"the", "you", "my", "me", "i", "your", "love", "and", "of",
                "it", "in", "on", "we", "be", "is", "to", "don't", "i'm"},
    "spanish": {"el", "la", "los", "las", "de", "que", "y", "mi", "tu", "te",
                "amor", "corazón", "una", "por", "con", "para", "no", "yo",
                "quiero", "eres", "sin", "más"},
    "french": {"le", "la", "les", "de", "du", "des", "je", "tu", "pas",
               "mon", "ma", "pour", "avec", "dans", "qui", "que", "c'est",
               "toi", "moi", "et", "un", "une", "est", "sur"},
    "portuguese": {"o", "a", "os", "as", "de", "do", "da", "que", "e", "eu",
                   "você", "meu", "minha", "não", "com", "pra", "para",
                   "amor", "coração", "um", "uma", "sem", "é"},
}

APPLE_GENRE_LANGUAGE = {
    "K-Pop": "korean", "J-Pop": "japanese", "Anime": "japanese",
    "Latin": "spanish", "Urbano latino": "spanish", "Pop Latino": "spanish",
    "Música Mexicana": "spanish", "Regional Mexicano": "spanish",
    "Sertanejo": "portuguese", "MPB": "portuguese", "Brazilian": "portuguese",
    "Funk Brasileiro": "portuguese", "Pagode": "portuguese",
    "Samba": "portuguese", "Axé": "portuguese",
    "French Pop": "french", "Variété française": "french",
    "Chanson française": "french",
}


def words(text: str) -> list[str]:
    return re.findall(r"[\w']+", text.lower())


def stopword_vote(title: str) -> str | None:
    ws = words(re.sub(r"\(.*?\)|\[.*?\]", "", title))
    scores = {l: sum(w in s for w in ws) for l, s in STOPWORDS.items()}
    best = max(scores, key=scores.get)
    return best if scores[best] > 0 else None


def language_of(title: str, artist: str, hint: str,
                apple_genres: list[str]) -> str | None:
    """Best guess at the sung language; None when unsure (the song is
    skipped, so a chosen language filter never shows a wrong song)."""
    text = f"{title} {artist}"
    for lang, rx in SCRIPTS.items():
        if rx.search(text):
            return lang if hint in (lang, "any") else None
    if CJK.search(text):
        return "japanese" if hint == "japanese" else None
    if NON_LATIN.search(title):
        return None
    for g in apple_genres:
        if g in APPLE_GENRE_LANGUAGE:
            lang = APPLE_GENRE_LANGUAGE[g]
            return lang if lang == hint else None
    vote = stopword_vote(title)
    if hint in ("korean", "japanese"):
        # Latin-script titles are common in K-pop/J-pop; trust the source
        # unless the title reads like another language.
        return hint if vote in (None, "english") else None
    if hint == "thai":
        return None  # Thai songs nearly always have Thai titles
    if hint == "english":
        return "english" if vote in (None, "english") else None
    return hint if vote == hint else None


# ---- HTTP with caching and Deezer's rate limit ---------------------------------

session = requests.Session()
_last_call = [0.0]


def get_json(url: str, params: dict | None = None) -> dict:
    key = re.sub(r"[^\w]+", "_", url + json.dumps(params or {}, sort_keys=True,
                                                    ensure_ascii=True))[-180:]
    path = CACHE / "http" / f"{key}.json"
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    for attempt in range(5):
        wait = 0.13 - (time.time() - _last_call[0])  # ~8 calls/s < 50 per 5s
        if wait > 0:
            time.sleep(wait)
        _last_call[0] = time.time()
        try:
            r = session.get(url, params=params, timeout=20)
            data = r.json()
        except (requests.RequestException, ValueError):
            time.sleep(2 * (attempt + 1))
            continue
        if isinstance(data, dict) and "error" in data:
            time.sleep(5)  # quota exceeded: back off and retry
            continue
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
        return data
    return {}


# ---- Collect ----------------------------------------------------------------


def norm(s: str) -> str:
    s = unicodedata.normalize("NFKD", s.lower())
    s = re.sub(r"\(.*?\)|\[.*?\]|feat\..*|ft\..*", "", s)
    return re.sub(r"[^\w]+", "", s)


def deezer_match(title: str, artist: str) -> dict | None:
    data = get_json("https://api.deezer.com/search",
                    {"q": f'artist:"{artist}" track:"{title}"', "limit": 5})
    hits = data.get("data") or get_json(
        "https://api.deezer.com/search",
        {"q": f"{artist} {title}", "limit": 5}).get("data") or []
    want = norm(artist.split(",")[0].split("&")[0])
    for h in hits:
        if h.get("preview") and want[:6] in norm(h["artist"]["name"]):
            return h
    return None


def album_genres(track: dict) -> set[str]:
    album = get_json(f"https://api.deezer.com/album/{track['album']['id']}")
    return {g["name"] for g in (album.get("genres") or {}).get("data", [])}


# Album tags that prove a Latin-script title is really K-pop / J-pop.
ASIAN_TAGS = {
    "korean": {"K-Pop"},
    "japanese": {"J-Pop", "Asian Music"},
}
# Album tags that mean a "study" playlist slipped in a sung song.
VOCAL_TAGS = {"Rap/Hip Hop", "R&B", "Reggaeton", "Latin Music", "K-Pop",
              "J-Pop", "Asian Music", "Pop", "Country"}
QUIET_TAGS = {"Classical", "Jazz", "Films/Games", "Film Scores",
              "Chill Out/Trip-Hop/Lounge", "Electro", "Ambient"}


def verified(track: dict, language: str | None, instrumental: bool) -> bool:
    """Second check using Deezer's album genres. Charts in Korea and Japan
    also list Western hits whose titles look like K-pop/J-pop titles."""
    text = f"{track['title']} {track['artist']['name']}"
    if language in ASIAN_TAGS and not SCRIPTS[language].search(text) \
            and not (language == "japanese" and CJK.search(text)):
        return bool(album_genres(track) & ASIAN_TAGS[language])
    if instrumental:
        tags = album_genres(track)
        return not (tags & VOCAL_TAGS) or bool(tags & QUIET_TAGS - {"Electro"})
    return True


def collect(per_language: int) -> list[dict]:
    found: dict[int, dict] = {}

    def add(track: dict, language: str | None, instrumental: bool,
            source: str, hint_genre: str | None = None):
        if not track or not track.get("preview") or track["id"] in found:
            return
        if not track.get("readable", True):
            return
        if not verified(track, language, instrumental):
            return
        found[track["id"]] = {
            "deezer": track, "language": language,
            "instrumental": instrumental, "source": source,
            "hint_genre": hint_genre,
        }

    for country, lang in APPLE_COUNTRIES.items():
        feed = get_json(f"https://rss.applemarketingtools.com/api/v2/{country}"
                        "/music/most-played/100/songs.json")
        for item in (feed.get("feed") or {}).get("results", []):
            genres = [g["name"] for g in item.get("genres", [])]
            guess = language_of(item["name"], item["artistName"], lang, genres)
            if guess is None:
                continue
            add(deezer_match(item["name"], item["artistName"]), guess, False,
                f"apple-{country}")
        print(f"apple {country}: {len(found)} so far", flush=True)

    for lang, queries in DEEZER_QUERIES.items():
        for q in queries:
            pls = get_json("https://api.deezer.com/search/playlist",
                           {"q": q, "limit": 2}).get("data", [])
            for pl in pls:
                tracks = get_json(f"https://api.deezer.com/playlist/{pl['id']}"
                                  "/tracks", {"limit": 100}).get("data", [])
                for t in tracks:
                    if lang == "instrumental":
                        add(t, None, True, f"deezer:{q}", q)
                        continue
                    guess = language_of(t["title"], t["artist"]["name"],
                                        lang, [])
                    if guess:
                        add(t, guess, False, f"deezer:{q}", q)
        print(f"deezer {lang}: {len(found)} so far", flush=True)

    # Cap each language at the most popular songs.
    by_lang: dict[str, list[dict]] = {}
    for entry in found.values():
        by_lang.setdefault(entry["language"] or "instrumental", []).append(entry)
    chosen = []
    for lang, entries in by_lang.items():
        entries.sort(key=lambda e: -e["deezer"].get("rank", 0))
        chosen += entries[:per_language]
        print(f"{lang}: {len(entries)} found, {min(len(entries), per_language)}"
              " kept", flush=True)
    return chosen


# ---- Analyse ----------------------------------------------------------------

MAJOR = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
MINOR = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]


def scale(x: float, lo: float, hi: float) -> float:
    return min(1.0, max(0.0, (x - lo) / (hi - lo)))


def analyse(track_id: int, url: str) -> dict | None:
    """Features of one 30 s preview, cached by Deezer id."""
    out = CACHE / "features" / f"{track_id}.json"
    if out.exists():
        return json.loads(out.read_text())
    import librosa  # imported here so worker processes load it lazily
    import numpy as np

    warnings.filterwarnings("ignore")
    mp3 = CACHE / "audio" / f"{track_id}.mp3"
    mp3.parent.mkdir(parents=True, exist_ok=True)
    try:
        r = requests.get(url, timeout=30)
        if r.status_code != 200 or len(r.content) < 50_000:
            return None
        mp3.write_bytes(r.content)
        y, sr = librosa.load(str(mp3), sr=22050, mono=True, duration=30)
    except Exception:
        return None
    finally:
        mp3.unlink(missing_ok=True)  # never keep the audio
    if len(y) < sr * 10:
        return None

    rms = librosa.feature.rms(y=y)[0]
    loud_db = 20 * math.log10(float(np.mean(rms)) + 1e-9)
    centroid = float(np.mean(librosa.feature.spectral_centroid(y=y, sr=sr)))
    tempo = float(np.atleast_1d(librosa.feature.tempo(y=y, sr=sr))[0])
    onsets = librosa.onset.onset_detect(y=y, sr=sr)
    onset_rate = len(onsets) / (len(y) / sr)
    chroma = librosa.feature.chroma_cqt(y=y, sr=sr).mean(axis=1)
    major = max(np.corrcoef(np.roll(MAJOR, k), chroma)[0, 1] for k in range(12))
    minor = max(np.corrcoef(np.roll(MINOR, k), chroma)[0, 1] for k in range(12))

    energy = (0.45 * scale(loud_db, -32, -8) + 0.25 * scale(onset_rate, 0.5, 4)
              + 0.15 * scale(tempo, 60, 170) + 0.15 * scale(centroid, 800, 3500))
    mode = 0.5 + max(-0.5, min(0.5, (major - minor) * 2.5))  # 0 minor .. 1 major
    valence = (0.40 * mode + 0.30 * scale(tempo, 60, 160)
               + 0.30 * scale(centroid, 900, 3000))
    result = {
        "energy": round(100 * energy), "valence": round(5 + 90 * valence),
        "tempo": round(tempo), "loudness_db": round(loud_db, 1),
        "brightness_hz": round(centroid), "major": round(float(major - minor), 3),
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result))
    return result


# ---- Store ------------------------------------------------------------------

DEEZER_GENRES = {
    "Pop": "pop", "Rap/Hip Hop": "hipHop", "Rock": "rock", "Metal": "rock",
    "Dance": "electronic", "Electro": "electronic", "R&B": "rnb",
    "Alternative": "indie", "Indie Pop": "indie", "Indie Rock": "indie",
    "Folk": "folk", "Reggaeton": "latin", "Latin Music": "latin",
    "Brazilian Music": "latin", "Jazz": "jazz", "Classical": "classical",
    "Films/Games": "soundtrack", "Film Scores": "soundtrack",
    "Soul & Funk": "soul", "Country": "country", "Chill Out/Trip-Hop/Lounge":
    "ambient",
}
HINT_GENRES = {
    "piano study": "classical", "classical focus": "classical",
    "lofi study beats": "lofi", "ambient study": "ambient",
    "jazz instrumental": "jazz", "film scores": "soundtrack",
    "anime hits": "soundtrack", "k-drama ost": "soundtrack",
    "bossa nova": "jazz", "sertanejo": "country", "fado": "folk",
}


def atmosphere(energy: int, valence: int) -> list[str]:
    if energy >= 65:
        return ["energetic"] if valence >= 50 else ["energetic", "dramatic"]
    if energy <= 35:
        return ["peaceful", "cozy"] if valence >= 50 else ["peaceful", "dreamy"]
    return ["cozy", "nostalgic"] if valence >= 50 else ["nostalgic", "dramatic"]


def to_entry(e: dict, feats: dict) -> dict:
    d = e["deezer"]
    album = get_json(f"https://api.deezer.com/album/{d['album']['id']}")
    names = [g["name"] for g in (album.get("genres") or {}).get("data", [])]
    genres = sorted({DEEZER_GENRES[n] for n in names if n in DEEZER_GENRES})
    if e["hint_genre"] in HINT_GENRES:
        genres = sorted({*genres, HINT_GENRES[e["hint_genre"]]})
    if e["language"] == "korean" and "pop" in genres:
        genres = sorted({*genres, "kpop"} - {"pop"})
    if e["language"] in ("spanish", "portuguese") and not genres:
        genres = ["latin"]
    if not genres:
        genres = ["classical"] if e["instrumental"] else ["pop"]
    year = (album.get("release_date") or "")[:4]
    entry = {
        "id": f"dz-{d['id']}",
        "title": d["title"],
        "artist": d["artist"]["name"],
        "album": d["album"]["title"],
        **({"year": int(year)} if year.isdigit() and int(year) > 1900 else {}),
        "genres": genres,
        **({"language": e["language"]} if e["language"] else {}),
        "instrumental": e["instrumental"],
        "explicit": bool(d.get("explicit_lyrics")),
        "valence": feats["valence"],
        "energy": feats["energy"],
        # Deezer rank is roughly log-distributed up to ~1,000,000.
        "popularity": round(100 * scale(math.log10(d.get("rank", 1) + 1), 3, 6)),
        "atmosphere": atmosphere(feats["energy"], feats["valence"]),
        "cues": ["night"] if feats["brightness_hz"] < 1300
        and feats["energy"] < 40 else [],
        "analysis": "preview",
    }
    return entry


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--per-language", type=int, default=150)
    ap.add_argument("--workers", type=int, default=4)
    args = ap.parse_args()

    chosen = collect(args.per_language)
    print(f"analysing {len(chosen)} previews…", flush=True)
    feats: dict[int, dict] = {}
    with cf.ProcessPoolExecutor(args.workers) as pool:
        futures = {pool.submit(analyse, e["deezer"]["id"],
                               e["deezer"]["preview"]): e for e in chosen}
        for i, f in enumerate(cf.as_completed(futures), 1):
            e = futures[f]
            try:
                r = f.result()
            except Exception:
                r = None
            if r:
                feats[e["deezer"]["id"]] = r
            if i % 50 == 0:
                print(f"  {i}/{len(chosen)} analysed", flush=True)

    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    # Keep hand-curated songs; replace earlier analysed ones.
    kept = [t for t in catalog["tracks"] if t.get("analysis") != "preview"]
    seen = {norm(t["title"]) + "|" + norm(t["artist"])[:6] for t in kept}
    added = []
    for e in chosen:
        f = feats.get(e["deezer"]["id"])
        if not f:
            continue
        entry = to_entry(e, f)
        key = norm(entry["title"]) + "|" + norm(entry["artist"])[:6]
        if key in seen:
            continue
        seen.add(key)
        added.append(entry)
    catalog["_note"] = (
        "Built-in catalogue. Song metadata is factual. Entries marked "
        '"analysis": "preview" were measured from 30-second Deezer previews '
        "by tool/build_catalog.py (loudness, brightness, tempo, onsets, key); "
        "the rest were estimated by hand. Valence, energy and atmosphere are "
        "estimates, not data from any music service."
    )
    catalog["tracks"] = kept + added
    CATALOG.write_text(
        "{\n" + f'  "_note": {json.dumps(catalog["_note"], ensure_ascii=False)},\n'
        '  "tracks": [\n'
        + ",\n".join("    " + json.dumps(t, ensure_ascii=False)
                     for t in catalog["tracks"])
        + "\n  ]\n}\n",
        encoding="utf-8", newline="\n")
    counts: dict[str, int] = {}
    for t in catalog["tracks"]:
        k = t.get("language", "instrumental")
        counts[k] = counts.get(k, 0) + 1
    print(f"catalogue: {len(catalog['tracks'])} songs ({len(added)} analysed)")
    print(json.dumps(counts, ensure_ascii=False))


if __name__ == "__main__":
    sys.exit(main())
