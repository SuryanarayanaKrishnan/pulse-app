# Bug reports from beta testers

Testers shake the phone (or use **Settings > Beta tools > Report a bug**) to
send feedback with a screenshot. Nothing here uses a paid service.

## What the app does

1. A shake (three firm jolts inside about a second, then a 3 second pause)
   is read from the accelerometer, only while the app is open and only if
   **Settings > Beta tools > Shake to report a bug** is on. It defaults to on
   in beta builds (`--dart-define=BETA_BUILD=false` turns the default off) and
   the choice is remembered.
2. The current screen is captured **before** the sheet opens.
3. The sheet shows the screenshot (pen in two colours, hide-box, undo, clear,
   and a switch that pixelates all text), a note, a category (Bug, Confusing,
   Idea) and a plain list of what will be attached.
4. Attached: app version and build, platform and OS version, screen name,
   locale and theme, and the last 200 lines of an in-memory activity log.
   The log holds only screen names, analytics event names and errors with
   stack traces. Every line passes through `lib/bugreport/redactor.dart`,
   which removes digits, amounts, emails, phone numbers, IBAN-like codes,
   quoted text and `merchant:`/`name:`/`note:`-style fields. The log is
   redacted again when the report is built.
5. Delivery:
   * **Share sheet** (always available): writes `report.md` and
     `screenshot.png` to a temporary folder and opens the system share sheet.
   * **Issue endpoint** (optional): if the build has `BUG_REPORT_URL`, the app
     POSTs the report there. If the request fails the app falls back to the
     share sheet.

Analytics (only when the person has turned sharing on) record
`bug_report_opened` (`source`: shake or settings) and `bug_report_sent`
(`method`: local or issue). Never the note, screenshot or log.

## Turning on the issue endpoint

```
flutter run --dart-define=BUG_REPORT_URL=https://pulse-bugs.<you>.workers.dev/report
```

With the define empty (the default) the app only offers the share sheet.
The URL is not a secret. **The GitHub token must never be in the app, the
repo or the define.** It lives only as a secret in the worker or server.

## Endpoint contract

`POST <BUG_REPORT_URL>` with `Content-Type: application/json`:

```json
{
  "title": "[Bug] Chart looks wrong",
  "category": "bug",
  "body": "# markdown report ...",
  "device": { "app_version": "1.0.0", "build": "7", "platform": "android",
              "os_version": "...", "locale": "en-AE", "theme": "dark",
              "screen": "/home" },
  "screenshot_png_base64": "<optional, at most ~700 KB of PNG>"
}
```

Response: `201` with `{ "issue_url": "https://github.com/OWNER/REPO/issues/123" }`.
Any non-2xx makes the app fall back to the share sheet.

The server must:

* hold a **fine-grained personal access token** limited to the one repository,
  with only *Issues: read and write* (and *Contents: read and write* if you
  store screenshots as below). Set an expiry;
* rate limit (below: 5 reports per IP per hour, plus a global cap);
* reject bodies over 1 MB, titles over 120 characters, `body` over 60 KB,
  and categories other than `bug`, `confusing`, `idea`;
* never echo the token, and log nothing from the body;
* escape nothing into code: the body is Markdown the app already redacted, but
  treat it as untrusted text.

Use a **private** repository for reports, since screenshots can still show
what a tester forgot to hide.

## Cloudflare Worker (free plan)

`wrangler.toml`:

```toml
name = "pulse-bugs"
main = "worker.js"
compatibility_date = "2025-01-01"

[[kv_namespaces]]
binding = "RATE"
id = "<kv namespace id>"      # wrangler kv namespace create RATE

[vars]
REPO = "OWNER/pulse-bug-reports"   # private repo
```

```
wrangler secret put GITHUB_TOKEN     # paste the fine-scoped token here, only
```

`worker.js`:

```js
const CATS = { bug: "bug", confusing: "confusing", idea: "idea" };
const MAX_BODY = 1_000_000, PER_HOUR = 5, GLOBAL_PER_DAY = 200;
const json = (o, s = 200) =>
  new Response(JSON.stringify(o), { status: s, headers: { "content-type": "application/json" } });

async function bump(kv, key, ttl) {
  const n = parseInt((await kv.get(key)) || "0", 10) + 1;
  await kv.put(key, String(n), { expirationTtl: ttl });
  return n;
}

export default {
  async fetch(req, env) {
    if (req.method !== "POST") return json({ error: "method" }, 405);
    const len = parseInt(req.headers.get("content-length") || "0", 10);
    if (len > MAX_BODY) return json({ error: "too_large" }, 413);

    const ip = req.headers.get("cf-connecting-ip") || "unknown";
    const hour = new Date().toISOString().slice(0, 13);
    const day = hour.slice(0, 10);
    if ((await bump(env.RATE, `ip:${ip}:${hour}`, 3700)) > PER_HOUR) return json({ error: "rate" }, 429);
    if ((await bump(env.RATE, `all:${day}`, 90000)) > GLOBAL_PER_DAY) return json({ error: "busy" }, 429);

    let r;
    try { r = await req.json(); } catch { return json({ error: "json" }, 400); }
    const title = String(r.title || "").slice(0, 120);
    const category = CATS[r.category];
    const body = String(r.body || "");
    if (!title || !category || body.length > 60_000) return json({ error: "invalid" }, 400);

    const gh = (path, init) =>
      fetch(`https://api.github.com/repos/${env.REPO}/${path}`, {
        ...init,
        headers: {
          authorization: `Bearer ${env.GITHUB_TOKEN}`,
          accept: "application/vnd.github+json",
          "user-agent": "pulse-bug-worker",
          "content-type": "application/json",
        },
      });

    let extra = "";
    if (r.screenshot_png_base64 && r.screenshot_png_base64.length < 1_000_000) {
      const name = `screens/${Date.now()}-${crypto.randomUUID()}.png`;
      const put = await gh(`contents/${name}`, {
        method: "PUT",
        body: JSON.stringify({ message: "bug screenshot", content: r.screenshot_png_base64 }),
      });
      if (put.ok) extra = `\n\n## Screenshot\nhttps://github.com/${env.REPO}/blob/HEAD/${name}`;
    }

    const res = await gh("issues", {
      method: "POST",
      body: JSON.stringify({ title, body: body + extra, labels: ["beta-report", category] }),
    });
    if (!res.ok) return json({ error: "github" }, 502);
    const issue = await res.json();
    return json({ issue_url: issue.html_url }, 201);
  },
};
```

Create the labels `beta-report`, `bug`, `confusing`, `idea` in the repository
first (GitHub ignores unknown labels for tokens without triage rights).
Deploy with `wrangler deploy` when you are ready. Nothing has been deployed
by this change.

## FastAPI alternative

```python
import base64, os, time, uuid
import httpx
from collections import defaultdict, deque
from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel, Field

app = FastAPI()
TOKEN = os.environ["GITHUB_TOKEN"]        # server-side only
REPO = os.environ["REPO"]                 # "OWNER/pulse-bug-reports" (private)
PER_HOUR, MAX_BYTES = 5, 1_000_000
hits: dict[str, deque] = defaultdict(deque)

class Report(BaseModel):
    title: str = Field(max_length=120)
    category: str
    body: str = Field(max_length=60_000)
    screenshot_png_base64: str | None = Field(default=None, max_length=1_000_000)

@app.post("/report", status_code=201)
async def report(r: Report, request: Request):
    if int(request.headers.get("content-length", "0")) > MAX_BYTES:
        raise HTTPException(413)
    if r.category not in {"bug", "confusing", "idea"}:
        raise HTTPException(400)
    ip, now = request.client.host, time.time()
    q = hits[ip]
    while q and now - q[0] > 3600:
        q.popleft()
    if len(q) >= PER_HOUR:
        raise HTTPException(429)
    q.append(now)

    h = {"Authorization": f"Bearer {TOKEN}", "Accept": "application/vnd.github+json"}
    body = r.body
    async with httpx.AsyncClient(timeout=15) as c:
        if r.screenshot_png_base64:
            name = f"screens/{int(now)}-{uuid.uuid4()}.png"
            put = await c.put(f"https://api.github.com/repos/{REPO}/contents/{name}", headers=h,
                              json={"message": "bug screenshot", "content": r.screenshot_png_base64})
            if put.is_success:
                body += f"\n\n## Screenshot\nhttps://github.com/{REPO}/blob/HEAD/{name}"
        res = await c.post(f"https://api.github.com/repos/{REPO}/issues", headers=h,
                           json={"title": r.title, "body": body, "labels": ["beta-report", r.category]})
    if not res.is_success:
        raise HTTPException(502)
    return {"issue_url": res.json()["html_url"]}
```

Run it behind HTTPS on any free host. The in-memory rate limit resets on
restart; put a reverse proxy limit in front for anything public.

## Known limits

* Device model is not included: it needs a native plugin (`device_info_plus`)
  or a platform channel. OS name and version come from `dart:io`.
* Screenshots come from the Flutter view only. System dialogs, keyboards and
  platform views (maps, PDF viewers) may be missing.
* The redactor is deliberately blunt and cannot know a free-text note's
  meaning. The note is sent as typed, so the sheet asks testers to leave out
  names and amounts, and shows everything before it goes.
* Shake thresholds were set from typical values, not tuned on hardware.
