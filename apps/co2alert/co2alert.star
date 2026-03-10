"""
Applet: CO2 Alert
Summary: High CO2 warning
Description: Displays a high CO2 alert with current PPM value. Designed to be pushed from Home Assistant.
Author: tronbyt
"""

load("render.star", "render")
load("schema.star", "schema")

RED = "#CC3333"
RED_BG = "#150909"
AMBER = "#FFAA33"

def main(config):
    ppm = config.get("ppm", "")
    location = config.get("location", "KITCHEN")

    header = render.Column(children = [
        render.Box(height = 1, color = RED_BG),
        render.Box(
            height = 6, color = RED_BG,
            child = render.Row(
                expanded = True,
                main_align = "space_between",
                cross_align = "center",
                children = [
                    render.Padding(pad = (2, 0, 0, 0), child = render.Text("CO2", font = "tom-thumb", color = "#CCCCCC")),
                    render.Padding(pad = (0, 0, 2, 0), child = render.Text(location.upper(), font = "tom-thumb", color = RED)),
                ],
            ),
        ),
        render.Box(width = 64, height = 1, color = RED),
    ])

    children = [
        render.Text("HIGH CO2", font = "tb-8", color = RED),
    ]
    if ppm:
        children.append(render.Box(height = 3))
        children.append(render.Text(ppm + " ppm", font = "tom-thumb", color = AMBER))

    content = render.Box(
        height = 24, color = "#000000",
        child = render.Column(
            expanded = True,
            main_align = "center",
            cross_align = "center",
            children = children,
        ),
    )

    return render.Root(
        delay = 500,
        child = render.Animation(
            children = [
                render.Column(children = [header, content]),
                render.Column(children = [
                    header,
                    render.Box(
                        height = 24, color = "#000000",
                        child = render.Column(
                            expanded = True,
                            main_align = "center",
                            cross_align = "center",
                            children = [
                                render.Text("HIGH CO2", font = "tb-8", color = "#661111"),
                            ] + ([render.Box(height = 3), render.Text(ppm + " ppm", font = "tom-thumb", color = AMBER)] if ppm else []),
                        ),
                    ),
                ]),
            ],
        ),
    )

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "ppm",
                name = "CO2 PPM",
                desc = "Current CO2 level in PPM (passed via push config)",
                icon = "wind",
            ),
            schema.Text(
                id = "location",
                name = "Location",
                desc = "Room name to display",
                icon = "locationDot",
                default = "KITCHEN",
            ),
        ],
    )
