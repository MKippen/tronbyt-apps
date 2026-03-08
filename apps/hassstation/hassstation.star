"""
Applet: HASS Sensor Station
Summary: Named HA station with two sensors
Description: Displays a named Home Assistant sensor station with two entities side by side. Perfect for greenhouse temp/humidity, energy pair, or any two sensors in a room.
Author: tronbyt
"""

load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")

OPENMOJI_BASE = "https://cdn.jsdelivr.net/gh/hfg-gmuend/openmoji@15.0.0/color/72x72/"

# Animation timing
SPLASH_FRAMES = 25  # icon holds for ~2s
SLIDE_FRAMES = 12   # slide transition ~1s
DATA_FRAMES = 1500  # data holds for ~120s — animation never loops for any sane display time
FRAME_DELAY = 80    # ms per frame

def ease(t):
    # Smooth ease-in-out — slow start, fast middle, slow end
    if t < 0.5:
        return 2.0 * t * t
    return -1.0 + (4.0 - 2.0 * t) * t

def make_secondary_widget(num, unit, color):
    """Secondary sensor: number in tom-thumb, unit slightly offset for visual separation."""
    if unit:
        return render.Row(
            cross_align = "center",
            children = [
                render.Text(num, font = "tom-thumb", color = color),
                render.Padding(pad = (1, 1, 0, 0), child = render.Text(unit, font = "tom-thumb", color = color)),
            ],
        )
    return render.Text(num, font = "tom-thumb", color = color)

STATION_EMOJIS = [
    # Plants & Garden
    ("🪴 Potted Plant", "1FAB4"),
    ("🌿 Herb", "1F33F"),
    ("🌱 Seedling", "1F331"),
    ("🌲 Evergreen", "1F332"),
    ("🌵 Cactus", "1F335"),
    ("🍀 Clover", "1F340"),
    # Home Rooms
    ("🏠 House", "1F3E0"),
    ("🛋️ Living Room", "1F6CB-FE0F"),
    ("🛏️ Bedroom", "1F6CF-FE0F"),
    ("🍳 Kitchen", "1F373"),
    ("🚿 Bathroom", "1F6BF"),
    ("🪟 Window", "1FA9F"),
    # Garage & Outdoor
    ("🚗 Garage", "1F697"),
    ("🌊 Pool", "1F30A"),
    # Energy
    ("⚡ Energy", "26A1"),
    ("🔋 Battery", "1F50B"),
    ("🔌 Power", "1F50C"),
    ("🔥 Heating", "1F525"),
    ("💧 Water", "1F4A7"),
    # Fitness & Health
    ("🏃 Activity", "1F3C3"),
    ("❤️ Health", "2764-FE0F"),
    # Misc
    ("⭐ Custom", "2B50"),
    ("🐶 Pet Area", "1F436"),
    ("🐱 Cat Area", "1F431"),
]

CONDITION_TYPES = [
    ("above threshold", "above"),
    ("below threshold", "below"),
    ("equals value", "equals"),
    ("not equals value", "not_equals"),
    ("is 'on'", "is_on"),
    ("is 'off'", "is_off"),
]

def check_condition(state, cond_type, cond_value):
    if cond_type == "is_on":
        return state == "on"
    if cond_type == "is_off":
        return state == "off"
    if cond_type == "equals":
        return state == cond_value
    if cond_type == "not_equals":
        return state != cond_value
    if cond_type in ("above", "below") and is_numeric(state) and is_numeric(cond_value):
        val = float(state)
        threshold = float(cond_value)
        return val > threshold if cond_type == "above" else val < threshold
    return False

def is_numeric(s):
    if not s:
        return False
    test = s
    if test.startswith("-"):
        test = test[1:]
    if not test:
        return False
    parts = test.split(".")
    if len(parts) == 1:
        return parts[0].isdigit()
    if len(parts) == 2:
        return parts[0].isdigit() and parts[1].isdigit() and len(parts[0]) > 0
    return False

def format_value(state, unit, decimals):
    display = state
    if is_numeric(state):
        val = float(state)
        if decimals == 0:
            rounded = int(val + 0.5) if val >= 0.0 else int(val - 0.5)
            display = str(rounded)
        elif decimals == 1:
            r = int(val * 10.0 + 0.5) if val >= 0.0 else int(val * 10.0 - 0.5)
            display = str(r // 10) + "." + str(r % 10)
        else:
            r = int(val * 100.0 + 0.5) if val >= 0.0 else int(val * 100.0 - 0.5)
            dec = str(r % 100)
            display = str(r // 100) + "." + (dec if len(dec) == 2 else "0" + dec)
    return (display + unit) if unit else display

def fetch_entity(entity_id, ha_url, ha_token):
    if not entity_id or not ha_url or not ha_token:
        return "N/A", "", ""
    rep = http.get(
        ha_url + "/api/states/" + entity_id,
        ttl_seconds = 30,
        headers = {"Authorization": "Bearer " + ha_token},
    )
    if rep.status_code != 200:
        return "ERR", "", ""
    data = rep.json()
    attrs = data.get("attributes", {})
    return data.get("state", "N/A"), attrs.get("unit_of_measurement", ""), attrs.get("friendly_name", "")

def _hex2(n):
    n = max(0, min(255, int(n + 0.5)))
    d = "0123456789ABCDEF"
    return d[n >> 4] + d[n & 15]

def _hex_to_rgb(c):
    h = c.lstrip("#").upper()
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)

def _lerp_color(ca, cb, t):
    ra, ga, ba = _hex_to_rgb(ca)
    rb, gb, bb = _hex_to_rgb(cb)
    return "#" + _hex2(ra + t * (rb - ra)) + _hex2(ga + t * (gb - ga)) + _hex2(ba + t * (bb - ba))

def _gradient_color(val, low_v, mid_v, high_v, low_c, mid_c, high_c):
    if val <= low_v:
        return low_c
    if val >= high_v:
        return high_c
    if val <= mid_v:
        return _lerp_color(low_c, mid_c, (val - low_v) / (mid_v - low_v))
    return _lerp_color(mid_c, high_c, (val - mid_v) / (high_v - mid_v))

def get_value_color(state, config, suffix):
    normal = config.get("normal_color" + suffix) or "#FFFFFF"
    if not is_numeric(state):
        return normal
    val = float(state)

    # Gradient mode: smoothly blend low → normal → high color by value position
    if config.get("gradient" + suffix) == "true":
        low_v = config.get("below_value" + suffix) or ""
        mid_v = config.get("normal_value" + suffix) or ""
        high_v = config.get("above_value" + suffix) or ""
        low_c = config.get("below_color" + suffix) or "#4488FF"
        high_c = config.get("above_color" + suffix) or "#FF4444"
        if is_numeric(low_v) and is_numeric(mid_v) and is_numeric(high_v):
            return _gradient_color(val, float(low_v), float(mid_v), float(high_v), low_c, normal, high_c)

    # Threshold mode (default): hard switch at boundaries
    above_val = config.get("above_value" + suffix) or ""
    below_val = config.get("below_value" + suffix) or ""
    if above_val and is_numeric(above_val) and val > float(above_val):
        return config.get("above_color" + suffix) or "#FF4444"
    if below_val and is_numeric(below_val) and val < float(below_val):
        return config.get("below_color" + suffix) or "#4488FF"
    return normal

def load_emoji(code):
    if not code:
        return None
    rep = http.get(OPENMOJI_BASE + code + ".png", ttl_seconds = 86400)
    return rep.body() if rep.status_code == 200 else None

def main(config):
    ha_url = config.get("ha_url") or ""
    ha_token = config.get("ha_token") or ""

    # Visibility condition — return None (skip in rotation) if not met
    cond_entity = config.get("cond_entity") or ""
    if cond_entity:
        cond_state, _, _ = fetch_entity(cond_entity, ha_url, ha_token)
        if not check_condition(cond_state, config.get("cond_type") or "above", config.get("cond_value") or ""):
            return None

    station_name = config.get("station_name") or "Station"
    station_emoji = config.get("station_emoji") or "1FAB4"
    header_color = config.get("header_color") or "#0a1a0a"
    accent_color = config.get("accent_color") or "#2a7a2a"

    # Primary entity (middle row — hero metric)
    entity_id_1 = config.get("entity_id_1") or ""
    state1, unit1, _ = fetch_entity(entity_id_1, ha_url, ha_token)
    decimals1 = int(config.get("decimals_1") or "0")
    unit_str1 = config.get("unit_1") or unit1 or ""
    num1 = format_value(state1, "", decimals1)
    color1 = get_value_color(state1, config, "_1")

    # Secondary entity — left slot of bottom bar
    entity_id_2 = config.get("entity_id_2") or ""
    state2, unit2, _ = fetch_entity(entity_id_2, ha_url, ha_token)
    decimals2 = int(config.get("decimals_2") or "0")
    unit_str2 = config.get("unit_2") or unit2 or ""
    num2 = format_value(state2, "", decimals2)
    color2 = get_value_color(state2, config, "_2")

    # Tertiary entity — right slot of bottom bar (optional)
    entity_id_3 = config.get("entity_id_3") or ""
    num3 = None
    unit_str3 = ""
    color3 = "#888888"
    if entity_id_3:
        state3, unit3, _ = fetch_entity(entity_id_3, ha_url, ha_token)
        decimals3 = int(config.get("decimals_3") or "0")
        unit_str3 = config.get("unit_3") or unit3 or ""
        num3 = format_value(state3, "", decimals3)
        color3 = get_value_color(state3, config, "_3")

    station_icon = load_emoji(station_emoji)

    # ── SPLASH: big icon centered on dark bg ──────────────────────────────
    big_icon = render.Image(src = station_icon, width = 28, height = 28) if station_icon else render.Box(width = 28, height = 28)
    splash = render.Box(
        width = 64,
        height = 32,
        color = header_color,
        child = render.Column(
            expanded = True,
            main_align = "center",
            cross_align = "center",
            children = [big_icon],
        ),
    )

    # ── DATA VIEW: the station layout ─────────────────────────────────────
    # Header (9px): 8px band + 1px accent line — 8px matches icon/tom-thumb height exactly
    icon_widget = render.Image(src = station_icon, width = 8, height = 8) if station_icon else render.Box(width = 8, height = 8)
    top = render.Column(children = [
        render.Box(
            height = 8,
            color = header_color,
            child = render.Row(
                cross_align = "center",
                children = [
                    render.Padding(pad = (1, 0, 1, 0), child = icon_widget),
                    render.Text(station_name, font = "tom-thumb", color = "#88cc88"),
                ],
            ),
        ),
        render.Box(width = 64, height = 1, color = accent_color),
    ])

    # Primary (15px): hero metric centered — number big, unit small
    if unit_str1:
        hero = render.Row(
            cross_align = "end",
            children = [
                render.Text(num1, font = "terminus-14", color = color1),
                render.Padding(pad = (1, 0, 0, 1), child = render.Text(unit_str1, font = "tb-8", color = color1)),
            ],
        )
    else:
        hero = render.Text(num1, font = "terminus-14", color = color1)

    middle = render.Box(
        height = 16,
        child = render.Column(
            expanded = True,
            main_align = "center",
            cross_align = "center",
            children = [hero],
        ),
    )

    # Bottom (7px): secondary entities
    if num3:
        bottom_child = render.Row(
            expanded = True,
            children = [
                render.Box(
                    width = 31,
                    child = render.Column(
                        expanded = True,
                        main_align = "center",
                        cross_align = "center",
                        children = [make_secondary_widget(num2, unit_str2, color2)],
                    ),
                ),
                render.Box(width = 1, height = 7, color = "#1a1a1a"),
                render.Box(
                    width = 32,
                    child = render.Column(
                        expanded = True,
                        main_align = "center",
                        cross_align = "center",
                        children = [make_secondary_widget(num3, unit_str3, color3)],
                    ),
                ),
            ],
        )
    else:
        bottom_child = render.Column(
            expanded = True,
            main_align = "center",
            cross_align = "center",
            children = [make_secondary_widget(num2, unit_str2, color2)],
        )

    bottom = render.Box(height = 7, child = bottom_child)
    data = render.Column(children = [top, middle, bottom])

    # ── ANIMATION ─────────────────────────────────────────────────────────
    # Phase 1: icon splash holds
    # Phase 2: data slides in over solid black (self-contained frames, no stack
    #          over splash so the icon can't bleed through)
    # Phase 3: data holds, then loops
    frames = []

    for _ in range(SPLASH_FRAMES):
        frames.append(splash)

    for i in range(SLIDE_FRAMES):
        t = ease((i + 1.0) / SLIDE_FRAMES)
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
    emoji_options = [
        schema.Option(display = name, value = code)
        for name, code in STATION_EMOJIS
    ]

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
                desc = "Long-lived access token from HA Profile > Security > Long-lived access tokens",
                icon = "key",
                secret = True,
            ),
            schema.Text(
                id = "station_name",
                name = "Station Name",
                desc = "Name displayed in the header (e.g. Greenhouse, Living Room, Garage)",
                icon = "tag",
                default = "Station",
            ),
            schema.Dropdown(
                id = "station_emoji",
                name = "Station Icon",
                desc = "Emoji shown next to the station name in the header",
                icon = "faceGrin",
                default = "1FAB4",
                options = emoji_options,
            ),
            schema.Color(
                id = "header_color",
                name = "Header Background",
                desc = "Background color of the station name band",
                icon = "palette",
                default = "#0a1a0a",
                palette = ["#0a1a0a", "#000000", "#0a0a1a", "#1a0a0a", "#0a1a1a"],
            ),
            schema.Color(
                id = "accent_color",
                name = "Accent Line",
                desc = "Color of the divider line below the header",
                icon = "palette",
                default = "#2a7a2a",
                palette = ["#2a7a2a", "#2a2a7a", "#7a2a2a", "#7a6a2a", "#2a7a7a"],
            ),
            # Sensor 1
            schema.Text(
                id = "entity_id_1",
                name = "Sensor 1 Entity ID",
                desc = "Primary (large) sensor, shown left (e.g. sensor.greenhouse_temperature)",
                icon = "temperatureHalf",
            ),
            schema.Text(
                id = "unit_1",
                name = "Sensor 1 Unit Override",
                desc = "Override the displayed unit (leave blank to use HA value)",
                icon = "ruler",
                default = "",
            ),
            schema.Dropdown(
                id = "decimals_1",
                name = "Sensor 1 Decimal Places",
                desc = "Number of decimal places to show for sensor 1",
                icon = "hashtag",
                default = "0",
                options = [
                    schema.Option(display = "0 — whole number (61°F)", value = "0"),
                    schema.Option(display = "1 — one decimal (61.2°F)", value = "1"),
                    schema.Option(display = "2 — two decimals (61.23°F)", value = "2"),
                ],
            ),
            schema.Color(
                id = "normal_color_1",
                name = "Sensor 1 Normal Color",
                desc = "Value text color when in normal range",
                icon = "palette",
                default = "#FFFFFF",
                palette = ["#FFFFFF", "#AAAAAA", "#AAFFAA", "#FFD700"],
            ),
            schema.Text(
                id = "above_value_1",
                name = "Sensor 1 High Threshold",
                desc = "Value above which the High Color is shown (e.g. 85)",
                icon = "arrowUp",
                default = "",
            ),
            schema.Color(
                id = "above_color_1",
                name = "Sensor 1 High Color",
                desc = "Color when sensor 1 exceeds the high threshold",
                icon = "palette",
                default = "#FF4444",
                palette = ["#FF4444", "#FF8800", "#FF0000"],
            ),
            schema.Text(
                id = "below_value_1",
                name = "Sensor 1 Low Threshold",
                desc = "Value below which the Low Color is shown (e.g. 50)",
                icon = "arrowDown",
                default = "",
            ),
            schema.Color(
                id = "below_color_1",
                name = "Sensor 1 Low Color",
                desc = "Color when sensor 1 is below the low threshold",
                icon = "palette",
                default = "#4488FF",
                palette = ["#4488FF", "#00AAFF", "#0044FF"],
            ),
            schema.Toggle(
                id = "gradient_1",
                name = "Sensor 1 Dynamic Gradient",
                desc = "Smoothly blend color between low, normal, and high — e.g. 59°F is slightly blue, 78°F slightly red",
                icon = "palette",
                default = False,
            ),
            schema.Text(
                id = "normal_value_1",
                name = "Sensor 1 Normal Value",
                desc = "The comfortable midpoint for gradient mode (e.g. 70). Color interpolates: Low Color → Normal Color → High Color",
                icon = "hashtag",
                default = "",
            ),
            # Sensor 2
            schema.Text(
                id = "entity_id_2",
                name = "Sensor 2 Entity ID",
                desc = "Secondary (small) sensor, shown right (e.g. sensor.greenhouse_humidity)",
                icon = "temperatureHalf",
            ),
            schema.Text(
                id = "unit_2",
                name = "Sensor 2 Unit Override",
                desc = "Override the displayed unit (leave blank to use HA value)",
                icon = "ruler",
                default = "",
            ),
            schema.Dropdown(
                id = "decimals_2",
                name = "Sensor 2 Decimal Places",
                desc = "Number of decimal places to show for sensor 2",
                icon = "hashtag",
                default = "0",
                options = [
                    schema.Option(display = "0 — whole number", value = "0"),
                    schema.Option(display = "1 — one decimal", value = "1"),
                    schema.Option(display = "2 — two decimals", value = "2"),
                ],
            ),
            schema.Color(
                id = "normal_color_2",
                name = "Sensor 2 Normal Color",
                desc = "Value text color when in normal range",
                icon = "palette",
                default = "#AADDFF",
                palette = ["#AADDFF", "#FFFFFF", "#AAFFAA", "#FFD700"],
            ),
            schema.Text(
                id = "above_value_2",
                name = "Sensor 2 High Threshold",
                desc = "Value above which the High Color is shown",
                icon = "arrowUp",
                default = "",
            ),
            schema.Color(
                id = "above_color_2",
                name = "Sensor 2 High Color",
                desc = "Color when sensor 2 exceeds the high threshold",
                icon = "palette",
                default = "#FF8800",
                palette = ["#FF8800", "#FF4444", "#FF0000"],
            ),
            schema.Text(
                id = "below_value_2",
                name = "Sensor 2 Low Threshold",
                desc = "Value below which the Low Color is shown",
                icon = "arrowDown",
                default = "",
            ),
            schema.Color(
                id = "below_color_2",
                name = "Sensor 2 Low Color",
                desc = "Color when sensor 2 is below the low threshold",
                icon = "palette",
                default = "#4488FF",
                palette = ["#4488FF", "#00AAFF", "#0044FF"],
            ),
            # Sensor 3 (optional — fills right slot of bottom bar)
            schema.Text(
                id = "entity_id_3",
                name = "Sensor 3 Entity ID (optional)",
                desc = "Right slot of bottom bar. Leave blank to show sensor 2 full-width.",
                icon = "temperatureHalf",
                default = "",
            ),
            schema.Text(
                id = "unit_3",
                name = "Sensor 3 Unit Override",
                desc = "Override the displayed unit (leave blank to use HA value)",
                icon = "ruler",
                default = "",
            ),
            schema.Dropdown(
                id = "decimals_3",
                name = "Sensor 3 Decimal Places",
                desc = "Number of decimal places to show for sensor 3",
                icon = "hashtag",
                default = "0",
                options = [
                    schema.Option(display = "0 — whole number", value = "0"),
                    schema.Option(display = "1 — one decimal", value = "1"),
                    schema.Option(display = "2 — two decimals", value = "2"),
                ],
            ),
            schema.Color(
                id = "normal_color_3",
                name = "Sensor 3 Normal Color",
                desc = "Value text color when in normal range",
                icon = "palette",
                default = "#FFDD88",
                palette = ["#FFDD88", "#FFFFFF", "#AAFFAA", "#AADDFF"],
            ),
            schema.Text(
                id = "above_value_3",
                name = "Sensor 3 High Threshold",
                desc = "Value above which the High Color is shown",
                icon = "arrowUp",
                default = "",
            ),
            schema.Color(
                id = "above_color_3",
                name = "Sensor 3 High Color",
                desc = "Color when sensor 3 exceeds the high threshold",
                icon = "palette",
                default = "#FF4444",
                palette = ["#FF4444", "#FF8800", "#FF0000"],
            ),
            schema.Text(
                id = "below_value_3",
                name = "Sensor 3 Low Threshold",
                desc = "Value below which the Low Color is shown",
                icon = "arrowDown",
                default = "",
            ),
            schema.Color(
                id = "below_color_3",
                name = "Sensor 3 Low Color",
                desc = "Color when sensor 3 is below the low threshold",
                icon = "palette",
                default = "#4488FF",
                palette = ["#4488FF", "#00AAFF", "#0044FF"],
            ),
            # Visibility condition (optional — leave blank to always show)
            schema.Text(
                id = "cond_entity",
                name = "Show Only When Entity (optional)",
                desc = "Leave blank to always show. Set an entity ID to make this station conditional.",
                icon = "eye",
                default = "",
            ),
            schema.Dropdown(
                id = "cond_type",
                name = "Visibility Condition",
                desc = "Condition the entity must meet for this station to appear in rotation",
                icon = "boltLightning",
                default = "above",
                options = [
                    schema.Option(display = label, value = value)
                    for label, value in CONDITION_TYPES
                ],
            ),
            schema.Text(
                id = "cond_value",
                name = "Condition Value",
                desc = "Threshold or value to compare against (e.g. 50, on, pending)",
                icon = "hashtag",
                default = "",
            ),
        ],
    )
