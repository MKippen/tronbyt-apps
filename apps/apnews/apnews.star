"""
Applet: AP Top News
Summary: Latest AP news headline
Description: AP badge splash eases into a full-screen scrolling top story headline.
Author: tronbyt
"""

load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")

AP_RSS_URL = "https://news.google.com/rss/search?q=site:apnews.com&hl=en-US&gl=US&ceid=US:en"

ACCENT = "#CC0000"

SPLASH_FRAMES = 25
SLIDE_FRAMES  = 12
FRAME_DELAY   = 80

def ease(t):
    if t < 0.5:
        return 2.0 * t * t
    return -1.0 + (4.0 - 2.0 * t) * t

def fetch_headline():
    rep = http.get(AP_RSS_URL, ttl_seconds = 300)
    if rep.status_code != 200:
        return None
    return extract_first_title(rep.body())

def extract_first_title(xml):
    item_start = xml.find("<item>")
    if item_start < 0:
        return None
    item_xml = xml[item_start:]
    t_start   = item_xml.find("<title>")
    if t_start < 0:
        return None
    t_start += len("<title>")
    t_end = item_xml.find("</title>", t_start)
    if t_end < 0:
        return None
    title = item_xml[t_start:t_end]
    title = title.replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")
    title = title.replace("&#39;", "'").replace("&quot;", '"').replace("&apos;", "'")
    if title.endswith(" - AP News"):
        title = title[:-10]
    return title

def main(config):
    headline = fetch_headline()
    if headline == None:
        headline = "No story available"

    # ── SPLASH: AP red badge centered on black ────────────────────────────
    splash = render.Box(
        width = 64, height = 32, color = "#000000",
        child = render.Column(
            expanded = True, main_align = "center", cross_align = "center",
            children = [
                render.Stack(children = [
                    render.Box(width = 32, height = 22, color = ACCENT),
                    render.Box(
                        width = 32, height = 22,
                        child = render.Column(
                            expanded = True, main_align = "center", cross_align = "center",
                            children = [render.Text("AP", font = "terminus-14", color = "#FFFFFF")],
                        ),
                    ),
                ]),
            ],
        ),
    )

    # ── DATA: full 32px — small AP label + wrapped headline scrolling up ──
    data = render.Box(
        width = 64, height = 32, color = "#000000",
        child = render.Marquee(
            width = 64,
            height = 32,
            scroll_direction = "vertical",
            offset_start = 32,
            offset_end = 8,
            child = render.Column(children = [
                render.Padding(
                    pad = (2, 1, 0, 3),
                    child = render.Text("AP", font = "tom-thumb", color = ACCENT),
                ),
                render.Padding(
                    pad = (1, 0, 1, 0),
                    child = render.WrappedText(
                        headline,
                        width = 62,
                        color = "#FFFFFF",
                        font = "tom-thumb",
                        linespacing = 1,
                    ),
                ),
            ]),
        ),
    )

    # ── ANIMATION: splash → ease → data ───────────────────────────────────
    frames = []
    for _ in range(SPLASH_FRAMES):
        frames.append(splash)
    for i in range(SLIDE_FRAMES):
        t   = ease((i + 1.0) / SLIDE_FRAMES)
        pad = int(64.0 * (1.0 - t))
        frames.append(render.Box(
            width = 64, height = 32, color = "#000000",
            child = render.Row(children = [
                render.Box(width = pad, height = 32),
                data,
            ]),
        ))
    frames.append(data)

    return render.Root(
        delay = FRAME_DELAY,
        child = render.Animation(children = frames),
    )

def get_schema():
    return schema.Schema(version = "1", fields = [])
