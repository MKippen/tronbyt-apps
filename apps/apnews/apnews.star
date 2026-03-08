"""
Applet: AP Top News
Summary: Latest AP news headline
Description: Shows the current top story from Associated Press with a scrolling headline.
Author: tronbyt
"""

load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")

AP_RSS_URL = "https://news.google.com/rss/search?q=site:apnews.com&hl=en-US&gl=US&ceid=US:en"

ACCENT    = "#CC0000"
HEADER_BG = "#1A0000"

def fetch_headline():
    rep = http.get(AP_RSS_URL, ttl_seconds = 300)
    if rep.status_code != 200:
        return None
    return extract_first_title(rep.body())

def extract_first_title(xml):
    # Skip channel <title> — find first <item> block
    item_start = xml.find("<item>")
    if item_start < 0:
        return None
    item_xml = xml[item_start:]

    t_start = item_xml.find("<title>")
    if t_start < 0:
        return None
    t_start += len("<title>")
    t_end = item_xml.find("</title>", t_start)
    if t_end < 0:
        return None

    title = item_xml[t_start:t_end]

    # Decode common XML entities
    title = title.replace("&amp;", "&")
    title = title.replace("&lt;", "<")
    title = title.replace("&gt;", ">")
    title = title.replace("&#39;", "'")
    title = title.replace("&quot;", "\"")
    title = title.replace("&apos;", "'")

    # Strip " - AP News" suffix added by Google News
    if title.endswith(" - AP News"):
        title = title[:-10]

    return title

def main(config):
    headline = fetch_headline()
    if headline == None:
        headline = "Unable to fetch news"

    # ── HEADER: AP badge left, TOP NEWS right ────────────────────────────
    header = render.Column(children = [
        render.Box(height = 1, color = HEADER_BG),
        render.Box(
            height = 6, color = HEADER_BG,
            child = render.Row(
                expanded = True,
                main_align = "space_between",
                cross_align = "center",
                children = [
                    render.Padding(pad = (2, 0, 0, 0), child = render.Text("AP", font = "tom-thumb", color = ACCENT)),
                    render.Padding(pad = (0, 0, 2, 0), child = render.Text("TOP NEWS", font = "tom-thumb", color = "#666666")),
                ],
            ),
        ),
        render.Box(width = 64, height = 1, color = ACCENT),
    ])

    # ── CONTENT: scrolling headline, vertically centered ─────────────────
    content = render.Box(
        height = 24,
        child = render.Column(
            expanded = True,
            main_align = "center",
            cross_align = "start",
            children = [
                render.Marquee(
                    width = 64,
                    child = render.Text(headline, font = "tb-8", color = "#FFFFFF"),
                    offset_start = 64,
                    offset_end = 64,
                ),
            ],
        ),
    )

    return render.Root(
        delay = 40,
        child = render.Column(children = [header, content]),
    )

def get_schema():
    return schema.Schema(version = "1", fields = [])
