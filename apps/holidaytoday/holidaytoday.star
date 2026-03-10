"""
Applet: Holiday Today
Summary: Today's US holiday with emoji
Description: Shows today's US public holiday (or next upcoming) with a matching emoji icon. Uses the API Ninjas holidays API.
Author: tronbyt
"""

load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

API_URL = "https://api.api-ninjas.com/v1/holidays"
OPENMOJI_BASE = "https://cdn.jsdelivr.net/gh/hfg-gmuend/openmoji@15.0.0/color/72x72/"

# Keyword → OpenMoji codepoint (single-codepoint where possible for reliability)
HOLIDAY_EMOJIS = {
    "new year": "1F387",
    "martin luther king": "262E-FE0F",
    "mlk": "262E-FE0F",
    "presidents": "1F3DB-FE0F",
    "washington": "1F3DB-FE0F",
    "memorial": "1F3C5",
    "juneteenth": "270A",
    "independence": "1F386",
    "labor": "1F527",
    "columbus": "1F30E",
    "indigenous": "1F30E",
    "veterans": "1F396-FE0F",
    "thanksgiving": "1F983",
    "christmas": "1F384",
    "easter": "1F423",
    "halloween": "1F383",
    "valentine": "2764-FE0F",
}
DEFAULT_EMOJI = "2B50"

def get_emoji_code(name):
    lower = name.lower()
    for keyword in HOLIDAY_EMOJIS:
        if keyword in lower:
            return HOLIDAY_EMOJIS[keyword]
    return DEFAULT_EMOJI

def load_emoji(code):
    url = OPENMOJI_BASE + code + ".png"
    rep = http.get(url, ttl_seconds = 86400)
    if rep.status_code == 200:
        return rep.body()
    return None

def fetch_holidays(api_key, year):
    url = API_URL + "?country=US"
    rep = http.get(url, ttl_seconds = 86400, headers = {"X-Api-Key": api_key})
    if rep.status_code != 200:
        return []
    return rep.json()

def find_today(holidays, today_iso):
    for h in holidays:
        if h.get("date", "") == today_iso:
            return h
    return None

def find_next(holidays, today_iso):
    best = None
    for h in holidays:
        d = h.get("date", "")
        if d > today_iso:
            if best == None or d < best.get("date", ""):
                best = h
    return best

def days_between(today, target):
    ty = int(today[0:4])
    tm = int(today[5:7])
    td = int(today[8:10])
    hy = int(target[0:4])
    hm = int(target[5:7])
    hd = int(target[8:10])
    return (hy - ty) * 365 + (hm - tm) * 30 + (hd - td)

def render_no_key():
    return render.Root(child = render.Box(
        width = 64, height = 32,
        child = render.Column(
            expanded = True, main_align = "center", cross_align = "center",
            children = [
                render.Text("HOLIDAY", font = "tom-thumb", color = "#888888"),
                render.Text("add api key", font = "tom-thumb", color = "#555555"),
            ],
        ),
    ))

def main(config):
    api_key = config.get("api_key", "")
    if not api_key:
        return render_no_key()

    tz = config.get("$tz") or "America/New_York"
    now = time.now().in_location(tz)
    today_iso = now.format("2006-01-02")
    year = now.format("2006")
    date_str = now.format("Jan 2").upper()

    holidays = fetch_holidays(api_key, year)

    holiday = find_today(holidays, today_iso)
    is_today = holiday != None
    if not is_today:
        holiday = find_next(holidays, today_iso)

    if holiday == None:
        return render.Root(child = render.Box(
            width = 64, height = 32,
            child = render.Column(
                expanded = True, main_align = "center", cross_align = "center",
                children = [render.Text("No holidays", font = "tom-thumb", color = "#666666")],
            ),
        ))

    name = holiday.get("name", "Holiday")
    emoji_code = get_emoji_code(name)
    icon_bytes = load_emoji(emoji_code)

    # Color / subtext
    if is_today:
        accent = "#FFCC00"
        header_bg = "#1A1400"
        sub_text = "TODAY"
    else:
        target_iso = holiday.get("date", "")
        days = days_between(today_iso, target_iso)
        accent = "#5588FF"
        header_bg = "#080D1A"
        sub_text = "in " + str(days) + "d"

    # ── HEADER ─────────────────────────────────────────────────────────────
    header = render.Column(children = [
        render.Box(height = 1, color = header_bg),
        render.Box(
            height = 6, color = header_bg,
            child = render.Row(
                expanded = True,
                main_align = "space_between",
                cross_align = "center",
                children = [
                    render.Padding(pad = (2, 0, 0, 0), child = render.Text("HOLIDAY", font = "tom-thumb", color = "#CCCCCC")),
                    render.Padding(pad = (0, 0, 2, 0), child = render.Text(date_str, font = "tom-thumb", color = accent)),
                ],
            ),
        ),
        render.Box(width = 64, height = 1, color = accent),
    ])

    # ── EMOJI ICON ─────────────────────────────────────────────────────────
    icon_size = 22
    if icon_bytes:
        icon_inner = render.Image(src = icon_bytes, width = icon_size - 2, height = icon_size - 2)
    else:
        icon_inner = render.Box(width = icon_size - 2, height = icon_size - 2, color = "#333")
    icon_box = render.Stack(children = [
        render.Box(width = icon_size, height = icon_size, color = header_bg),
        render.Padding(pad = (1, 1, 0, 0), child = icon_inner),
    ])

    # ── TEXT COLUMN ─────────────────────────────────────────────────────────
    text_col = render.Column(
        main_align = "center",
        cross_align = "start",
        expanded = True,
        children = [
            render.Marquee(
                width = 64 - icon_size - 4,
                child = render.Text(name, font = "tb-8", color = "#FFFFFF"),
            ),
            render.Text(sub_text, font = "tom-thumb", color = accent),
        ],
    )

    # ── CONTENT ─────────────────────────────────────────────────────────────
    content = render.Box(
        height = 24,
        child = render.Row(
            expanded = True,
            cross_align = "center",
            children = [
                icon_box,
                render.Padding(pad = (2, 0, 0, 0), child = text_col),
            ],
        ),
    )

    return render.Root(child = render.Column(children = [header, content]))

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "api_key",
                name = "API Ninjas Key",
                desc = "Free API key from api-ninjas.com — used to fetch US public holidays",
                icon = "key",
                default = "",
            ),
        ],
    )
