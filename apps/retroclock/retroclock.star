"""
Applet: Retro Flip Clock
Summary: Mechanical flip clock
Description: Classic split-flap flip clock with individual digit panels, horizontal split gap, and animated flip intro.
Author: tronbyt
"""

load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")
load("encoding/json.star", "json")

DEFAULT_LOCATION = """
{
    "lat": "40.6781784",
    "lng": "-73.9441579",
    "description": "Brooklyn, NY, USA",
    "locality": "Brooklyn",
    "timezone": "America/New_York"
}
"""

# Colors
BG = "#000000"
PANEL_TOP = "#282828"
PANEL_BOT = "#1E1E1E"
GAP_COLOR = "#0C0C0C"
DIGIT_COLOR = "#E8E0D0"
COLON_COLOR = "#555555"
DATE_COLOR = "#444444"

# Sizing — 4 individual digit panels
DIGIT_W = 14
DIGIT_H = 22
GAP_H = 2
COLON_W = 4
SPACING = 1

FRAME_DELAY = 80
FLIP_STEPS = 6

def single_digit(ch, width, height, gap):
    """One flip panel with top/bottom halves and a gap."""
    half = (height - gap) // 2
    return render.Stack(children = [
        # Two-tone panel with gap
        render.Column(children = [
            render.Box(width = width, height = half, color = PANEL_TOP),
            render.Box(width = width, height = gap, color = GAP_COLOR),
            render.Box(width = width, height = half, color = PANEL_BOT),
        ]),
        # Digit centered over the whole panel
        render.Box(
            width = width, height = height,
            child = render.Column(
                expanded = True, main_align = "center", cross_align = "center",
                children = [render.Text(ch, font = "terminus-16", color = DIGIT_COLOR)],
            ),
        ),
    ])

def blank_digit(width, height, gap):
    """Empty panel — no digit."""
    half = (height - gap) // 2
    return render.Column(children = [
        render.Box(width = width, height = half, color = PANEL_TOP),
        render.Box(width = width, height = gap, color = GAP_COLOR),
        render.Box(width = width, height = half, color = PANEL_BOT),
    ])

def flipping_digit(ch, width, height, gap, progress):
    """Digit panel mid-flip. Flap covers full panel, peels away top-to-bottom."""
    if progress >= 1.0:
        return single_digit(ch, width, height, gap)

    # Flap covers from top, shrinking as digit is revealed
    reveal = int(height * progress + 0.5)
    cover = height - reveal

    return render.Stack(children = [
        # Base panel background
        render.Column(children = [
            render.Box(width = width, height = (height - gap) // 2, color = PANEL_TOP),
            render.Box(width = width, height = gap, color = GAP_COLOR),
            render.Box(width = width, height = (height - gap) // 2, color = PANEL_BOT),
        ]),
        # New digit underneath (fully rendered but hidden by flap)
        render.Box(
            width = width, height = height,
            child = render.Column(
                expanded = True, main_align = "center", cross_align = "center",
                children = [render.Text(ch, font = "terminus-16", color = DIGIT_COLOR)],
            ),
        ),
        # Flap: solid cover that shrinks from bottom up, revealing digit top-down
        render.Column(children = [
            render.Box(width = width, height = reveal, color = "#00000000"),
            render.Box(width = width, height = cover, color = PANEL_BOT),
        ]),
        # Gap line stays visible
        render.Column(children = [
            render.Box(width = width, height = (height - gap) // 2, color = "#00000000"),
            render.Box(width = width, height = gap, color = GAP_COLOR),
        ]),
    ])

def make_colon(height, visible):
    if visible:
        return render.Box(
            width = COLON_W, height = height,
            child = render.Column(
                expanded = True, main_align = "center", cross_align = "center",
                children = [
                    render.Box(width = 2, height = 2, color = COLON_COLOR),
                    render.Box(height = 4),
                    render.Box(width = 2, height = 2, color = COLON_COLOR),
                ],
            ),
        )
    return render.Box(width = COLON_W, height = height)

def build_frame(d1, d2, d3, d4, colon_on, date_str):
    spacer = render.Box(width = SPACING, height = DIGIT_H)
    return render.Box(
        width = 64, height = 32, color = BG,
        child = render.Column(
            expanded = True, main_align = "center", cross_align = "center",
            children = [
                render.Box(height = 2),
                render.Row(
                    main_align = "center",
                    cross_align = "center",
                    children = [
                        d1, spacer, d2,
                        make_colon(DIGIT_H, colon_on),
                        d3, spacer, d4,
                    ],
                ),
                render.Box(height = 3),
                render.Text(date_str, font = "tom-thumb", color = DATE_COLOR),
            ],
        ),
    )

def main(config):
    location = config.get("location", DEFAULT_LOCATION)
    loc = json.decode(location)
    timezone = loc.get("timezone", time.tz())
    use_24h = config.bool("use_24h", False)

    now = time.now().in_location(timezone)

    if use_24h:
        h = now.hour
    else:
        h = now.hour
        if h == 0:
            h = 12
        elif h > 12:
            h -= 12
    m = now.minute

    hour_str = "0" + str(h) if h < 10 else str(h)
    min_str = "0" + str(m) if m < 10 else str(m)

    # For 12h, blank leading zero
    if not use_24h and h < 10:
        hour_str = " " + str(h)

    d = [hour_str[0], hour_str[1], min_str[0], min_str[1]]
    date_str = now.format("Mon Jan 2").upper()

    frames = []

    # ── INTRO: blank pause ──
    blanks = [blank_digit(DIGIT_W, DIGIT_H, GAP_H) for _ in range(4)]
    for _ in range(6):
        frames.append(build_frame(blanks[0], blanks[1], blanks[2], blanks[3], True, date_str))

    # ── INTRO: rattle through digits fast then decelerate to final value ──
    # Each digit spins through several numbers before landing
    all_digits = "0123456789"
    settled = list(blanks)
    for digit_idx in range(4):
        target = d[digit_idx]
        if target == " ":
            # Leading space for 12h single digit — just flip in blank
            settled[digit_idx] = blank_digit(DIGIT_W, DIGIT_H, GAP_H)
            for _ in range(2):
                frames.append(build_frame(settled[0], settled[1], settled[2], settled[3], True, date_str))
            continue

        target_i = int(target)
        # Spin through 4-6 random digits before landing
        spin_count = 5
        spin_digits = []
        for s in range(spin_count):
            spin_digits.append(all_digits[(target_i + spin_count - s) % 10])
        spin_digits.append(target)

        # Fast flips (1 frame each), then slow down (more frames per flip)
        for si in range(len(spin_digits)):
            ch = spin_digits[si]
            is_last = (si == len(spin_digits) - 1)

            # Speed: fast at start, slow at end
            if si < 2:
                flip_frames = 1  # fastest
                hold = 0
            elif si < 4:
                flip_frames = 2
                hold = 1
            else:
                flip_frames = 4  # slowest for final landing
                hold = 2

            for step in range(flip_frames):
                progress = (step + 1.0) / flip_frames
                panels = list(settled)
                panels[digit_idx] = flipping_digit(ch, DIGIT_W, DIGIT_H, GAP_H, progress)
                frames.append(build_frame(panels[0], panels[1], panels[2], panels[3], True, date_str))

            settled[digit_idx] = single_digit(ch, DIGIT_W, DIGIT_H, GAP_H)
            for _ in range(hold):
                frames.append(build_frame(settled[0], settled[1], settled[2], settled[3], True, date_str))

        # Pause after this digit settles
        for _ in range(2):
            frames.append(build_frame(settled[0], settled[1], settled[2], settled[3], True, date_str))

    # ── HOLD: blinking colon ──
    for i in range(180):
        colon_on = (i % 12) < 6
        frames.append(build_frame(settled[0], settled[1], settled[2], settled[3], colon_on, date_str))

    return render.Root(
        delay = FRAME_DELAY,
        child = render.Animation(children = frames),
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
            schema.Toggle(
                id = "use_24h",
                name = "24 Hour Format",
                desc = "Use 24-hour time",
                default = False,
                icon = "clock",
            ),
        ],
    )
