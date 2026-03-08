"""
Applet: Stock Chart
Summary: Stock price with 5-day sparkline
Description: Shows current price, daily % change, and a 5-day price sparkline. Header and chart color shift green when up, red when down.
Author: tronbyt
"""

load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")

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

def hex_dim(color, factor):
    """Return a darkened version of a hex color (factor 0.0–1.0)."""
    h = color.lstrip("#").upper()
    d = "0123456789ABCDEF"
    r = int(int(h[0:2], 16) * factor)
    g = int(int(h[2:4], 16) * factor)
    b = int(int(h[4:6], 16) * factor)
    return "#" + d[r >> 4] + d[r & 15] + d[g >> 4] + d[g & 15] + d[b >> 4] + d[b & 15]

def make_sparkline(prices, width, height, color):
    """Bar chart with a dim full-height track behind each bar."""
    clean = [p for p in prices if p != None]
    if len(clean) < 2:
        return render.Box(width = width, height = height)
    min_p = min(clean)
    max_p = max(clean)
    rng = max_p - min_p
    if rng == 0.0:
        rng = 0.01
    bar_w = width // len(clean)
    if bar_w < 1:
        bar_w = 1
    pts = clean[-(width // bar_w):]
    track = hex_dim(color, 0.22)
    cols = []
    for p in pts:
        bar_h = int((p - min_p) / rng * float(height - 1) + 0.5) + 1
        if bar_h < 1:
            bar_h = 1
        if bar_h > height:
            bar_h = height
        col = render.Stack(children = [
            render.Box(width = bar_w, height = height, color = track),
            render.Padding(
                pad = (0, height - bar_h, 0, 0),
                child = render.Box(width = bar_w, height = bar_h, color = color),
            ),
        ])
        cols.append(col)
    return render.Box(
        width = width,
        height = height,
        child = render.Row(children = cols),
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

    is_up     = current >= prev
    accent    = up_color if is_up else dn_color
    header_bg = "#091509" if is_up else "#150909"
    price_str = format_price(current)
    pct_str   = format_pct(current, prev)

    # ── HEADER: ticker left, % change right, accent divider ───────────────
    header = render.Column(children = [
        render.Box(
            height = 7, color = header_bg,
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

    # ── PRICE with drop shadow ─────────────────────────────────────────────
    shadow_row = render.Row(
        cross_align = "end",
        children = [
            render.Padding(pad = (0, 0, 0, 1), child = render.Text("$", font = "tb-8", color = "#000000")),
            render.Text(price_str, font = "terminus-14", color = "#000000"),
        ],
    )
    price_row = render.Row(
        cross_align = "end",
        children = [
            render.Padding(pad = (0, 0, 0, 1), child = render.Text("$", font = "tb-8", color = "#FFFFFF")),
            render.Text(price_str, font = "terminus-14", color = "#FFFFFF"),
        ],
    )
    price_widget = render.Stack(children = [
        render.Padding(pad = (1, 1, 0, 0), child = shadow_row),
        price_row,
    ])

    # ── CHART + PRICE: sparkline fills 24px, price pinned near bottom ──────
    content = render.Stack(children = [
        make_sparkline(closes, 64, 24, accent),
        render.Box(
            height = 24,
            child = render.Column(
                expanded = True, main_align = "end", cross_align = "center",
                children = [render.Padding(pad = (0, 0, 0, 2), child = price_widget)],
            ),
        ),
    ])

    return render.Root(child = render.Column(children = [header, content]))

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
