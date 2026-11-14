"""Tops up the catalogue with the world's best-known artists.

The catalogue is built from playlists and charts, so it holds whoever
happened to be on them. This adds the famous names people actually look for
in the app's band picker.

1. Collect candidates by walking Deezer's "related artists" out from the
   catalogue's own busiest artists, so the walk starts in every language the
   app lists, plus the worldwide chart.
2. Rank them by Deezer's fan count, a worldwide figure, and keep the top
   --artists.
3. Give each one at least --per-artist songs, analysed exactly like the rest
   of the catalogue (30-second preview; the audio is deleted straight after).

Songs whose language cannot be told are skipped, so a language filter never
shows the wrong song. Artists who sing in a language the app does not list
end up with no songs, and are left out.

Usage (from the project root, after build_catalog.py's requirements):
    py tool/add_artists.py --artists 1000 --per-artist 4
"""

from __future__ import annotations

import argparse
import concurrent.futures as cf
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from build_catalog import (  # noqa: E402
    CATALOG,
    analyse,
    get_json,
    language_of,
    to_entry,
    verified,
    write_artists,
)

# Deezer's genre charts turned out to return the same worldwide list for
# every genre, so this walks "related artists" instead: from a seed artist it
# reaches more of the same kind of music, and each hop carries a fan count.

# Languages the app lists. Anything else, and the song is skipped.
LATIN_HINTS = ("english", "spanish", "portuguese", "french")

CRAWL_SEEDS = 400


def seeds_from_catalog(tracks: list[dict], limit: int) -> list[dict]:
    """The catalogue's own busiest artists, with what it knows about them.

    They start the crawl, so it begins in every language the app lists
    rather than only in English.
    """
    by_key: dict[str, dict] = {}
    for t in tracks:
        name = (t.get("artist") or "").strip()
        if not name:
            continue
        e = by_key.setdefault(
            name.lower(),
            {"name": name, "songs": 0, "langs": {}, "sung": 0},
        )
        e["songs"] += 1
        if t.get("language"):
            e["langs"][t["language"]] = e["langs"].get(t["language"], 0) + 1
        if not t.get("instrumental"):
            e["sung"] += 1
    ranked = sorted(by_key.values(), key=lambda e: -e["songs"])[:limit]
    out = []
    for e in ranked:
        langs = e["langs"]
        out.append(
            {
                "name": e["name"],
                # The language most of their songs are in is a far better
                # guess than any chart could give.
                "hint": max(langs, key=lambda k: langs[k]) if langs else "english",
                "instrumental": e["sung"] == 0,
            }
        )
    return out


def crawl(seeds: list[dict], hops: int) -> dict[int, dict]:
    """Artist id -> {name, hint, instrumental, fans}, from related artists."""
    from collections import deque

    found: dict[int, dict] = {}
    queue: deque[int] = deque()

    for seed in seeds:
        hit = get_json(
            "https://api.deezer.com/search/artist",
            {"q": seed["name"], "limit": 1},
        ).get("data", [])
        if not hit:
            continue
        artist_id = hit[0]["id"]
        if artist_id in found:
            continue
        found[artist_id] = {
            "name": hit[0]["name"],
            "hint": seed["hint"],
            "instrumental": seed["instrumental"],
            "fans": hit[0].get("nb_fan"),
        }
        queue.append(artist_id)
    print(f"{len(found)} seed artists", flush=True)

    # Deezer's worldwide chart, for anyone big the catalogue has missed.
    for a in get_json(
        "https://api.deezer.com/chart/0/artists", {"limit": 100}
    ).get("data", []):
        if a["id"] not in found:
            found[a["id"]] = {
                "name": a["name"],
                "hint": "english",
                "instrumental": False,
                "fans": a.get("nb_fan"),
            }
            queue.append(a["id"])

    for used in range(hops):
        if not queue:
            break
        artist_id = queue.popleft()
        parent = found[artist_id]
        related = get_json(
            f"https://api.deezer.com/artist/{artist_id}/related"
        ).get("data", [])
        for a in related:
            if a["id"] in found:
                continue
            # Related artists nearly always sing in the same language, so
            # the hint travels with the hop.
            found[a["id"]] = {
                "name": a["name"],
                "hint": parent["hint"],
                "instrumental": parent["instrumental"],
                "fans": a.get("nb_fan"),
            }
            queue.append(a["id"])
        if (used + 1) % 100 == 0:
            print(f"  {used + 1} hops, {len(found)} artists found", flush=True)
    return found


def by_fame(found: dict[int, dict], keep: int) -> list[dict]:
    """Deezer's fan count is a worldwide figure, so it ranks fame fairly."""
    ranked = []
    for artist_id, info in found.items():
        fans = info["fans"]
        if not isinstance(fans, int):
            details = get_json(f"https://api.deezer.com/artist/{artist_id}")
            fans = details.get("nb_fan")
        if not isinstance(fans, int):
            continue
        ranked.append({**info, "id": artist_id, "fans": fans})
    ranked.sort(key=lambda a: -a["fans"])
    return ranked[:keep]


def asked_for(names: str) -> list[dict]:
    """The bands named on the command line, looked up by name.

    Deezer's search is forgiving about spelling, but it answers anything, so
    a name it cannot find is reported rather than quietly skipped.
    """
    out = []
    for name in (n.strip() for n in names.split(",")):
        if not name:
            continue
        hit = get_json(
            "https://api.deezer.com/search/artist", {"q": name, "limit": 1}
        ).get("data", [])
        if not hit:
            print(f"  no artist found for {name!r}", flush=True)
            continue
        print(f"  {name!r} -> {hit[0]['name']}", flush=True)
        out.append(
            {
                "id": hit[0]["id"],
                "name": hit[0]["name"],
                "hint": "english",
                "instrumental": False,
                "fans": hit[0].get("nb_fan"),
            }
        )
    return out


def language_for(title: str, artist: str, hint: str) -> str | None:
    """The song's language, or None when it cannot be told.

    Thai, Korean and Japanese are settled by the writing system, so they
    need no hint. Only a Latin-script title falls back to the hint, and a
    title that reads like another language is still refused.
    """
    by_script = language_of(title, artist, "any", [])
    if by_script:
        return by_script
    if hint not in LATIN_HINTS:
        hint = "english"
    return language_of(title, artist, hint, [])


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--artists", type=int, default=1000)
    ap.add_argument("--per-artist", type=int, default=4)
    ap.add_argument("--also", default="",
                    help="band names to add whatever their fan count, "
                         "comma separated")
    ap.add_argument("--hops", type=int, default=700,
                    help="how many artists to ask for related artists")
    ap.add_argument("--workers", type=int, default=6)
    args = ap.parse_args()

    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    have_ids = {t["id"] for t in catalog["tracks"]}
    counts: dict[str, int] = {}
    for t in catalog["tracks"]:
        key = (t.get("artist") or "").strip().lower()
        counts[key] = counts.get(key, 0) + 1

    if args.also:
        # Named bands skip the crawl and the fan ranking entirely, so asking
        # for one by name always works.
        famous = asked_for(args.also)
    else:
        famous = by_fame(
            crawl(seeds_from_catalog(catalog["tracks"], CRAWL_SEEDS),
                  args.hops),
            args.artists,
        )
    print(f"{len(famous)} famous artists; topping up to {args.per_artist}",
          flush=True)

    wanted: list[dict] = []
    for i, artist in enumerate(famous, 1):
        missing = args.per_artist - counts.get(artist["name"].strip().lower(), 0)
        if missing <= 0:
            continue
        top = get_json(
            f"https://api.deezer.com/artist/{artist['id']}/top", {"limit": 15}
        ).get("data", [])
        taken = 0
        for track in top:
            if taken >= missing:
                break
            if not track.get("preview") or f"dz-{track['id']}" in have_ids:
                continue
            # Deezer marks songs it cannot stream; they would be dead
            # entries in the catalogue.
            if not track.get("readable", True):
                continue
            instrumental = artist["instrumental"]
            language = None
            if not instrumental:
                language = language_for(
                    track["title"], track["artist"]["name"], artist["hint"]
                )
                if language is None:
                    continue
            if not verified(track, language, instrumental):
                continue
            have_ids.add(f"dz-{track['id']}")
            wanted.append(
                {
                    "deezer": track,
                    "language": language,
                    "instrumental": instrumental,
                    "source": f"famous:{artist['name']}",
                    "hint_genre": None,
                }
            )
            taken += 1
        if i % 50 == 0:
            print(f"  {i}/{len(famous)} artists, {len(wanted)} songs to add",
                  flush=True)

    print(f"analysing {len(wanted)} previews…", flush=True)
    feats: dict[int, dict] = {}
    with cf.ProcessPoolExecutor(args.workers) as pool:
        futures = {
            pool.submit(analyse, e["deezer"]["id"], e["deezer"]["preview"]): e
            for e in wanted
        }
        for n, f in enumerate(cf.as_completed(futures), 1):
            e = futures[f]
            try:
                r = f.result()
            except Exception:
                r = None
            if r:
                feats[e["deezer"]["id"]] = r
            if n % 100 == 0:
                print(f"  {n}/{len(wanted)} analysed", flush=True)

    added = []
    for e in wanted:
        f = feats.get(e["deezer"]["id"])
        if f:
            added.append(to_entry(e, f))
    catalog["tracks"] = catalog["tracks"] + added
    CATALOG.write_text(
        "{\n"
        + f'  "_note": {json.dumps(catalog["_note"], ensure_ascii=False)},\n'
        '  "tracks": [\n'
        + ",\n".join(
            "    " + json.dumps(t, ensure_ascii=False) for t in catalog["tracks"]
        )
        + "\n  ]\n}\n",
        encoding="utf-8",
        newline="\n",
    )
    print(f"catalogue: {len(catalog['tracks'])} songs ({len(added)} added)")
    write_artists(catalog["tracks"])


if __name__ == "__main__":
    sys.exit(main())
