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

GASBars bars(bool buy)
{
   GASBars b={2501,2502,2498,2499.8,2501.3,2499.5,2501,2499.9,2500,2500,55,48,2};
   if(!buy)
   {
      b.trend_close=5000-b.trend_close; b.trend_fast=5000-b.trend_fast; b.trend_slow=5000-b.trend_slow;
      b.open=5000-b.open; b.close=5000-b.close; b.previous_close=5000-b.previous_close;
      double high=b.high; b.high=5000-b.low; b.low=5000-high;
      b.ema=5000-b.ema; b.previous_ema=5000-b.previous_ema; b.rsi=100-b.rsi; b.previous_rsi=100-b.previous_rsi;
   }
   return b;
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
      assert(fill.buy==buy && near(fill.lots,.03));
      assert(buy ? fill.stop<fill.entry && fill.target>fill.entry : fill.stop>fill.entry && fill.target<fill.entry);
      double risk=std::abs(fill.entry-fill.stop);
      assert(std::abs(fill.target-fill.entry)/risk>=2-1e-9);
      assert(fill.lots*broker.LossPerLot(buy,fill.entry,fill.stop)<=10);
      assert(p.estimated_margin<=125);
      double trigger=fill.entry+(buy ? risk : -risk);
      assert(GoldReachedOneR(buy,trigger,fill.entry,risk));
      assert(!GoldReachedOneR(buy,trigger+(buy ? -.01 : .01),fill.entry,risk));
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
      assert(run(bars(true),q,broker,p)==GAS_SENT);
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
      TestExecution broker; GASBars b=bars(true); b.rsi=49;
      assert(run(b,quote(true),broker,p)==GAS_NO_SIGNAL);
      assert(broker.attempts==0);
      b=bars(true); b.low=2500.5; b.open=2500.6; b.previous_close=2500.8; b.previous_rsi=52;
      assert(run(b,quote(true),broker,p)==GAS_NO_SIGNAL);
      assert(broker.attempts==0);
   }
   {
      TestExecution broker; GASQuote q=quote(true); q.tick_size=std::numeric_limits<double>::quiet_NaN();
      assert(run(bars(true),q,broker,p)==GAS_BAD_DATA);
      assert(broker.attempts==0);
      assert(run(bars(true),quote(true),broker,p,0)==GAS_RISK);
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
   std::cout << "GoldAutoScalp production pipeline: 300 synthetic closed bars -> 20 test-broker market submissions/fills (10 buys, 10 sells). Rejection and risk guards passed. NOT an MT5 backtest.\n";
}
