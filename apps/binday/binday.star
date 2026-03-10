"""
Applet: Bin Day
Summary: Garbage/recycling reminder
Description: Shows which bins to take out with icon splash and slide animation. Only shows Sunday + Monday morning.
Author: tronbyt
"""

load("encoding/base64.star", "base64")
load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

BIN_ICON_B64 = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAYCAYAAAD6S912AAAAdklEQVR4nGNgoCdYsGDBf2yYZINOnDjxnxhMVcOINjQqKuo/KZgoV27ZsuU/MZgow2hqYFNTE4YhyGLDyECYJnwGguiBMxDmbXwGkmQYzQykShqEAWyuQ3YlyQbicyVZhoEARQUCOrCxsfkPw/jEBs7AUUA0AABJbte+qsV9zwAAAABJRU5ErkJggg=="

RECYCLE_BLUE = "#2196F3"
YARD_BROWN = "#8D6E3F"
LABEL_COLOR = "#CCCCCC"

SPLASH_FRAMES = 25
SLIDE_FRAMES = 12
DATA_FRAMES = 1500
FRAME_DELAY = 80

def ease(t):
    if t < 0.5:
        return 2.0 * t * t
    return -1.0 + (4.0 - 2.0 * t) * t

def hex_dim(color, factor):
    h = color.lstrip("#").upper()
    d = "0123456789ABCDEF"
    vals = []
    for i in range(3):
        v = (d.index(h[i * 2]) * 16 + d.index(h[i * 2 + 1]))
        v = int(v * factor)
        if v > 255:
            v = 255
        vals.append(v)
    return "#" + d[vals[0] >> 4] + d[vals[0] & 15] + d[vals[1] >> 4] + d[vals[1] & 15] + d[vals[2] >> 4] + d[vals[2] & 15]

def fetch_state(entity_id, ha_url, ha_token):
    if not entity_id or not ha_url or not ha_token:
        return "unknown"
    rep = http.get(
        ha_url + "/api/states/" + entity_id,
        ttl_seconds = 5,
        headers = {"Authorization": "Bearer " + ha_token},
    )
    if rep.status_code != 200:
        return "unknown"
    data = rep.json()
    return data.get("state", "unknown")

def main(config):
    ha_url = config.get("ha_url") or ""
    ha_token = config.get("ha_token") or ""

    now = time.now()

    # Show all day Sunday + Monday until 9am
    force_show = config.bool("force_show", False)
    today = now.format("Monday").lower()
    hour = now.hour
    show = False
    if today == "sunday":
        show = True
    elif today == "monday" and hour < 9:
        show = True
    if not show and not force_show:
        return []

    # Fetch which bins are active
    yard_entity = config.get("yard_entity") or "input_boolean.garbage_yardwaste"
    recycle_entity = config.get("recycle_entity") or "input_boolean.garbage_recycling"

    yard_on = fetch_state(yard_entity, ha_url, ha_token) == "on"
    recycle_on = fetch_state(recycle_entity, ha_url, ha_token) == "on"

    icon_bytes = base64.decode(BIN_ICON_B64)
    if recycle_on:
        accent = RECYCLE_BLUE
        bin_label = "RECYCLING"
    else:
        accent = YARD_BROWN
        bin_label = "YARD WASTE"

    header_bg = hex_dim(accent, 0.15)

    # ── SPLASH: centered icon on black ──
    icon = render.Image(src = icon_bytes, width = 20, height = 24)
    splash = render.Box(
        width = 64, height = 32, color = "#000000",
        child = render.Column(
            expanded = True, main_align = "center", cross_align = "center",
            children = [icon],
        ),
    )

    # ── DATA SCREEN ──
    header = render.Column(children = [
        render.Box(height = 1, color = header_bg),
        render.Box(
            height = 6, color = header_bg,
            child = render.Row(
                expanded = True,
                main_align = "center",
                cross_align = "center",
                children = [
                    render.Text("TRASH REMINDER", font = "tom-thumb", color = LABEL_COLOR),
                ],
            ),
        ),
        render.Box(width = 64, height = 1, color = accent),
    ])

    content = render.Box(
        height = 24,
        child = render.Column(
            expanded = True, main_align = "center", cross_align = "center",
            children = [
                render.Text(bin_label, font = "tb-8", color = accent),
            ],
        ),
    )

    data = render.Column(children = [header, content])

    # ── ANIMATION: splash → slide → hold ──
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
            schema.Text(
                id = "yard_entity",
                name = "Yard Waste Entity",
                desc = "HA input_boolean for yard waste week",
                icon = "leaf",
                default = "input_boolean.garbage_yardwaste",
            ),
            schema.Text(
                id = "recycle_entity",
                name = "Recycling Entity",
                desc = "HA input_boolean for recycling week",
                icon = "recycle",
                default = "input_boolean.garbage_recycling",
            ),
        ],
    )
