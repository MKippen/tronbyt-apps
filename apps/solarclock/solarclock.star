"""
Applet: Solar Clock
Summary: Clock with solar gradient
Description: Minimal clock with soft pastel gradient that shifts through the day based on weather. Inspired by iPhone StandBy Solar face.
Author: tronbyt
"""

load("encoding/json.star", "json")
load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

DEFAULT_LOCATION = """
{
    "lat": "40.6781784",
    "lng": "-73.9441579",
    "description": "Brooklyn, NY, USA",
    "locality": "Brooklyn",
    "timezone": "America/New_York"
}
"""

# Soft pastel horizontal gradients [left, right] — iPhone Solar style
# Light, airy washes that shift with time of day and weather
PALETTES = {
    "Clear_day":      ["#78B8D8", "#D0C868"],
    "Clear_morning":  ["#C098D0", "#90B8D8"],
    "Clear_dawn":     ["#D89870", "#C878A0"],
    "Clear_dusk":     ["#C87850", "#7858A0"],
    "Clear_night":    ["#203050", "#182840"],
    "Clouds_day":     ["#8898A8", "#A8A898"],
    "Clouds_night":   ["#202830", "#1C2428"],
    "Rain_day":       ["#607888", "#708098"],
    "Rain_night":     ["#181E28", "#1C2430"],
    "Snow_day":       ["#98B0C8", "#C0C8D0"],
    "Snow_night":     ["#283848", "#203040"],
    "Storm_day":      ["#484060", "#383058"],
    "Storm_night":    ["#141420", "#0E0E1C"],
    "Mist_day":       ["#808888", "#989088"],
    "Mist_night":     ["#1C2020", "#202424"],
}

def hex_to_rgb(h):
    d = "0123456789ABCDEF"
    h = h.lstrip("#").upper()
    return [d.index(h[0]) * 16 + d.index(h[1]), d.index(h[2]) * 16 + d.index(h[3]), d.index(h[4]) * 16 + d.index(h[5])]

def rgb_to_hex(r, g, b):
    d = "0123456789ABCDEF"
    r = max(0, min(255, int(r)))
    g = max(0, min(255, int(g)))
    b = max(0, min(255, int(b)))
    return "#" + d[r >> 4] + d[r & 15] + d[g >> 4] + d[g & 15] + d[b >> 4] + d[b & 15]

def lerp_color(c1, c2, t):
    r1 = hex_to_rgb(c1)
    r2 = hex_to_rgb(c2)
    return rgb_to_hex(
        r1[0] + (r2[0] - r1[0]) * t,
        r1[1] + (r2[1] - r1[1]) * t,
        r1[2] + (r2[2] - r1[2]) * t,
    )

def main(config):
    location = config.get("location", DEFAULT_LOCATION)
    loc = json.decode(location)
    lat = loc["lat"]
    lng = loc["lng"]
    timezone = loc.get("timezone", time.tz())
    units = config.get("units", "imperial")
    api_key = config.get("api_key", "")
    show_temp = config.bool("show_temp", True)
    use_24h = config.bool("use_24h", False)

    now = time.now().in_location(timezone)

    # Fetch weather
    weather_main = "Clear"
    temp = None
    is_night = False
    sunrise_h = 6
    sunset_h = 18

    if api_key:
        url = "https://api.openweathermap.org/data/2.5/weather?lat={}&lon={}&units={}&appid={}".format(lat, lng, units, api_key)
        rep = http.get(url, ttl_seconds = 300)
        if rep.status_code == 200:
            data = json.decode(rep.body())
            weather_main = data["weather"][0]["main"]
            icon = data["weather"][0].get("icon", "01d")
            is_night = icon.endswith("n")

            if weather_main in ("Haze", "Smoke", "Ash", "Fog"):
                weather_main = "Mist"
            if weather_main in ("Squall", "Tornado"):
                weather_main = "Storm"
            if weather_main == "Drizzle":
                weather_main = "Rain"

            temp = int(data["main"]["temp"] + 0.5)

            sys_data = data.get("sys", {})
            if sys_data.get("sunrise"):
                sr = time.from_timestamp(sys_data["sunrise"]).in_location(timezone)
                sunrise_h = sr.hour
            if sys_data.get("sunset"):
                ss = time.from_timestamp(sys_data["sunset"]).in_location(timezone)
                sunset_h = ss.hour

    # Determine palette
    hour = now.hour
    dn = "_night" if is_night else "_day"

    if weather_main == "Clear":
        if is_night:
            palette_key = "Clear_night"
        elif hour >= sunrise_h and hour < sunrise_h + 2:
            palette_key = "Clear_dawn"
        elif hour >= sunset_h - 1 and hour <= sunset_h + 1:
            palette_key = "Clear_dusk"
        elif hour < 12:
            palette_key = "Clear_morning"
        else:
            palette_key = "Clear_day"
    elif weather_main in ("Clouds", "Partly_Sun"):
        palette_key = "Clouds" + dn
    elif weather_main == "Rain":
        palette_key = "Rain" + dn
    elif weather_main == "Snow":
        palette_key = "Snow" + dn
    elif weather_main in ("Thunderstorm", "Storm"):
        palette_key = "Storm" + dn
    elif weather_main == "Mist":
        palette_key = "Mist" + dn
    else:
        palette_key = "Clear" + dn

    palette = PALETTES.get(palette_key, PALETTES["Clear_day"])

    # Horizontal gradient background (64 columns, 1px wide each)
    bg_children = []
    for i in range(64):
        t = i / 63.0
        color = lerp_color(palette[0], palette[1], t)
        bg_children.append(render.Box(width = 1, height = 32, color = color))
    bg = render.Row(children = bg_children)

    # Format time
    TIME_FONT = "terminus-18"
    if use_24h:
        time_str = now.format("15:04")
        time_str_blink = now.format("15 04")
    else:
        h = now.hour
        minute = now.minute
        if h == 0:
            h = 12
        elif h > 12:
            h -= 12
        min_pad = "0" + str(minute) if minute < 10 else str(minute)
        time_str = str(h) + ":" + min_pad
        time_str_blink = str(h) + " " + min_pad

    clock_on = render.Stack(children = [
        render.Padding(pad = (1, 1, 0, 0), child = render.Text(time_str, font = TIME_FONT, color = "#00000030")),
        render.Text(time_str, font = TIME_FONT, color = "#FFFFFF"),
    ])
    clock_off = render.Stack(children = [
        render.Padding(pad = (1, 1, 0, 0), child = render.Text(time_str_blink, font = TIME_FONT, color = "#00000030")),
        render.Text(time_str_blink, font = TIME_FONT, color = "#FFFFFF"),
    ])

    # Bottom info — very subtle
    bottom_children = []
    if show_temp and temp != None:
        bottom_children.append(
            render.Text(str(temp) + "\u00b0", font = "tom-thumb", color = "#FFFFFF55"),
        )

    overlay_children = [
        render.Box(height = 3),
        render.Animation(children = [clock_on, clock_off]),
    ]

    if bottom_children:
        overlay_children.append(
            render.Padding(
                pad = (0, 0, 0, 0),
                child = render.Row(
                    main_align = "center",
                    children = bottom_children,
                ),
            ),
        )

    overlay = render.Column(
        expanded = True,
        main_align = "center",
        cross_align = "center",
        children = overlay_children,
    )

    return render.Root(
        delay = 500,
        child = render.Box(
            width = 64, height = 32,
            child = render.Stack(children = [bg, overlay]),
        ),
    )

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Location(
                id = "location",
                name = "Location",
                desc = "Location for weather and timezone",
                icon = "locationDot",
            ),
            schema.Dropdown(
                id = "units",
                name = "Units",
                desc = "Temperature units",
                default = "imperial",
                options = [
                    schema.Option(display = "Fahrenheit", value = "imperial"),
                    schema.Option(display = "Celsius", value = "metric"),
                ],
                icon = "temperatureHalf",
            ),
            schema.Toggle(
                id = "show_temp",
                name = "Show Temperature",
                desc = "Display current temp below time",
                default = True,
                icon = "thermometer",
            ),
            schema.Toggle(
                id = "use_24h",
                name = "24 Hour Format",
                desc = "Use 24-hour time",
                default = False,
                icon = "clock",
            ),
            schema.Text(
                id = "api_key",
                name = "OpenWeather API Key",
                desc = "OpenWeatherMap API key (same key as Weather app)",
                icon = "key",
                secret = True,
            ),
        ],
    )
