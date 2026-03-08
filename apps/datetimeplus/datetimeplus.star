"""
Applet: DateTime+
Summary: Date, time, and weather
Description: Clock with day/date header, time with AM/PM inline, and live weather at the bottom. Accent color shifts with time of day and weather conditions.
Author: tronbyt
"""

load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

OPEN_METEO = "https://api.open-meteo.com/v1/forecast"

def sky_color(hour, wmo):
    """Dynamic accent: nighttime = atmospheric time-based, daytime = weather-driven."""
    # Night (10pm–5am): deep indigo
    if hour < 5 or hour >= 22:
        return "#2233BB"
    # Pre-dawn (5–7am): amber
    elif hour < 7:
        return "#FF8833"
    # Dusk (7–9pm): orange-red
    elif hour >= 19:
        return "#FF6622"
    # Daytime (7am–7pm): follow the weather
    elif wmo == None or wmo <= 1:
        return "#FFAA22"   # clear sky: golden
    elif wmo <= 3:
        return "#55AACC"   # partly/mainly cloudy: slate blue
    elif wmo <= 48:
        return "#7788AA"   # fog: muted slate
    elif wmo <= 82:
        return "#4477FF"   # rain / snow: blue
    else:
        return "#9944FF"   # thunderstorm: purple

def wmo_label(code):
    if code == None:
        return ""
    elif code == 0:
        return "Clear"
    elif code <= 3:
        return "Cloudy"
    elif code <= 48:
        return "Fog"
    elif code <= 67:
        return "Rain"
    elif code <= 77:
        return "Snow"
    elif code <= 82:
        return "Showers"
    elif code <= 99:
        return "Tstorm"
    return ""

def fetch_weather(lat, lon, use_f):
    unit = "fahrenheit" if use_f else "celsius"
    url  = (OPEN_METEO + "?latitude=" + lat + "&longitude=" + lon +
            "&current=temperature_2m,weathercode&temperature_unit=" + unit)
    rep  = http.get(url, ttl_seconds = 900)
    if rep.status_code != 200:
        return None, None
    current = rep.json().get("current", {})
    return current.get("temperature_2m", None), current.get("weathercode", None)

def main(config):
    use24  = config.get("use_24hour") == "true"
    use_f  = config.get("use_fahrenheit") != "false"
    tz     = config.get("$tz") or "America/New_York"
    lat    = config.get("latitude") or ""
    lon    = config.get("longitude") or ""

    now  = time.now().in_location(tz)
    hour = int(now.format("15"))

    day_str  = now.format("Monday").upper()      # "SUNDAY"
    date_str = now.format("January 2").upper()   # "MARCH 8"
    ampm_str = now.format("pm")                  # "am" / "pm"
    time_str = now.format("15:04") if use24 else now.format("3:04")

    # Weather (optional — only if lat/lon configured)
    temp, wmo = None, None
    if lat and lon:
        temp, wmo = fetch_weather(lat, lon, use_f)

    accent    = sky_color(hour, wmo)
    header_bg = "#0D0D0D"

    # ── HEADER: day left (accent), date right (dim) ────────────────────────
    header = render.Column(children = [
        render.Box(height = 1, color = header_bg),
        render.Box(
            height = 6, color = header_bg,
            child = render.Row(
                expanded = True,
                main_align = "space_between",
                cross_align = "center",
                children = [
                    render.Padding(pad = (2, 0, 0, 0), child = render.Text(day_str, font = "tom-thumb", color = accent)),
                    render.Padding(pad = (0, 0, 2, 0), child = render.Text(date_str, font = "tom-thumb", color = "#CCCCCC")),
                ],
            ),
        ),
        render.Box(width = 64, height = 1, color = accent),
    ])

    # ── TIME + AM/PM inline, centered in 18px ─────────────────────────────
    ampm_widget = [] if use24 else [
        render.Padding(pad = (1, 0, 0, 1), child = render.Text(ampm_str, font = "tom-thumb", color = accent)),
    ]
    time_row = render.Row(
        cross_align = "end",
        children = [render.Text(time_str, font = "terminus-14", color = "#FFFFFF")] + ampm_widget,
    )
    time_area = render.Box(
        height = 18,
        child = render.Column(
            expanded = True, main_align = "center", cross_align = "center",
            children = [time_row],
        ),
    )

    # ── WEATHER STRIP (6px) ───────────────────────────────────────────────
    if temp != None:
        unit_sym  = "F" if use_f else "C"
        temp_str  = str(int(temp)) + "°" + unit_sym + "  " + wmo_label(wmo)
    else:
        temp_str = ""
    weather_area = render.Box(
        height = 6,
        child = render.Column(
            expanded = True, main_align = "center", cross_align = "center",
            children = [render.Text(temp_str, font = "tom-thumb", color = "#888888")],
        ),
    )

    return render.Root(child = render.Column(children = [header, time_area, weather_area]))

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "latitude",
                name = "Latitude",
                desc = "Your location latitude for weather (e.g. 37.7749)",
                icon = "locationDot",
                default = "",
            ),
            schema.Text(
                id = "longitude",
                name = "Longitude",
                desc = "Your location longitude for weather (e.g. -122.4194)",
                icon = "locationDot",
                default = "",
            ),
            schema.Toggle(
                id = "use_fahrenheit",
                name = "Fahrenheit",
                desc = "Show temperature in °F (off = °C)",
                icon = "thermometer",
                default = True,
            ),
            schema.Toggle(
                id = "use_24hour",
                name = "24-Hour Time",
                desc = "Use 24-hour format instead of 12-hour with AM/PM",
                icon = "clock",
                default = False,
            ),
        ],
    )
