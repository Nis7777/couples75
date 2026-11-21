#!/usr/bin/env python3
"""Optional helper: re-import every PNG in ArtSource/ into Shared/Assets.xcassets after the art changes.
The imported art is already committed, so the project builds without running this.

- Each PNG becomes an image set named after the file (char_w1_stand.png -> "char_w1_stand").
- AppIcon.png is resized to 1024x1024, alpha stripped, and used as the single-size app icon.
Uses `sips` on macOS; falls back to Pillow if available.
Run from the repository root:  python3 scripts/import_art.py
"""
import json, os, shutil, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "ArtSource")
CAT = os.path.join(ROOT, "Shared", "Assets.xcassets")
INFO = {"author": "xcode", "version": 1}

def write_json(path, obj):
    with open(path, "w") as f:
        json.dump(obj, f, indent=2)
        f.write("\n")

def have_sips():
    return shutil.which("sips") is not None

def make_icon(src, dst):
    if have_sips():
        tmp = dst + ".tmp.jpg"
        # Converting through JPEG strips alpha; then back to PNG.
        subprocess.run(["sips", "-z", "1024", "1024", src, "--out", dst], check=True, capture_output=True)
        subprocess.run(["sips", "-s", "format", "jpeg", dst, "--out", tmp], check=True, capture_output=True)
        subprocess.run(["sips", "-s", "format", "png", tmp, "--out", dst], check=True, capture_output=True)
        os.remove(tmp)
        return
    from PIL import Image
    img = Image.open(src).convert("RGBA").resize((1024, 1024), Image.LANCZOS)
    bg = Image.new("RGB", img.size, (255, 246, 240))
    bg.paste(img, mask=img.split()[3])
    bg.save(dst)

def main():
    os.makedirs(CAT, exist_ok=True)
    write_json(os.path.join(CAT, "Contents.json"), {"info": INFO})

    # Colours used by Info.plist / Xcode
    for name, rgb in (("AccentColor", (0xC9, 0x45, 0x2A)), ("LaunchBackground", (0xFF, 0xF6, 0xF0))):
        d = os.path.join(CAT, name + ".colorset")
        os.makedirs(d, exist_ok=True)
        write_json(os.path.join(d, "Contents.json"), {
            "colors": [{"idiom": "universal", "color": {"color-space": "srgb", "components": {
                "red": "0x%02X" % rgb[0], "green": "0x%02X" % rgb[1], "blue": "0x%02X" % rgb[2], "alpha": "1.000"}}}],
            "info": INFO})

    icon_dir = os.path.join(CAT, "AppIcon.appiconset")
    os.makedirs(icon_dir, exist_ok=True)
    icon_dst = os.path.join(icon_dir, "AppIcon.png")
    icon_src = os.path.join(SRC, "AppIcon.png")
    if os.path.exists(icon_src):
        make_icon(icon_src, icon_dst)
        print("AppIcon imported")
    write_json(os.path.join(icon_dir, "Contents.json"), {
        "images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
        "info": INFO})

    count = 0
    for fn in sorted(os.listdir(SRC)) if os.path.isdir(SRC) else []:
        if not fn.lower().endswith(".png") or fn == "AppIcon.png":
            continue
        name = os.path.splitext(fn)[0]
        d = os.path.join(CAT, name + ".imageset")
        os.makedirs(d, exist_ok=True)
        shutil.copyfile(os.path.join(SRC, fn), os.path.join(d, fn))
        write_json(os.path.join(d, "Contents.json"), {
            "images": [{"filename": fn, "idiom": "universal"}],
            "info": INFO, "properties": {"preserves-vector-representation": False}})
        count += 1
    print(f"Imported {count} image(s).")

if __name__ == "__main__":
    sys.exit(main())
