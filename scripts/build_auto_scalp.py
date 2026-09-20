"""Embed the tested no-preset EA core; no custom includes are needed in MT5."""
from pathlib import Path
import argparse
import re

ROOT = Path(__file__).resolve().parents[1]
MAIN = ROOT / "mt5/Experts/GoldAutoScalp.mq5"


def render():
    source = MAIN.read_text()
    content = "\n".join((ROOT / "mt5/Include" / name).read_text().rstrip()
                        for name in ("GoldRiskMath.mqh", "GoldAutoScalpCore.mqh"))
    block = "// BEGIN GENERATED GAS CORE: edit Include modules, then run scripts/build_auto_scalp.py\n" + content + "\n// END GENERATED GAS CORE"
    marker = "#include <GoldAutoScalpCore.mqh>"
    if source.count(marker) == 1:
        return source.replace(marker, block)
    pattern = r"// BEGIN GENERATED GAS CORE[^\n]*\n.*?// END GENERATED GAS CORE"
    if len(re.findall(pattern, source, re.S)) != 1:
        raise ValueError("Expected exactly one embedded GAS core")
    return re.sub(pattern, lambda _: block, source, flags=re.S)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    content = render()
    if args.check:
        if MAIN.read_text() != content:
            raise SystemExit("GoldAutoScalp embedded core is out of date")
        print("GoldAutoScalp embedded core matches tested sources.")
    else:
        MAIN.write_text(content)
        print("Built no-preset GoldAutoScalp.mq5")
