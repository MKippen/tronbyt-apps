"""
Applet: F1 Next Race
Summary: Next Formula 1 grand prix
Description: Shows the next F1 race location, date, and local start time with a racing car splash animation.
Author: tronbyt
"""

load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

OPENMOJI_BASE = "https://cdn.jsdelivr.net/gh/hfg-gmuend/openmoji@15.0.0/color/72x72/"
F1_NEXT_URL   = "https://raw.githubusercontent.com/jvivona/tidbyt-data/refs/heads/main/formula1/next.json"

ACCENT    = "#CC0000"   # F1 red
HEADER_BG = "#150000"   # deep red tint

SPLASH_FRAMES = 25    # ~2s icon hold
SLIDE_FRAMES  = 12    # ~1s ease-in slide
DATA_FRAMES   = 1500  # ~120s data hold — never loops at normal display times
FRAME_DELAY   = 80    # ms per frame

def ease(t):
    if t < 0.5:
        return 2.0 * t * t
    return -1.0 + (4.0 - 2.0 * t) * t

def fetch_next_race():
    rep = http.get(F1_NEXT_URL, ttl_seconds = 1800)
    if rep.status_code != 200:
        return None
    races = rep.json().get("MRData", {}).get("RaceTable", {}).get("Races", [])
    return races[0] if races else None

def load_icon(code):
    rep = http.get(OPENMOJI_BASE + code + ".png", ttl_seconds = 86400)
    return rep.body() if rep.status_code == 200 else None

def main(config):
    tz    = config.get("$tz") or "America/New_York"
    use24 = config.get("use_24hour") == "true"

    icon_img = load_icon("1F3CE-FE0F")  # 🏎️ racing car
    race     = fetch_next_race()

    if race == None:
        return render.Root(child = render.Box(
            width = 64, height = 32,
            child = render.Column(
                expanded = True, main_align = "center", cross_align = "center",
                children = [
                    render.Text("F1", font = "tb-8", color = ACCENT),
                    render.Text("off season", font = "tom-thumb", color = "#888888"),
                ],
            ),
        ))

    race_date = race.get("date", "")
    race_time = race.get("time", "")

    if race_time and race_time != "TBD":
        race_dt  = time.parse_time(race_date + "T" + race_time, "2006-01-02T15:04:05Z", "UTC").in_location(tz)
        time_str = race_dt.format("15:04") if use24 else race_dt.format("3:04") + " " + race_dt.format("PM")
    else:
        race_dt  = time.parse_time(race_date + "T12:00:00Z", "2006-01-02T15:04:05Z", "UTC").in_location(tz)
        time_str = "TBD"

    date_str = race_dt.format("Jan 2")          # "Mar 8"
    day_str  = race_dt.format("Mon").upper()    # "SUN"
    locality  = race.get("Circuit", {}).get("Location", {}).get("locality", "?").upper()
    round_str = "R" + race.get("round", "?")

    # ── SPLASH: big icon centered ──────────────────────────────────────────
    big_icon = render.Image(src = icon_img, width = 28, height = 28) if icon_img else render.Box(width = 28, height = 28)
    splash = render.Box(
        width = 64, height = 32, color = HEADER_BG,
        child = render.Column(
            expanded = True, main_align = "center", cross_align = "center",
            children = [big_icon],
        ),
    )

    # ── DATA VIEW ─────────────────────────────────────────────────────────
    small_icon = render.Image(src = icon_img, width = 6, height = 6) if icon_img else render.Box(width = 6, height = 6)

    # Header: icon + city (left), round (right), red accent line
    header = render.Column(children = [
        render.Box(height = 1, color = HEADER_BG),
        render.Box(
            height = 6, color = HEADER_BG,
            child = render.Row(
                expanded = True,
                main_align = "space_between",
                cross_align = "center",
                children = [
                    render.Row(
                        cross_align = "center",
                        children = [
                            render.Padding(pad = (1, 0, 1, 0), child = small_icon),
                            render.Text(locality, font = "tom-thumb", color = "#CCCCCC"),
                        ],
                    ),
                    render.Padding(pad = (0, 0, 2, 0), child = render.Text(round_str, font = "tom-thumb", color = ACCENT)),
                ],
            ),
        ),
        render.Box(width = 64, height = 1, color = ACCENT),
    ])

    # Middle: hero race date in terminus-14
    date_area = render.Box(
        height = 16,
        child = render.Column(
            expanded = True, main_align = "center", cross_align = "center",
            children = [render.Text(date_str, font = "terminus-14", color = "#FFFFFF")],
        ),
    )

    # Bottom: day (left, dim) — local race time (right, red)
    time_area = render.Box(
        height = 8,
        child = render.Row(
            expanded = True,
            main_align = "space_between",
            cross_align = "center",
            children = [
                render.Padding(pad = (4, 0, 0, 0), child = render.Text(day_str, font = "tom-thumb", color = "#888888")),
                render.Padding(pad = (0, 0, 4, 0), child = render.Text(time_str, font = "tom-thumb", color = ACCENT)),
            ],
        ),
    )

    data = render.Column(children = [header, date_area, time_area])

    # ── ANIMATION: icon splash → ease slide → data hold ───────────────────
    frames = []
    for _ in range(SPLASH_FRAMES):
        frames.append(splash)
    for i in range(SLIDE_FRAMES):
        t   = ease((i + 1.0) / SLIDE_FRAMES)
        pad = int(64.0 * (1.0 - t))
        frames.append(render.Stack(children = [
            splash,
            render.Padding(pad = (pad, 0, 0, 0), child = data),
        ]))
    for _ in range(DATA_FRAMES):
        frames.append(data)

    return render.Root(
        delay = FRAME_DELAY,
        child = render.Animation(children = frames),
    )

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Toggle(
                id = "use_24hour",
                name = "24-Hour Time",
                desc = "Display race start time in 24-hour format",
                icon = "clock",
                default = False,
            ),
        ],
    )
