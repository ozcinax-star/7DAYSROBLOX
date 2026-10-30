# Dev-only: prepares the Studio MCP fallback sync (used when Rojo is not connected).
# Writes into OUT_DIR:
#   bundle.json   every .luau script of the Rojo tree with its Studio path and class
#   tests.luau    copy of tests/run.luau
#   Harness.luau  copy of tools/studio/Harness.luau (sync + test runner, loaded over HTTP)
# Usage:
#   python tools/studio/bundle.py <repo root> <out dir>
#   cd <out dir> && python -m http.server 8765 --bind 127.0.0.1
# Then see docs/HANDOFF.md ("Studio MCP ile senkron ve test").
import json, os, shutil, sys

root, out_dir = sys.argv[1], sys.argv[2]
os.makedirs(out_dir, exist_ok=True)
mounts = [
    ("src/shared", "ReplicatedStorage/Shared"),
    ("src/server", "ServerScriptService/Server"),
    ("src/client", "StarterPlayer/StarterPlayerScripts/Client"),
]
items = []
for src, dest in mounts:
    for dirpath, _, files in os.walk(os.path.join(root, src)):
        rel = os.path.relpath(dirpath, os.path.join(root, src)).replace("\\", "/")
        for f in sorted(files):
            if not f.endswith(".luau"):
                continue
            text = open(os.path.join(dirpath, f), encoding="utf-8").read()
            name = f[:-5]
            cls = "ModuleScript"
            if name.endswith(".server"):
                cls, name = "Script", name[:-7]
            elif name.endswith(".client"):
                cls, name = "LocalScript", name[:-7]
            parts = [] if rel == "." else rel.split("/")
            if name == "init":
                path = "/".join([dest] + parts)  # the folder itself becomes the script
            else:
                path = "/".join([dest] + parts + [name])
            items.append({"path": path, "class": cls, "source": text})
json.dump(items, open(os.path.join(out_dir, "bundle.json"), "w", encoding="utf-8"))
shutil.copyfile(os.path.join(root, "tests", "run.luau"), os.path.join(out_dir, "tests.luau"))
shutil.copyfile(os.path.join(root, "tools", "studio", "Harness.luau"), os.path.join(out_dir, "Harness.luau"))
print(len(items), "scripts ->", out_dir)
