#ifndef GOLD_RISK_MATH_MQH
#define GOLD_RISK_MATH_MQH

double GoldDrawdownPct(double baseline,double equity)
{
   if(!MathIsValidNumber(baseline) || !MathIsValidNumber(equity) || baseline<=0.0) return 100.0;
   return MathMax(0.0,100.0*(baseline-equity)/baseline);
}

double GoldRiskBudget(double equity,double risk_pct,double drawdown,double reduce_at)
{
   if(!MathIsValidNumber(equity) || !MathIsValidNumber(risk_pct) || !MathIsValidNumber(drawdown) ||
      !MathIsValidNumber(reduce_at) || equity<=0.0 || risk_pct<=0.0) return 0.0;
   return equity*risk_pct/100.0*(drawdown>=reduce_at ? 0.5 : 1.0);
}

double GoldVolume(double budget,double loss_per_lot,double minimum,double maximum,double step)
{
   if(!MathIsValidNumber(budget) || !MathIsValidNumber(loss_per_lot) || !MathIsValidNumber(minimum) ||
      !MathIsValidNumber(maximum) || !MathIsValidNumber(step) ||
      budget<=0.0 || loss_per_lot<=0.0 || minimum<=0.0 || maximum<minimum || step<=0.0)
      return 0.0;
   double lots=MathFloor((MathMin(maximum,budget/loss_per_lot)+1e-12)/step)*step;
   if(lots<minimum-1e-10 || lots*loss_per_lot>budget+1e-8) return 0.0;
   return lots;
}

double GoldBudgetWithinLimits(double budget,double equity,double day_floor,double week_floor,double hard_floor)
{
   if(!MathIsValidNumber(budget) || !MathIsValidNumber(equity) || !MathIsValidNumber(day_floor) ||
      !MathIsValidNumber(week_floor) || !MathIsValidNumber(hard_floor)) return 0.0;
   double floor=MathMax(day_floor,MathMax(week_floor,hard_floor));
   return MathMax(0.0,MathMin(budget,equity-floor));
}

double GoldFixedVolume(double requested,double budget,double loss_per_lot,double minimum,double maximum,double step)
{
   if(!MathIsValidNumber(requested) || requested<=0) return 0;
   double allowed=GoldVolume(budget,loss_per_lot,minimum,maximum,step);
   if(allowed<=0 || requested<minimum-1e-10 || requested>allowed+1e-10) return 0;
   double normalized=MathFloor(requested/step+0.5)*step;
   if(MathAbs(normalized-requested)>1e-8 || normalized*loss_per_lot>budget+1e-8) return 0;
   return normalized;
}

double GoldPrice(double price,double tick_size,bool round_up)
{
   if(!MathIsValidNumber(price) || !MathIsValidNumber(tick_size) || tick_size<=0.0) return 0.0;
   double units=price/tick_size;
   return (round_up ? MathCeil(units-1e-9) : MathFloor(units+1e-9))*tick_size;
}

bool GoldReachedOneR(bool buy,double executable_price,double entry,double initial_risk)
{
   return MathIsValidNumber(executable_price) && MathIsValidNumber(entry) && MathIsValidNumber(initial_risk) &&
      initial_risk>0.0 && (buy ? executable_price-entry : entry-executable_price)>=initial_risk;
}

double GoldBreakEven(bool buy,double entry,double costs,double profit_per_tick,double tick_size,int extra_ticks)
{
   if(!MathIsValidNumber(entry) || !MathIsValidNumber(costs) || !MathIsValidNumber(profit_per_tick) ||
      !MathIsValidNumber(tick_size) || profit_per_tick<=0.0 || tick_size<=0.0 || extra_ticks<0) return 0.0;
   double offset=(MathMax(0.0,costs)/profit_per_tick+extra_ticks)*tick_size;
   return GoldPrice(entry+(buy ? offset : -offset),tick_size,buy);
}

bool GoldImprovesStop(bool buy,double old_stop,double new_stop,double tick_size)
{
   if(!MathIsValidNumber(old_stop) || !MathIsValidNumber(new_stop) || !MathIsValidNumber(tick_size) ||
      new_stop<=0.0 || tick_size<=0.0) return false;
   return old_stop<=0.0 || (buy ? new_stop-old_stop : old_stop-new_stop)>=tick_size*0.5;
}
#endif
