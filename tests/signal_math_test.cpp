#include <algorithm>
#include <cassert>
#include <cmath>
#include <iostream>
#include <limits>

double MathMax(double a,double b) { return std::max(a,b); }
double MathMin(double a,double b) { return std::min(a,b); }
double MathAbs(double a) { return std::abs(a); }
double MathFloor(double a) { return std::floor(a); }
double MathCeil(double a) { return std::ceil(a); }
bool MathIsValidNumber(double a) { return std::isfinite(a); }
#include "../mt5/Include/GoldRiskMath.mqh"
#include "../mt5/Include/GoldSignalMath.mqh"

bool near(double a,double b) { return std::abs(a-b)<1e-8; }

void candidate(bool buy)
{
   auto p=[buy](double price) { return buy ? price : 5000-price; };
   int direction=buy ? 1 : -1;
   assert(GoldEMADirection(p(2500),p(2485),p(2484))==direction);
   assert(GoldEMADirection(p(2498),p(2492),p(2491.5))==direction);
   double sweep_low=MathMin(p(2490),p(2495)),sweep_high=MathMax(p(2490),p(2495));
   double extreme=buy ? sweep_low : sweep_high;
   assert(GoldSweep(buy,sweep_low,sweep_high,p(2492.5),p(2491)));
   assert(GoldInZone(extreme,p(2492),3.5,1.0));
   assert(!GoldInZone(extreme,p(2480),2.5,.5));

   double open=p(2492),close=p(2496);
   double low=MathMin(p(2491),p(2496.5)),high=MathMax(p(2491),p(2496.5));
   assert(GoldSweepIntact(buy,low,high,extreme));
   assert(!GoldSweepIntact(buy,MathMin(p(2489),p(2496.5)),MathMax(p(2489),p(2496.5)),extreme));
   double trigger=buy ? sweep_high : sweep_low;
   assert(GoldBreakConfirmed(buy,open,close,trigger));
   assert(!GoldBreakConfirmed(buy,open,close,p(2500)));
   assert(GoldMomentumConfirmed(buy,open,close,2.5,.4,true,buy ? 55 : 45,buy ? 48 : 52));
   assert(!GoldMomentumConfirmed(buy,open,close,2.5,.4,true,buy ? 49 : 51,buy ? 48 : 52));

   double entry=(open+close)/2,stop=p(2489.5),obstacle=p(2501);
   double initial_target=entry+(buy ? 1 : -1)*2*MathAbs(entry-stop);
   assert(!GoldTargetHasRoom(buy,entry,initial_target,obstacle,.2));
   double adjusted=GoldEntryBeforeObstacle(buy,entry,stop,2,obstacle,.2,.01);
   assert(near(adjusted,p(2493.26)));
   assert(GoldEntryInsideCandle(buy,adjusted,stop,low,high));
   double risk=MathAbs(adjusted-stop);
   double target=GoldPrice(adjusted+(buy ? 1 : -1)*2*risk,.01,buy);
   assert(GoldTargetHasRoom(buy,adjusted,target,obstacle,.2));
   assert(MathAbs(target-adjusted)/risk>=2-1e-10);
   assert((20.0+17.0)/(risk*100)<=.1);
   double lots=GoldVolume(GoldRiskBudget(500,2,0,5),risk*100+17,.01,.1,.01);
   assert(near(lots,.02));
   assert(lots*(risk*100+17)<=10);

   double too_deep=GoldEntryBeforeObstacle(buy,entry,stop,2,p(2494.1),.2,.01);
   assert(!GoldEntryInsideCandle(buy,too_deep,stop,low,high));
   // A deeper entry can reveal another, closer obstacle; recheck before sending.
   double next=GoldNearestObstacle(buy,adjusted,p(2493.8),obstacle);
   assert(near(next,p(2493.8)));
   double next_entry=GoldEntryBeforeObstacle(buy,adjusted,stop,2,next,.2,.01);
   assert(!GoldEntryInsideCandle(buy,next_entry,stop,low,high));
}

int main()
{
   candidate(true);
   candidate(false);
   double nan=std::numeric_limits<double>::quiet_NaN();
   assert(GoldEMADirection(2500,2490,2490)==0);
   assert(GoldEMADirection(nan,2490,2489)==0);
   assert(!GoldSweep(true,2490,2495,2489,2491));
   assert(!GoldSweep(true,2490,2495,2492,2490));
   assert(!GoldInZone(2490,2492,0,1));
   assert(!GoldInZone(2490,2492,3.5,nan));
   assert(!GoldBreakConfirmed(true,2496,2496,2495));
   assert(!GoldMomentumConfirmed(true,2495,2496,2,.8,true,55,50));
   assert(GoldMomentumConfirmed(true,2495,2496,2,.4,true,55,50));
   assert(!GoldMomentumConfirmed(true,2495,2496,2,.4,true,50,49));
   assert(near(GoldEntryBeforeObstacle(true,2500,2495,1,2505,.2,.01),0));
   assert(near(GoldEntryBeforeObstacle(true,2500,2495,2,2505,.2,0),0));
   assert(near(GoldEntryBeforeObstacle(true,2500,2495,2,nan,.2,.01),0));
   assert(near(GoldEntryBeforeObstacle(true,2500,2495,2,2490,.2,.01),2500));
   assert(!GoldEntryInsideCandle(true,nan,2490,2495,2500));
   for(bool buy : {true,false})
      for(double rr : {2.0,3.0,5.0})
         for(double tick : {.01,.05,.10})
            for(int i=51;i<=180;i++)
            {
               double entry=buy ? 2505 : 2495,stop=2500;
               double obstacle=stop+(buy ? 1 : -1)*i*.1;
               double adjusted=GoldEntryBeforeObstacle(buy,entry,stop,rr,obstacle,.2,tick);
               assert(adjusted>0);
               assert(buy ? adjusted<=entry && adjusted>stop : adjusted>=entry && adjusted<stop);
               double risk=MathAbs(adjusted-stop);
               double target=GoldPrice(adjusted+(buy ? 1 : -1)*rr*risk,tick,buy);
               assert(GoldTargetHasRoom(buy,adjusted,target,obstacle,.2));
               assert(MathAbs(target-adjusted)/risk>=rr-1e-8);
            }
   std::cout << "Signal helper tests passed: synthetic buy/sell candidate chains, RR adjustment, risk gates, and rejection cases (not MT5 fills).\n";
}
