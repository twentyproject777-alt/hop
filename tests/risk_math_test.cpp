#include <algorithm>
#include <cassert>
#include <cmath>
#include <iostream>
#include <limits>

double MathMax(double a,double b) { return std::max(a,b); }
double MathMin(double a,double b) { return std::min(a,b); }
double MathFloor(double a) { return std::floor(a); }
double MathCeil(double a) { return std::ceil(a); }
double MathAbs(double a) { return std::abs(a); }
bool MathIsValidNumber(double a) { return std::isfinite(a); }
#include "../mt5/Include/GoldRiskMath.mqh"

bool near(double a,double b) { return std::abs(a-b)<1e-8; }

int main()
{
   assert(near(GoldDrawdownPct(10000,9200),8));
   assert(near(GoldDrawdownPct(10000,11000),0));
   assert(near(GoldRiskBudget(10000,.25,0,5),25));
   assert(near(GoldRiskBudget(9500,.25,5,5),11.875));
   assert(near(GoldBudgetWithinLimits(25,10000,9900,9700,9000),25));
   assert(near(GoldBudgetWithinLimits(25,9910,9900,9700,9000),10));
   assert(near(GoldBudgetWithinLimits(25,9910,9800,9905,9000),5));
   assert(near(GoldBudgetWithinLimits(25,9910,9800,9700,9908),2));
   assert(near(GoldBudgetWithinLimits(25,9890,9900,9700,9000),0));
   assert(near(GoldVolume(25,507,.01,10,.01),.04));
   assert(near(GoldVolume(1,507,.01,10,.01),0));
   assert(near(GoldVolume(10000,100,.01,1,.01),1));
   assert(near(GoldVolume(100,500,.1,1,.1),.2));
   assert(near(GoldVolume(100,0,.01,1,.01),0));
   // $500 account: exact fixed lots never override the dollar risk cap.
   assert(near(GoldVolume(1.25,507,.01,1,.01),0));
   assert(near(GoldVolume(5,207,.01,1,.01),.02));
   assert(near(GoldFixedVolume(.05,10,107,.01,1,.01),.05));
   assert(near(GoldFixedVolume(.10,10,87,.01,1,.01),.10));
   assert(near(GoldFixedVolume(.10,10,107,.01,1,.01),0));
   assert(near(GoldFixedVolume(.05,10,507,.01,1,.01),0));
   assert(near(GoldFixedVolume(.055,10,107,.01,1,.01),0));
   assert(near(GoldFixedVolume(.05,10,107,.10,1,.01),0));
   assert(near(GoldFixedVolume(.10,10,87,.01,.05,.01),0));
   assert(near(GoldFixedVolume(.05,5,107,.01,1,.01),0));
   assert(near(GoldFixedVolume(.05,10,107,.01,1,0),0));
   assert(near(GoldFixedVolume(1e-11,10,107,0,1,0),0));
   double nan=std::numeric_limits<double>::quiet_NaN();
   double inf=std::numeric_limits<double>::infinity();
   assert(near(GoldFixedVolume(nan,10,107,.01,1,.01),0));
   assert(near(GoldFixedVolume(.05,10,107,.01,1,nan),0));
   assert(near(GoldVolume(100,nan,.01,1,.01),0));
   assert(near(GoldVolume(inf,500,.01,1,.01),0));
   assert(near(GoldVolume(100,500,.01,1,0),0));
   assert(near(GoldVolume(100,500,.1,.01,.01),0));
   assert(near(GoldRiskBudget(nan,.25,0,5),0));
   assert(near(GoldDrawdownPct(10000,nan),100));
   for(int budget=1;budget<1000;budget++)
      for(double step : {.001,.01,.1,.25,1.0})
      {
         double lots=GoldVolume(budget,507,step,10,step);
         assert(lots*507<=budget+1e-8);
         assert(lots==0 || lots>=step-1e-10);
         assert(lots<=10+1e-10);
         assert(near(lots/step,std::round(lots/step)));
      }
   assert(!GoldReachedOneR(true,2504.99,2500,5));
   assert(GoldReachedOneR(true,2505,2500,5));
   assert(!GoldReachedOneR(false,2495.01,2500,5));
   assert(GoldReachedOneR(false,2495,2500,5));
   assert(!GoldReachedOneR(true,2510,2500,0));
   assert(!GoldReachedOneR(true,inf,2500,5));
   assert(near(GoldBreakEven(true,2500,.70,.10,.01,2),2500.09));
   assert(near(GoldBreakEven(false,2500,.70,.10,.01,2),2499.91));
   assert(GoldImprovesStop(true,2495,2500.09,.01));
   assert(!GoldImprovesStop(true,2501,2500.09,.01));
   assert(GoldImprovesStop(false,2505,2499.91,.01));
   assert(!GoldImprovesStop(false,2499,2499.91,.01));
   assert(!GoldImprovesStop(false,2505,nan,.01));
   assert(near(GoldBreakEven(true,2500,.7,0,.01,2),0));
   assert(near(GoldBreakEven(true,2500,inf,.1,.01,2),0));
   assert(near(GoldPrice(2500.071,.05,true),2500.10));
   assert(near(GoldPrice(2500.071,.05,false),2500.05));
   std::cout << "Risk math tests passed (including 4,995 lot-sizing cases).\n";
}
