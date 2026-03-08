"""
Applet: F1 Next Race
Summary: Next Formula 1 grand prix
Description: Shows the next F1 race with circuit map, date, and local start time. Only appears within 5 days of the race.
Author: tronbyt
"""

load("encoding/base64.star", "base64")
load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

F1_NEXT_URL   = "https://raw.githubusercontent.com/jvivona/tidbyt-data/refs/heads/main/formula1/next.json"
F1_TRACKS_URL = "https://raw.githubusercontent.com/jvivona/tidbyt-data/refs/heads/main/formula1/metadata/tracks.json"

ACCENT    = "#CC0000"
HEADER_BG = "#150000"

SPLASH_FRAMES = 25
SLIDE_FRAMES  = 12
DATA_FRAMES   = 1500
FRAME_DELAY   = 80

# F1 logo — 64×16 PNG, embedded so no runtime HTTP needed for the splash
F1_LOGO_B64 = "iVBORw0KGgoAAAANSUhEUgAAAEAAAAAQCAYAAACm53kpAAAABGdBTUEAALGPC/xhBQAAACBjSFJNAAB6JgAAgIQAAPoAAACA6AAAdTAAAOpgAAA6mAAAF3CculE8AAAARGVYSWZNTQAqAAAACAABh2kABAAAAAEAAAAaAAAAAAADoAEAAwAAAAEAAQAAoAIABAAAAAEAAABAoAMABAAAAAEAAAAQAAAAAH5CjXsAAAQ9SURBVFgJvZZraI5hGMevvTuYMcsOmPjCGuWDLLWa7NtEZum1mkTaal/I4QOrNUkjUUJIWY3mMGQ5RUj5IB+E5APllJUch43ZjB39/vNO8zzPe8rLVXfv/Tz3dV/X//+/rvt+3jiLgTWbJaeZ5fjMphFudp/ZrDiz6cx5bSnMkwZikCdUiIRfi13kLiBXf7zZLX5T+z02gdNYt26zLYF9Hl4RvHpvNnWEWQWuJSTLTYQoZK2XocQiPTSY/jMjr/J1QqgMcj2QugiOVMRwmchr9JhVZ5jtEN6o7Z5ZYo7ZegJVIUAmiQdJi+z/tgD5dgj5IfMO8lcYk394ABFxKt8P3o2Q3y2XqAXoMBuPsnVJVF3EvVRW4P9hIo/orXTcYkZHstllSGYLl9PU8qz1ItS6dLODQ+uIFbm95oxDuJGq530Ls03KRq1umJjDl0UeLC2QLdF7yF+DYFYI8t2sraLy9cPjRIyxzWwmCc6SeMr34RECcwWiKwbPl+4ARi/nspv3eoypgcNH3BbavBQ8qVTxHAnSqa7LVGF8v7NWSeWPOx0i6oCPZvm0UBNjkhf5QDV0sVyH9AUAPmZ0UiHdxv0o4JPP35oIEjeRtlfsFzzOIf4pfscEI8+aLsdyKn+GuctUuJDWYlY40uw0jhO82ovWE/GXAFqNzysUXYgI+YyJLKUClhMz2Bhhc4UEwiIiJiDmM0RYTM65dNwJXo/yajEJTu52cK0Yy1chWOyQoD6ZFRHoJAkzvMgjjL6ldxnL8fPjVwPb0QKEADH9BEpouu85pOZDKg/yR5knhyDfhkjLqPxVtga1oAJ8MFsEmWM4pHm1VwohAXQDMCshXosY5ToeIh5rk9Cc94fkWgCeQsQ+AvkkL/K6h8DwgaIszQRfOCxgdxuVLyXQyVDku8zOA2oZAfYgRrm+Cv+Q/H0IFZFiHuQbyONJXmeNtXcI44+EvJi7LkEuvBWQr1N7OSuvdlE1IN9AtTeS8DDPxZ2K5DCBGVKXWFGbcgkcsW8Tp5hRBq79EPTRCS5TPt6/QqglkL/jcgjyQnl+G5WvJNABAiU5k8gxcA73IcBWqt7Ic5Hz/4BIczPrbrjBnmuMtwjQw4hKB8XAtOc6WCogv0uYvLoscBE305H+cWYPtDFq4zu/9ivf7C8kbXWMzzxTiQF+t7Xz1xffm3SAy097We9DyA0g/0PcqAEFNpBrE/8+lduVTzgpgHI+eWs2g5yJ5C7AN+8NOMGTEy7v4BEgUBWTHSgc51RYLKhGH+pupgr1+Fyi7fOdlZcf1dcfjvXcvIfCJQ63Dpl4yG8lZ7WOohOX9nMf6BP8iG7zZ5s9lQBgyOV1Ap1cwh5tq2UENR/kayC/04u8dulscansTTfbTqImnl3k5QdQganF76/JKx641nDMqsnpSV5HBMyfyFmaBXntoQg6ai1MmxnxsH/Dc8hO/Al8VltdlA6wRwAAAABJRU5ErkJggg=="

def ease(t):
    if t < 0.5:
        return 2.0 * t * t
    return -1.0 + (4.0 - 2.0 * t) * t

def fetch_json(url, ttl):
    rep = http.get(url, ttl_seconds = ttl)
    if rep.status_code != 200:
        return None
    return rep.json()

def main(config):
    tz    = config.get("$tz") or "America/New_York"
    use24 = config.get("use_24hour") == "true"

    race_data = fetch_json(F1_NEXT_URL, 1800)
    if race_data == None:
        return None
    races = race_data.get("MRData", {}).get("RaceTable", {}).get("Races", [])
    if not races:
        return None

    race      = races[0]
    race_date = race.get("date", "")
    race_time = race.get("time", "")

    if race_time and race_time != "TBD":
        race_dt  = time.parse_time(race_date + "T" + race_time, "2006-01-02T15:04:05Z", "UTC").in_location(tz)
        time_str = race_dt.format("15:04") if use24 else race_dt.format("3:04pm").replace("m", "")
    else:
        race_dt  = time.parse_time(race_date + "T12:00:00Z", "2006-01-02T15:04:05Z", "UTC").in_location(tz)
        time_str = "TBD"

    date_str   = race_dt.format("Jan 2")
    locality   = race.get("Circuit", {}).get("Location", {}).get("locality", "?").upper()
    round_str  = "R" + race.get("round", "?")
    round_lbl  = "Race " + race.get("round", "?")
    circuit_id = race.get("Circuit", {}).get("circuitId", "").lower()

    # Load circuit map (28×23 outline, fetched + cached for 24h)
    track_img = None
    tracks = fetch_json(F1_TRACKS_URL, 86400)
    if tracks and circuit_id in tracks:
        track_img = base64.decode(tracks[circuit_id])

    # ── SPLASH: F1 logo centered on dark red ──────────────────────────────
    logo_img = base64.decode(F1_LOGO_B64)
    splash = render.Box(
        width = 64, height = 32, color = "#000000",
        child = render.Column(
            expanded = True, main_align = "center", cross_align = "center",
            children = [render.Image(src = logo_img, width = 48, height = 12)],
        ),
    )

    # ── DATA VIEW ─────────────────────────────────────────────────────────
    # Header: city left, round right
    header = render.Column(children = [
        render.Box(height = 1, color = HEADER_BG),
        render.Box(
            height = 6, color = HEADER_BG,
            child = render.Row(
                expanded = True,
                main_align = "space_between",
                cross_align = "center",
                children = [
                    render.Padding(pad = (2, 0, 0, 0), child = render.Text(locality, font = "tom-thumb", color = "#CCCCCC")),
                    render.Padding(pad = (0, 0, 2, 0), child = render.Text(round_str, font = "tom-thumb", color = ACCENT)),
                ],
            ),
        ),
        render.Box(width = 64, height = 1, color = ACCENT),
    ])

    # Content: circuit map left (28px) + race info right (36px)
    left_widget = render.Image(src = track_img, width = 28, height = 23) if track_img else render.Box(width = 28, height = 23)

    right_widget = render.Box(
        width = 36, height = 24,
        child = render.Column(
            expanded = True,
            main_align = "center",
            cross_align = "start",
            children = [
                render.Padding(pad = (2, 0, 0, 0), child = render.Text(date_str, font = "5x8", color = "#FFFFFF")),
                render.Padding(pad = (2, 2, 0, 0), child = render.Text(time_str, font = "tom-thumb", color = ACCENT)),
                render.Padding(pad = (2, 0, 0, 0), child = render.Text(round_lbl, font = "tom-thumb", color = "#666666")),
            ],
        ),
    )

    content = render.Row(children = [left_widget, right_widget])
    data    = render.Column(children = [header, content])

    # ── ANIMATION: F1 logo splash → ease → data hold ─────────────────────────
    # Each slide frame is self-contained: a 64×32 black box with a Row of
    # [black spacer | data]. No stacking over the splash, so no bleed-through.
    frames = []
    for _ in range(SPLASH_FRAMES):
        frames.append(splash)
    for i in range(SLIDE_FRAMES):
        t   = ease((i + 1.0) / SLIDE_FRAMES)
        pad = int(64.0 * (1.0 - t))
        frames.append(render.Box(
            width = 64, height = 32, color = "#000000",
            child = render.Row(children = [
                render.Box(width = pad, height = 32),
                data,
            ]),
        ))
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
