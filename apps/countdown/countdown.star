"""
Applet: Countdown
Summary: Days until event
Description: Countdown timer showing days remaining until a configurable event.
Author: tronbyt
"""

load("encoding/json.star", "json")
load("math.star", "math")
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

def main(config):
    location = config.get("location", DEFAULT_LOCATION)
    loc = json.decode(location)
    timezone = loc.get("timezone", time.tz())

    event_name = config.get("event_name") or "EVENT"
    target_date = config.get("target_date") or "2026-06-14"
    accent = config.get("accent_color") or "#FFB833"

    now = time.now().in_location(timezone)

    # Parse target date
    parts = target_date.split("-")
    if len(parts) != 3:
        return []
    target_year = int(parts[0])
    target_month = int(parts[1])
    target_day = int(parts[2])

    # Build target time at midnight
    target = time.time(year = target_year, month = target_month, day = target_day, location = timezone)

    # Calculate days remaining
    diff = target - now
    days_left = int(diff.hours / 24)
    if diff.hours % 24 > 0:
        days_left = days_left + 1

    # If event has passed, hide
    if days_left < 0:
        return []

    header_bg = hex_dim(accent, 0.15)

    # Header
    header = render.Column(children = [
        render.Box(height = 1, color = header_bg),
        render.Box(
            height = 6, color = header_bg,
            child = render.Row(
                expanded = True,
                main_align = "space_between",
                cross_align = "center",
                children = [
                    render.Padding(pad = (2, 0, 0, 0), child = render.Marquee(
                        width = 36,
                        child = render.Text(event_name.upper(), font = "tom-thumb", color = "#CCCCCC"),
                    )),
                    render.Padding(pad = (0, 0, 2, 0), child = render.Text(target_date[5:], font = "tom-thumb", color = accent)),
                ],
            ),
        ),
        render.Box(width = 64, height = 1, color = accent),
    ])

    # Days display
    days_str = str(days_left)

    if days_left == 0:
        label = "TODAY!"
        content = render.Box(
            height = 24,
            child = render.Column(
                expanded = True, main_align = "center", cross_align = "center",
                children = [
                    render.Text(label, font = "tb-8", color = accent),
                ],
            ),
        )
    else:
        # Big number + "DAYS" label
        content = render.Box(
            height = 24,
            child = render.Column(
                expanded = True, main_align = "center", cross_align = "center",
                children = [
                    render.Row(
                        cross_align = "end",
                        children = [
                            render.Padding(
                                pad = (0, 0, 1, 1),
                                child = render.Text("in", font = "tb-8", color = accent),
                            ),
                            render.Text(days_str, font = "terminus-14", color = "#FFFFFF"),
                            render.Padding(
                                pad = (1, 0, 0, 1),
                                child = render.Text("DAYS", font = "tb-8", color = accent),
                            ),
                        ],
                    ),
                ],
            ),
        )

    return render.Root(
        delay = 500,
        child = render.Column(children = [header, content]),
    )

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Location(
                id = "location",
                name = "Location",
                desc = "Location for timezone",
                icon = "locationDot",
            ),
            schema.Text(
                id = "event_name",
                name = "Event Name",
                desc = "Name of the event (shown in header)",
                icon = "plane",
                default = "GERMANY",
            ),
            schema.Text(
                id = "target_date",
                name = "Target Date",
                desc = "Date in YYYY-MM-DD format",
                icon = "calendar",
                default = "2026-06-14",
            ),
            schema.Text(
                id = "accent_color",
                name = "Accent Color",
                desc = "Hex color for accent (e.g. #FFB833, #FF4444, #33BBFF)",
                icon = "palette",
                default = "#FFB833",
            ),
        ],
    )
