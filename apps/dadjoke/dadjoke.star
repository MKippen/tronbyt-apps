"""
Applet: Dad Joke
Summary: Random dad joke
Description: Pulls a random dad joke from icanhazdadjoke.com and scrolls it on screen.
Author: tronbyt
"""

load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

COLORS = [
    ("#FFCC00", "#1A1400"),  # yellow
    ("#FF6B6B", "#1A0808"),  # red
    ("#4ECDC4", "#081A18"),  # teal
    ("#A78BFA", "#100A1A"),  # purple
    ("#FF9F43", "#1A1008"),  # orange
    ("#54A0FF", "#080E1A"),  # blue
    ("#5CD85C", "#0A1A0A"),  # green
    ("#FF78C4", "#1A0814"),  # pink
]

def main(config):
    rep = http.get(
        "https://icanhazdadjoke.com/",
        headers = {"Accept": "application/json"},
        ttl_seconds = 600,
    )
    pick = int(time.now().unix) % len(COLORS)
    accent = COLORS[pick][0]
    header_bg = COLORS[pick][1]

    if rep.status_code != 200:
        joke = "Why did the API fail? Because it couldn't GET a joke."
    else:
        joke = rep.json().get("joke", "No joke today.")

    header = render.Column(children = [
        render.Box(height = 1, color = header_bg),
        render.Box(
            height = 6, color = header_bg,
            child = render.Row(
                expanded = True,
                main_align = "center",
                cross_align = "center",
                children = [
                    render.Text("DAD JOKE", font = "tom-thumb", color = accent),
                ],
            ),
        ),
        render.Box(width = 64, height = 1, color = accent),
    ])

    body = render.Padding(
        pad = (1, 4, 1, 4),
        child = render.WrappedText(
            joke,
            width = 62,
            color = "#FFFFFF",
            font = "tom-thumb",
            linespacing = 1,
        ),
    )

    return render.Root(
        delay = 150,
        child = render.Marquee(
            width = 64,
            height = 32,
            scroll_direction = "vertical",
            offset_start = 0,
            offset_end = 0,
            child = render.Column(children = [header, body]),
        ),
    )

def get_schema():
    return schema.Schema(version = "1", fields = [])
