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
        self.assertIn("GoldAutoScalp v2.10 READY", source)
        self.assertNotIn("BuyLimit(", source)
        self.assertNotIn("SellLimit(", source)
        self.assertNotIn("InpSignalProfile", source)
        self.assertNotIn("InpSessionStartHour", source)
        self.assertNotIn("PERIOD_H1", source)
        self.assertIn("InpAllowRealTrading=false", source)
        self.assertIn("InpRiskPercent=2.0", source)
        self.assertIn("InpRewardRisk=2.0", source)
        self.assertIn("InpMaxEntriesPerDay=12", source)
        self.assertIn("GASDailyEntryAllowed(entries,InpMaxEntriesPerDay)", source)

    def test_closed_bar_trend_and_breakout_inputs(self):
        source = builder.MAIN.read_text()
        loader = source.split("bool LoadBars(GASBars &b)", 1)[1].split("class MT5Execution", 1)[0]
        self.assertIn("Value(fast15,4,b.trend_previous_fast)", loader)
        self.assertIn("Value(fast5,1,b.fast_ema)", loader)
        self.assertIn("MathMax(rates[2].high,MathMax(rates[3].high,rates[4].high))", loader)
        self.assertIn("MathMin(rates[2].low,MathMin(rates[3].low,rates[4].low))", loader)
        self.assertNotRegex(loader, r"rates\[0\]\.\w+")
        self.assertNotRegex(loader, r"Value\(\w+,0,")
        self.assertIn("GAS2 BLOCKS:", source)
        self.assertIn("GAS2 SIGNALS:", source)
        self.assertIn("GAS2 TESTER:", source)

    def test_existing_risk_locks_are_not_reset_to_force_frequency(self):
        source = builder.MAIN.read_text()
        self.assertIn("const ulong MAGIC=26092002", source)
        self.assertIn('prefix="GAS2."', source)
        self.assertIn('if(dd>=8) Write("pause",1)', source)
        self.assertIn('if(dd>=10) Write("hard",1)', source)
        self.assertIn('Read("dayEq")*.97,Read("weekEq")*.94,Read("peak")*.90', source)
        self.assertIn("if(MQLInfoInteger(MQL_TESTER)) GlobalVariablesDeleteAll(prefix)", source)
        self.assertIn('if(Read("pause")>0)', source)


if __name__ == "__main__":
    unittest.main()
