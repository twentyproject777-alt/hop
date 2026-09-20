#include <algorithm>
#include <cassert>
#include <cmath>
#include <iostream>
#include <limits>
#include <vector>

double MathMax(double a,double b) { return std::max(a,b); }
double MathMin(double a,double b) { return std::min(a,b); }
double MathAbs(double a) { return std::abs(a); }
double MathFloor(double a) { return std::floor(a); }
double MathCeil(double a) { return std::ceil(a); }
bool MathIsValidNumber(double a) { return std::isfinite(a); }
#include "../mt5/Include/GoldRiskMath.mqh"
#include "../mt5/Include/GoldAutoScalpCore.mqh"

bool near(double a,double b) { return std::abs(a-b)<1e-8; }
struct Sent { bool buy; double lots,entry,stop,target; };

class TestExecution : public GASExecution
{
public:
   bool allowed=true,reject=false;
   double margin_per_lot=2500;
   int attempts=0;
   std::vector<Sent> fills;
   bool Allowed(bool) override { return allowed; }
   double LossPerLot(bool,double entry,double stop) override { return (std::abs(entry-stop)+.60)*100+7; }
   double MarginPerLot(bool,double) override { return margin_per_lot; }
   bool SendMarket(bool buy,double lots,double entry,double stop,double target) override
   {
      attempts++;
      if(reject) return false;
      fills.push_back({buy,lots,entry,stop,target});
      return true;
   }
};

GASBars mirror(GASBars b)
{
   b.trend_close=5000-b.trend_close; b.trend_fast=5000-b.trend_fast; b.trend_slow=5000-b.trend_slow;
   b.trend_previous_fast=5000-b.trend_previous_fast;
   b.open=5000-b.open; b.close=5000-b.close; b.previous_close=5000-b.previous_close;
   double high=b.high; b.high=5000-b.low; b.low=5000-high;
   high=b.previous_high; b.previous_high=5000-b.previous_low; b.previous_low=5000-high;
   high=b.breakout_high; b.breakout_high=5000-b.breakout_low; b.breakout_low=5000-high;
   b.ema=5000-b.ema; b.previous_ema=5000-b.previous_ema;
   b.fast_ema=5000-b.fast_ema; b.previous_fast_ema=5000-b.previous_fast_ema;
   b.rsi=100-b.rsi; b.previous_rsi=100-b.previous_rsi;
   return b;
}

GASBars bars(bool buy)
{
   GASBars b={};
   b.trend_close=2501; b.trend_fast=2500; b.trend_slow=2498; b.trend_previous_fast=2499.5; b.trend_atr=4;
   b.open=2499.8; b.high=2501.3; b.low=2499.5; b.close=2501; b.previous_close=2499.9;
   b.ema=2500; b.previous_ema=2499.9; b.fast_ema=2500.2; b.previous_fast_ema=2500.1;
   b.rsi=55; b.previous_rsi=48; b.atr=2;
   b.previous_high=2500.4; b.previous_low=2499.4; b.breakout_high=2500.9; b.breakout_low=2499.1;
   return buy ? b : mirror(b);
}

GASBars continuation(bool buy,bool breakout)
{
   GASBars b=bars(true);
   b.ema=2499.5; b.previous_ema=2499.4; b.fast_ema=2500.2; b.previous_fast_ema=2500.1;
   b.open=2500.55; b.low=breakout ? 2500.5 : 2500.3;
   b.previous_close=2500.7; b.previous_high=2500.8; b.previous_low=2500.3;
   b.previous_rsi=53; b.breakout_high=breakout ? 2500.9 : 2501.2; b.breakout_low=2500.0;
   return buy ? b : mirror(b);
}

// Signal-only v2.00 reference (3595ec7); not a profitability/backtest comparator.
int legacy_direction(const GASBars &b)
{
   bool buy=b.trend_fast>b.trend_slow && b.trend_close>b.trend_slow;
   bool sell=b.trend_fast<b.trend_slow && b.trend_close<b.trend_slow;
   if(buy && (b.low<=b.ema || b.previous_close<=b.previous_ema || b.previous_rsi<=50) &&
      b.close>b.open && b.close>b.ema && b.rsi>50 && b.rsi>b.previous_rsi) return 1;
   if(sell && (b.high>=b.ema || b.previous_close>=b.previous_ema || b.previous_rsi>=50) &&
      b.close<b.open && b.close<b.ema && b.rsi<50 && b.rsi<b.previous_rsi) return -1;
   return 0;
}

GASQuote quote(bool buy)
{
   return {buy ? 2501.0 : 2498.8,buy ? 2501.2 : 2499.0,.01,.05,.01,100,.01,500};
}

GASResult run(GASBars b,GASQuote q,TestExecution &broker,GASPlan &p,double budget=10)
{
   return GASProcess(b,q,budget,.1,2,1,.25,.25,broker,p);
}

int main()
{
   GASPlan p;
   for(bool buy : {true,false})
   {
      TestExecution broker;
      assert(run(bars(buy),quote(buy),broker,p)==GAS_SENT);
      assert(broker.attempts==1 && broker.fills.size()==1);
      const Sent &fill=broker.fills.front();
      assert(fill.buy==buy && near(fill.lots,.01));
      assert(p.setup==GAS_SETUP_PULLBACK && !p.minimum_lot_bridge);
      assert(buy ? fill.stop<fill.entry && fill.target>fill.entry : fill.stop>fill.entry && fill.target<fill.entry);
      double risk=std::abs(fill.entry-fill.stop);
      assert(std::abs(fill.target-fill.entry)/risk>=2-1e-9);
      assert(fill.lots*broker.LossPerLot(buy,fill.entry,fill.stop)<=5);
      assert(p.estimated_margin<=125);
      double trigger=fill.entry+(buy ? risk : -risk);
      assert(GoldReachedOneR(buy,trigger,fill.entry,risk));
      assert(!GoldReachedOneR(buy,trigger+(buy ? -.01 : .01),fill.entry,risk));
      GASBars b=bars(buy);
      assert(buy ? fill.stop<std::min(b.low,b.previous_low) : fill.stop>std::max(b.high,b.previous_high)+quote(buy).ask-quote(buy).bid);
      for(bool breakout : {false,true})
      {
         TestExecution other;
         GASBars c=continuation(buy,breakout);
         assert(legacy_direction(c)==0);
         assert(run(c,quote(buy),other,p)==GAS_SENT);
         assert(p.setup==(breakout ? GAS_SETUP_BREAKOUT : GAS_SETUP_PULLBACK));
         assert(other.attempts==1 && other.fills.front().buy==buy);
      }
      TestExecution other;
      b=bars(buy); b.trend_previous_fast=b.trend_fast+(buy ? .1 : -.1);
      assert(legacy_direction(b)==(buy ? 1 : -1));
      assert(run(b,quote(buy),other,p)==GAS_NO_TREND);
      b=bars(buy); b.trend_close=b.trend_fast+(buy ? -.1 : .1);
      assert(run(b,quote(buy),other,p)==GAS_NO_TREND);
      b=bars(buy); b.trend_slow=b.trend_fast+(buy ? -.2 : .2);
      assert(run(b,quote(buy),other,p)==GAS_NO_TREND);
      b=bars(buy); b.fast_ema=b.ema+(buy ? -.1 : .1);
      assert(run(b,quote(buy),other,p)==GAS_NO_SIGNAL);
      b=bars(buy); b.rsi=buy ? 76 : 24;
      assert(run(b,quote(buy),other,p)==GAS_QUALITY);
      b=bars(buy); b.high+=6;
      assert(run(b,quote(buy),other,p)==GAS_QUALITY);
      b=bars(buy); b.close+=buy ? 2 : -2;
      b.high=std::max(b.high,b.close+.1); b.low=std::min(b.low,b.close-.1);
      assert(run(b,quote(buy),other,p)==GAS_QUALITY);
      GASQuote q=quote(buy); q.bid+=buy ? 1 : -1; q.ask+=buy ? 1 : -1;
      assert(run(bars(buy),q,other,p)==GAS_ENTRY_MOVED);
      assert(other.attempts==0);
   }
   {
      TestExecution broker; broker.reject=true;
      assert(run(bars(true),quote(true),broker,p)==GAS_REJECTED);
      assert(broker.attempts==1 && broker.fills.empty());
   }
   {
      TestExecution broker; broker.allowed=false;
      assert(run(bars(true),quote(true),broker,p)==GAS_NOT_ALLOWED);
      assert(broker.attempts==0);
   }
   {
      TestExecution broker; GASQuote q=quote(true); q.free_margin=120;
      assert(run(bars(true),q,broker,p,20)==GAS_SENT);
      assert(near(p.lots,.01));
      assert(p.estimated_margin<=q.free_margin*.25);
   }
   {
      TestExecution broker; broker.margin_per_lot=50000;
      assert(run(bars(true),quote(true),broker,p)==GAS_MARGIN);
      assert(broker.attempts==0);
   }
   {
      TestExecution broker; GASBars b=bars(true); b.atr=20;
      assert(run(b,quote(true),broker,p)==GAS_RISK);
      assert(broker.attempts==0 && p.estimated_loss>10);
   }
   {
      TestExecution broker; GASQuote q=quote(true); q.ask=q.bid+.6;
      assert(run(bars(true),q,broker,p)==GAS_SPREAD);
      assert(broker.attempts==0);
   }
   {
      // Charts are Bid-based: price movement and spread are separate limits.
      TestExecution broker; GASQuote q=quote(true);
      q.bid=2501.4; q.ask=2501.9;
      assert(run(bars(true),q,broker,p)==GAS_SENT);
      assert(broker.fills.front().entry-bars(true).close<=.5*bars(true).atr);
      TestExecution blocked;
      q.bid=2501.51; q.ask=2501.71;
      assert(run(bars(true),q,blocked,p)==GAS_ENTRY_MOVED);
      q.bid=2501; q.ask=2501.51;
      assert(run(bars(true),q,blocked,p)==GAS_SPREAD);
      assert(blocked.attempts==0);
   }
   {
      TestExecution broker; GASBars b=bars(true); b.rsi=49;
      assert(run(b,quote(true),broker,p)==GAS_NO_SIGNAL);
      assert(broker.attempts==0);
      b=bars(true); b.low=2500.5; b.open=2500.6; b.previous_close=2500.8; b.previous_rsi=52;
      b.previous_high=2500.9; b.breakout_high=2501.2;
      assert(run(b,quote(true),broker,p)==GAS_NO_SIGNAL);
      assert(broker.attempts==0);
   }
   {
      TestExecution broker; GASQuote q=quote(true); q.tick_size=std::numeric_limits<double>::quiet_NaN();
      assert(run(bars(true),q,broker,p)==GAS_BAD_DATA);
      assert(broker.attempts==0);
      assert(run(bars(true),quote(true),broker,p,0)==GAS_RISK);
      GASBars b=bars(true); b.trend_previous_fast=std::numeric_limits<double>::quiet_NaN();
      assert(run(b,quote(true),broker,p)==GAS_BAD_DATA);
      b=bars(true); b.breakout_high=b.previous_high-.1;
      assert(run(b,quote(true),broker,p)==GAS_BAD_DATA);
      assert(broker.attempts==0);
   }
   {
      TestExecution broker; GASBars b=bars(true);
      b.previous_low=2496; b.breakout_low=2496;
      assert(run(b,quote(true),broker,p)==GAS_SENT);
      assert(near(p.stop,2495.8) && near(p.lots,.01) && p.minimum_lot_bridge);
      assert(p.estimated_loss>5 && p.estimated_loss<=10);
      TestExecution denied;
      double remaining=GoldBudgetWithinLimits(9.8,490,485,470,450);
      assert(near(remaining,5));
      assert(run(b,quote(true),denied,p,remaining)==GAS_RISK);
      assert(denied.attempts==0);
      GASQuote q=quote(true); q.minimum_lot=.1;
      assert(run(bars(true),q,denied,p)==GAS_RISK);
      assert(GASProcess(bars(true),quote(true),10,.005,2,1,.25,.25,denied,p)==GAS_RISK);
      assert(denied.attempts==0);
      b.previous_low=2490; b.breakout_low=2490;
      assert(run(b,quote(true),denied,p)==GAS_WIDE_STOP);
      assert(denied.attempts==0);
   }
   {
      for(int budget=1;budget<=20;budget++)
         for(int volatility=1;volatility<=20;volatility++)
         {
            TestExecution broker; GASBars b=bars(true); b.atr=volatility;
            GASResult r=run(b,quote(true),broker,p,budget);
            if(r==GAS_SENT)
            {
               assert(p.estimated_loss<=budget+1e-8);
               assert(p.minimum_lot_bridge ? near(p.lots,.01) : p.estimated_loss<=.5*budget+1e-8);
               assert(p.estimated_margin<=125 && p.lots<=.1);
            }
            else assert(broker.attempts==0);
         }
      assert(GASDailyEntryAllowed(3,12) && !GASDailyEntryAllowed(3,3));
      assert(GASDailyEntryAllowed(11,12) && !GASDailyEntryAllowed(12,12));
      assert(!GASDailyEntryAllowed(-1,12) && !GASDailyEntryAllowed(0,0));
      assert(!GASDailyEntryAllowed(0,13) && !GASDailyEntryAllowed(0,48));
      assert(GoldDrawdownPct(505,464)>8);
   }
   // Closed-bar replay exercises the SAME production pipeline through broker submission.
   // This broker is a test double, not MetaTrader or real historical data.
   TestExecution replay;
   for(int day=0;day<10;day++)
      for(int bar=0;bar<30;bar++)
      {
         bool buy=day%2==0;
         GASBars b=bars(buy);
         if(bar!=8 && bar!=20) b.rsi=50;
         GASResult r=run(b,quote(buy),replay,p);
         assert(r==((bar==8 || bar==20) ? GAS_SENT : GAS_NO_SIGNAL));
      }
   assert(replay.attempts==20 && replay.fills.size()==20);
   std::cout << "GoldAutoScalp 2.10: trend/continuation/structural-stop tests, 400 sizing scenarios and daily-cap boundaries passed. 300 synthetic snapshots -> 20 test-broker submissions/fills. NOT a profitability or MT5 backtest.\n";
}
