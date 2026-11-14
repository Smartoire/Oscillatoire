"""Converts the app icons to RGB PNGs (no alpha channel), which App Store Connect requires."""
from PIL import Image

ICONS = [
    "App/Assets.xcassets/AppIcon.appiconset/icon.png",
    "App/Assets.xcassets/AppIcon.appiconset/icon-512.png",
]

for path in ICONS:
    img = Image.open(path).convert("RGBA")
    flat = Image.new("RGB", img.size, (255, 255, 255))
    flat.paste(img, mask=img.getchannel("A"))
    flat.save(path, "PNG")
    print("flattened", path)
