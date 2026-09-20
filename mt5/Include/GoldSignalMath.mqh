#ifndef GOLD_SIGNAL_MATH_MQH
#define GOLD_SIGNAL_MATH_MQH

int GoldEMADirection(double close,double ema,double previous)
{
   if(!MathIsValidNumber(close) || !MathIsValidNumber(ema) || !MathIsValidNumber(previous) || ema<=0) return 0;
   if(close>ema && ema>previous) return 1;
   if(close<ema && ema<previous) return -1;
   return 0;
}

bool GoldSweep(bool buy,double low,double high,double close,double level)
{
   if(!MathIsValidNumber(low) || !MathIsValidNumber(high) || !MathIsValidNumber(close) ||
      !MathIsValidNumber(level) || low>high || close<low || close>high || level<=0) return false;
   return buy ? low<level && close>level : high>level && close<level;
}

bool GoldInZone(double extreme,double zone,double atr,double tolerance)
{
   return MathIsValidNumber(extreme) && MathIsValidNumber(zone) && MathIsValidNumber(atr) &&
      MathIsValidNumber(tolerance) && atr>0 && tolerance>0 && MathAbs(extreme-zone)<=atr*tolerance;
}

bool GoldSweepIntact(bool buy,double low,double high,double extreme)
{
   return MathIsValidNumber(low) && MathIsValidNumber(high) && MathIsValidNumber(extreme) &&
      low<=high && (buy ? low>=extreme : high<=extreme);
}

bool GoldBreakConfirmed(bool buy,double open,double close,double level)
{
   return MathIsValidNumber(open) && MathIsValidNumber(close) && MathIsValidNumber(level) &&
      (buy ? close>level && close>open : close<level && close<open);
}

bool GoldMomentumConfirmed(bool buy,double open,double close,double atr,double min_body,bool use_rsi,double rsi,double previous_rsi)
{
   if(!MathIsValidNumber(open) || !MathIsValidNumber(close) || !MathIsValidNumber(atr) ||
      !MathIsValidNumber(min_body) || atr<=0 || min_body<=0 || MathAbs(close-open)<atr*min_body) return false;
   if(!use_rsi) return true;
   if(!MathIsValidNumber(rsi) || !MathIsValidNumber(previous_rsi) || rsi<0 || rsi>100 || previous_rsi<0 || previous_rsi>100) return false;
   return buy ? rsi>50 && rsi>previous_rsi : rsi<50 && rsi<previous_rsi;
}

bool GoldEntryInsideCandle(bool buy,double entry,double stop,double low,double high)
{
   return MathIsValidNumber(entry) && MathIsValidNumber(stop) && MathIsValidNumber(low) && MathIsValidNumber(high) &&
      low<=high && entry>=low && entry<=high && (buy ? entry>stop : entry<stop);
}

double GoldEntryBeforeObstacle(bool buy,double entry,double stop,double rr,double obstacle,double spread,double tick)
{
   if(!MathIsValidNumber(entry) || !MathIsValidNumber(stop) || !MathIsValidNumber(rr) ||
      !MathIsValidNumber(obstacle) || !MathIsValidNumber(spread) || !MathIsValidNumber(tick) ||
      rr<2 || spread<0 || tick<=0 || (buy ? entry<=stop : entry>=stop)) return 0;
   if(obstacle<=0 || (buy ? obstacle<=entry : obstacle>=entry)) return entry;
   // Leave two ticks for target rounding and the strict obstacle clearance check.
   double bound=(obstacle+(buy ? -1 : 1)*(spread+2*tick)+rr*stop)/(1+rr);
   double adjusted=GoldPrice(buy ? MathMin(entry,bound) : MathMax(entry,bound),tick,!buy);
   if(buy ? adjusted<=stop : adjusted>=stop) return 0;
   return adjusted;
}
#endif
