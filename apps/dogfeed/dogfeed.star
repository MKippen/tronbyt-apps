"""
Applet: Dog Feed
Summary: Dog feeding status
Description: Shows breakfast and dinner feeding status from Home Assistant with happy/hungry dog icons.
Author: tronbyt
"""

load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

OPENMOJI_BASE = "https://cdn.jsdelivr.net/gh/hfg-gmuend/openmoji@15.0.0/color/72x72/"

# Dog face for splash, bone for fed, hot dog (meat on bone) for hungry
EMOJI_DOG = "1F436"
EMOJI_FED = "1F966"       # broccoli = healthy fed
EMOJI_HUNGRY = "1F356"    # meat on bone = hungry

SPLASH_FRAMES = 25
SLIDE_FRAMES = 12
DATA_FRAMES = 1500
FRAME_DELAY = 80

GREEN = "#33BB55"
RED = "#CC3333"
GREEN_BG = "#091509"
RED_BG = "#150909"

def ease(t):
    if t < 0.5:
        return 2.0 * t * t
    return -1.0 + (4.0 - 2.0 * t) * t

def fetch_state(entity_id, ha_url, ha_token):
    if not entity_id or not ha_url or not ha_token:
        return "unknown", {}
    rep = http.get(
        ha_url + "/api/states/" + entity_id,
        ttl_seconds = 30,
        headers = {"Authorization": "Bearer " + ha_token},
    )
    if rep.status_code != 200:
        return "unknown", {}
    data = rep.json()
    return data.get("state", "unknown"), data.get("attributes", {})

def load_emoji(code):
    url = OPENMOJI_BASE + code + ".png"
    rep = http.get(url, ttl_seconds = 86400)
    return rep.body() if rep.status_code == 200 else None

def format_time_12h(time_str):
    """Convert '06:30:00' or '17:30:00' to '6:30a' or '5:30p'"""
    parts = time_str.split(":")
    if len(parts) < 2:
        return time_str
    h = int(parts[0])
    m = parts[1]
    suffix = "a"
    if h >= 12:
        suffix = "p"
    if h > 12:
        h = h - 12
    if h == 0:
        h = 12
    return str(h) + ":" + m + suffix

def is_past_time(time_str, now):
    """Check if current time is past the given HH:MM:SS schedule."""
    parts = time_str.split(":")
    if len(parts) < 2:
        return False
    h = int(parts[0])
    m = int(parts[1])
    return now.hour > h or (now.hour == h and now.minute >= m)

def main(config):
    ha_url = config.get("ha_url") or ""
    ha_token = config.get("ha_token") or ""

    # Fetch feeding states
    bkfst_state, _ = fetch_state("input_boolean.breakfast_fed", ha_url, ha_token)
    dinner_state, _ = fetch_state("input_boolean.dinner_fed", ha_url, ha_token)
    bkfst_time_state, bkfst_time_attrs = fetch_state("input_datetime.breakfast_time", ha_url, ha_token)
    dinner_time_state, dinner_time_attrs = fetch_state("input_datetime.dinner_time", ha_url, ha_token)

    bkfst_fed = (bkfst_state == "on")
    dinner_fed = (dinner_state == "on")

    bkfst_time = format_time_12h(bkfst_time_state) if bkfst_time_state != "unknown" else "???"
    dinner_time = format_time_12h(dinner_time_state) if dinner_time_state != "unknown" else "???"

    # Determine if it's past meal time (needs feeding)
    now = time.now()
    bkfst_due = is_past_time(bkfst_time_state, now)
    dinner_due = is_past_time(dinner_time_state, now)

    # Load dog emoji for splash
    dog_bytes = load_emoji(EMOJI_DOG)

    # Overall status for header — only "HUNGRY" if a meal is due and not fed
    any_hungry = (bkfst_due and not bkfst_fed) or (dinner_due and not dinner_fed)
    all_fed = bkfst_fed and dinner_fed
    accent = GREEN if not any_hungry else RED
    header_bg = GREEN_BG if not any_hungry else RED_BG
    status_text = "ALL FED" if all_fed else ("HUNGRY" if any_hungry else "OK")

    # ── SPLASH: dog face centered ────────────────────────────────────────
    dog_icon = render.Image(src = dog_bytes, width = 24, height = 24) if dog_bytes else render.Box(width = 24, height = 24)
    splash = render.Box(
        width = 64, height = 32, color = "#000000",
        child = render.Column(
            expanded = True, main_align = "center", cross_align = "center",
            children = [dog_icon],
        ),
    )

    # ── DATA VIEW ────────────────────────────────────────────────────────
    # Header band
    header = render.Column(children = [
        render.Box(height = 1, color = header_bg),
        render.Box(
            height = 6, color = header_bg,
            child = render.Row(
                expanded = True,
                main_align = "space_between",
                cross_align = "center",
                children = [
                    render.Padding(pad = (2, 0, 0, 0), child = render.Text("DOG FEED", font = "tom-thumb", color = "#CCCCCC")),
                    render.Padding(pad = (0, 0, 2, 0), child = render.Text(status_text, font = "tom-thumb", color = accent)),
                ],
            ),
        ),
        render.Box(width = 64, height = 1, color = accent),
    ])

    # Meal column helper
    def meal_col(label, fed, due, meal_time):
        if fed:
            color = GREEN
            bg = GREEN_BG
            status = "FED"
        elif due:
            color = RED
            bg = RED_BG
            status = "FEED!"
        else:
            color = "#666666"
            bg = "#111111"
            status = "OK"
        return render.Box(
            width = 31, height = 23,
            child = render.Column(
                expanded = True,
                main_align = "center",
                cross_align = "center",
                children = [
                    render.Text(label, font = "tom-thumb", color = "#AAAAAA"),
                    render.Box(height = 1),
                    render.Box(
                        width = 27, height = 9, color = bg,
                        child = render.Column(
                            expanded = True,
                            main_align = "center",
                            cross_align = "center",
                            children = [
                                render.Text(status, font = "tom-thumb", color = color),
                            ],
                        ),
                    ),
                    render.Box(height = 2),
                    render.Text(meal_time, font = "tom-thumb", color = "#666666"),
                ],
            ),
        )

    content = render.Column(children = [
        render.Box(height = 1),
        render.Box(
            height = 23,
            child = render.Row(
                expanded = True,
                main_align = "center",
                cross_align = "center",
                children = [
                    meal_col("BKFST", bkfst_fed, bkfst_due, bkfst_time),
                    render.Box(width = 1, height = 18, color = "#222222"),
                    meal_col("DINNER", dinner_fed, dinner_due, dinner_time),
                ],
            ),
        ),
    ])

    data = render.Column(children = [header, content])

    # ── ANIMATION: splash → push left → data hold ────────────────────────
    frames = []
    for _ in range(SPLASH_FRAMES):
        frames.append(splash)

    for i in range(SLIDE_FRAMES):
        t = ease((i + 1.0) / SLIDE_FRAMES)
        offset = int(64.0 * (1.0 - t))
        frames.append(render.Box(
            width = 64, height = 32, color = "#000000",
            child = render.Padding(
                pad = (-64 + offset, 0, 0, 0),
                child = render.Row(children = [splash, data]),
            ),
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
            schema.Text(
                id = "ha_url",
                name = "Home Assistant URL",
                desc = "Full URL of your HA instance (e.g. http://homeassistant.local:8123)",
                icon = "link",
            ),
            schema.Text(
                id = "ha_token",
                name = "HA Access Token",
                desc = "Long-lived access token from HA Profile > Security",
                icon = "key",
                secret = True,
            ),
        ],
    )
