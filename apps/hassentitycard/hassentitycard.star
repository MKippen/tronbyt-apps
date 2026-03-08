"""
Applet: HASS Entity Card
Summary: HA entity with emoji icon
Description: Displays a single Home Assistant entity value with a customizable emoji icon and threshold-based colors.
Author: tronbyt
"""

load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")

OPENMOJI_BASE = "https://cdn.jsdelivr.net/gh/hfg-gmuend/openmoji@15.0.0/color/72x72/"

EMOJIS = [
    # Nature & Garden
    ("🌿 Plant/Herb", "1F33F"),
    ("🌱 Seedling", "1F331"),
    ("🌾 Wheat/Grain", "1F33E"),
    ("🍃 Leaves", "1F343"),
    ("🌺 Flower", "1F33A"),
    ("🌻 Sunflower", "1F33B"),
    ("🌵 Cactus", "1F335"),
    ("🍀 Clover", "1F340"),
    ("🌲 Evergreen", "1F332"),
    ("🌳 Tree", "1F333"),
    # Weather & Temperature
    ("🌡️ Thermometer", "1F321-FE0F"),
    ("☀️ Sun", "2600-FE0F"),
    ("🌤️ Partly Cloudy", "1F324-FE0F"),
    ("🌧️ Rain", "1F327-FE0F"),
    ("❄️ Snowflake", "2744-FE0F"),
    ("🌨️ Snow", "1F328-FE0F"),
    ("🌬️ Wind", "1F32C-FE0F"),
    ("🌊 Wave", "1F30A"),
    ("🌈 Rainbow", "1F308"),
    ("⛈️ Thunderstorm", "26C8-FE0F"),
    # Home & Appliances
    ("🏠 House", "1F3E0"),
    ("💡 Light Bulb", "1F4A1"),
    ("🔒 Locked", "1F512"),
    ("🔓 Unlocked", "1F513"),
    ("🚪 Door", "1F6AA"),
    ("🛋️ Couch", "1F6CB-FE0F"),
    ("🛏️ Bed", "1F6CF-FE0F"),
    ("🚿 Shower", "1F6BF"),
    ("🍳 Cooking", "1F373"),
    ("🧹 Broom", "1F9F9"),
    ("🪴 Potted Plant", "1FAB4"),
    ("🪟 Window", "1FA9F"),
    # Energy & Power
    ("⚡ Lightning", "26A1"),
    ("🔋 Battery", "1F50B"),
    ("🔌 Plug", "1F50C"),
    ("🔥 Fire", "1F525"),
    ("💧 Water Drop", "1F4A7"),
    ("♨️ Hot Springs", "2668-FE0F"),
    # Status & Alerts
    ("🔔 Bell", "1F514"),
    ("🔕 Bell Off", "1F515"),
    ("⚠️ Warning", "26A0-FE0F"),
    ("✅ Check", "2705"),
    ("❌ X Mark", "274C"),
    ("🚨 Alarm", "1F6A8"),
    ("🟢 Green Circle", "1F7E2"),
    ("🟡 Yellow Circle", "1F7E1"),
    ("🔴 Red Circle", "1F534"),
    # Transport & Garage
    ("🚗 Car", "1F697"),
    ("🏎️ Race Car", "1F3CE-FE0F"),
    ("🛻 Truck", "1F6FB"),
    ("🚲 Bicycle", "1F6B2"),
    ("✈️ Plane", "2708-FE0F"),
    ("🚀 Rocket", "1F680"),
    # Food & Kitchen
    ("☕ Coffee", "2615"),
    ("🍺 Beer", "1F37A"),
    ("🧃 Juice Box", "1F9C3"),
    ("🍕 Pizza", "1F355"),
    ("🧊 Ice Cube", "1F9CA"),
    # Fitness & Health
    ("🏃 Running", "1F3C3"),
    ("❤️ Heart", "2764-FE0F"),
    ("💪 Muscle", "1F4AA"),
    ("🩺 Stethoscope", "1FA7A"),
    ("😴 Sleeping", "1F634"),
    # Misc
    ("⭐ Star", "2B50"),
    ("🎵 Music", "1F3B5"),
    ("📦 Package", "1F4E6"),
    ("🐶 Dog", "1F436"),
    ("🐱 Cat", "1F431"),
    ("🐔 Chicken", "1F414"),
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
        # Strip trailing zeros from floats
        parts = state.split(".")
        decimal = parts[1].rstrip("0")
        if decimal:
            display = parts[0] + "." + decimal
        else:
            display = parts[0]
    if unit:
        return display + unit
    return display

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
    state = data.get("state", "N/A")
    attrs = data.get("attributes", {})
    unit = attrs.get("unit_of_measurement", "")
    friendly = attrs.get("friendly_name", "")
    return state, unit, friendly

def get_value_color(state, config, suffix = ""):
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
    url = OPENMOJI_BASE + code + ".png"
    rep = http.get(url, ttl_seconds = 86400)
    if rep.status_code == 200:
        return rep.body()
    return None

def render_icon(img_bytes, bg_color, size):
    inner = size - 4
    if img_bytes:
        img_widget = render.Image(src = img_bytes, width = inner, height = inner)
    else:
        img_widget = render.Box(width = inner, height = inner, color = "#444444")
    return render.Stack(children = [
        render.Box(width = size, height = size, color = bg_color),
        render.Padding(pad = 2, child = img_widget),
    ])

def render_entity_row(icon_img, bg_color, value, label, value_color):
    """One 16px-tall row: icon square + value + scrolling label. Used in dual-entity mode."""
    inner = 14
    if icon_img:
        img_widget = render.Image(src = icon_img, width = inner, height = inner)
    else:
        img_widget = render.Box(width = inner, height = inner, color = "#444444")
    icon = render.Stack(children = [
        render.Box(width = 16, height = 16, color = bg_color),
        render.Padding(pad = 1, child = img_widget),
    ])
    return render.Row(
        cross_align = "center",
        children = [
            icon,
            render.Padding(
                pad = (1, 0, 0, 0),
                child = render.Column(
                    main_align = "center",
                    cross_align = "start",
                    expanded = True,
                    children = [
                        render.Text(value, font = "tb-8", color = value_color),
                        render.Marquee(
                            width = 47,
                            child = render.Text(label, font = "tom-thumb", color = "#666666"),
                        ),
                    ],
                ),
            ),
        ],
    )

def render_dual_card(icon1, value1, label1, color1, bg1, icon2, value2, label2, color2, bg2):
    return render.Root(
        child = render.Column(
            expanded = True,
            children = [
                render.Box(height = 16, child = render_entity_row(icon1, bg1, value1, label1, color1)),
                render.Box(height = 16, child = render_entity_row(icon2, bg2, value2, label2, color2)),
            ],
        ),
    )

def render_card(icon_img, value, label, value_color, bg_color, is2x):
    if is2x:
        icon_size = 44
        val_font = "terminus-28"
        lbl_font = "terminus-14"
        canvas_w = 128
    else:
        icon_size = 22
        val_font = "terminus-14"
        lbl_font = "tb-8"
        canvas_w = 64

    marquee_w = canvas_w - icon_size - 2

    return render.Root(
        child = render.Row(
            expanded = True,
            cross_align = "center",
            children = [
                render_icon(icon_img, bg_color, icon_size),
                render.Padding(
                    pad = (2, 0, 0, 0),
                    child = render.Column(
                        main_align = "center",
                        cross_align = "start",
                        expanded = True,
                        children = [
                            render.Text(value, font = val_font, color = value_color),
                            render.Marquee(
                                width = marquee_w,
                                child = render.Text(label, font = lbl_font, color = "#888888"),
                            ),
                        ],
                    ),
                ),
            ],
        ),
    )

def main(config):
    ha_url = config.get("ha_url") or ""
    ha_token = config.get("ha_token") or ""

    # Entity 1
    entity_id = config.get("entity_id") or ""
    state1, unit1, friendly1 = fetch_entity(entity_id, ha_url, ha_token)
    label1 = config.get("label") or friendly1 or entity_id
    value1 = format_value(state1, config.get("unit") or unit1 or "")
    color1 = get_value_color(state1, config)
    icon1 = load_emoji(config.get("emoji") or "1F321-FE0F")
    bg1 = config.get("icon_bg_color") or "#1C1C2E"

    # Entity 2 (optional — activates dual layout when set)
    entity_id_2 = config.get("entity_id_2") or ""
    if entity_id_2:
        state2, unit2, friendly2 = fetch_entity(entity_id_2, ha_url, ha_token)
        label2 = config.get("label_2") or friendly2 or entity_id_2
        value2 = format_value(state2, config.get("unit_2") or unit2 or "")
        color2 = get_value_color(state2, config, "_2")
        icon2 = load_emoji(config.get("emoji_2") or "1F4A7")
        bg2 = config.get("icon_bg_color_2") or "#1C2E2E"
        return render_dual_card(icon1, value1, label1, color1, bg1, icon2, value2, label2, color2, bg2)

    return render_card(icon1, value1, label1, color1, bg1, False)

def get_schema():
    emoji_options = [
        schema.Option(display = name, value = code)
        for name, code in EMOJIS
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
                id = "entity_id",
                name = "Entity ID",
                desc = "Entity to display (e.g. sensor.greenhouse_temperature)",
                icon = "temperatureHalf",
            ),
            schema.Text(
                id = "label",
                name = "Label Override",
                desc = "Optional label override (defaults to entity friendly_name)",
                icon = "tag",
                default = "",
            ),
            schema.Text(
                id = "unit",
                name = "Unit Override",
                desc = "Optional unit override (defaults to unit_of_measurement attribute)",
                icon = "ruler",
                default = "",
            ),
            schema.Dropdown(
                id = "emoji",
                name = "Emoji Icon",
                desc = "Icon to display alongside the entity value",
                icon = "faceGrin",
                default = "1F321-FE0F",
                options = emoji_options,
            ),
            schema.Color(
                id = "icon_bg_color",
                name = "Icon Background Color",
                desc = "Background color behind the emoji icon",
                icon = "palette",
                default = "#1C1C2E",
                palette = ["#1C1C2E", "#000000", "#1a2a1a", "#1a1a2e"],
            ),
            schema.Color(
                id = "normal_color",
                name = "Normal Value Color",
                desc = "Text color for the value when within normal range",
                icon = "palette",
                default = "#FFFFFF",
                palette = ["#FFFFFF", "#AAAAAA", "#00FF88", "#FFD700"],
            ),
            schema.Text(
                id = "above_value",
                name = "High Threshold",
                desc = "If numeric value exceeds this, use the High Color (e.g. 80)",
                icon = "arrowUp",
                default = "",
            ),
            schema.Color(
                id = "above_color",
                name = "High Color",
                desc = "Value color when above the high threshold",
                icon = "palette",
                default = "#FF4444",
                palette = ["#FF4444", "#FF8800", "#FF0000"],
            ),
            schema.Text(
                id = "below_value",
                name = "Low Threshold",
                desc = "If numeric value is below this, use the Low Color (e.g. 50)",
                icon = "arrowDown",
                default = "",
            ),
            schema.Color(
                id = "below_color",
                name = "Low Color",
                desc = "Value color when below the low threshold",
                icon = "palette",
                default = "#4488FF",
                palette = ["#4488FF", "#00AAFF", "#0044FF"],
            ),
            # --- Entity 2 (optional — enables dual-entity layout) ---
            schema.Text(
                id = "entity_id_2",
                name = "Entity 2 ID (optional)",
                desc = "Second entity to display below entity 1 (e.g. sensor.greenhouse_humidity). Leave blank for single-entity mode.",
                icon = "temperatureHalf",
                default = "",
            ),
            schema.Text(
                id = "label_2",
                name = "Entity 2 Label",
                desc = "Optional label override for entity 2",
                icon = "tag",
                default = "",
            ),
            schema.Text(
                id = "unit_2",
                name = "Entity 2 Unit",
                desc = "Optional unit override for entity 2",
                icon = "ruler",
                default = "",
            ),
            schema.Dropdown(
                id = "emoji_2",
                name = "Entity 2 Emoji",
                desc = "Icon for entity 2",
                icon = "faceGrin",
                default = "1F4A7",
                options = emoji_options,
            ),
            schema.Color(
                id = "icon_bg_color_2",
                name = "Entity 2 Icon Background",
                desc = "Background color behind entity 2 emoji",
                icon = "palette",
                default = "#1C2E2E",
                palette = ["#1C2E2E", "#000000", "#1a1a2e", "#2e1a1a"],
            ),
            schema.Color(
                id = "normal_color_2",
                name = "Entity 2 Normal Color",
                desc = "Value text color for entity 2 in normal range",
                icon = "palette",
                default = "#FFFFFF",
                palette = ["#FFFFFF", "#AAAAAA", "#00FF88", "#FFD700"],
            ),
            schema.Text(
                id = "above_value_2",
                name = "Entity 2 High Threshold",
                desc = "If entity 2 value exceeds this, use the High Color",
                icon = "arrowUp",
                default = "",
            ),
            schema.Color(
                id = "above_color_2",
                name = "Entity 2 High Color",
                desc = "Entity 2 value color when above threshold",
                icon = "palette",
                default = "#FF4444",
                palette = ["#FF4444", "#FF8800", "#FF0000"],
            ),
            schema.Text(
                id = "below_value_2",
                name = "Entity 2 Low Threshold",
                desc = "If entity 2 value is below this, use the Low Color",
                icon = "arrowDown",
                default = "",
            ),
            schema.Color(
                id = "below_color_2",
                name = "Entity 2 Low Color",
                desc = "Entity 2 value color when below threshold",
                icon = "palette",
                default = "#4488FF",
                palette = ["#4488FF", "#00AAFF", "#0044FF"],
            ),
        ],
    )
