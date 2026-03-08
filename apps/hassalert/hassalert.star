"""
Applet: HASS Alert
Summary: Conditional HA entity alert
Description: Invisible in rotation until a Home Assistant entity meets a condition — then flashes a bold alert. Use for CO alarms, security, leaks, or any threshold event.
Author: tronbyt
"""

load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")

OPENMOJI_BASE = "https://cdn.jsdelivr.net/gh/hfg-gmuend/openmoji@15.0.0/color/72x72/"

FLASH_ON = 8    # bright frames
FLASH_OFF = 8   # dark frames
FRAME_DELAY = 120  # ms per frame — 120ms × 16 frames = ~2s blink cycle

ALERT_EMOJIS = [
    ("🚨 Siren", "1F6A8"),
    ("⚠️ Warning", "26A0-FE0F"),
    ("🔥 Fire", "1F525"),
    ("💨 CO / Gas", "1F4A8"),
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

def make_alert_frame(icon_img, title, value, bg_color, text_color):
    icon_w = render.Image(src = icon_img, width = 12, height = 12) if icon_img else render.Box(width = 12, height = 12)
    return render.Box(
        width = 64,
        height = 32,
        color = bg_color,
        child = render.Column(
            expanded = True,
            children = [
                # Header: icon + scrolling title (14px)
                render.Box(
                    height = 14,
                    child = render.Row(
                        expanded = True,
                        cross_align = "center",
                        children = [
                            render.Padding(pad = (2, 0, 2, 0), child = icon_w),
                            render.Marquee(
                                width = 48,
                                child = render.Text(title, font = "tb-8", color = text_color),
                            ),
                        ],
                    ),
                ),
                # Divider (1px)
                render.Box(width = 64, height = 1, color = text_color),
                # Value (17px)
                render.Box(
                    height = 17,
                    child = render.Column(
                        expanded = True,
                        main_align = "center",
                        cross_align = "center",
                        children = [render.Text(value, font = "terminus-14", color = text_color)],
                    ),
                ),
            ],
        ),
    )

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
    alert_color = config.get("alert_color") or "#FF2222"
    emoji_code = config.get("alert_emoji") or "1F6A8"
    display_value = state + (unit if unit else "")

    icon_img = load_emoji(emoji_code)

    bright = make_alert_frame(icon_img, alert_title, display_value, alert_color, "#FFFFFF")
    dark = make_alert_frame(icon_img, alert_title, display_value, "#000000", alert_color)

    frames = []
    for _ in range(FLASH_ON):
        frames.append(bright)
    for _ in range(FLASH_OFF):
        frames.append(dark)

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
                desc = "Entity ID to monitor (e.g. sensor.co_level, binary_sensor.smoke, alarm_control_panel.home)",
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
                desc = "Threshold or comparison value (e.g. 50, pending, on). Not needed for 'is on/off'.",
                icon = "hashtag",
                default = "",
            ),
            schema.Text(
                id = "alert_title",
                name = "Alert Title",
                desc = "Text shown in the alert header (e.g. CO ALERT, Front Door Open). Defaults to entity friendly name.",
                icon = "tag",
                default = "",
            ),
            schema.Dropdown(
                id = "alert_emoji",
                name = "Alert Icon",
                desc = "Icon shown in the alert",
                icon = "faceGrin",
                default = "1F6A8",
                options = emoji_options,
            ),
            schema.Color(
                id = "alert_color",
                name = "Alert Color",
                desc = "Color used when the alert is active",
                icon = "palette",
                default = "#FF2222",
                palette = ["#FF2222", "#FF8800", "#FFDD00", "#FF00FF", "#00AAFF"],
            ),
        ],
    )
