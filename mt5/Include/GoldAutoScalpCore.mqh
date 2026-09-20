#ifndef GOLD_AUTO_SCALP_CORE_MQH
#define GOLD_AUTO_SCALP_CORE_MQH

// Requires GoldRiskMath.mqh first; the distribution builder enforces this order.

struct GASBars
{
   double trend_close,trend_fast,trend_slow;
   double open,high,low,close,previous_close,ema,previous_ema,rsi,previous_rsi,atr;
   double trend_previous_fast,trend_atr,fast_ema,previous_fast_ema;
   double previous_high,previous_low,breakout_high,breakout_low;
};

struct GASQuote
{
   double bid,ask,tick_size,minimum_stop,minimum_lot,maximum_lot,lot_step,free_margin;
};

enum GASSetup { GAS_SETUP_NONE=0,GAS_SETUP_PULLBACK,GAS_SETUP_BREAKOUT };

struct GASPlan
{
   int direction;
   GASSetup setup;
   bool minimum_lot_bridge;
   double entry,stop,target,lots,estimated_loss,estimated_margin;
};

enum GASResult
{
   GAS_NO_SIGNAL=0,GAS_BAD_DATA,GAS_SPREAD,GAS_RISK,GAS_MARGIN,GAS_NOT_ALLOWED,GAS_REJECTED,GAS_SENT,
   GAS_NO_TREND,GAS_QUALITY,GAS_ENTRY_MOVED,GAS_READY,GAS_WIDE_STOP
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
      MathIsValidNumber(b.trend_previous_fast) && MathIsValidNumber(b.trend_atr) &&
      MathIsValidNumber(b.fast_ema) && MathIsValidNumber(b.previous_fast_ema) &&
      MathIsValidNumber(b.previous_high) && MathIsValidNumber(b.previous_low) &&
      MathIsValidNumber(b.breakout_high) && MathIsValidNumber(b.breakout_low) &&
      b.trend_close>0 && b.trend_fast>0 && b.trend_slow>0 && b.low>0 && b.high>=b.low &&
      b.open>=b.low && b.open<=b.high && b.close>=b.low && b.close<=b.high &&
      b.previous_close>0 && b.ema>0 && b.previous_ema>0 && b.atr>0 &&
      b.rsi>=0 && b.rsi<=100 && b.previous_rsi>=0 && b.previous_rsi<=100 &&
      b.trend_previous_fast>0 && b.trend_atr>0 && b.fast_ema>0 && b.previous_fast_ema>0 &&
      b.previous_low>0 && b.previous_high>=b.previous_close && b.previous_low<=b.previous_close &&
      b.breakout_high>=b.previous_high && b.breakout_low<=b.previous_low && b.breakout_low>0;
}

int GASTrendDirection(const GASBars &b)
{
   if(!GASValidBars(b)) return 0;
   if(MathAbs(b.trend_fast-b.trend_slow)<.15*b.trend_atr) return 0;
   if(b.trend_fast>b.trend_slow && b.trend_close>b.trend_fast && b.trend_fast>b.trend_previous_fast) return 1;
   if(b.trend_fast<b.trend_slow && b.trend_close<b.trend_fast && b.trend_fast<b.trend_previous_fast) return -1;
   return 0;
}

GASResult GASSignal(const GASBars &b,int &direction,GASSetup &setup)
{
   direction=0; setup=GAS_SETUP_NONE;
   if(!GASValidBars(b)) return GAS_BAD_DATA;
   int trend=GASTrendDirection(b);
   if(trend==0) return GAS_NO_TREND;
   bool buy=trend>0;
   bool aligned=buy ? b.fast_ema>b.ema && b.close>b.fast_ema && b.close>b.open && b.rsi>50 && b.rsi>b.previous_rsi
                    : b.fast_ema<b.ema && b.close<b.fast_ema && b.close<b.open && b.rsi<50 && b.rsi<b.previous_rsi;
   if(!aligned) return GAS_NO_SIGNAL;
   if(MathAbs(b.close-b.fast_ema)>b.atr || b.high-b.low>2.5*b.atr ||
      (buy ? b.rsi>75 : b.rsi<25)) return GAS_QUALITY;
   bool pullback=buy ? b.low<=b.fast_ema+.1*b.atr || b.previous_close<=b.previous_fast_ema
                    : b.high>=b.fast_ema-.1*b.atr || b.previous_close>=b.previous_fast_ema;
   bool breakout=buy ? b.close>b.breakout_high : b.close<b.breakout_low;
   if(!pullback && !breakout) return GAS_NO_SIGNAL;
   direction=trend;
   setup=pullback ? GAS_SETUP_PULLBACK : GAS_SETUP_BREAKOUT;
   return GAS_READY;
}

bool GASDailyEntryAllowed(int filled,int maximum)
{
   return filled>=0 && maximum>0 && maximum<=12 && filled<maximum;
}

GASResult GASProcess(const GASBars &bars,const GASQuote &q,double budget,double max_lots,double rr,
                     double stop_atr,double max_spread_atr,double margin_fraction,GASExecution &broker,GASPlan &plan)
{
   plan.direction=0; plan.entry=0; plan.stop=0; plan.target=0; plan.lots=0; plan.estimated_loss=0; plan.estimated_margin=0;
   plan.setup=GAS_SETUP_NONE; plan.minimum_lot_bridge=false;
   if(!GASValidBars(bars) || !MathIsValidNumber(q.bid) || !MathIsValidNumber(q.ask) ||
      !MathIsValidNumber(q.tick_size) || !MathIsValidNumber(q.minimum_stop) || !MathIsValidNumber(q.minimum_lot) ||
      !MathIsValidNumber(q.maximum_lot) || !MathIsValidNumber(q.lot_step) || !MathIsValidNumber(q.free_margin) ||
      !MathIsValidNumber(budget) || !MathIsValidNumber(max_lots) || !MathIsValidNumber(rr) ||
      !MathIsValidNumber(stop_atr) || !MathIsValidNumber(max_spread_atr) || !MathIsValidNumber(margin_fraction) ||
      q.bid<=0 || q.ask<q.bid || q.tick_size<=0 || q.minimum_stop<0 || q.minimum_lot<=0 ||
      q.maximum_lot<q.minimum_lot || q.lot_step<=0 || max_lots<=0 || rr<2 || stop_atr<=0 ||
      max_spread_atr<=0 || margin_fraction<=0 || margin_fraction>1) return GAS_BAD_DATA;
   GASResult signal=GASSignal(bars,plan.direction,plan.setup);
   if(signal!=GAS_READY) return signal;
   if(q.ask-q.bid>bars.atr*max_spread_atr) return GAS_SPREAD;
   if(budget<=0) return GAS_RISK;
   bool buy=plan.direction>0;
   if(MathAbs(q.bid-bars.close)>.25*bars.atr || (buy ? q.bid<=bars.fast_ema : q.bid>=bars.fast_ema)) return GAS_ENTRY_MOVED;
   if(!broker.Allowed(buy)) return GAS_NOT_ALLOWED;
   plan.entry=buy ? q.ask : q.bid;
   double distance=MathMax(bars.atr*stop_atr,q.minimum_stop+q.tick_size);
   plan.stop=GoldPrice((buy ? q.bid : q.ask)+(buy ? -distance : distance),q.tick_size,!buy);
   double structural_stop=buy ? MathMin(bars.low,bars.previous_low)-.1*bars.atr
                              : MathMax(bars.high,bars.previous_high)+(q.ask-q.bid)+.1*bars.atr;
   plan.stop=GoldPrice(buy ? MathMin(plan.stop,structural_stop) : MathMax(plan.stop,structural_stop),q.tick_size,!buy);
   if(plan.stop<=0) return GAS_BAD_DATA;
   double risk=buy ? plan.entry-plan.stop : plan.stop-plan.entry;
   if(risk-(q.ask-q.bid)>3*bars.atr+q.tick_size) return GAS_WIDE_STOP;
   plan.target=GoldPrice(plan.entry+(buy ? 1 : -1)*rr*risk,q.tick_size,buy);
   if(risk<=0 || plan.target<=0) return GAS_BAD_DATA;
   double loss=broker.LossPerLot(buy,plan.entry,plan.stop);
   if(!MathIsValidNumber(loss) || loss<=0) return GAS_BAD_DATA;
   double cap=MathMin(max_lots,q.maximum_lot);
   double risk_lots=GoldVolume(.5*budget,loss,q.minimum_lot,cap,q.lot_step);
   // Only the broker minimum may exceed the preferred half-budget, never the hard budget.
   if(risk_lots<=0 && GoldFixedVolume(q.minimum_lot,budget,loss,q.minimum_lot,cap,q.lot_step)>0)
   { risk_lots=q.minimum_lot; plan.minimum_lot_bridge=true; }
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
