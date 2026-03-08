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

def format_value(state, unit):
    display = state
    if is_numeric(state) and "." in state:
        parts = state.split(".")
        decimal = parts[1].rstrip("0")
        display = (parts[0] + "." + decimal) if decimal else parts[0]
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

def get_value_color(state, config, suffix):
    normal = config.get("normal_color" + suffix) or "#FFFFFF"
    if not is_numeric(state):
        return normal
    val = float(state)
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

    station_name = config.get("station_name") or "Station"
    station_emoji = config.get("station_emoji") or "1FAB4"
    header_color = config.get("header_color") or "#0a1a0a"
    accent_color = config.get("accent_color") or "#2a7a2a"

    entity_id_1 = config.get("entity_id_1") or ""
    state1, unit1, _ = fetch_entity(entity_id_1, ha_url, ha_token)
    value1 = format_value(state1, config.get("unit_1") or unit1 or "")
    color1 = get_value_color(state1, config, "_1")

    entity_id_2 = config.get("entity_id_2") or ""
    state2, unit2, _ = fetch_entity(entity_id_2, ha_url, ha_token)
    value2 = format_value(state2, config.get("unit_2") or unit2 or "")
    color2 = get_value_color(state2, config, "_2")

    station_icon = load_emoji(station_emoji)

    # Header band: icon + station name (10px, keep as-is)
    icon_widget = render.Image(src = station_icon, width = 8, height = 8) if station_icon else render.Box(width = 8, height = 8)
    header = render.Box(
        height = 10,
        color = header_color,
        child = render.Row(
            cross_align = "center",
            children = [
                render.Padding(pad = (1, 0, 1, 0), child = icon_widget),
                render.Text(station_name, font = "tom-thumb", color = "#88cc88"),
            ],
        ),
    )

    # 1px accent line
    accent = render.Box(width = 64, height = 1, color = accent_color)

    # Primary value: large (terminus-14), left-aligned, 14px zone
    # Units carry the meaning — no label needed (°F = temp, % = humidity)
    primary = render.Box(
        height = 14,
        child = render.Row(
            expanded = True,
            cross_align = "center",
            children = [
                render.Padding(pad = (3, 0, 0, 0), child = render.Text(value1, font = "terminus-14", color = color1)),
            ],
        ),
    )

    # Secondary value: small (tom-thumb), right-aligned, 7px zone
    secondary = render.Box(
        height = 7,
        child = render.Row(
            expanded = True,
            main_align = "end",
            cross_align = "center",
            children = [
                render.Padding(pad = (0, 0, 3, 0), child = render.Text(value2, font = "tom-thumb", color = color2)),
            ],
        ),
    )

    # Layout: header(10) + accent(1) + primary(14) + secondary(7) = 32px
    return render.Root(
        child = render.Column(
            children = [header, accent, primary, secondary],
        ),
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
        ],
    )
