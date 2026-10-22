"""Import the supplied Pokemon Companion PMD walking artwork losslessly.

Requires Pillow and lupa (LuaJIT 2.1). No ROM or Pokemon Companion runtime code
is copied. The source ZIP is read in place; original atlases stay untouched.

    python tools/import_companion_sprites.py --archive PokemonCompanion-FireRed-v0.1.2.zip

Only cardinal walking animation group 0 is needed by WildFollowers. Sequence
lengths, 60 Hz durations, pose offsets, palettes, and the original ground pivot
are preserved; transparent padding is normalized without resampling artwork.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import zipfile

from PIL import Image
from lupa.luajit21 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
DIRECTIONS = (("down", 1), ("left", 7), ("right", 3), ("up", 5))
EXCLUDED = {"decoy", "statue", "rayquaza_cutscene"}
ROM_MD5 = "2100cf6f17e12cd34f1513647dfa506b"


def sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def lua_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=ROOT)
    args = parser.parse_args()
    root = args.output.resolve()
    archive = args.archive.resolve()
    lua = LuaRuntime(unpack_returned_tuples=True)
    # Metadata is data: it receives no IO, OS, require, or other ambient globals.
    read_table = lua.eval("function(source) local f=assert(loadstring(source)); setfenv(f,{}); return f() end")
    with zipfile.ZipFile(archive) as source:
        for member in source.namelist():
            path = PurePosixPath(member.replace("\\", "/"))
            assert not path.is_absolute() and ".." not in path.parts and ":" not in str(path), member
        prefix = "PokemonCompanion/"
        manifest_raw = source.read(prefix + "manifest.json")
        manifest = json.loads(manifest_raw)
        assert manifest["id"] == "pokemon_companion" and manifest["version"] == "0.1.2"
        catalog_raw = source.read(prefix + "assets/catalog.lua")
        catalog = read_table(catalog_raw.decode("utf-8"))
        entries = {str(key): value for key, value in catalog.entries.items()}
        assert len(entries) == 423 and EXCLUDED <= entries.keys()
        national = {int(dex): str(stem) for dex, stem in catalog.byDex.items()}
        assert set(national) == set(range(1, 387))
        # Red Rescue Team predates Munchlax's published National Dex number.
        national[446] = "munchlax"
        forms = {"UNOWN_" + chr(65 + index): "unown_" + chr(97 + index) for index in range(26)}
        forms.update({
            "UNOWN_EMARK": "unown_emark", "UNOWN_EXCLAMATION": "unown_emark",
            "UNOWN_EXCLAMATION_MARK": "unown_emark", "UNOWN_EXCLAMATION_POINT": "unown_emark",
            "UNOWN_QMARK": "unown_qmark", "UNOWN_QUESTION": "unown_qmark",
            "UNOWN_QUESTION_MARK": "unown_qmark",
            "DEOXYS_NORMAL": "deoxys_normal", "DEOXYS_ATTACK": "deoxys_attack",
            "DEOXYS_DEFENSE": "deoxys_defense", "DEOXYS_SPEED": "deoxys_speed",
            "CASTFORM_NORMAL": "castform", "CASTFORM_SUNNY": "castform_sunny",
            "CASTFORM_RAINY": "castform_rainy", "CASTFORM_SNOWY": "castform_snowy",
        })
        assert all(stem in entries and stem not in EXCLUDED for stem in forms.values())
        destination = root / "assets/companion"
        destination.mkdir(parents=True, exist_ok=True)
        files = []
        sheets = {}
        total_frames = 0
        verified_pixels = 0
        for stem, entry in sorted(entries.items()):
            if stem in EXCLUDED:
                continue
            png_name = prefix + f"assets/{stem}.png"
            meta_name = prefix + f"assets/{stem}.lua"
            png_raw, meta_raw = source.read(png_name), source.read(meta_name)
            original = Image.open(io.BytesIO(png_raw)).convert("RGBA")
            metadata = read_table(meta_raw.decode("utf-8"))
            fw, fh, columns = int(metadata.frameWidth), int(metadata.frameHeight), int(metadata.frameColumns)
            source_ax, source_ay = int(metadata.anchorX), int(metadata.anchorY)
            poses = int(entry.frames)
            assert original.size == (fw * columns, ((poses + columns - 1) // columns) * fh), stem
            groups = metadata.animations[1]
            sequences = {}
            all_frames = []
            for direction, source_index in DIRECTIONS:
                sequence = metadata.sequences[groups[source_index]]
                frames = []
                for index in range(1, len(sequence) + 1):
                    item = sequence[index]
                    pose, ticks, dx, dy = (int(item[i]) for i in range(1, 5))
                    assert 1 <= pose <= poses and ticks > 0, (stem, direction, index)
                    pose -= 1
                    tile = original.crop(((pose % columns) * fw, (pose // columns) * fh,
                                          (pose % columns + 1) * fw, (pose // columns + 1) * fh))
                    bounds = tile.getchannel("A").getbbox()
                    assert bounds, (stem, direction, index)
                    relative = (bounds[0] - source_ax + dx, bounds[1] - source_ay + dy,
                                bounds[2] - source_ax + dx, bounds[3] - source_ay + dy)
                    frame = {"tile": tile, "bounds": bounds, "relative": relative,
                             "source_pose": pose + 1, "ticks": ticks, "dx": dx, "dy": dy}
                    frames.append(frame)
                    all_frames.append(frame)
                assert frames, (stem, direction)
                sequences[direction] = frames
            left = min(frame["relative"][0] for frame in all_frames)
            top = min(frame["relative"][1] for frame in all_frames)
            right = max(frame["relative"][2] for frame in all_frames)
            bottom = max(frame["relative"][3] for frame in all_frames)
            ax = max(-left, right, 1)
            ay = max(-top, 0)
            width, height = ax * 2, ay + max(bottom, 0)
            count = max(map(len, sequences.values()))
            # All source cardinal sequences currently have equal lengths. The
            # schema still carries independent duration arrays for each row.
            sheet = Image.new("RGBA", (width * count, height * 4))
            per_direction = {}
            source_frames = {}
            for row, (direction, _) in enumerate(DIRECTIONS):
                per_direction[direction] = []
                source_frames[direction] = []
                for index, frame in enumerate(sequences[direction]):
                    crop = frame["tile"].crop(frame["bounds"])
                    rx, ry = frame["relative"][:2]
                    xy = (index * width + ax + rx, row * height + ay + ry)
                    sheet.paste(crop, xy)
                    per_direction[direction].append(frame["ticks"])
                    source_frames[direction].append([frame["source_pose"], frame["ticks"], frame["dx"], frame["dy"]])
                    # Prove pixel and relative ground-anchor equivalence for
                    # every imported pose, including original walking bobs.
                    expected = Image.new("RGBA", (width, height))
                    expected.paste(crop, (ax + rx, ay + ry))
                    actual = sheet.crop((index * width, row * height, (index + 1) * width, (row + 1) * height))
                    assert actual.tobytes() == expected.tobytes(), (stem, direction, index)
                    assert (ax + rx) - ax == frame["bounds"][0] - source_ax + frame["dx"]
                    assert (ay + ry) - ay == frame["bounds"][1] - source_ay + frame["dy"]
                    verified_pixels += sum(crop.getchannel("A").histogram()[1:])
            asset_path = f"assets/companion/{stem}.png"
            target = root / asset_path
            sheet.save(target, optimize=True)
            reloaded = Image.open(target).convert("RGBA")
            assert sheet.tobytes() == reloaded.tobytes(), stem
            total_frames += len(all_frames)
            sheets[asset_path] = {"columns": count, "frameWidth": width, "frameHeight": height,
                                   "anchorX": ax, "anchorY": ay, "duration_ticks": per_direction}
            files.append({
                "id": stem, "path": asset_path, "sha256": sha256(target.read_bytes()),
                "national": 446 if stem == "munchlax" else int(entry.dexNumber),
                "source_monster_id": int(entry.monsterId),
                "source_png": png_name, "source_png_sha256": sha256(png_raw),
                "source_metadata": meta_name, "source_metadata_sha256": sha256(meta_raw),
                "source_frame_width": fw, "source_frame_height": fh,
                "source_anchor_x": source_ax, "source_anchor_y": source_ay,
                "columns": count, "frameWidth": width, "frameHeight": height,
                "anchorX": ax, "anchorY": ay, "directional_frames": source_frames,
            })
        assert len(files) == 420
        path_of = lambda stem: f"assets/companion/{stem}.png"
        lines = ["-- Generated by tools/import_companion_sprites.py. Original PMD art and 60 Hz timing.",
                 "-- Rows: down, left, right, up. Native pixels; ground anchors include original pose offsets.",
                 "return function() return {", " national={"]
        lines += [f"  [{dex}]={lua_string(path_of(stem))}," for dex, stem in sorted(national.items())]
        lines += [" },", " forms={"]
        lines += [f"  [{lua_string(key)}]={lua_string(path_of(stem))}," for key, stem in sorted(forms.items())]
        lines += [" },", " sheets={"]
        for path, sheet in sorted(sheets.items()):
            duration_code = ",".join(direction + "={" + ",".join(f"{tick}/60" for tick in sheet["duration_ticks"][direction]) + "}"
                                     for direction, _ in DIRECTIONS)
            fields = ",".join(key + "=" + str(sheet[key]) for key in ("columns", "frameWidth", "frameHeight", "anchorX", "anchorY"))
            lines.append(f"  [{lua_string(path)}]={{{fields},durations={{{duration_code}}}}},")
        lines += [" }", "} end", ""]
        (root / "src/companion_data.lua").write_text("\n".join(lines), encoding="utf-8")
        audit = {
            "schema": 1, "source_archive": archive.name, "source_archive_sha256": sha256(archive.read_bytes()),
            "source_mod": {"id": "pokemon_companion", "version": "0.1.2", "author": "TheOriginalDrJ"},
            "source_game": "Pokemon Mystery Dungeon: Red Rescue Team (USA/Australia)",
            "source_rom_md5_from_archive": ROM_MD5,
            "source_catalog_sha256": sha256(catalog_raw),
            "source_manifest_sha256": sha256(manifest_raw),
            "source_extraction_metadata_sha256": sha256(source.read(prefix + "assets/extraction.json")),
            "source_readme_sha256": sha256(source.read(prefix + "README.md")),
            "source_license": "No explicit LICENSE or redistribution grant was present in the supplied archive.",
            "conversion": "Cardinal animation group 0 only; original frame pixels, palettes, offsets and 60 Hz timing retained. Transparent canvas normalized around original ground anchor; no resampling or recoloring.",
            "excluded_special_actors": sorted(EXCLUDED),
            "coverage": {"national_species": len(national), "sheets": len(files), "additional_real_forms": 33,
                         "walking_frames": total_frames, "direction_sequences": len(files) * 4,
                         "min_frames_per_direction": min(row["columns"] for row in files),
                         "max_frames_per_direction": max(row["columns"] for row in files),
                         "verified_visible_pixel_instances": verified_pixels},
            "palette_policy": "Only original normal PMD palettes are supplied; shiny and gender variants use that artwork without invented recolors.",
            "files": files,
        }
        (root / "COMPANION-OVERWORLD-AUDIT.json").write_text(json.dumps(audit, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(audit["coverage"], indent=2))


if __name__ == "__main__":
    main()
