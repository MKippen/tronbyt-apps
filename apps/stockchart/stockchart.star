"""
Applet: Stock Chart
Summary: Stock price with 3-day sparkline
Description: Shows current price, daily % change, and a 3-day price sparkline. Header and chart color shift green when up, red when down. Animated icon splash intro.
Author: tronbyt
"""

load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")

OPENMOJI_BASE = "https://cdn.jsdelivr.net/gh/hfg-gmuend/openmoji@15.0.0/color/72x72/"

SPLASH_FRAMES = 25
SLIDE_FRAMES  = 12
DATA_FRAMES   = 1500
FRAME_DELAY   = 80

def ease(t):
    if t < 0.5:
        return 2.0 * t * t
    return -1.0 + (4.0 - 2.0 * t) * t

def load_emoji(code):
    rep = http.get(OPENMOJI_BASE + code + ".png", ttl_seconds = 86400)
    return rep.body() if rep.status_code == 200 else None

def fetch_quote(symbol):
    url = (
        "https://query1.finance.yahoo.com/v8/finance/chart/" +
        symbol +
        "?interval=30m&range=5d"
    )
    rep = http.get(url, ttl_seconds = 300, headers = {"User-Agent": "Mozilla/5.0"})
    if rep.status_code != 200:
        return None
    results = rep.json().get("chart", {}).get("result", [])
    return results[0] if results else None

def format_price(price):
    if price >= 1000:
        return str(int(price + 0.5))
    if price >= 100:
        return str(int(price + 0.5))
    if price >= 10:
        r = int(price * 10.0 + 0.5)
        return str(r // 10) + "." + str(r % 10)
    r = int(price * 100.0 + 0.5)
    dec = str(r % 100)
    return str(r // 100) + "." + (dec if len(dec) == 2 else "0" + dec)

def format_pct(current, prev):
    if prev == 0.0:
        return "N/A"
    pct = (current - prev) / prev * 100.0
    sign = "+" if pct >= 0.0 else "-"
    abs_pct = pct if pct >= 0.0 else -pct
    whole = int(abs_pct)
    dec = int(abs_pct * 10.0 + 0.5) % 10
    return sign + str(whole) + "." + str(dec) + "%"

def make_sparkline(prices, width, height, color):
    clean = [p for p in prices if p != None]
    if len(clean) < 2:
        return render.Box(width = width, height = height)
    min_p = min(clean)
    max_p = max(clean)
    rng = max_p - min_p
    if rng == 0.0:
        rng = 0.01
    n = len(clean)
    bar_w = width // n
    if bar_w < 1:
        bar_w = 1
    pts = clean[-(width // bar_w):]
    cols = []
    for p in pts:
        h = int((p - min_p) / rng * float(height - 1) + 0.5) + 1
        if h < 1:
            h = 1
        if h > height:
            h = height
        cols.append(render.Box(width = bar_w, height = h, color = color))
    return render.Box(
        width = width,
        height = height,
        child = render.Row(cross_align = "end", children = cols),
    )

def main(config):
    symbol   = (config.get("symbol") or "MSFT").upper()
    up_color = config.get("up_color") or "#33BB55"
    dn_color = config.get("down_color") or "#CC3333"

    result = fetch_quote(symbol)
    if result == None:
        return render.Root(child = render.Box(
            width = 64, height = 32,
            child = render.Column(
                expanded = True, main_align = "center", cross_align = "center",
                children = [
                    render.Text(symbol, font = "tom-thumb", color = "#AAAAAA"),
                    render.Text("no data", font = "tom-thumb", color = "#CC4444"),
                ],
            ),
        ))

    meta    = result.get("meta", {})
    current = float(meta.get("regularMarketPrice") or 0)
    prev    = float(meta.get("previousClose") or current)
    closes  = result.get("indicators", {}).get("quote", [{}])[0].get("close", [])

    is_up      = current >= prev
    accent     = up_color if is_up else dn_color
    header_bg  = "#091509" if is_up else "#150909"
    price_str  = format_price(current)
    pct_str    = format_pct(current, prev)
    emoji_code = "1F4C8" if is_up else "1F4C9"
    icon_img   = load_emoji(emoji_code)

    # ── SPLASH: chart emoji centered on near-black ─────────────────────────
    big_icon = render.Image(src = icon_img, width = 28, height = 28) if icon_img else render.Box(width = 28, height = 28)
    splash = render.Box(
        width = 64, height = 32, color = "#111111",
        child = render.Column(
            expanded = True, main_align = "center", cross_align = "center",
            children = [big_icon],
        ),
    )

    # ── DATA VIEW ──────────────────────────────────────────────────────────
    # Header (8px + 1px accent): ticker left, % change right
    header = render.Column(children = [
        render.Box(
            height = 8, color = header_bg,
            child = render.Row(
                expanded = True,
                main_align = "space_between",
                cross_align = "center",
                children = [
                    render.Padding(pad = (2, 0, 0, 0), child = render.Text(symbol, font = "tom-thumb", color = "#CCCCCC")),
                    render.Padding(pad = (0, 0, 2, 0), child = render.Text(pct_str, font = "tom-thumb", color = accent)),
                ],
            ),
        ),
        render.Box(width = 64, height = 1, color = accent),
    ])

    # Price (15px): $ small baseline, number large
    price_widget = render.Row(
        cross_align = "end",
        children = [
            render.Padding(pad = (0, 0, 0, 1), child = render.Text("$", font = "tb-8", color = "#FFFFFF")),
            render.Text(price_str, font = "terminus-14", color = "#FFFFFF"),
        ],
    )
    price_area = render.Box(
        height = 15,
        child = render.Column(
            expanded = True, main_align = "center", cross_align = "center",
            children = [price_widget],
        ),
    )

    # Sparkline (8px): 3-day price chart, accent colored
    chart = make_sparkline(closes, 64, 8, accent)

    data = render.Column(children = [header, price_area, chart])

    # ── ANIMATION ──────────────────────────────────────────────────────────
    frames = []
    for _ in range(SPLASH_FRAMES):
        frames.append(splash)
    for i in range(SLIDE_FRAMES):
        t = ease((i + 1.0) / SLIDE_FRAMES)
        pad = int(64.0 * (1.0 - t))
        frames.append(render.Stack(children = [
            splash,
            render.Padding(pad = (pad, 0, 0, 0), child = data),
        ]))
    for _ in range(DATA_FRAMES):
        frames.append(data)

    return render.Root(delay = FRAME_DELAY, child = render.Animation(children = frames))

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "symbol",
                name = "Stock Symbol",
                desc = "Ticker symbol (e.g. MSFT, AAPL, TSLA, SPY)",
                icon = "chartLine",
                default = "MSFT",
            ),
            schema.Color(
                id = "up_color",
                name = "Up Color",
                desc = "Accent color when price is up from previous close",
                icon = "palette",
                default = "#33BB55",
                palette = ["#33BB55", "#44FF66", "#00AA44", "#88FFAA"],
            ),
            schema.Color(
                id = "down_color",
                name = "Down Color",
                desc = "Accent color when price is down from previous close",
                icon = "palette",
                default = "#CC3333",
                palette = ["#CC3333", "#FF4444", "#AA0000", "#FF8888"],
            ),
        ],
    )
