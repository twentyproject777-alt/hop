import importlib.util
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("build_standalone", ROOT / "scripts/build_standalone.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class DistributionTests(unittest.TestCase):
    def test_standalone_matches_tested_sources(self):
        output = builder.OUTPUT.read_text()
        self.assertEqual(output, builder.render())
        self.assertNotIn("#include <GoldRiskMath.mqh>", output)
        self.assertIn("#include <Trade\\Trade.mqh>", output)
        self.assertEqual(output.count("double GoldFixedVolume("), 1)

    def test_primary_expert_has_no_custom_include_dependency(self):
        source = builder.MAIN.read_text()
        self.assertEqual(source, builder.render_main())
        self.assertNotIn("#include <GoldRiskMath.mqh>", source)
        self.assertEqual(source.count("double GoldFixedVolume("), 1)
        self.assertEqual(source.count("bool GoldTargetHasRoom("), 1)
        self.assertIn('#property version   "1.30"', source)
        self.assertIn("GoldTrendSweep v1.30 initialized", source)
        self.assertEqual(source.count("bool GoldBreakConfirmed("), 1)
        self.assertNotIn("#include <GoldSignalMath.mqh>", source)

    def test_presets_match_declared_inputs_and_limits(self):
        source = (ROOT / "mt5/Experts/GoldTrendSweep.mq5").read_text()
        defaults = dict(re.findall(r"^input\s+\w+\s+(Inp\w+)\s*=([^;]+);", source, re.M))
        files = sorted((ROOT / "mt5/Presets").glob("*.set"))
        self.assertEqual(len(files), 5)
        for path in files:
            with self.subTest(preset=path.name):
                values = dict(defaults)
                for line in path.read_text().splitlines():
                    if not line or line.startswith(";"):
                        continue
                    key, value = line.split("=", 1)
                    self.assertIn(key, defaults)
                    values[key] = value
                risk = float(values["InpRiskPercent"])
                daily = float(values["InpDailyLossPercent"])
                weekly = float(values["InpWeeklyLossPercent"])
                self.assertTrue(0 < risk <= 2)
                self.assertTrue(risk <= daily <= 3)
                self.assertTrue(daily < weekly <= 6)
                self.assertTrue(0 < float(values["InpReduceRiskDrawdown"]) < float(values["InpPauseDrawdown"]) < float(values["InpHardDrawdown"]) <= 20)
                self.assertLessEqual(float(values["InpFixedLots"]), float(values["InpMaxLots"]))
                self.assertEqual(values["InpAllowRealTrading"], "false")
                self.assertEqual(values["InpNewsMode"], "0")
                self.assertEqual(values["InpTesterSkipCalendar"], "true")
                self.assertEqual(values["InpDiagnostics"], "true")
                self.assertEqual(values["InpSignalProfile"], "1" if "v130" in path.name else "0")
                self.assertTrue(2 <= int(values["InpM15EMAPeriod"]) <= 200)
                self.assertTrue(0 < float(values["InpBalancedZoneATR"]) <= 3)
                self.assertTrue(0 < float(values["InpBalancedMinBodyATR"]) < float(values["InpMaxRangeATR"]))
                if "Fixed005" in path.name:
                    self.assertEqual(values["InpLotMode"], "1")
                    self.assertEqual(float(values["InpFixedLots"]), .05)
                elif "Fixed010" in path.name:
                    self.assertEqual(values["InpLotMode"], "1")
                    self.assertEqual(float(values["InpFixedLots"]), .10)
                else:
                    self.assertEqual(values["InpLotMode"], "0")


if __name__ == "__main__":
    unittest.main()
