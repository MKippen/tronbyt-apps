"""
Applet: AP Top News
Summary: Latest AP news headline
Description: AP badge scrolls up from bottom, then headline text follows and fills the screen top to bottom.
Author: tronbyt
"""

load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")

AP_RSS_URL = "https://news.google.com/rss/search?q=site:apnews.com&hl=en-US&gl=US&ceid=US:en"

ACCENT = "#CC0000"

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

    # AP badge — full 32px tall block, centered on black
    ap_block = render.Box(
        width = 64, height = 32, color = "#000000",
        child = render.Column(
            expanded = True, main_align = "center", cross_align = "center",
            children = [
                render.Stack(children = [
                    render.Box(width = 34, height = 22, color = ACCENT),
                    render.Box(
                        width = 34, height = 22,
                        child = render.Column(
                            expanded = True, main_align = "center", cross_align = "center",
                            children = [render.Text("AP", font = "terminus-14", color = "#FFFFFF")],
                        ),
                    ),
                ]),
            ],
        ),
    )

    # Headline block — full width wrapped text follows the badge
    headline_block = render.Padding(
        pad = (1, 6, 1, 8),
        child = render.WrappedText(
            headline,
            width = 62,
            color = "#FFFFFF",
            font = "tom-thumb",
            linespacing = 1,
        ),
    )

    # Single vertical marquee: AP fills screen → pushes up → headline scrolls in
    return render.Root(
        delay = 75,
        child = render.Marquee(
            width = 64,
            height = 32,
            scroll_direction = "vertical",
            offset_start = 32,
            offset_end = 32,
            child = render.Column(children = [ap_block, headline_block]),
        ),
    )

def get_schema():
    return schema.Schema(version = "1", fields = [])
