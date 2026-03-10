# Tronbyt App Design Language

Design conventions for the custom apps in this repo. Follow these patterns when building or modifying apps so everything feels consistent on the 64×32 display.

---

## Canvas

- **Size**: 64×32 px, RGB, no alpha
- **Background**: `#000000` or near-black. Never pure white backgrounds.
- **Font choices**: `tom-thumb` (5px), `tb-8` (~8px), `terminus-14` (14px hero)

---

## Header Band — 8px total

Every app gets a header band at the top. Structure (top to bottom):

```
1px  — top margin (header_bg color — breathing room)
6px  — content row (tinted dark bg)
1px  — accent separator line (full width, accent color)
```

```python
header = render.Column(children = [
    render.Box(height = 1, color = header_bg),
    render.Box(
        height = 6, color = header_bg,
        child = render.Row(
            expanded = True,
            main_align = "space_between",
            cross_align = "center",
            children = [
                render.Padding(pad = (2, 0, 0, 0), child = render.Text(label, font = "tom-thumb", color = "#CCCCCC")),
                render.Padding(pad = (0, 0, 2, 0), child = render.Text(value, font = "tom-thumb", color = accent)),
            ],
        ),
    ),
    render.Box(width = 64, height = 1, color = accent),
])
```

- **Left slot**: static label (ticker, entity name, title) — `#CCCCCC`
- **Right slot**: dynamic value (% change, status) — accent color
- **Header bg tint**: dark version of the accent direction
  - Up / good: `"#091509"` (dark green)
  - Down / alert: `"#150909"` (dark red)
  - Neutral: `"#111111"`

---

## Color System

| Role | Default | Notes |
|---|---|---|
| Up / positive | `#33BB55` | User-configurable `up_color` |
| Down / negative | `#CC3333` | User-configurable `down_color` |
| Alert | `#CC0000` | For hassalert-style apps |
| Label text | `#CCCCCC` | Static titles, tickers |
| Primary value | `#FFFFFF` | Hero number |
| Secondary value | `#AAAAAA` | Smaller secondary readings |
| Dim chart track | `hex_dim(accent, 0.22)` | Background track behind bars |

### `hex_dim` helper (copy into any app that needs it)

```python
def hex_dim(color, factor):
    h = color.lstrip("#").upper()
    d = "0123456789ABCDEF"
    r = int(int(h[0:2], 16) * factor)
    g = int(int(h[2:4], 16) * factor)
    b = int(int(h[4:6], 16) * factor)
    return "#" + d[r >> 4] + d[r & 15] + d[g >> 4] + d[g & 15] + d[b >> 4] + d[b & 15]
```

---

## Typography

### Hero value (large number + small unit)

```python
render.Row(
    cross_align = "end",
    children = [
        render.Padding(pad = (0, 0, 0, 1), child = render.Text("$", font = "tb-8", color = "#FFFFFF")),
        render.Text(value_str, font = "terminus-14", color = "#FFFFFF"),
    ],
)
```

The unit/prefix sits at baseline (`tb-8`, `pad=(0,0,0,1)` lifts it 1px). The number is `terminus-14`. Both in a `cross_align = "end"` Row.

### Drop shadow (text over a complex background)

```python
shadow = render.Row(cross_align = "end", children = [
    render.Padding(pad = (0, 0, 0, 1), child = render.Text("$", font = "tb-8", color = "#000000")),
    render.Text(value_str, font = "terminus-14", color = "#000000"),
])
foreground = render.Row(cross_align = "end", children = [
    render.Padding(pad = (0, 0, 0, 1), child = render.Text("$", font = "tb-8", color = "#FFFFFF")),
    render.Text(value_str, font = "terminus-14", color = "#FFFFFF"),
])
shadowed = render.Stack(children = [
    render.Padding(pad = (1, 1, 0, 0), child = shadow),  # 1px right + 1px down
    foreground,
])
```

---

## Sparkline / Chart

Bar chart with dim full-height track behind each bar — looks like a proper data viz background, not floating bars.

```python
def hex_dim(color, factor): ...  # see above

def make_sparkline(prices, width, height, color):
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
        if bar_h < 1: bar_h = 1
        if bar_h > height: bar_h = height
        cols.append(render.Stack(children = [
            render.Box(width = bar_w, height = height, color = track),
            render.Padding(pad = (0, height - bar_h, 0, 0),
                child = render.Box(width = bar_w, height = bar_h, color = color)),
        ]))
    return render.Box(width = width, height = height,
        child = render.Row(children = cols))
```

---

## Layout Zones

### Two-zone (stockchart style)

```
8px  — header band
24px — content (can Stack chart + value)
```

Price pinned near the bottom of the content area:
```python
render.Box(
    height = 24,
    child = render.Column(
        expanded = True, main_align = "end", cross_align = "center",
        children = [render.Padding(pad = (0, 0, 0, 2), child = price_widget)],
    ),
)
```

### Three-zone (hassstation style)

```
8px  — header band
16px — primary value (terminus-14 hero)
8px  — secondary values (tom-thumb, 2 readings side by side)
```

### Layered (chart behind value)

```python
content = render.Stack(children = [
    make_sparkline(closes, 64, 24, accent),   # chart as background
    render.Box(height = 24, child = render.Column(
        expanded = True, main_align = "end", cross_align = "center",
        children = [render.Padding(pad = (0, 0, 0, 2), child = price_widget)],
    )),
])
```

---

## Animation Pattern (splash → slide → hold)

For apps where a visual intro makes sense (sensor alerts, etc.). Skip for data apps like stockchart.

```python
SPLASH_FRAMES = 25    # ~2s icon hold
SLIDE_FRAMES  = 12    # ~1s ease transition
DATA_FRAMES   = 1500  # ~120s hold — never loops at normal display times
FRAME_DELAY   = 80    # ms per frame

def ease(t):
    if t < 0.5:
        return 2.0 * t * t
    return -1.0 + (4.0 - 2.0 * t) * t

# Build frames
frames = []
for _ in range(SPLASH_FRAMES):
    frames.append(splash)
for i in range(SLIDE_FRAMES):
    t = ease((i + 1.0) / SLIDE_FRAMES)
    pad = int(64.0 * (1.0 - t))
    # Self-contained frame (black box + Row spacer) — never stack over splash
    # or WebP delta frames let the splash bleed through during the transition.
    frames.append(render.Box(
        width = 64, height = 32, color = "#000000",
        child = render.Row(children = [
            render.Box(width = pad, height = 32),
            data,
        ]),
    ))
for _ in range(DATA_FRAMES):
    frames.append(data)

return render.Root(delay = FRAME_DELAY, child = render.Animation(children = frames))
```

**Rule**: DATA_FRAMES must be large enough that the animation never loops within any realistic display window. 1500 × 80ms = 120 seconds. If the app stays up for ≤ 120s it will never loop.

---

## Spacing Cheatsheet

| Location | Value |
|---|---|
| Header text left/right padding | `pad = (2, 0, 0, 0)` / `pad = (0, 0, 2, 0)` |
| Header top margin | 1px (header_bg Box before content row) |
| Unit suffix baseline lift | `pad = (0, 0, 0, 1)` on `tb-8` text |
| Bottom-pinned value | `pad = (0, 0, 0, 2)` on value, `main_align = "end"` |
| Drop shadow offset | `pad = (1, 1, 0, 0)` on shadow layer |
| **Edge breathing room** | Always at least 1px padding from top/bottom/left/right edges — never place text flush against the display boundary |

---

## Deployment Workflow

### Dev loop (instant, no restart needed)

The apps directory is **bind-mounted** into the server container at `/app/data/system-apps`. Local `.star` edits are immediately visible to the server — no push or restart required.

After editing a `.star` file, just run:
```bash
cd /Users/mike/code/tronbyt/server && ./refresh-app.sh
```

This script:
1. Resets the admin password and logs in
2. Deletes all cached WebP renders from the Docker volume
3. Cycles `/next` 20× to trigger fresh renders
4. Confirms which apps re-rendered

### Publishing to GitHub (for prod / PR)

1. `git add` + `git commit` + `git push origin main`
2. No restart needed — bind mount keeps server in sync with local files

### App config (installation schema fields)

POST to `/devices/{id}/{iname}/config` as JSON with the schema fields nested under `"config"`:
```json
{"enabled":true,"uinterval":0,"display_time":0,"notes":"","color_filter":"",
 "config":{"field1":"value1","field2":"value2"}}
```
