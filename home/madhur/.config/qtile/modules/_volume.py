from qtile_extras import widget

class Volume(widget.PulseVolume):
    """Like regular Volume, but uses NerdFonts' icons."""

    icon_list: list[str]
    format: str

    defualts = [
        (
            "format",
            "{icon} {volume}%",
            "The format to display the volume and icon",
        ),
        ("show_volume_when_mute", False, "Self explanatory"),
        ("mute_icon", "󰝟", "Icon to display when the mute"),
        ("no_volume_icon", "󰸈", "Icon to display when the volume is 0 and is not muted"),
        ("icon_list", ["󰕿", "󰖀", "󰕾"], "List of icons for low, medium and high volume, in order"),
    ]

    def __init__(self, **config):
        super().__init__(**config)
        self.add_defaults(self.defualts)

    def _update_drawer(self):
        if self.volume < 0:
            icon = self.mute_icon
        elif not self.volume:
            icon = self.no_volume_icon
        elif self.volume <= 20:
            icon = self.icon_list[0]
        elif self.volume < 70:
            icon = self.icon_list[1]
        else:
            icon = self.icon_list[2]

        volume = self.volume if icon != self.mute_icon else "0"
        self.text = self.format.format(icon=icon, volume=volume)
