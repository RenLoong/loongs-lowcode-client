#!/usr/bin/env python3
from __future__ import annotations
import base64, json, pathlib, struct, sys

def write_size(buf, value):
    if value < 254:
        buf.append(value)
    elif value <= 0xFFFF:
        buf.append(254)
        buf.extend(struct.pack("<H", value))
    else:
        buf.append(255)
        buf.extend(struct.pack("<I", value))

def write_value(buf, value):
    if isinstance(value, str):
        data = value.encode("utf-8")
        buf.append(0x07)
        write_size(buf, len(data))
        buf.extend(data)
    elif isinstance(value, list):
        buf.append(0x0C)
        write_size(buf, len(value))
        for it in value:
            write_value(buf, it)
    elif isinstance(value, dict):
        buf.append(0x0D)
        write_size(buf, len(value))
        for k, v in value.items():
            write_value(buf, k)
            write_value(buf, v)
    else:
        raise TypeError(type(value))

def read_size(data, i):
    n = data[i]
    i += 1
    if n < 254:
        return n, i
    if n == 254:
        return struct.unpack_from("<H", data, i)[0], i + 2
    return struct.unpack_from("<I", data, i)[0], i + 4

def decode(data, i=0):
    t = data[i]
    i += 1
    if t == 0x07:
        n, i = read_size(data, i)
        return data[i:i + n].decode("utf-8"), i + n
    if t == 0x0C:
        n, i = read_size(data, i)
        out = []
        for _ in range(n):
            v, i = decode(data, i)
            out.append(v)
        return out, i
    if t == 0x0D:
        n, i = read_size(data, i)
        out = {}
        for _ in range(n):
            k, i = decode(data, i)
            v, i = decode(data, i)
            out[k] = v
        return out, i
    raise ValueError(hex(t))

GEIST_FIX = {
    "packages/shadcn_ui/fonts/Geist[wght].ttf": "packages/shadcn_ui/fonts/Geist-wght-font.ttf",
    "packages/shadcn_ui/fonts/GeistMono[wght].ttf": "packages/shadcn_ui/fonts/GeistMono-wght-font.ttf",
}

def slim(web: pathlib.Path) -> None:
    assets = web / "assets"
    build_font = assets / "packages/lucide_icons_flutter/assets/build_font"
    if build_font.exists():
        for f in build_font.glob("LucideVariable-*.ttf"):
            f.unlink()
        try:
            build_font.rmdir()
        except OSError:
            pass
    fm_path = assets / "FontManifest.json"
    fm = json.loads(fm_path.read_text(encoding="utf-8"))
    fm = [
        e for e in fm
        if not (
            e.get("family", "").startswith("packages/lucide_icons_flutter/Lucide")
            and e.get("family") != "packages/lucide_icons_flutter/Lucide"
        )
    ]
    fm_path.write_text(json.dumps(fm, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    bin_json = assets / "AssetManifest.bin.json"
    mapping, _ = decode(base64.b64decode(json.loads(bin_json.read_text(encoding="utf-8"))), 0)
    mapping = {k: v for k, v in mapping.items() if "LucideVariable" not in k}
    fixed = {}
    for k, v in mapping.items():
        nk = GEIST_FIX.get(k, k)
        nv = []
        for item in v:
            if isinstance(item, dict) and "asset" in item:
                item = dict(item)
                item["asset"] = GEIST_FIX.get(item["asset"], item["asset"])
            nv.append(item)
        fixed[nk] = nv
    buf = bytearray()
    write_value(buf, fixed)
    encoded = bytes(buf)
    (assets / "AssetManifest.bin").write_bytes(encoded)
    bin_json.write_text(json.dumps(base64.b64encode(encoded).decode("ascii")), encoding="utf-8")
    print(f"slimmed {web}: fonts={len(fm)} assets={len(fixed)}")

if __name__ == "__main__":
    targets = [pathlib.Path(p) for p in sys.argv[1:]] or [
        pathlib.Path("/www/wwwroot/loongs-swoole/lowcode/server/apps/Showcase/public/web"),
    ]
    for t in targets:
        slim(t)