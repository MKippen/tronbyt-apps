"""
Applet: Family Calendar
Summary: Upcoming family events
Description: Shows the next upcoming events from a Home Assistant calendar entity with scrolling event list.
Author: tronbyt
"""

load("encoding/base64.star", "base64")
load("encoding/json.star", "json")
load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

CAL_ICON_B64 = "iVBORw0KGgoAAAANSUhEUgAAAA4AAAAQCAYAAAAmlE46AAAAOElEQVR4nGNgQAInmoz+gzADGsAlTp7G//Od/5ODKdOooSBCEkbRCAPEsKlj46hTB5VTydJIDgYA07q97K82N1cAAAAASUVORK5CYII="

DEFAULT_LOCATION = """
{
    "lat": "40.6781784",
    "lng": "-73.9441579",
    "description": "Brooklyn, NY, USA",
    "locality": "Brooklyn",
    "timezone": "America/New_York"
}
"""

ACCENT = "#FF9F43"
LABEL_COLOR = "#CCCCCC"
DIM_COLOR = "#666666"
EVENT_COLOR = "#FFFFFF"
MAX_EVENTS = 5

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

def pad2(n):
    if n < 10:
        return "0" + str(n)
    return str(n)

def format_event_date(event, now, timezone):
    """Parse event start and return a short display string like 'TODAY', 'TOM', 'Fri 3/21'."""
    start = event.get("start", {})

    if start.get("dateTime"):
        # Timed event — extract date portion and time
        dt_str = start["dateTime"]
        # Format: 2026-03-14T10:00:00-07:00
        date_part = dt_str[:10]
        time_part = dt_str[11:16]
        h = int(time_part[:2])
        m = int(time_part[3:5])
        ampm = "a"
        if h >= 12:
            ampm = "p"
        if h == 0:
            h = 12
        elif h > 12:
            h = h - 12
        time_str = str(h) + ":" + pad2(m) + ampm
    elif start.get("date"):
        date_part = start["date"]
        time_str = ""
    else:
        return "", "", ""

    # Parse the date
    parts = date_part.split("-")
    year = int(parts[0])
    month = int(parts[1])
    day = int(parts[2])

    event_time = time.time(year = year, month = month, day = day, location = timezone)
    now_midnight = time.time(year = now.year, month = now.month, day = now.day, location = timezone)

    diff_hours = (event_time - now_midnight).hours
    diff_days = int(diff_hours / 24)

    if diff_days == 0:
        date_str = "TODAY"
    elif diff_days == 1:
        date_str = "TOMORROW"
    else:
        # Show day of week + month/day
        dow = event_time.format("Mon")
        date_str = dow + " " + str(month) + "/" + str(day)

    return date_str, time_str, date_part

def fetch_events(cal_entity, ha_url, ha_token, now, timezone):
    """Fetch upcoming events from HA calendar API."""
    if not cal_entity or not ha_url or not ha_token:
        return []

    # Query next 14 days
    start_str = str(now.year) + "-" + pad2(now.month) + "-" + pad2(now.day) + "T00:00:00"
    end_year = now.year
    end_month = now.month
    end_day = now.day + 14
    # Simple overflow handling
    if end_month in [1, 3, 5, 7, 8, 10, 12]:
        max_day = 31
    elif end_month in [4, 6, 9, 11]:
        max_day = 30
    else:
        max_day = 28
    if end_day > max_day:
        end_day = end_day - max_day
        end_month = end_month + 1
        if end_month > 12:
            end_month = 1
            end_year = end_year + 1
    end_str = str(end_year) + "-" + pad2(end_month) + "-" + pad2(end_day) + "T23:59:59"

    url = ha_url + "/api/calendars/" + cal_entity + "?start=" + start_str + "&end=" + end_str
    rep = http.get(
        url,
        ttl_seconds = 300,
        headers = {"Authorization": "Bearer " + ha_token},
    )
    if rep.status_code != 200:
        return []
    return rep.json()

def sort_key(event):
    """Return a sortable string for an event."""
    start = event.get("start", {})
    if start.get("dateTime"):
        return start["dateTime"][:19]
    if start.get("date"):
        return start["date"] + "T00:00:00"
    return "9999"

def dedupe_events(events):
    """Remove duplicate events (same summary + same date)."""
    seen = {}
    result = []
    for e in events:
        sk = sort_key(e)
        key = e.get("summary", "") + "|" + sk[:10]
        if key not in seen:
            seen[key] = True
            result.append(e)
    return result

def main(config):
    location = config.get("location", DEFAULT_LOCATION)
    loc = json.decode(location)
    timezone = loc.get("timezone", time.tz())

    ha_url = config.get("ha_url") or ""
    ha_token = config.get("ha_token") or ""
    cal_entity = config.get("cal_entity") or "calendar.mkippen_mike_and_sarah_2"
    accent = config.get("accent_color") or ACCENT
    cal_name = config.get("cal_name") or "FAMILY"

    now = time.now().in_location(timezone)

    events = fetch_events(cal_entity, ha_url, ha_token, now, timezone)

    # Sort by start time
    # Simple bubble sort since starlark has no sorted() with key
    for i in range(len(events)):
        for j in range(i + 1, len(events)):
            if sort_key(events[j]) < sort_key(events[i]):
                events[i], events[j] = events[j], events[i]

    # Filter to future events only and dedupe
    events = dedupe_events(events)

    # Build text body for WrappedText
    lines = []
    prev_date = ""
    count = 0
    for e in events:
        if count >= MAX_EVENTS:
            break
        summary = e.get("summary", "???")
        date_str, time_str, date_raw = format_event_date(e, now, timezone)
        if not date_str:
            continue

        # Date separator when date changes
        if date_raw != prev_date:
            prev_date = date_raw
            if len(lines) > 0:
                lines.append("")
            lines.append(date_str)

        # Event line
        if time_str:
            lines.append(time_str + " " + summary)
        else:
            lines.append(summary)
        count = count + 1

    if len(lines) == 0:
        lines.append("No events")

    header_bg = hex_dim(accent, 0.15)

    # Full-screen splash — calendar icon centered
    icon_bytes = base64.decode(CAL_ICON_B64)
    splash = render.Box(
        width = 64, height = 32, color = "#000000",
        child = render.Column(
            expanded = True, main_align = "center", cross_align = "center",
            children = [
                render.Image(src = icon_bytes, width = 14, height = 16),
            ],
        ),
    )

    # Build body rows with date headers in accent, events in white
    body_children = []
    prev_date2 = ""
    count2 = 0
    for e in events:
        if count2 >= MAX_EVENTS:
            break
        summary = e.get("summary", "???")
        date_str, time_str, date_raw = format_event_date(e, now, timezone)
        if not date_str:
            continue

        if date_raw != prev_date2:
            prev_date2 = date_raw
            if len(body_children) > 0:
                body_children.append(render.Box(height = 2))
            body_children.append(render.Padding(
                pad = (1, 0, 0, 0),
                child = render.Text(date_str, font = "tom-thumb", color = accent),
            ))

        if time_str:
            label = time_str + " " + summary
        else:
            label = summary
        body_children.append(render.Padding(
            pad = (1, 0, 1, 0),
            child = render.WrappedText(
                label,
                width = 62,
                color = EVENT_COLOR,
                font = "tom-thumb",
                linespacing = 1,
            ),
        ))
        count2 = count2 + 1

    body = render.Padding(
        pad = (0, 3, 0, 3),
        child = render.Column(children = body_children),
    )

    return render.Root(
        delay = 150,
        child = render.Marquee(
            width = 64,
            height = 32,
            scroll_direction = "vertical",
            offset_start = 0,
            offset_end = 0,
            child = render.Column(children = [splash, body]),
        ),
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
                id = "ha_url",
                name = "Home Assistant URL",
                desc = "Full URL of your HA instance",
                icon = "link",
            ),
            schema.Text(
                id = "ha_token",
                name = "HA Access Token",
                desc = "Long-lived access token",
                icon = "key",
                secret = True,
            ),
            schema.Text(
                id = "cal_entity",
                name = "Calendar Entity",
                desc = "HA calendar entity ID",
                icon = "calendar",
                default = "calendar.mkippen_mike_and_sarah_2",
            ),
            schema.Text(
                id = "cal_name",
                name = "Calendar Name",
                desc = "Header label (e.g. FAMILY, KIDS, etc.)",
                icon = "tag",
                default = "FAMILY",
            ),
            schema.Text(
                id = "accent_color",
                name = "Accent Color",
                desc = "Hex color for accent",
                icon = "palette",
                default = "#FF9F43",
            ),
        ],
    )
