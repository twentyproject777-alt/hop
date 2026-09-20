import importlib.util
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("build_auto_scalp", ROOT / "scripts/build_auto_scalp.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class AutoScalpDistributionTests(unittest.TestCase):
    def test_single_file_and_core_consistency(self):
        source = builder.MAIN.read_text()
        self.assertEqual(source, builder.render())
        self.assertEqual(re.findall(r"#include\s+<([^>]+)>", source), ["Trade\\Trade.mqh"])
        self.assertEqual(source.count("GASResult GASProcess("), 1)
        self.assertIn("GASProcess(bars,q,budget", source)
        self.assertIn("OrderCheck(request,check)", source)
        self.assertIn("OrderSend(request,result)", source)
        self.assertLess(source.index("double GoldVolume("), source.index("GASResult GASProcess("))
        self.assertIn("SYMBOL_TRADE_EXECUTION_MARKET) request.price=0", source)
        self.assertIn('if(!RequestSettled())', source)
        self.assertLess(source.index('Write("awaitRequest",1)'), source.index("OrderSend(request,result)"))

    def test_no_preset_or_old_strategy_dependency(self):
        source = builder.MAIN.read_text()
        self.assertIn("GoldAutoScalp v2.00 READY", source)
        self.assertNotIn("BuyLimit(", source)
        self.assertNotIn("SellLimit(", source)
        self.assertNotIn("InpSignalProfile", source)
        self.assertNotIn("InpSessionStartHour", source)
        self.assertNotIn("PERIOD_H1", source)
        self.assertIn("InpAllowRealTrading=false", source)
        self.assertIn("InpRiskPercent=2.0", source)
        self.assertIn("InpRewardRisk=2.0", source)


if __name__ == "__main__":
    unittest.main()
