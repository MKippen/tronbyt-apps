"""
Applet: DateTime+
Summary: Date, time, and day of week
Description: Clean clock display — date in the header with AM/PM, large hero time in the middle, full day of week at the bottom.
Author: tronbyt
"""

load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

def main(config):
    accent = config.get("accent_color") or "#4488FF"
    use24  = config.get("use_24hour") == "true"
    tz     = config.get("$tz") or "America/New_York"

    now = time.now().in_location(tz)

    date_str = now.format("Jan 2")            # "Mar 8"
    day_str  = now.format("Monday").upper()   # "SATURDAY"
    ampm_str = now.format("PM")               # "AM" / "PM"
    time_str = now.format("15:04") if use24 else now.format("3:04")

    header_bg = "#0D0D0D"

    # ── HEADER: date left, AM/PM right ────────────────────────────────────
    header = render.Column(children = [
        render.Box(height = 1, color = header_bg),
        render.Box(
            height = 6, color = header_bg,
            child = render.Row(
                expanded = True,
                main_align = "space_between",
                cross_align = "center",
                children = [
                    render.Padding(pad = (2, 0, 0, 0), child = render.Text(date_str, font = "tom-thumb", color = "#CCCCCC")),
                    render.Padding(pad = (0, 0, 2, 0), child = render.Text("" if use24 else ampm_str, font = "tom-thumb", color = accent)),
                ],
            ),
        ),
        render.Box(width = 64, height = 1, color = accent),
    ])

    # ── TIME: hero number, centered in 16px ───────────────────────────────
    time_area = render.Box(
        height = 16,
        child = render.Column(
            expanded = True, main_align = "center", cross_align = "center",
            children = [render.Text(time_str, font = "terminus-14", color = "#FFFFFF")],
        ),
    )

    # ── DAY: full day name in accent, centered ─────────────────────────────
    day_area = render.Box(
        height = 8,
        child = render.Column(
            expanded = True, main_align = "center", cross_align = "center",
            children = [render.Text(day_str, font = "tom-thumb", color = accent)],
        ),
    )

    return render.Root(child = render.Column(children = [header, time_area, day_area]))

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Color(
                id = "accent_color",
                name = "Accent Color",
                desc = "Color for the separator line, AM/PM indicator, and day of week",
                icon = "palette",
                default = "#4488FF",
                palette = ["#4488FF", "#33BB55", "#CC3333", "#FF8800", "#AA44FF", "#FFDD00"],
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
