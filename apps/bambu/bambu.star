"""
Applet: Bambu 3D
Summary: Bambu printer status
Description: Shows Bambu 3D printer status from Home Assistant — progress, temps, time remaining.
Author: tronbyt
"""

load("encoding/base64.star", "base64")
load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

# Bambu Lab logo 24x24 PNG uncompressed (from simple-icons)
BAMBU_LOGO_B64 = "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AAAAAP4C+wD3/P0AAAACAAEABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAAAAAAAAAAAB/gEAAAEDAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAH9/2NufjV5wAAAAASUVORK5CYII="

SPLASH_FRAMES = 25
SLIDE_FRAMES = 12
DATA_FRAMES = 1500
FRAME_DELAY = 80

BAMBU_GREEN = "#00AE42"
IDLE_GRAY = "#666666"
RED = "#CC3333"
BAMBU_GREEN_BG = "#001A0A"
IDLE_BG = "#111111"
RED_BG = "#150909"

def ease(t):
    if t < 0.5:
        return 2.0 * t * t
    return -1.0 + (4.0 - 2.0 * t) * t

def fetch_state(entity_id, ha_url, ha_token):
    if not entity_id or not ha_url or not ha_token:
        return "unknown"
    rep = http.get(
        ha_url + "/api/states/" + entity_id,
        ttl_seconds = 30,
        headers = {"Authorization": "Bearer " + ha_token},
    )
    if rep.status_code != 200:
        return "unknown"
    data = rep.json()
    return data.get("state", "unknown")


def format_remaining(minutes_str):
    """Convert minutes string to '2h 15m' or '15m'."""
    if minutes_str == "unknown" or minutes_str == "unavailable":
        return ""
    mins = int(float(minutes_str)) if minutes_str.replace(".", "").replace("-", "").isdigit() else 0
    if mins <= 0:
        return ""
    h = mins // 60
    m = mins % 60
    if h > 0:
        return str(h) + "h " + str(m) + "m"
    return str(m) + "m"

def main(config):
    ha_url = config.get("ha_url") or ""
    ha_token = config.get("ha_token") or ""
    prefix = config.get("entity_prefix") or "x1c"

    # Fetch printer data
    status = fetch_state("sensor." + prefix + "_print_status", ha_url, ha_token)
    progress_str = fetch_state("sensor." + prefix + "_print_progress", ha_url, ha_token)
    remaining_str = fetch_state("sensor." + prefix + "_remaining_time", ha_url, ha_token)
    task_name = fetch_state("sensor." + prefix + "_task_name", ha_url, ha_token)
    nozzle_str = fetch_state("sensor." + prefix + "_nozzle_temperature", ha_url, ha_token)
    bed_str = fetch_state("sensor." + prefix + "_bed_temperature", ha_url, ha_token)
    stage = fetch_state("sensor." + prefix + "_current_stage", ha_url, ha_token)

    # Parse values
    progress = int(float(progress_str)) if progress_str not in ("unknown", "unavailable") and progress_str.replace(".", "").replace("-", "").isdigit() else 0
    nozzle = int(float(nozzle_str)) if nozzle_str not in ("unknown", "unavailable") and nozzle_str.replace(".", "").replace("-", "").isdigit() else 0
    bed = int(float(bed_str)) if bed_str not in ("unknown", "unavailable") and bed_str.replace(".", "").replace("-", "").isdigit() else 0
    time_left = format_remaining(remaining_str)

    is_printing = status.lower() in ("running", "printing", "prepare", "slicing")
    is_error = status.lower() in ("failed", "error", "stuck")
    is_idle = not is_printing and not is_error
    is_finished = status.lower() in ("finish", "finished", "complete", "completed")

    # Skip rotation when idle or finished
    if is_idle or is_finished:
        return []

    # Colors based on state
    if is_error:
        accent = RED
        header_bg = RED_BG
        status_text = "ERROR"
    elif is_printing:
        accent = BAMBU_GREEN
        header_bg = BAMBU_GREEN_BG
        status_text = str(progress) + "%"
    else:
        accent = IDLE_GRAY
        header_bg = IDLE_BG
        status_text = "IDLE"

    # ── SPLASH ──────────────────────────────────────────────────────────
    logo_bytes = base64.decode(BAMBU_LOGO_B64)
    icon = render.Image(src = logo_bytes, width = 24, height = 24)
    splash = render.Box(
        width = 64, height = 32, color = "#000000",
        child = render.Column(
            expanded = True, main_align = "center", cross_align = "center",
            children = [icon],
        ),
    )

    # ── HEADER ──────────────────────────────────────────────────────────
    header = render.Column(children = [
        render.Box(height = 1, color = header_bg),
        render.Box(
            height = 6, color = header_bg,
            child = render.Row(
                expanded = True,
                main_align = "space_between",
                cross_align = "center",
                children = [
                    render.Padding(pad = (2, 0, 0, 0), child = render.Text("MR 3D", font = "tom-thumb", color = "#CCCCCC")),
                    render.Padding(pad = (0, 0, 2, 0), child = render.Text(status_text, font = "tom-thumb", color = accent)),
                ],
            ),
        ),
        render.Box(width = 64, height = 1, color = accent),
    ])

    # ── CONTENT ─────────────────────────────────────────────────────────
    if is_printing:
        # Progress bar
        bar_w = int(60.0 * progress / 100.0)
        if bar_w < 1 and progress > 0:
            bar_w = 1
        progress_bar = render.Padding(
            pad = (2, 0, 2, 0),
            child = render.Stack(children = [
                render.Box(width = 60, height = 3, color = "#222222"),
                render.Box(width = bar_w, height = 3, color = accent),
            ]),
        )

        # Task name
        task_display = task_name if task_name not in ("unknown", "unavailable", "") else ""
        # Strip .3mf / .gcode extensions
        if task_display.endswith(".3mf"):
            task_display = task_display[:-4]
        elif task_display.endswith(".gcode"):
            task_display = task_display[:-6]
        task_widget = render.Padding(
            pad = (2, 0, 2, 0),
            child = render.Marquee(
                width = 60,
                child = render.Text(task_display, font = "tom-thumb", color = "#AAAAAA"),
            ),
        ) if task_display else render.Box(height = 6)

        # Temps + time
        temp_text = str(nozzle) + "/" + str(bed) + "C"
        bottom_children = [
            render.Text(temp_text, font = "tom-thumb", color = "#666666"),
        ]
        if time_left:
            bottom_children.append(render.Text(time_left, font = "tom-thumb", color = accent))

        bottom = render.Padding(
            pad = (2, 0, 2, 0),
            child = render.Row(
                expanded = True,
                main_align = "space_between",
                cross_align = "center",
                children = bottom_children,
            ),
        )

        content = render.Column(children = [
            render.Box(height = 2),
            progress_bar,
            render.Box(height = 2),
            task_widget,
            render.Box(height = 1),
            bottom,
        ])
    elif is_error:
        # Error view — prominent alert with task name
        task_display = task_name if task_name not in ("unknown", "unavailable", "") else ""
        if task_display.endswith(".3mf"):
            task_display = task_display[:-4]
        elif task_display.endswith(".gcode"):
            task_display = task_display[:-6]

        error_label = stage if stage not in ("unknown", "unavailable", "") else "FAILED"

        content = render.Box(
            height = 24, color = RED_BG,
            child = render.Column(
                expanded = True,
                main_align = "center",
                cross_align = "center",
                children = [
                    render.Text(error_label.upper(), font = "tb-8", color = RED),
                    render.Box(height = 2),
                    render.Padding(
                        pad = (2, 0, 2, 0),
                        child = render.Marquee(
                            width = 60,
                            child = render.Text(task_display, font = "tom-thumb", color = "#AAAAAA"),
                        ),
                    ) if task_display else render.Box(height = 6),
                ],
            ),
        )
    else:
        # Idle view
        display_stage = stage if stage not in ("unknown", "unavailable", "") else "IDLE"
        content = render.Box(
            height = 24,
            child = render.Column(
                expanded = True,
                main_align = "center",
                cross_align = "center",
                children = [
                    render.Text(display_stage, font = "tom-thumb", color = accent),
                    render.Box(height = 2),
                    render.Text(str(nozzle) + "/" + str(bed) + "C", font = "tom-thumb", color = "#444444"),
                ],
            ),
        )

    data = render.Column(children = [header, content])

    # ── ANIMATION ───────────────────────────────────────────────────────
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
                id = "entity_prefix",
                name = "Entity Prefix",
                desc = "Bambu entity prefix in HA (e.g. x1c, p1s, a1_mini)",
                icon = "cube",
                default = "x1c",
            ),
        ],
    )
