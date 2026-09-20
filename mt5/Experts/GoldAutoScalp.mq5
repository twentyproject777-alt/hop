#property strict
#property version "2.00"
#property description "No-preset XAU trend-pullback RSI8. Market entries, ATR SL, TP2R, BE1R."
#include <Trade\Trade.mqh>
// BEGIN GENERATED GAS CORE: edit Include modules, then run scripts/build_auto_scalp.py
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

double GoldNearestObstacle(bool buy,double entry,double level,double nearest)
{
   if(!MathIsValidNumber(entry) || !MathIsValidNumber(level) || level<=0) return nearest;
   if(buy ? level<=entry : level>=entry) return nearest;
   if(nearest<=0 || (buy ? level<nearest : level>nearest)) return level;
   return nearest;
}

double GoldMinimumRiskForCosts(double spread_cost,double reserved_cost,double fraction,double lots)
{
   if(!MathIsValidNumber(spread_cost) || !MathIsValidNumber(reserved_cost) || !MathIsValidNumber(fraction) ||
      !MathIsValidNumber(lots) || spread_cost<0 || reserved_cost<0 || fraction<=0 || lots<=0) return 0;
   return lots*((spread_cost+reserved_cost)/fraction+reserved_cost);
}

bool GoldTargetHasRoom(bool buy,double entry,double target,double obstacle,double buffer)
{
   if(!MathIsValidNumber(entry) || !MathIsValidNumber(target) || !MathIsValidNumber(obstacle) ||
      !MathIsValidNumber(buffer) || buffer<0 || (buy ? target<=entry : target>=entry)) return false;
   if(obstacle<=0 || (buy ? obstacle<=entry : obstacle>=entry)) return true;
   return buy ? obstacle>target+buffer : obstacle<target-buffer;
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
// END GENERATED GAS CORE

input bool InpAllowRealTrading=false;
input double InpRiskPercent=2.0;
input double InpMaxLots=0.10;
input double InpRewardRisk=2.0;
input double InpStopATR=1.0;
input double InpMaxSpreadATR=0.25;
input double InpCommissionPerLotRoundTurn=7.0;
input int InpSlippagePoints=30;
input bool InpLiveNewsFilter=true;

const ulong MAGIC=26092002;
CTrade manager;
int fast15=INVALID_HANDLE,slow15=INVALID_HANDLE,ema5=INVALID_HANDLE,atr5=INVALID_HANDLE,rsi5=INVALID_HANDLE;
string prefix,lock_key,last_note="";
double lock_token=0;
bool lock_owned=false;
datetime last_bar=0,note_bar=0,news_checked=0,run_start=0;
bool news_blocked=true;
ulong evaluated=0,signals=0,sent_orders=0,filled_deals=0;
ulong rejected=0,risk_skips=0,margin_skips=0,spread_skips=0,data_skips=0;

string K(string name) { return prefix+name; }
double Read(string name) { return GlobalVariableCheck(K(name)) ? GlobalVariableGet(K(name)) : 0; }
void Write(string name,double value)
{
   if(GlobalVariableCheck(K(name)) && Read(name)==value) return;
   GlobalVariableSet(K(name),value);
   GlobalVariablesFlush();
}

void Note(string message)
{
   datetime bar=iTime(_Symbol,PERIOD_M5,0);
   if(message==last_note && bar==note_bar) return;
   last_note=message; note_bar=bar;
   Print("GAS2: ",message);
}

bool OwnPosition()
{
   return (ulong)PositionGetInteger(POSITION_MAGIC)==MAGIC && PositionGetString(POSITION_SYMBOL)==_Symbol;
}

bool OperationsAllowed()
{
   return MQLInfoInteger(MQL_TESTER) || (TerminalInfoInteger(TERMINAL_CONNECTED) &&
      TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && MQLInfoInteger(MQL_TRADE_ALLOWED) &&
      AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) && AccountInfoInteger(ACCOUNT_TRADE_EXPERT));
}

datetime Midnight(datetime now)
{
   MqlDateTime t;
   TimeToStruct(now,t); t.hour=0; t.min=0; t.sec=0;
   return StructToTime(t);
}

bool RiskState()
{
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   if((!MQLInfoInteger(MQL_TESTER) && !TerminalInfoInteger(TERMINAL_CONNECTED)) || !MathIsValidNumber(eq) ||
      (eq<=0 && !GlobalVariableCheck(K("peak"))) || TimeCurrent()<=0) return false;
   datetime day=Midnight(TimeCurrent());
   MqlDateTime t;
   TimeToStruct(day,t);
   datetime week=day-((t.day_of_week+6)%7)*86400;
   if(!GlobalVariableCheck(K("peak")) || eq>Read("peak")) Write("peak",eq);
   if(Read("day")!=(double)day)
   { Write("day",(double)day); Write("dayEq",eq); Write("dayLock",0); }
   if(Read("week")!=(double)week)
   { Write("week",(double)week); Write("weekEq",eq); Write("weekLock",0); }
   if(GoldDrawdownPct(Read("dayEq"),eq)>=3) Write("dayLock",1);
   if(GoldDrawdownPct(Read("weekEq"),eq)>=6) Write("weekLock",1);
   double dd=GoldDrawdownPct(Read("peak"),eq);
   if(dd>=8) Write("pause",1);
   if(dd>=10) Write("hard",1);
   return true;
}

double Budget()
{
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   double base=GoldRiskBudget(eq,InpRiskPercent,GoldDrawdownPct(Read("peak"),eq),5);
   return GoldBudgetWithinLimits(base,eq,Read("dayEq")*.97,Read("weekEq")*.94,Read("peak")*.90);
}

bool Managed(bool ok,string action)
{
   uint code=manager.ResultRetcode();
   if(ok && (code==TRADE_RETCODE_DONE || code==TRADE_RETCODE_DONE_PARTIAL || code==TRADE_RETCODE_NO_CHANGES)) return true;
   Note(StringFormat("%s failed: %u %s",action,code,manager.ResultRetcodeDescription()));
   return false;
}

bool RetryReady(ulong ticket,bool closing)
{
   string key=(closing ? "C" : "M")+(string)ticket;
   if(TimeCurrent()-(datetime)Read(key)<(closing ? 2 : 5)) return false;
   Write(key,(double)TimeCurrent());
   return true;
}

void CloseOwnPositions()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket>0 && OwnPosition() && RetryReady(ticket,true)) Managed(manager.PositionClose(ticket),"Risk exit");
   }
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong ticket=OrderGetTicket(i);
      if(ticket>0 && (ulong)OrderGetInteger(ORDER_MAGIC)==MAGIC && OrderGetString(ORDER_SYMBOL)==_Symbol)
         Managed(manager.OrderDelete(ticket),"Risk cancel");
   }
}

bool Exposure()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
      if(PositionGetTicket(i)>0 && (PositionGetString(POSITION_SYMBOL)==_Symbol || (ulong)PositionGetInteger(POSITION_MAGIC)==MAGIC)) return true;
   for(int i=OrdersTotal()-1;i>=0;i--)
      if(OrderGetTicket(i)>0 && (OrderGetString(ORDER_SYMBOL)==_Symbol || (ulong)OrderGetInteger(ORDER_MAGIC)==MAGIC)) return true;
   return false;
}

bool RequestSettled()
{
   if(Read("awaitRequest")<=0) return true;
   for(int i=PositionsTotal()-1;i>=0;i--)
      if(PositionGetTicket(i)>0 && OwnPosition()) { Write("awaitRequest",0); return true; }
   datetime requested=(datetime)Read("requestTime");
   if(!HistorySelect(requested,TimeCurrent())) return false;
   for(int i=0;i<HistoryDealsTotal();i++)
   {
      ulong deal=HistoryDealGetTicket(i);
      if((ulong)HistoryDealGetInteger(deal,DEAL_MAGIC)==MAGIC && HistoryDealGetString(deal,DEAL_SYMBOL)==_Symbol &&
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal,DEAL_ENTRY)==DEAL_ENTRY_IN)
      { Write("awaitRequest",0); return true; }
   }
   for(int i=0;i<HistoryOrdersTotal();i++)
   {
      ulong order=HistoryOrderGetTicket(i);
      if((ulong)HistoryOrderGetInteger(order,ORDER_MAGIC)!=MAGIC || HistoryOrderGetString(order,ORDER_SYMBOL)!=_Symbol ||
         (datetime)HistoryOrderGetInteger(order,ORDER_TIME_SETUP)<requested) continue;
      ENUM_ORDER_STATE state=(ENUM_ORDER_STATE)HistoryOrderGetInteger(order,ORDER_STATE);
      if(state==ORDER_STATE_REJECTED || state==ORDER_STATE_CANCELED || state==ORDER_STATE_EXPIRED)
      { Write("awaitRequest",0); return true; }
   }
   return false;
}

int EntryOrders(datetime since)
{
   if(!HistorySelect(since,TimeCurrent())) return -1;
   ulong ids[];
   for(int i=0;i<HistoryDealsTotal();i++)
   {
      ulong deal=HistoryDealGetTicket(i);
      if((ulong)HistoryDealGetInteger(deal,DEAL_MAGIC)!=MAGIC || HistoryDealGetString(deal,DEAL_SYMBOL)!=_Symbol ||
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal,DEAL_ENTRY)!=DEAL_ENTRY_IN) continue;
      ulong id=(ulong)HistoryDealGetInteger(deal,DEAL_ORDER);
      bool found=false;
      for(int j=0;j<ArraySize(ids);j++) if(ids[j]==id) { found=true; break; }
      if(!found) { int size=ArraySize(ids); ArrayResize(ids,size+1); ids[size]=id; }
   }
   return ArraySize(ids);
}

bool NewsBlock()
{
   if(MQLInfoInteger(MQL_TESTER) || !InpLiveNewsFilter) return false;
   datetime now=TimeCurrent();
   if(now-news_checked<30) return news_blocked;
   news_checked=now; news_blocked=true;
   MqlCalendarValue values[];
   int count=CalendarValueHistory(values,now-1800,now+1831,NULL,"USD");
   if(count<0) { Note("Calendar unavailable; live entries blocked, existing positions still managed."); return true; }
   for(int i=0;i<count;i++)
   {
      MqlCalendarEvent event;
      if(!CalendarEventById(values[i].event_id,event) || event.importance==CALENDAR_IMPORTANCE_HIGH) return true;
   }
   news_blocked=false;
   return false;
}

bool Value(int handle,int shift,double &value)
{
   double data[1];
   if(CopyBuffer(handle,0,shift,1,data)!=1 || !MathIsValidNumber(data[0]) || data[0]==EMPTY_VALUE) return false;
   value=data[0]; return true;
}

bool LoadBars(GASBars &b)
{
   if(BarsCalculated(slow15)<52 || BarsCalculated(ema5)<22 || BarsCalculated(atr5)<16 || BarsCalculated(rsi5)<10) return false;
   MqlRates rates[];
   ArraySetAsSeries(rates,true);
   if(CopyRates(_Symbol,PERIOD_M5,0,3,rates)!=3) return false;
   b.open=rates[1].open; b.high=rates[1].high; b.low=rates[1].low; b.close=rates[1].close; b.previous_close=rates[2].close;
   b.trend_close=iClose(_Symbol,PERIOD_M15,1);
   return Value(fast15,1,b.trend_fast) && Value(slow15,1,b.trend_slow) && Value(ema5,1,b.ema) && Value(ema5,2,b.previous_ema) &&
      Value(atr5,1,b.atr) && Value(rsi5,1,b.rsi) && Value(rsi5,2,b.previous_rsi) && GASValidBars(b);
}

class MT5Execution : public GASExecution
{
public:
   virtual bool Allowed(bool buy)
   {
      long mode=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE);
      long orders=SymbolInfoInteger(_Symbol,SYMBOL_ORDER_MODE);
      return OperationsAllowed() && (mode==SYMBOL_TRADE_MODE_FULL || (buy && mode==SYMBOL_TRADE_MODE_LONGONLY) ||
         (!buy && mode==SYMBOL_TRADE_MODE_SHORTONLY)) && (orders & SYMBOL_ORDER_MARKET)!=0 &&
         (orders & SYMBOL_ORDER_SL)!=0 && (orders & SYMBOL_ORDER_TP)!=0;
   }
   virtual double LossPerLot(bool buy,double entry,double stop)
   {
      double result=0,slippage=InpSlippagePoints*_Point;
      if(!OrderCalcProfit(buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,_Symbol,1.0,
         entry+(buy ? slippage : -slippage),stop+(buy ? -slippage : slippage),result)) return 0;
      return MathAbs(result)+InpCommissionPerLotRoundTurn;
   }
   virtual double MarginPerLot(bool buy,double entry)
   {
      double margin=0;
      if(!OrderCalcMargin(buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,_Symbol,1.0,entry,margin)) return 0;
      return margin;
   }
   virtual bool SendMarket(bool buy,double lots,double entry,double stop,double target)
   {
      MqlTradeRequest request={};
      MqlTradeCheckResult check={};
      MqlTradeResult result={};
      request.action=TRADE_ACTION_DEAL; request.symbol=_Symbol; request.magic=MAGIC;
      request.type=buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      request.volume=NormalizeDouble(lots,8); request.price=NormalizeDouble(entry,_Digits);
      if(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_EXEMODE)==SYMBOL_TRADE_EXECUTION_MARKET) request.price=0;
      request.sl=NormalizeDouble(stop,_Digits); request.tp=NormalizeDouble(target,_Digits);
      request.deviation=InpSlippagePoints; request.comment="GoldAutoScalp 2.00";
      long filling=SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);
      if((filling & SYMBOL_FILLING_FOK)!=0) request.type_filling=ORDER_FILLING_FOK;
      else if((filling & SYMBOL_FILLING_IOC)!=0) request.type_filling=ORDER_FILLING_IOC;
      else if(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_EXEMODE)!=SYMBOL_TRADE_EXECUTION_MARKET) request.type_filling=ORDER_FILLING_RETURN;
      else { Note("No supported market filling mode."); return false; }
      ResetLastError();
      if(!OrderCheck(request,check) || (check.retcode!=0 && check.retcode!=TRADE_RETCODE_DONE))
      { PrintFormat("GAS2 ORDER CHECK FAILED: retcode=%u comment=%s margin=%.2f free=%.2f error=%d",check.retcode,check.comment,check.margin,check.margin_free,GetLastError()); return false; }
      Write("requestStop",request.sl); Write("requestTime",(double)TimeCurrent()); Write("requestBuy",buy ? 1 : 0);
      Write("awaitRequest",1);
      bool ok=OrderSend(request,result);
      PrintFormat("GAS2 MARKET SEND: buy=%s lots=%.4f SL=%.5f TP=%.5f retcode=%u comment=%s deal=%I64u order=%I64u",
         buy ? "true" : "false",lots,stop,target,result.retcode,result.comment,result.deal,result.order);
      if(!ok || (result.retcode!=TRADE_RETCODE_DONE && result.retcode!=TRADE_RETCODE_DONE_PARTIAL && result.retcode!=TRADE_RETCODE_PLACED))
      {
         if(result.retcode!=0 && result.retcode!=TRADE_RETCODE_TIMEOUT && result.retcode!=TRADE_RETCODE_CONNECTION) Write("awaitRequest",0);
         return false;
      }
      if(result.order>0) Write("O"+(string)result.order,request.sl);
      if(result.deal>0) filled_deals++;
      return true;
   }
};

MT5Execution broker;

bool OriginalStop(ulong id,bool buy,datetime opened,double &stop,double &paid)
{
   stop=Read("S"+(string)id); paid=0;
   if(HistorySelectByPosition(id))
      for(int j=0;j<HistoryDealsTotal();j++)
      {
         ulong deal=HistoryDealGetTicket(j);
         if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal,DEAL_ENTRY)!=DEAL_ENTRY_IN) continue;
         paid+=MathMax(0.0,-HistoryDealGetDouble(deal,DEAL_COMMISSION))+MathMax(0.0,-HistoryDealGetDouble(deal,DEAL_FEE));
         if(stop>0) continue;
         ulong order=(ulong)HistoryDealGetInteger(deal,DEAL_ORDER);
         stop=Read("O"+(string)order);
         if(stop<=0) stop=OrderSelect(order) ? OrderGetDouble(ORDER_SL) : HistoryOrderGetDouble(order,ORDER_SL);
      }
   if(stop<=0 && opened>=(datetime)Read("requestTime") && opened<=(datetime)Read("requestTime")+120 &&
      Read("requestBuy")==(buy ? 1.0 : 0.0)) stop=Read("requestStop");
   if(stop>0) Write("S"+(string)id,stop);
   return stop>0;
}

void ManagePositions(MqlTick &tick)
{
   double tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   bool metadata_ok=MathIsValidNumber(tick_size) && tick_size>0;
   if(!metadata_ok) Note("Tick-size metadata unavailable; skip BE calculation, retain emergency exits.");
   double distance=(double)MathMax(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL))*_Point+tick_size;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !OwnPosition()) continue;
      bool buy=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY;
      ulong id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN),sl=PositionGetDouble(POSITION_SL),tp=PositionGetDouble(POSITION_TP);
      double volume=PositionGetDouble(POSITION_VOLUME),swap=PositionGetDouble(POSITION_SWAP);
      datetime opened=(datetime)PositionGetInteger(POSITION_TIME);
      double original=0,paid=0;
      if(!metadata_ok)
      {
         if((sl<=0 || tp<=0 || TimeCurrent()-opened>=3600) && RetryReady(ticket,true))
            Managed(manager.PositionClose(ticket),"Protection/time exit without tick metadata");
         continue;
      }
      if(TimeCurrent()-opened>=3600)
      { if(RetryReady(ticket,true)) Managed(manager.PositionClose(ticket),"Time exit"); continue; }
      if(!OriginalStop(id,buy,opened,original,paid))
      {
         if(sl>0 && tp>0 && TimeCurrent()-opened<15) { Note("Protected fill awaiting original-order metadata."); continue; }
         if(RetryReady(ticket,true)) Managed(manager.PositionClose(ticket),"Cannot recover original protection");
         continue;
      }
      double risk=buy ? entry-original : original-entry;
      if(risk<=0) { if(RetryReady(ticket,true)) Managed(manager.PositionClose(ticket),"Invalid original risk"); continue; }
      double desired_tp=NormalizeDouble(GoldPrice(entry+(buy ? 1 : -1)*InpRewardRisk*risk,tick_size,buy),_Digits);
      if(sl<=0 || tp<=0)
      {
         double recovered_sl=sl>0 ? sl : original;
         bool can_restore=buy ? recovered_sl<tick.bid-distance && desired_tp>tick.bid+distance
                              : recovered_sl>tick.ask+distance && desired_tp<tick.ask-distance;
         if(can_restore && RetryReady(ticket,false) && Managed(manager.PositionModify(ticket,recovered_sl,desired_tp),"Restore fill protection")) continue;
         if(RetryReady(ticket,true)) Managed(manager.PositionClose(ticket),"Emergency unprotected-position exit");
         continue;
      }
      if(GoldReachedOneR(buy,buy ? tick.bid : tick.ask,entry,risk)) Write("B"+(string)id,1);
      double new_sl=sl;
      if(Read("B"+(string)id)>0)
      {
         double profit_tick=0;
         if(OrderCalcProfit(buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,_Symbol,volume,entry,entry+(buy ? tick_size : -tick_size),profit_tick))
         {
            double costs=MathMax(InpCommissionPerLotRoundTurn*volume,2*paid)+MathMax(0.0,-swap);
            double be=NormalizeDouble(GoldBreakEven(buy,entry,costs,profit_tick,tick_size,2),_Digits);
            if(GoldImprovesStop(buy,sl,be,tick_size) && (buy ? be<tick.bid-distance && be<desired_tp : be>tick.ask+distance && be>desired_tp)) new_sl=be;
         }
      }
      bool tp_valid=buy ? desired_tp>tick.bid+distance : desired_tp<tick.ask-distance;
      double next_tp=tp_valid ? desired_tp : tp;
      if((MathAbs(new_sl-sl)>=tick_size*.5 || MathAbs(next_tp-tp)>=tick_size*.5) && RetryReady(ticket,false))
         Managed(manager.PositionModify(ticket,new_sl,next_tp),"BE/actual-fill RR update");
   }
}

void Run(bool allow_entry)
{
   if(!RiskState()) { Note("Account equity/time/connection not ready; risk baseline unchanged."); return; }
   if(!OperationsAllowed()) { Note("Trading permissions/connection unavailable; cannot send or modify orders."); return; }
   if(Read("dayLock")>0 || Read("weekLock")>0 || Read("hard")>0)
   { CloseOwnPositions(); Note("Daily/weekly/hard drawdown lock active."); return; }
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick) || !MathIsValidNumber(tick.bid) || !MathIsValidNumber(tick.ask) ||
      tick.bid<=0 || tick.ask<tick.bid || TimeCurrent()-tick.time>30) return;
   ManagePositions(tick);
   if(!allow_entry) return;
   datetime bar=iTime(_Symbol,PERIOD_M5,0);
   if(bar==0 || bar==last_bar) return;
   last_bar=bar;
   evaluated++;
   if(Read("pause")>0) { Note("DD8% pause; review required before reset."); return; }
   if(!RequestSettled()) { Note("Previous market request unconfirmed; no duplicate entry. Check broker history before resetting awaitRequest."); return; }
   if(Exposure()) { Note("Existing symbol/magic exposure; no additional position."); return; }
   int entries=EntryOrders((datetime)Read("day"));
   if(entries<0 || entries>=3) { Note("Daily filled-entry cap reached or trade history unavailable."); return; }
   if(NewsBlock()) { Note("Live USD news blackout."); return; }
   GASBars bars;
   if(!LoadBars(bars)) { data_skips++; Note("Waiting for M5/M15 history (EMA50 warmup)."); return; }
   GASQuote q;
   q.bid=tick.bid; q.ask=tick.ask; q.tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   q.minimum_stop=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;
   q.minimum_lot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN); q.maximum_lot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   q.lot_step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP); q.free_margin=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   GASPlan plan;
   double budget=Budget();
   GASResult result=GASProcess(bars,q,budget,InpMaxLots,InpRewardRisk,InpStopATR,InpMaxSpreadATR,.25,broker,plan);
   if(plan.direction!=0) signals++;
   if(result==GAS_SENT) sent_orders++;
   if(result==GAS_REJECTED) rejected++;
   if(result==GAS_RISK) risk_skips++;
   if(result==GAS_MARGIN) margin_skips++;
   if(result==GAS_SPREAD) spread_skips++;
   if(result==GAS_BAD_DATA) data_skips++;
   Note(StringFormat("%s: side=%d lot=%.4f SL=%.5f TP=%.5f risk_estimate=%.2f budget=%.2f (risk skip shows minimum-lot loss).",
      EnumToString(result),plan.direction,plan.lots,plan.stop,plan.target,plan.estimated_loss,budget));
}

int OnInit()
{
   if(InpRiskPercent<=0 || InpRiskPercent>2 || InpMaxLots<=0 || InpRewardRisk<2 || InpRewardRisk>5 ||
      InpStopATR<.5 || InpStopATR>3 || InpMaxSpreadATR<=0 || InpMaxSpreadATR>.5 ||
      InpCommissionPerLotRoundTurn<0 || InpSlippagePoints<0) return INIT_PARAMETERS_INCORRECT;
   string name=_Symbol; StringToUpper(name);
   if(StringFind(name,"XAU")<0 && StringFind(name,"GOLD")<0)
   { Print("GoldAutoScalp requires an XAU/GOLD symbol."); return INIT_PARAMETERS_INCORRECT; }
   if(!MQLInfoInteger(MQL_TESTER) && AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL && !InpAllowRealTrading)
   { Print("Real account disabled; validate on tester/demo first."); return INIT_PARAMETERS_INCORRECT; }
   prefix="GAS2."+(string)AccountInfoInteger(ACCOUNT_LOGIN)+"."+(string)MAGIC+".";
   if(MQLInfoInteger(MQL_TESTER)) GlobalVariablesDeleteAll(prefix);
   lock_key=K("instance");
   if(!GlobalVariableCheck(lock_key)) GlobalVariableTemp(lock_key);
   lock_token=(double)ChartID(); if(lock_token==0) lock_token=1;
   if(!GlobalVariableSetOnCondition(lock_key,lock_token,0))
   { Print("GoldAutoScalp already running for this account in this terminal."); return INIT_FAILED; }
   lock_owned=true;
   fast15=iMA(_Symbol,PERIOD_M15,20,0,MODE_EMA,PRICE_CLOSE); slow15=iMA(_Symbol,PERIOD_M15,50,0,MODE_EMA,PRICE_CLOSE);
   ema5=iMA(_Symbol,PERIOD_M5,20,0,MODE_EMA,PRICE_CLOSE); atr5=iATR(_Symbol,PERIOD_M5,14); rsi5=iRSI(_Symbol,PERIOD_M5,8,PRICE_CLOSE);
   if(fast15==INVALID_HANDLE || slow15==INVALID_HANDLE || ema5==INVALID_HANDLE || atr5==INVALID_HANDLE || rsi5==INVALID_HANDLE) return INIT_FAILED;
   manager.SetExpertMagicNumber(MAGIC); manager.SetTypeFillingBySymbol(_Symbol); manager.SetDeviationInPoints(InpSlippagePoints); manager.SetAsyncMode(false);
   RiskState(); run_start=TimeCurrent(); last_bar=iTime(_Symbol,PERIOD_M5,0);
   if(!EventSetTimer(5)) return INIT_FAILED;
   Print("GoldAutoScalp v2.00 READY — NO PRESET REQUIRED. M15 EMA20/50, M5 pullback/RSI8, MARKET orders, ATR stop, TP2R+, BE1R.");
   PrintFormat("GAS2 equity=%.2f %s risk=%.2f%% minlot=%.4f step=%.4f contract=%.2f; no fixed-hour gate, no swing/RR-obstacle veto.",
      AccountInfoDouble(ACCOUNT_EQUITY),AccountInfoString(ACCOUNT_CURRENCY),InpRiskPercent,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),
      SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP),SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE));
   if(MQLInfoInteger(MQL_TESTER)) Print("WARNING: tester baseline has NO NEWS FILTER; live/demo uses USD calendar unless explicitly disabled.");
   return INIT_SUCCEEDED;
}

void OnTick() { Run(true); }
void OnTimer() { Run(false); }
void OnDeinit(const int reason)
{
   EventKillTimer();
   if(lock_owned)
   {
      PrintFormat("GAS2 SUMMARY: bars=%I64u signals=%I64u sent_orders=%I64u response_deals=%I64u filled_entry_orders=%d rejected=%I64u risk_skips=%I64u margin_skips=%I64u spread_skips=%I64u data_skips=%I64u",
         evaluated,signals,sent_orders,filled_deals,EntryOrders(run_start),rejected,risk_skips,margin_skips,spread_skips,data_skips);
      GlobalVariableSetOnCondition(lock_key,0,lock_token); GlobalVariablesFlush();
   }
   if(fast15!=INVALID_HANDLE) IndicatorRelease(fast15);
   if(slow15!=INVALID_HANDLE) IndicatorRelease(slow15);
   if(ema5!=INVALID_HANDLE) IndicatorRelease(ema5);
   if(atr5!=INVALID_HANDLE) IndicatorRelease(atr5);
   if(rsi5!=INVALID_HANDLE) IndicatorRelease(rsi5);
}
