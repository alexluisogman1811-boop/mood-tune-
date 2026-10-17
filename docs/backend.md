# Backend services MoodScape can use

MoodScape never ships secret keys. Two optional features need a small server
that you run and control. Both must be served over **HTTPS**; the app refuses
plain HTTP.

## 1. Image analysis — `ANALYSIS_BACKEND_URL`

Used only after the user consents to uploading a photo. Without it, MoodScape
uses its on-device analyser (brightness, colour temperature, saturation,
contrast, dominant colours).

**Request**

```
POST {ANALYSIS_BACKEND_URL}/v1/analyze-environment
Content-Type: application/json

{ "image": "<base64 JPEG, ≤1024px long edge, EXIF stripped>", "mimeType": "image/jpeg" }
```

**Response 200**

```json
{
  "setting": "outdoor",
  "lighting": "soft",
  "visualAtmosphere": ["peaceful", "dreamy"],
  "environmentalCues": ["cloudy"],
  "energy": 35,
  "confidence": 0.85,
  "palette": ["#8FA3B8", "#3E4A5C"]
}
```

| Field | Allowed values |
| --- | --- |
| `setting` | `indoor`, `outdoor`, `nature`, `city`, `cafe`, `unknown` |
| `lighting` | `dark`, `bright`, `warm`, `cool`, `soft`, `unknown` |
| `visualAtmosphere` | any of `cozy`, `dreamy`, `peaceful`, `dramatic`, `energetic`, `nostalgic` |
| `environmentalCues` | any of `rain`, `sunshine`, `fog`, `cloudy`, `snow`, `night` |
| `energy` | number 0–100 (required) |
| `confidence` | number 0–1 (required) |
| `palette` | up to 6 `#RRGGBB` strings (optional) |

The app validates every field ([scene_features.dart](../lib/services/image_analysis/scene_features.dart)):
unknown labels are dropped, and missing or out-of-range `energy`/`confidence`
reject the whole response, which triggers the on-device fallback.

**Errors.** 5xx, 429 and network errors are retried up to 3 times with
back-off; other 4xx responses are not retried. Either way the app falls back
to on-device analysis and tells the user.

**Server guidance.**
- Keep the AI provider's API key on the server only.
- Prompt the model to describe the **environment**, never to infer the
  person's emotions, and to answer with the JSON above only.
- Don't store images. Process them in memory and discard them.
- Add authentication or rate limiting appropriate to your deployment.

## 2. Apple Music developer token — `APPLE_MUSIC_DEVELOPER_TOKEN_URL`

On iOS, MusicKit generates the developer token itself, so no backend is needed
as long as the MusicKit App Service is enabled for the bundle ID. On Android
(and other platforms) catalogue search needs a token from your server:

```
GET {APPLE_MUSIC_DEVELOPER_TOKEN_URL}
→ 200 { "token": "<ES256-signed JWT>" }
```

Sign the JWT on the server with your MusicKit private key (`.p8`), using
`kid` = key ID, `iss` = Team ID and an `exp` of up to 6 months. The app
reads `exp` to decide when to fetch a new token, and keeps tokens in memory
only.
