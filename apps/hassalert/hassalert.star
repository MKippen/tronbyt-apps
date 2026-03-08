"""
Applet: HASS Alert
Summary: Conditional HA entity alert
Description: Invisible in rotation until a Home Assistant entity meets a condition — then shows an animated alert with icon splash and entity value. Use for CO alarms, security, leaks, or any threshold event.
Author: tronbyt
"""

load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")

OPENMOJI_BASE = "https://cdn.jsdelivr.net/gh/hfg-gmuend/openmoji@15.0.0/color/72x72/"

# Animation timing (matches hassstation style)
SPLASH_FRAMES = 25   # icon holds for ~2s
SLIDE_FRAMES = 12    # ease transition ~1s
DATA_FRAMES = 165    # data holds ~13s — total ~16s, safely past 15s display window
FRAME_DELAY = 80     # ms per frame

ALERT_EMOJIS = [
    ("🚨 Siren", "1F6A8"),
    ("⚠️ Warning", "26A0-FE0F"),
    ("🔥 Fire", "1F525"),
    ("🫁 Lungs / CO2", "1FAC1"),
    ("😷 Air Quality / Mask", "1F637"),
    ("🌫️ Fog / Haze", "1F32B-FE0F"),
    ("💀 Danger", "1F480"),
    ("🤢 Toxic", "1F922"),
    ("💧 Water / Flood", "1F4A7"),
    ("🌡️ Temperature", "1F321-FE0F"),
    ("❄️ Freeze", "2744-FE0F"),
    ("🔒 Locked", "1F512"),
    ("🔓 Unlocked", "1F513"),
    ("🚪 Door", "1F6AA"),
    ("🪟 Window", "1FA9F"),
    ("💡 Light", "1F4A1"),
    ("🔋 Battery Low", "1F50B"),
    ("⚡ Power", "26A1"),
    ("🏃 Motion", "1F3C3"),
    ("🔔 Bell", "1F514"),
    ("❤️ Health", "2764-FE0F"),
    ("🐶 Pet", "1F436"),
    ("⭐ Custom", "2B50"),
]

CONDITION_TYPES = [
    ("above threshold", "above"),
    ("below threshold", "below"),
    ("equals value", "equals"),
    ("not equals value", "not_equals"),
    ("is 'on'", "is_on"),
    ("is 'off'", "is_off"),
]

DECIMALS_OPTIONS = [
    ("0 — whole number", "0"),
    ("1 decimal place", "1"),
    ("2 decimal places", "2"),
]

def ease(t):
    if t < 0.5:
        return 2.0 * t * t
    return -1.0 + (4.0 - 2.0 * t) * t

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

def load_emoji(code):
    if not code:
        return None
    rep = http.get(OPENMOJI_BASE + code + ".png", ttl_seconds = 86400)
    return rep.body() if rep.status_code == 200 else None

def format_value(state, decimals):
    if not is_numeric(state):
        return state
    val = float(state)
    if decimals == 0:
        rounded = int(val + 0.5) if val >= 0.0 else int(val - 0.5)
        return str(rounded)
    if decimals == 1:
        r = int(val * 10.0 + 0.5) if val >= 0.0 else int(val * 10.0 - 0.5)
        return str(r // 10) + "." + str(r % 10)
    r = int(val * 100.0 + 0.5) if val >= 0.0 else int(val * 100.0 - 0.5)
    dec = str(r % 100)
    return str(r // 100) + "." + (dec if len(dec) == 2 else "0" + dec)

def main(config):
    ha_url = config.get("ha_url") or ""
    ha_token = config.get("ha_token") or ""
    entity_id = config.get("entity_id") or ""

    state, unit, friendly_name = fetch_entity(entity_id, ha_url, ha_token)

    # Check condition — return None if not met (invisible in rotation)
    cond_type = config.get("condition_type") or "above"
    cond_value = config.get("condition_value") or ""
    if not check_condition(state, cond_type, cond_value):
        return None

    # Condition met — build alert
    alert_title = config.get("alert_title") or friendly_name or entity_id
    alert_color = config.get("alert_color") or "#CC0000"
    bg_color = config.get("bg_color") or "#111111"
    emoji_code = config.get("alert_emoji") or "1F6A8"
    unit_str = config.get("unit") or unit or ""
    decimals = int(config.get("decimals") or "0")
    display_num = format_value(state, decimals)

    icon_img = load_emoji(emoji_code)

    # ── SPLASH: big icon on dark background so any icon color pops ────────
    big_icon = render.Image(src = icon_img, width = 28, height = 28) if icon_img else render.Box(width = 28, height = 28, color = "#444444")
    splash = render.Box(
        width = 64,
        height = 32,
        color = bg_color,
        child = render.Column(
            expanded = True,
            main_align = "center",
            cross_align = "center",
            children = [big_icon],
        ),
    )

    # ── DATA VIEW: header band + value ────────────────────────────────────
    header = render.Column(children = [
        render.Box(
            height = 9,
            color = alert_color,
            child = render.Column(
                expanded = True,
                main_align = "center",
                cross_align = "center",
                children = [
                    render.Marquee(
                        width = 62,
                        align = "center",
                        child = render.Text(alert_title, font = "tom-thumb", color = "#FFFFFF"),
                    ),
                ],
            ),
        ),
        render.Box(width = 64, height = 1, color = "#FFFFFF"),
    ])

    # Value: number large, unit small (same pattern as hassstation primary)
    if unit_str:
        value_widget = render.Row(
            cross_align = "end",
            children = [
                render.Text(display_num, font = "terminus-14", color = "#FFFFFF"),
                render.Padding(pad = (1, 0, 0, 1), child = render.Text(unit_str, font = "tb-8", color = "#FFFFFF")),
            ],
        )
    else:
        value_widget = render.Text(display_num, font = "terminus-14", color = "#FFFFFF")

    value_area = render.Box(
        height = 22,
        color = bg_color,
        child = render.Column(
            expanded = True,
            main_align = "center",
            cross_align = "center",
            children = [value_widget],
        ),
    )

    data = render.Column(children = [header, value_area])

    # ── ANIMATION ─────────────────────────────────────────────────────────
    frames = []
    for _ in range(SPLASH_FRAMES):
        frames.append(splash)
    for i in range(SLIDE_FRAMES):
        t = ease((i + 1.0) / SLIDE_FRAMES)
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
    emoji_options = [
        schema.Option(display = name, value = code)
        for name, code in ALERT_EMOJIS
    ]
    condition_options = [
        schema.Option(display = label, value = value)
        for label, value in CONDITION_TYPES
    ]
    decimals_options = [
        schema.Option(display = label, value = value)
        for label, value in DECIMALS_OPTIONS
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
                desc = "Long-lived access token from HA Profile > Security",
                icon = "key",
                secret = True,
            ),
            schema.Text(
                id = "entity_id",
                name = "Entity to Watch",
                desc = "Entity ID to monitor (e.g. sensor.co2_kitchen, binary_sensor.smoke)",
                icon = "eye",
            ),
            schema.Dropdown(
                id = "condition_type",
                name = "Show Alert When",
                desc = "Condition that triggers the alert",
                icon = "boltLightning",
                default = "above",
                options = condition_options,
            ),
            schema.Text(
                id = "condition_value",
                name = "Condition Value",
                desc = "Threshold or comparison value (e.g. 500, pending). Not needed for 'is on/off'.",
                icon = "hashtag",
                default = "",
            ),
            schema.Text(
                id = "alert_title",
                name = "Alert Title",
                desc = "Text shown in the header (e.g. Kitchen CO2, Front Door). Defaults to entity friendly name.",
                icon = "tag",
                default = "",
            ),
            schema.Text(
                id = "unit",
                name = "Unit Override",
                desc = "Optional unit suffix (e.g. ppm, °F). Defaults to HA unit_of_measurement.",
                icon = "hashtag",
                default = "",
            ),
            schema.Dropdown(
                id = "decimals",
                name = "Decimal Places",
                desc = "How many decimal places to show for numeric values",
                icon = "hashtag",
                default = "0",
                options = decimals_options,
            ),
            schema.Dropdown(
                id = "alert_emoji",
                name = "Alert Icon",
                desc = "Icon shown during splash and in the header",
                icon = "faceGrin",
                default = "1F6A8",
                options = emoji_options,
            ),
            schema.Color(
                id = "alert_color",
                name = "Alert Color",
                desc = "Color of the header band — use your alert color here (red, orange, etc.)",
                icon = "palette",
                default = "#CC0000",
                palette = ["#CC0000", "#FF2222", "#FF8800", "#FFDD00", "#FF00FF", "#00AAFF"],
            ),
            schema.Color(
                id = "bg_color",
                name = "Background Color",
                desc = "Background behind the icon and value — keep dark so the icon is visible",
                icon = "palette",
                default = "#111111",
                palette = ["#111111", "#000000", "#0d0000", "#0a0a00", "#00000d", "#0a000a"],
            ),
        ],
    )
