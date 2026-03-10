"""
Applet: AP Top News
Summary: Latest AP news headlines
Description: AP badge scrolls up from bottom, then 2-3 AP headlines follow separated by red dividers.
Author: tronbyt
"""

load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")

AP_RSS_URL = "https://feedx.net/rss/ap.xml"

ACCENT = "#CC0000"

def fetch_headlines(n):
    rep = http.get(AP_RSS_URL, ttl_seconds = 300)
    if rep.status_code != 200:
        return []
    return extract_titles(rep.body(), n)

def extract_titles(xml, n):
    titles = []
    pos = 0
    for _ in range(n):
        item_start = xml.find("<item>", pos)
        if item_start < 0:
            break
        item_end = xml.find("</item>", item_start)
        end = item_end if item_end >= 0 else len(xml)
        item_xml = xml[item_start:end]

        t_start = item_xml.find("<title>")
        if t_start >= 0:
            t_start += len("<title>")
            t_end = item_xml.find("</title>", t_start)
            if t_end >= 0:
                title = item_xml[t_start:t_end]
                # Strip CDATA wrapper if present
                if title.startswith("<![CDATA[") and title.endswith("]]>"):
                    title = title[len("<![CDATA["):-len("]]>")]
                title = title.replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")
                title = title.replace("&#39;", "'").replace("&quot;", '"').replace("&apos;", "'")
                if title.endswith(" - AP News"):
                    title = title[:-10]
                titles.append(title)

        pos = item_end + len("</item>") if item_end >= 0 else len(xml)
    return titles

def main(config):
    headlines = fetch_headlines(2)
    if not headlines:
        headlines = ["No story available"]

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

    # Story blocks with red dividers between them
    story_blocks = []
    for i, headline in enumerate(headlines):
        if i > 0:
            story_blocks.append(render.Box(width = 64, height = 1, color = ACCENT))
        story_blocks.append(
            render.Padding(
                pad = (1, 6, 1, 8),
                child = render.WrappedText(
                    headline,
                    width = 62,
                    color = "#FFFFFF",
                    font = "tom-thumb",
                    linespacing = 1,
                ),
            ),
        )

    # Single vertical marquee: AP fills screen → pushes up → headlines scroll in
    return render.Root(
        delay = int(config.get("scroll_speed", "150")),
        child = render.Marquee(
            width = 64,
            height = 32,
            scroll_direction = "vertical",
            offset_start = 0,
            offset_end = 0,
            child = render.Column(children = [ap_block] + story_blocks),
        ),
    )

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Dropdown(
                id = "scroll_speed",
                name = "Scroll Speed",
                desc = "How fast headlines scroll (lower = faster)",
                icon = "gauge",
                default = "150",
                options = [
                    schema.Option(display = "Fast", value = "100"),
                    schema.Option(display = "Medium", value = "150"),
                    schema.Option(display = "Normal", value = "200"),
                    schema.Option(display = "Slow", value = "300"),
                ],
            ),
        ],
    )
