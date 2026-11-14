"""Build a narrow RollClub update using a checksum-pinned published runtime.

The server/runtime are not fully tracked in this repository. Reuse their exact
published bytes instead of taking a developer's installed server or packages.
Require the baseline AHK/reader to match the specified source revision first.
No release is published by this script.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import zipfile


ROOT = Path(__file__).resolve().parents[1]
READ_CALL = "_rollclub_kc.read_kc_list(_bridge, brand=brand)"
BACKGROUND_CALL = ('(_rollclub_kc.read_kc_list_background(_bridge, int(request.args["background_hwnd"])) '
                   'if "background_hwnd" in request.args else ' + READ_CALL + ')')
SOURCE_FILES = {
    "RollHelper/lib/RollClubKitchenStatus.ahk": "lib/RollClubKitchenStatus.ahk",
    "server/sync_rollclub_kitchens.py": "brands/rollclub/server/sync_rollclub_kitchens.py",
    "RollHelper/engine_rollclub.ahk": "engine_rollclub.ahk",
    "RollHelper/lib/RollClubDutyBackground.ahk": "lib/RollClubDutyBackground.ahk",
    "server/rollclub_kc_legacy.py": "brands/rollclub/server/rollclub_kc_legacy.py",
}


def normalized(data):
    return data.decode("utf-8-sig").replace("\r\n", "\n")


def build(args):
    for version in (args.version, args.catalog_version):
        if not re.fullmatch(r"\d+\.\d+\.\d+", version):
            raise ValueError("Expected a numeric three-part version")
    base = json.loads(args.base_manifest.read_text(encoding="utf-8-sig"))
    source = next(p for p in base["packages"] if p["id"] == "rollclub")
    if hashlib.sha256(args.base_archive.read_bytes()).hexdigest() != source["sha256"]:
        raise ValueError("Published RollClub archive SHA-256 mismatch")
    if tuple(map(int, args.version.split("."))) <= tuple(map(int, source["version"].split("."))):
        raise ValueError("RollClub version must increase")
    args.output.mkdir(parents=True, exist_ok=True)
    archive_path = args.output / f"brand-rollclub-{args.version}.zip"
    if archive_path.resolve() == args.base_archive.resolve():
        raise ValueError("Cannot overwrite the baseline archive")

    with zipfile.ZipFile(args.base_archive) as old:
        names = old.namelist()
        if len(set(names)) != len(names):
            raise ValueError("Duplicate archive paths")
        for name in names:
            parts = PurePosixPath(name).parts
            if ".." in parts or name.startswith("/") or "\\" in name or ":" in name:
                raise ValueError("Unsafe archive path")
        for packaged, tracked in SOURCE_FILES.items():
            if packaged not in names:  # new include
                continue
            committed = subprocess.check_output(["git", "-C", str(ROOT), "show", f"{args.base_source_ref}:{tracked}"])
            if normalized(old.read(packaged)) != normalized(committed):
                raise ValueError(f"Published {packaged} differs from baseline source")

        replacements = {packaged: (ROOT / tracked).read_bytes() for packaged, tracked in SOURCE_FILES.items()}
        for name in list(replacements):
            if name in names and normalized(replacements[name]) == normalized(old.read(name)):
                replacements[name] = old.read(name)
        for name, data in replacements.items():
            if name.endswith(".ahk") and not data.startswith(b"\xef\xbb\xbf"):
                raise ValueError(f"AHK UTF-8 BOM missing: {name}")
        app = normalized(old.read("server/app.py"))
        if "_rollclub_kc.read_kc_list_background(" in app:
            replacements["server/app.py"] = old.read("server/app.py")
        else:
            if app.count(READ_CALL) != 1:
                raise ValueError("Expected exactly one legacy duty route to extend")
            replacements["server/app.py"] = app.replace(READ_CALL, BACKGROUND_CALL).encode("utf-8")
        compile(replacements["server/app.py"], "app.py", "exec")
        compile(replacements["server/rollclub_kc_legacy.py"], "rollclub_kc_legacy.py", "exec")
        compile(replacements["server/sync_rollclub_kitchens.py"], "sync_rollclub_kitchens.py", "exec")
        package = json.loads(old.read("package.json"))
        if package["id"] != "rollclub" or package["version"] != source["version"]:
            raise ValueError("Baseline package identity mismatch")
        package["version"] = args.version
        replacements["package.json"] = json.dumps(package, ensure_ascii=False, indent=2).encode("utf-8")
        with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED) as new:
            for info in old.infolist():
                new.writestr(copy.copy(info), replacements.get(info.filename, old.read(info.filename)))
            for name in replacements.keys() - set(names):
                new.writestr(name, replacements[name])
        with zipfile.ZipFile(archive_path) as new:
            if new.testzip() is not None:
                raise ValueError("ZIP CRC check failed")
            if set(new.namelist()) != set(names) | set(replacements):
                raise ValueError("Unexpected package contents")
            for name in names:
                if name not in replacements and new.read(name) != old.read(name):
                    raise ValueError(f"Protected package file changed: {name}")

    manifest = copy.deepcopy(base)
    manifest["release"] = args.catalog_version
    target = next(p for p in manifest["packages"] if p["id"] == "rollclub")
    target["version"] = args.version
    target["url"] = f"https://github.com/{args.repository}/releases/download/v{args.catalog_version}/{archive_path.name}"
    target["sha256"] = hashlib.sha256(archive_path.read_bytes()).hexdigest()
    target.pop("asset", None)
    if manifest["launcher"] != base["launcher"]:
        raise ValueError("Protected launcher metadata changed")
    if [p for p in manifest["packages"] if p["id"] != "rollclub"] != [p for p in base["packages"] if p["id"] != "rollclub"]:
        raise ValueError("Protected package metadata changed")
    manifest_path = args.output / "release-manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"archive": str(archive_path), "sha256": target["sha256"], "manifest": str(manifest_path)}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-manifest", type=Path, required=True)
    parser.add_argument("--base-archive", type=Path, required=True)
    parser.add_argument("--base-source-ref", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--catalog-version", required=True)
    parser.add_argument("--repository", default="voffkazxc/RollHelper")
    parser.add_argument("--output", type=Path, required=True)
    build(parser.parse_args())
