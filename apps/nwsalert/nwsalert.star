"""
Applet: NWS Alert
Summary: Weather alerts from NWS
Description: Shows active NWS weather alerts from Home Assistant. Only appears in rotation when alerts are active.
Author: tronbyt
"""

load("encoding/base64.star", "base64")
load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")

WARN_ICON_B64 = "iVBORw0KGgoAAAANSUhEUgAAABIAAAAQCAYAAAAbBi9cAAAAYElEQVR4nK3TwQnAUAgDUCfpuftP0a0s8hFsMfVrE8hNHnpQpIheotZqrgwFMuA8Vn9hFMgRzxijQI+TAtTGKFBEMmgbo0BvBEEllkGoEOognxiC0GkpNNkmxfzDpzXjBgFEJ372WoMwAAAAAElFTkSuQmCC"

SPLASH_FRAMES = 25
SLIDE_FRAMES = 12
DATA_FRAMES = 1500
FRAME_DELAY = 80

# Severity colors
SEVERITY = {
    "Extreme": {"accent": "#FF2222", "bg": "#1A0505"},
    "Severe":  {"accent": "#FF8800", "bg": "#1A0E00"},
    "Moderate": {"accent": "#FFCC00", "bg": "#1A1400"},
    "Minor":   {"accent": "#4488FF", "bg": "#050E1A"},
}
DEFAULT_SEV = {"accent": "#FFCC00", "bg": "#1A1400"}

def ease(t):
    if t < 0.5:
        return 2.0 * t * t
    return -1.0 + (4.0 - 2.0 * t) * t

def fetch_alerts(entity_id, ha_url, ha_token):
    if not ha_url or not ha_token:
        return []
    url = ha_url + "/api/states/" + entity_id
    rep = http.get(
        url,
        ttl_seconds = 60,
        headers = {"Authorization": "Bearer " + ha_token},
    )
    if rep.status_code != 200:
        return []
    data = rep.json()
    return data.get("attributes", {}).get("Alerts", [])

def main(config):
    ha_url = config.get("ha_url") or ""
    ha_token = config.get("ha_token") or ""
    entity_id = config.get("entity_id") or "sensor.nws_alerts"
    force_show = config.bool("force_show", False)

    alerts = fetch_alerts(entity_id, ha_url, ha_token)

    if len(alerts) == 0 and not force_show:
        return []

    # Use first (most severe/recent) alert
    if len(alerts) > 0:
        alert = alerts[0]
        event = alert.get("Event", "Weather Alert")
        severity = alert.get("Severity", "Moderate")
        headline = alert.get("Headline", event)
    else:
        # force_show demo
        event = "Winter Storm Warning"
        severity = "Severe"
        headline = "Winter Storm Warning in effect until Saturday"

    sev = SEVERITY.get(severity, DEFAULT_SEV)
    accent = sev["accent"]
    header_bg = sev["bg"]

    # Splash: warning triangle centered
    icon_bytes = base64.decode(WARN_ICON_B64)
    splash = render.Box(
        width = 64, height = 32, color = "#000000",
        child = render.Column(
            expanded = True, main_align = "center", cross_align = "center",
            children = [
                render.Image(src = icon_bytes, width = 18, height = 16),
            ],
        ),
    )

    # Data view
    # Header: "NWS ALERT" left, severity right
    sev_label = severity.upper()
    header = render.Column(children = [
        render.Box(height = 1, color = header_bg),
        render.Box(
            height = 6, color = header_bg,
            child = render.Row(
                expanded = True,
                main_align = "space_between",
                cross_align = "center",
                children = [
                    render.Padding(pad = (2, 0, 0, 0), child = render.Text("NWS ALERT", font = "tom-thumb", color = "#CCCCCC")),
                    render.Padding(pad = (0, 0, 2, 0), child = render.Text(sev_label, font = "tom-thumb", color = accent)),
                ],
            ),
        ),
        render.Box(width = 64, height = 1, color = accent),
    ])

    # Body: event name in accent, headline scrolling in white
    body = render.Padding(
        pad = (2, 2, 2, 1),
        child = render.Column(
            children = [
                render.Marquee(
                    width = 60,
                    child = render.Text(event, font = "tom-thumb", color = accent),
                ),
                render.Box(height = 2),
                render.Marquee(
                    width = 60,
                    child = render.Text(headline, font = "tom-thumb", color = "#FFFFFF"),
                ),
            ],
        ),
    )

    # Alert count badge if multiple alerts
    if len(alerts) > 1:
        count_text = "+" + str(len(alerts) - 1) + " more"
        body = render.Padding(
            pad = (2, 2, 2, 1),
            child = render.Column(
                children = [
                    render.Marquee(
                        width = 60,
                        child = render.Text(event, font = "tom-thumb", color = accent),
                    ),
                    render.Box(height = 1),
                    render.Marquee(
                        width = 60,
                        child = render.Text(headline, font = "tom-thumb", color = "#FFFFFF"),
                    ),
                    render.Box(height = 1),
                    render.Text(count_text, font = "tom-thumb", color = "#666666"),
                ],
            ),
        )

    data = render.Column(children = [header, body])

    # Animation: splash -> slide left -> data hold
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
                id = "entity_id",
                name = "NWS Alerts Entity",
                desc = "HA sensor entity ID for NWS alerts",
                icon = "triangleExclamation",
                default = "sensor.nws_alerts",
            ),
        ],
    )
