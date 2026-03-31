"""
Applet: Artemis2Countdown
Summary: Countdown to Artemis II
Description: Countdown to the Artemis II crewed Moon mission launch on April 1, 2026 at 6:24 PM EDT.
Author: SoNu (for Molly)
"""

load("render.star", "render")
load("time.star", "time")
load("math.star", "math")
load("images/rocket_icon.png", ROCKET_A = "file")
load("images/rocket_icon_b.png", ROCKET_B = "file")
load("images/rocket_icon_c.png", ROCKET_C = "file")
load("images/rocket_icon_d.png", ROCKET_D = "file")

ROCKET_ICON = ROCKET_A.readall()
ROCKET_ICON_B = ROCKET_B.readall()
ROCKET_ICON_C = ROCKET_C.readall()
ROCKET_ICON_D = ROCKET_D.readall()

# Artemis II launch: April 1, 2026 at 6:24 PM EDT (22:24 UTC)
LAUNCH_TIME = time.parse_time("2026-04-01T22:24:00Z")

ACCENT = "#4DA6FF"       # NASA blue
HEADER_BG = "#0B1A2E"    # dark navy

def hex_dim(color, factor):
    h = color.lstrip("#").upper()
    d = "0123456789ABCDEF"
    r = int(int(h[0:2], 16) * factor)
    g = int(int(h[2:4], 16) * factor)
    b = int(int(h[4:6], 16) * factor)
    return "#" + d[r >> 4] + d[r & 15] + d[g >> 4] + d[g & 15] + d[b >> 4] + d[b & 15]

def main(config):
    now = time.now()
    diff = LAUNCH_TIME - now

    total_seconds = int(diff.seconds)

    if total_seconds <= 0:
        # Post-launch
        return render.Root(
            delay = 80,
            child = render.Column(children = [
                render.Box(height = 1, color = HEADER_BG),
                render.Box(
                    height = 6, color = HEADER_BG,
                    child = render.Row(
                        expanded = True, main_align = "center", cross_align = "center",
                        children = [render.Text("ARTEMIS II", font = "tom-thumb", color = ACCENT)],
                    ),
                ),
                render.Box(width = 64, height = 1, color = ACCENT),
                render.Box(height = 24, child = render.Column(
                    expanded = True, main_align = "center", cross_align = "center",
                    children = [
                        render.Text("LAUNCHED!", font = "tb-8", color = "#FFFFFF"),
                        render.Text("TO THE MOON", font = "tom-thumb", color = ACCENT),
                    ],
                )),
            ]),
        )

    days = total_seconds // 86400
    hours = (total_seconds % 86400) // 3600
    minutes = (total_seconds % 3600) // 60
    seconds = total_seconds % 60

    # Format countdown string
    if days > 0:
        countdown_str = "%dd %dh %dm" % (days, hours, minutes)
    elif hours > 0:
        countdown_str = "%dh %dm %ds" % (hours, minutes, seconds)
    else:
        countdown_str = "%dm %ds" % (minutes, seconds)

    # Header
    header = render.Column(children = [
        render.Box(height = 1, color = HEADER_BG),
        render.Box(
            height = 6, color = HEADER_BG,
            child = render.Row(
                expanded = True, main_align = "space_between", cross_align = "center",
                children = [
                    render.Padding(pad = (2, 0, 0, 0), child = render.Text("ARTEMIS II", font = "tom-thumb", color = "#CCCCCC")),
                    render.Padding(pad = (0, 0, 2, 0), child = render.Text("APR 1", font = "tom-thumb", color = ACCENT)),
                ],
            ),
        ),
        render.Box(width = 64, height = 1, color = ACCENT),
    ])

    # Rocket animation
    rocket_anim = render.Animation(children = [
        render.Image(src = ROCKET_ICON),
        render.Image(src = ROCKET_ICON_B),
        render.Image(src = ROCKET_ICON_C),
        render.Image(src = ROCKET_ICON_D),
        render.Image(src = ROCKET_ICON_C),
        render.Image(src = ROCKET_ICON_B),
    ])

    # Content area
    content = render.Box(
        height = 24,
        child = render.Row(
            expanded = True,
            main_align = "space_between",
            cross_align = "center",
            children = [
                render.Padding(
                    pad = (2, 0, 0, 0),
                    child = render.Column(
                        main_align = "center",
                        children = [
                            render.Text(countdown_str, font = "tb-8", color = "#FFFFFF"),
                            render.Padding(
                                pad = (0, 2, 0, 0),
                                child = render.Text("TO THE MOON", font = "tom-thumb", color = hex_dim(ACCENT, 0.7)),
                            ),
                        ],
                    ),
                ),
                render.Padding(pad = (0, 0, 2, 0), child = rocket_anim),
            ],
        ),
    )

    return render.Root(
        delay = 80,
        child = render.Column(children = [header, content]),
    )

def get_schema():
    return []
