#ifndef GOLD_AUTO_SCALP_CORE_MQH
#define GOLD_AUTO_SCALP_CORE_MQH

// Requires GoldRiskMath.mqh first; the distribution builder enforces this order.

struct GASBars
{
   double trend_close,trend_fast,trend_slow;
   double open,high,low,close,previous_close,ema,previous_ema,rsi,previous_rsi,atr;
};

struct GASQuote
{
   double bid,ask,tick_size,minimum_stop,minimum_lot,maximum_lot,lot_step,free_margin;
};

struct GASPlan
{
   int direction;
   double entry,stop,target,lots,estimated_loss,estimated_margin;
};

enum GASResult
{
   GAS_NO_SIGNAL=0,GAS_BAD_DATA,GAS_SPREAD,GAS_RISK,GAS_MARGIN,GAS_NOT_ALLOWED,GAS_REJECTED,GAS_SENT
};

class GASExecution
{
public:
   virtual bool Allowed(bool buy)=0;
   virtual double LossPerLot(bool buy,double entry,double stop)=0;
   virtual double MarginPerLot(bool buy,double entry)=0;
   virtual bool SendMarket(bool buy,double lots,double entry,double stop,double target)=0;
};

bool GASValidBars(const GASBars &b)
{
   return MathIsValidNumber(b.trend_close) && MathIsValidNumber(b.trend_fast) && MathIsValidNumber(b.trend_slow) &&
      MathIsValidNumber(b.open) && MathIsValidNumber(b.high) && MathIsValidNumber(b.low) && MathIsValidNumber(b.close) &&
      MathIsValidNumber(b.previous_close) && MathIsValidNumber(b.ema) && MathIsValidNumber(b.previous_ema) &&
      MathIsValidNumber(b.rsi) && MathIsValidNumber(b.previous_rsi) && MathIsValidNumber(b.atr) &&
      b.trend_close>0 && b.trend_fast>0 && b.trend_slow>0 && b.low>0 && b.high>=b.low &&
      b.open>=b.low && b.open<=b.high && b.close>=b.low && b.close<=b.high &&
      b.previous_close>0 && b.ema>0 && b.previous_ema>0 && b.atr>0 &&
      b.rsi>=0 && b.rsi<=100 && b.previous_rsi>=0 && b.previous_rsi<=100;
}

int GASDirection(const GASBars &b)
{
   if(!GASValidBars(b)) return 0;
   bool buy_bias=b.trend_fast>b.trend_slow && b.trend_close>b.trend_slow;
   bool sell_bias=b.trend_fast<b.trend_slow && b.trend_close<b.trend_slow;
   bool buy_pullback=b.low<=b.ema || b.previous_close<=b.previous_ema || b.previous_rsi<=50;
   bool sell_pullback=b.high>=b.ema || b.previous_close>=b.previous_ema || b.previous_rsi>=50;
   if(buy_bias && buy_pullback && b.close>b.open && b.close>b.ema && b.rsi>50 && b.rsi>b.previous_rsi) return 1;
   if(sell_bias && sell_pullback && b.close<b.open && b.close<b.ema && b.rsi<50 && b.rsi<b.previous_rsi) return -1;
   return 0;
}

GASResult GASProcess(const GASBars &bars,const GASQuote &q,double budget,double max_lots,double rr,
                     double stop_atr,double max_spread_atr,double margin_fraction,GASExecution &broker,GASPlan &plan)
{
   plan.direction=0; plan.entry=0; plan.stop=0; plan.target=0; plan.lots=0; plan.estimated_loss=0; plan.estimated_margin=0;
   if(!GASValidBars(bars) || !MathIsValidNumber(q.bid) || !MathIsValidNumber(q.ask) ||
      !MathIsValidNumber(q.tick_size) || !MathIsValidNumber(q.minimum_stop) || !MathIsValidNumber(q.minimum_lot) ||
      !MathIsValidNumber(q.maximum_lot) || !MathIsValidNumber(q.lot_step) || !MathIsValidNumber(q.free_margin) ||
      !MathIsValidNumber(budget) || !MathIsValidNumber(max_lots) || !MathIsValidNumber(rr) ||
      !MathIsValidNumber(stop_atr) || !MathIsValidNumber(max_spread_atr) || !MathIsValidNumber(margin_fraction) ||
      q.bid<=0 || q.ask<q.bid || q.tick_size<=0 || q.minimum_stop<0 || q.minimum_lot<=0 ||
      q.maximum_lot<q.minimum_lot || q.lot_step<=0 || max_lots<=0 || rr<2 || stop_atr<=0 ||
      max_spread_atr<=0 || margin_fraction<=0 || margin_fraction>1) return GAS_BAD_DATA;
   plan.direction=GASDirection(bars);
   if(plan.direction==0) return GAS_NO_SIGNAL;
   if(q.ask-q.bid>bars.atr*max_spread_atr) return GAS_SPREAD;
   if(budget<=0) return GAS_RISK;
   bool buy=plan.direction>0;
   if(!broker.Allowed(buy)) return GAS_NOT_ALLOWED;
   plan.entry=buy ? q.ask : q.bid;
   double distance=MathMax(bars.atr*stop_atr,q.minimum_stop+q.tick_size);
   plan.stop=GoldPrice((buy ? q.bid : q.ask)+(buy ? -distance : distance),q.tick_size,!buy);
   if(plan.stop<=0) return GAS_BAD_DATA;
   double risk=buy ? plan.entry-plan.stop : plan.stop-plan.entry;
   plan.target=GoldPrice(plan.entry+(buy ? 1 : -1)*rr*risk,q.tick_size,buy);
   if(risk<=0 || plan.target<=0) return GAS_BAD_DATA;
   double loss=broker.LossPerLot(buy,plan.entry,plan.stop);
   if(!MathIsValidNumber(loss) || loss<=0) return GAS_BAD_DATA;
   double risk_lots=GoldVolume(budget,loss,q.minimum_lot,MathMin(max_lots,q.maximum_lot),q.lot_step);
   plan.estimated_loss=q.minimum_lot*loss;
   if(risk_lots<=0) return GAS_RISK;
   double margin=broker.MarginPerLot(buy,plan.entry);
   if(!MathIsValidNumber(margin) || margin<=0) return GAS_BAD_DATA;
   double margin_lots=GoldVolume(MathMax(0.0,q.free_margin)*margin_fraction,margin,q.minimum_lot,risk_lots,q.lot_step);
   plan.estimated_margin=q.minimum_lot*margin;
   if(margin_lots<=0) return GAS_MARGIN;
   plan.lots=margin_lots;
   plan.estimated_loss=plan.lots*loss;
   plan.estimated_margin=plan.lots*margin;
   return broker.SendMarket(buy,plan.lots,plan.entry,plan.stop,plan.target) ? GAS_SENT : GAS_REJECTED;
}
#endif
