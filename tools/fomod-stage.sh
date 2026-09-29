#!/usr/bin/env bash
# Stage the Devious Devices NG payload the FOMOD zip is assembled from.
#
# Inputs (same layout the modforge pipeline downloads into):
#   artifacts/DDNG-DLL/       DeviousDevices.dll, DeviousDevices.pdb  (build-skse)
#   artifacts/DDNG-PEX/       *.pex                                  (build-papyrus)
#   this repo's tracked mod files: the master/patch records at the root and
#   the dist/ overlay (Seq/, SKSE/, scripts/source/)
#
# Output: stage/<mod root>, mirroring the layout of the existing
# DDNG-<version>-<sha>.zip archive exactly (see .github/workflows/build.yml's
# "Stage complete mod" step).
#
# The closing assertion refuses to continue when the staged tree carries a file
# the committed fomod-package.toml does not claim: a file added to dist/ or a
# new build output then turns this run red instead of silently missing from the
# zip (and package_fomod.py fails the other way round, on a claimed file that
# staging did not produce).
set -euo pipefail
cd "$(dirname "$0")/.."

DLL_DIR="artifacts/DDNG-DLL"
PEX_DIR="artifacts/DDNG-PEX"
for d in "$DLL_DIR" "$PEX_DIR"; do
  [ -d "$d" ] || { echo "::error::missing $d/ - fomod-release.yml downloads the 'Build and Release' artifacts there"; exit 1; }
done
[ -f "$DLL_DIR/DeviousDevices.dll" ] || { echo "::error::$DLL_DIR/DeviousDevices.dll missing"; exit 1; }
[ -f "$DLL_DIR/DeviousDevices.pdb" ] || { echo "::error::$DLL_DIR/DeviousDevices.pdb missing"; exit 1; }
[ "$(find "$PEX_DIR" -name '*.pex' | wc -l)" -gt 0 ] || { echo "::error::no .pex in $PEX_DIR/"; exit 1; }

rm -rf stage
mkdir -p stage/SKSE/Plugins stage/scripts

# Root records (the archive root carries them so the mod installs standalone).
cp -a "Devious Devices - Assets.esm" \
      "Devious Devices - Contraptions.esm" \
      "Devious Devices - Expansion.esm" \
      "Devious Devices - Integration.esm" \
      "Devious Devices SE patch.esp" \
      "Devious Devices_KID.ini" \
      stage/

# Tracked overlay (Seq/, SKSE/PartialAnimationReplacer/, scripts/source/...).
cp -a dist/. stage/

# Build outputs.
cp -a "$DLL_DIR"/. stage/SKSE/Plugins/
cp -a "$PEX_DIR"/. stage/scripts/

echo "staged $(find stage -type f | wc -l) files"

python3 - <<'EOF'
import sys
import tomllib
from pathlib import Path

spec = tomllib.loads(Path("fomod-package.toml").read_text())
claimed = {i["src"] for i in spec["files"] if i["src"].startswith("stage/")}
staged = {p.as_posix() for p in Path("stage").rglob("*") if p.is_file()}
unclaimed = sorted(staged - claimed)
if unclaimed:
    print("::error::staged payload files not claimed by fomod-package.toml "
          "(they would silently miss from the zip):")
    for f in unclaimed:
        print(f"  {f}")
    sys.exit(1)
print(f"fomod-package.toml claims all {len(staged)} staged payload files")
EOF
