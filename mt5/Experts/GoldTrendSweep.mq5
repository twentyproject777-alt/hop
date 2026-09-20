#property strict
#property version   "1.00"
#property description "XAUUSD H1/M15 trend, M5 sweep/structure/RSI; risk-capped, BE at 1R."

#include <Trade\Trade.mqh>
#include <GoldRiskMath.mqh>

enum ENUM_GOLD_NEWS_MODE { NEWS_MT5_CALENDAR=0, NEWS_MANUAL_TIMES=1, NEWS_DISABLED=2 };

input group "Safety and sizing"
input bool   InpAllowRealTrading=false;
input ulong  InpMagic=26092001;
input double InpRiskPercent=0.25;
input double InpDailyLossPercent=1.0;
input double InpWeeklyLossPercent=3.0;
input double InpReduceRiskDrawdown=5.0;
input double InpPauseDrawdown=8.0;
input double InpHardDrawdown=10.0;
input int    InpMaxEntriesPerDay=3;
input double InpMaxMarginPercent=20.0;
input double InpMaxLots=1.0;

input group "Execution and exits"
input double InpRewardRisk=2.0;
input double InpCommissionPerLotRoundTurn=7.0; // Account currency; verify with broker.
input int    InpSlippageReservePoints=30;
input int    InpBEExtraTicks=2;
input double InpMaxCostFraction=0.10;
input int    InpPendingBars=3;
input int    InpMaxHoldingMinutes=60;

input group "Signal (closed candles only)"
input bool   InpUseRSI=true;
input int    InpRSIPeriod=8;
input int    InpEMAPeriod=200;
input int    InpEMASlopeBars=3;
input int    InpATRPeriod=14;
input int    InpPivotWidth=2;
input int    InpSwingLookback=100;
input int    InpConfirmBars=3;
input double InpMinBodyATR=0.8;
input double InpStopBufferATR=0.2;
input double InpM15ZoneToleranceM5ATR=0.5;
input double InpMaxRangeATR=3.0;

input group "Trading hours (broker server time, adjust DST manually)"
input int    InpSessionStartHour=8;
input int    InpSessionEndHour=18;

input group "News (no calendar in Strategy Tester)"
input ENUM_GOLD_NEWS_MODE InpNewsMode=NEWS_MT5_CALENDAR;
input int    InpNewsMinutesBefore=30;
input int    InpNewsMinutesAfter=30;
input string InpManualNewsTimes=""; // Server timestamps: YYYY.MM.DD HH:MI;...

CTrade trade;
int ema_handle=INVALID_HANDLE,atr_handle=INVALID_HANDLE,rsi_handle=INVALID_HANDLE;
string prefix,instance_key;
datetime manual_news[],last_bar=0,last_news_check=0;
bool cached_news_block=true,instance_owned=false;
double instance_token=0;
int setup_direction=0,setup_age=0;
double setup_extreme=0,setup_break=0;

string Key(string suffix) { return prefix+suffix; }
double State(string suffix) { return GlobalVariableGet(Key(suffix)); }
void Save(string suffix,double value)
{
   string key=Key(suffix);
   if(GlobalVariableCheck(key) && GlobalVariableGet(key)==value) return;
   GlobalVariableSet(key,value);
   GlobalVariablesFlush();
}

bool OwnPosition()
{
   return (ulong)PositionGetInteger(POSITION_MAGIC)==InpMagic && PositionGetString(POSITION_SYMBOL)==_Symbol;
}

bool OwnOrder()
{
   return (ulong)OrderGetInteger(ORDER_MAGIC)==InpMagic && OrderGetString(ORDER_SYMBOL)==_Symbol;
}

bool TradeSucceeded(bool sent,string action)
{
   uint code=trade.ResultRetcode();
   if(sent && (code==TRADE_RETCODE_DONE || code==TRADE_RETCODE_PLACED || code==TRADE_RETCODE_DONE_PARTIAL))
      return true;
   PrintFormat("%s failed: %u %s",action,code,trade.ResultRetcodeDescription());
   return false;
}

datetime DayStart(datetime now)
{
   MqlDateTime parts;
   TimeToStruct(now,parts);
   parts.hour=0; parts.min=0; parts.sec=0;
   return StructToTime(parts);
}

datetime WeekStart(datetime now)
{
   MqlDateTime parts;
   TimeToStruct(now,parts);
   return DayStart(now)-((parts.day_of_week+6)%7)*86400;
}

void UpdateRiskState()
{
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   datetime now=TimeCurrent(),day=DayStart(now),week=WeekStart(now);
   if(!GlobalVariableCheck(Key("peak"))) Save("peak",equity);
   if(equity>State("peak")) Save("peak",equity);
   if(State("day")!=(double)day)
   {
      Save("day",(double)day); Save("dayEquity",equity); Save("dayLock",0);
   }
   if(State("week")!=(double)week)
   {
      Save("week",(double)week); Save("weekEquity",equity); Save("weekLock",0);
   }
   if(GoldDrawdownPct(State("dayEquity"),equity)>=InpDailyLossPercent) Save("dayLock",1);
   if(GoldDrawdownPct(State("weekEquity"),equity)>=InpWeeklyLossPercent) Save("weekLock",1);
   double dd=GoldDrawdownPct(State("peak"),equity);
   if(dd>=InpPauseDrawdown) Save("pause",1);
   if(dd>=InpHardDrawdown) Save("hard",1);
}

bool RiskLocked()
{
   return State("dayLock")>0 || State("weekLock")>0 || State("pause")>0 || State("hard")>0;
}

double AvailableRiskBudget()
{
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   double budget=GoldRiskBudget(equity,InpRiskPercent,GoldDrawdownPct(State("peak"),equity),InpReduceRiskDrawdown);
   return GoldBudgetWithinLimits(budget,equity,State("dayEquity")*(1-InpDailyLossPercent/100.0),
      State("weekEquity")*(1-InpWeeklyLossPercent/100.0),State("peak")*(1-InpHardDrawdown/100.0));
}

bool SessionOpen(datetime now)
{
   MqlDateTime parts;
   TimeToStruct(now,parts);
   if(parts.day_of_week==0 || parts.day_of_week==6) return false;
   if(InpSessionStartHour<InpSessionEndHour)
      return parts.hour>=InpSessionStartHour && parts.hour<InpSessionEndHour;
   return parts.hour>=InpSessionStartHour || parts.hour<InpSessionEndHour;
}

bool NewsBlocked()
{
   if(InpNewsMode==NEWS_DISABLED) return false;
   datetime now=TimeCurrent();
   if(InpNewsMode==NEWS_MANUAL_TIMES)
   {
      for(int i=0;i<ArraySize(manual_news);i++)
         if(now>=manual_news[i]-InpNewsMinutesBefore*60 && now<=manual_news[i]+InpNewsMinutesAfter*60)
            return true;
      return false;
   }
   if(now-last_news_check<30) return cached_news_block;
   last_news_check=now;
   cached_news_block=true;
   MqlCalendarValue values[];
   // Include the cache horizon so polling never delays the start of a blackout.
   int count=CalendarValueHistory(values,now-InpNewsMinutesAfter*60,now+InpNewsMinutesBefore*60+31,NULL,"USD");
   if(count<0)
   {
      PrintFormat("News calendar unavailable (%d); entries blocked.",GetLastError());
      return true;
   }
   for(int i=0;i<count;i++)
   {
      MqlCalendarEvent event;
      if(!CalendarEventById(values[i].event_id,event)) return true;
      if(event.importance==CALENDAR_IMPORTANCE_HIGH) return true;
   }
   cached_news_block=false;
   return false;
}

bool LoadRates(ENUM_TIMEFRAMES timeframe,MqlRates &rates[])
{
   ArraySetAsSeries(rates,true);
   int count=InpSwingLookback+2*InpPivotWidth+10;
   return CopyRates(_Symbol,timeframe,0,count,rates)==count;
}

bool IndicatorValue(int handle,int shift,double &value)
{
   double buffer[1];
   if(CopyBuffer(handle,0,shift,1,buffer)!=1 || !MathIsValidNumber(buffer[0]) || buffer[0]==EMPTY_VALUE)
      return false;
   value=buffer[0];
   return true;
}

bool Pivot(MqlRates &rates[],int index,bool high)
{
   for(int j=1;j<=InpPivotWidth;j++)
   {
      if(high && (rates[index].high<=rates[index-j].high || rates[index].high<=rates[index+j].high)) return false;
      if(!high && (rates[index].low>=rates[index-j].low || rates[index].low>=rates[index+j].low)) return false;
   }
   return true;
}

bool TwoSwings(MqlRates &rates[],bool high,int newest_allowed,double &first,double &second)
{
   int found=0;
   for(int i=newest_allowed;i<ArraySize(rates)-InpPivotWidth && i<=InpSwingLookback;i++)
   {
      if(!Pivot(rates,i,high)) continue;
      double value=high ? rates[i].high : rates[i].low;
      if(found++==0) first=value;
      else { second=value; return true; }
   }
   return false;
}

int Trend(double &support,double &resistance)
{
   if(BarsCalculated(ema_handle)<InpEMAPeriod+InpEMASlopeBars+2) return 0;
   double current_ema,previous_ema;
   if(!IndicatorValue(ema_handle,1,current_ema) || !IndicatorValue(ema_handle,1+InpEMASlopeBars,previous_ema)) return 0;
   double close=iClose(_Symbol,PERIOD_H1,1);
   MqlRates rates[];
   if(close<=0 || !LoadRates(PERIOD_M15,rates)) return 0;
   double high1,high2,low1,low2;
   if(!TwoSwings(rates,true,1+InpPivotWidth,high1,high2) || !TwoSwings(rates,false,1+InpPivotWidth,low1,low2)) return 0;
   support=low1; resistance=high1;
   if(close>current_ema && current_ema>previous_ema && high1>high2 && low1>low2) return 1;
   if(close<current_ema && current_ema<previous_ema && high1<high2 && low1<low2) return -1;
   return 0;
}

bool AnyExposure()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(PositionGetTicket(i)==0) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol || (ulong)PositionGetInteger(POSITION_MAGIC)==InpMagic) return true;
   }
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(OrderGetTicket(i)==0) continue;
      if(OrderGetString(ORDER_SYMBOL)==_Symbol || (ulong)OrderGetInteger(ORDER_MAGIC)==InpMagic) return true;
   }
   return false;
}

int EntriesToday()
{
   if(!HistorySelect((datetime)State("day"),TimeCurrent())) return InpMaxEntriesPerDay;
   ulong orders[];
   for(int i=0;i<HistoryDealsTotal();i++)
   {
      ulong deal=HistoryDealGetTicket(i);
      if((ulong)HistoryDealGetInteger(deal,DEAL_MAGIC)!=InpMagic) continue;
      ENUM_DEAL_ENTRY entry=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal,DEAL_ENTRY);
      if(entry!=DEAL_ENTRY_IN && entry!=DEAL_ENTRY_INOUT) continue;
      ulong order=(ulong)HistoryDealGetInteger(deal,DEAL_ORDER);
      bool seen=false;
      for(int j=0;j<ArraySize(orders);j++) if(orders[j]==order) { seen=true; break; }
      if(!seen) { int n=ArraySize(orders); ArrayResize(orders,n+1); orders[n]=order; }
   }
   return ArraySize(orders);
}

double TickSize() { return SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE); }
double Price(double value,bool up) { return NormalizeDouble(GoldPrice(value,TickSize(),up),_Digits); }

double LossPerLot(bool buy,double entry,double stop,bool include_slippage)
{
   double profit=0;
   double exit=stop+(include_slippage ? (buy ? -1 : 1)*InpSlippageReservePoints*_Point : 0);
   if(!OrderCalcProfit(buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,_Symbol,1.0,entry,exit,profit) ||
      !MathIsValidNumber(profit)) return 0;
   return MathAbs(profit)+(include_slippage ? InpCommissionPerLotRoundTurn : 0);
}

bool CostsAcceptable(bool buy,double entry,double stop,MqlTick &tick)
{
   double loss=LossPerLot(buy,entry,stop,false),spread_profit=0;
   if(loss<=0 || !OrderCalcProfit(buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,_Symbol,1.0,
      buy ? tick.ask : tick.bid,buy ? tick.bid : tick.ask,spread_profit) || !MathIsValidNumber(spread_profit)) return false;
   double reserve=LossPerLot(buy,entry,stop,true)-loss;
   return (MathAbs(spread_profit)+reserve)/loss<=InpMaxCostFraction;
}

void CancelOrders()
{
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong ticket=OrderGetTicket(i);
      if(ticket!=0 && OwnOrder()) TradeSucceeded(trade.OrderDelete(ticket),"Cancel pending");
   }
}

void ClosePositions()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket!=0 && OwnPosition()) TradeSucceeded(trade.PositionClose(ticket),"Risk/time exit");
   }
}

bool PositionHistory(ulong id,double &original_stop,double &paid_costs)
{
   original_stop=0; paid_costs=0;
   if(!HistorySelectByPosition(id)) return false;
   for(int i=0;i<HistoryDealsTotal();i++)
   {
      ulong deal=HistoryDealGetTicket(i);
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal,DEAL_ENTRY)!=DEAL_ENTRY_IN) continue;
      paid_costs+=MathMax(0.0,-HistoryDealGetDouble(deal,DEAL_COMMISSION))+MathMax(0.0,-HistoryDealGetDouble(deal,DEAL_FEE));
      ulong order=(ulong)HistoryDealGetInteger(deal,DEAL_ORDER);
      double stop=OrderSelect(order) ? OrderGetDouble(ORDER_SL) : HistoryOrderGetDouble(order,ORDER_SL);
      if(stop<=0 && GlobalVariableCheck(Key("S"+(string)order))) stop=State("S"+(string)order);
      if(original_stop==0 && stop>0) original_stop=stop;
   }
   return original_stop>0;
}

void ManageBreakEven(MqlTick &tick)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !OwnPosition()) continue;
      // Cancel unfilled remainder after a partial fill; never layer entries.
      CancelOrders();
      bool buy=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY;
      double entry=PositionGetDouble(POSITION_PRICE_OPEN),sl=PositionGetDouble(POSITION_SL),tp=PositionGetDouble(POSITION_TP);
      double volume=PositionGetDouble(POSITION_VOLUME),swap=PositionGetDouble(POSITION_SWAP);
      ulong id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      datetime opened=(datetime)PositionGetInteger(POSITION_TIME);
      if(sl<=0 || tp<=0 || TimeCurrent()-opened>=InpMaxHoldingMinutes*60)
      {
         TradeSucceeded(trade.PositionClose(ticket),"Missing protection/time exit");
         continue;
      }
      string risk_key="R"+(string)id,armed_key="B"+(string)id;
      double original_stop=0,paid=0;
      bool history_ok=PositionHistory(id,original_stop,paid);
      if(!history_ok && GlobalVariableCheck(Key(risk_key)))
      {
         double saved_risk=State(risk_key);
         if(saved_risk>0) { original_stop=entry+(buy ? -saved_risk : saved_risk); history_ok=true; }
      }
      if(!history_ok)
      {
         // Never reconstruct initial R from an already moved stop.
         TradeSucceeded(trade.PositionClose(ticket),"Cannot recover original risk");
         continue;
      }
      double initial_risk=buy ? entry-original_stop : original_stop-entry;
      if(initial_risk>0) Save(risk_key,initial_risk);
      if(initial_risk<=0)
      {
         TradeSucceeded(trade.PositionClose(ticket),"Invalid initial risk");
         continue;
      }
      if(GoldReachedOneR(buy,buy ? tick.bid : tick.ask,entry,initial_risk)) Save(armed_key,1);
      if(State(armed_key)<1) continue;
      double profit_tick=0;
      if(!OrderCalcProfit(buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,_Symbol,volume,entry,entry+(buy ? 1 : -1)*TickSize(),profit_tick)) continue;
      double costs=MathMax(InpCommissionPerLotRoundTurn*volume,2.0*paid)+MathMax(0.0,-swap);
      double be=NormalizeDouble(GoldBreakEven(buy,entry,costs,profit_tick,TickSize(),InpBEExtraTicks),_Digits);
      if(!GoldImprovesStop(buy,sl,be,TickSize())) continue;
      double distance=(double)MathMax(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL))*_Point+TickSize();
      if(buy ? (be>=tick.bid-distance || be>=tp) : (be<=tick.ask+distance || be<=tp)) continue;
      TradeSucceeded(trade.PositionModify(ticket,be,tp),"Break-even at 1R");
   }
}

void ValidatePending(MqlTick &tick)
{
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong ticket=OrderGetTicket(i);
      if(ticket==0 || !OwnOrder()) continue;
      bool buy=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)==ORDER_TYPE_BUY_LIMIT;
      double entry=OrderGetDouble(ORDER_PRICE_OPEN),sl=OrderGetDouble(ORDER_SL);
      double volume=OrderGetDouble(ORDER_VOLUME_CURRENT);
      double budget=AvailableRiskBudget();
      if((buy ? tick.bid<=sl : tick.ask>=sl) || !CostsAcceptable(buy,entry,sl,tick) || volume*LossPerLot(buy,entry,sl,true)>budget+0.01)
         TradeSucceeded(trade.OrderDelete(ticket),"Invalidated pending");
   }
}

void PlaceSetup(int direction,MqlRates &bar,double atr,double obstacle,MqlTick &tick)
{
   bool buy=direction>0;
   double entry=Price((bar.open+bar.close)/2.0,!buy);
   double stop=Price(setup_extreme+(buy ? -1 : 1)*InpStopBufferATR*atr,!buy);
   double risk=buy ? entry-stop : stop-entry;
   if(risk<=0) return;
   double target=Price(entry+(buy ? 1 : -1)*InpRewardRisk*risk,buy);
   double distance=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point+TickSize();
   if(risk<distance || (buy ? entry>=tick.ask-distance : entry<=tick.bid+distance)) return;
   if(buy ? obstacle<=target+tick.ask-tick.bid : obstacle>=target-(tick.ask-tick.bid)) return;
   if(!CostsAcceptable(buy,entry,stop,tick)) return;
   double budget=AvailableRiskBudget();
   double lots=GoldVolume(budget,LossPerLot(buy,entry,stop,true),SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),
                          MathMin(InpMaxLots,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX)),SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP));
   lots=NormalizeDouble(lots,8);
   if(lots<=0) return;
   double margin=0;
   if(!OrderCalcMargin(buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,_Symbol,lots,entry,margin) || margin<=0 ||
      margin>AccountInfoDouble(ACCOUNT_MARGIN_FREE)*InpMaxMarginPercent/100.0) return;
   long expiration=SymbolInfoInteger(_Symbol,SYMBOL_EXPIRATION_MODE);
   if((expiration & SYMBOL_EXPIRATION_SPECIFIED)==0)
   {
      Print("Broker lacks exact server-side pending expiration; setup skipped.");
      return;
   }
   datetime expires=iTime(_Symbol,PERIOD_M5,0)+InpPendingBars*PeriodSeconds(PERIOD_M5);
   trade.SetTypeFilling(ORDER_FILLING_RETURN);
   bool sent=buy ? trade.BuyLimit(lots,entry,_Symbol,stop,target,ORDER_TIME_SPECIFIED,expires,"GoldTrendSweep")
                 : trade.SellLimit(lots,entry,_Symbol,stop,target,ORDER_TIME_SPECIFIED,expires,"GoldTrendSweep");
   if(TradeSucceeded(sent,"Place retracement limit") && trade.ResultOrder()>0)
      Save("S"+(string)trade.ResultOrder(),stop);
   trade.SetTypeFillingBySymbol(_Symbol);
}

void ProcessBar(MqlTick &tick)
{
   double support=0,resistance=0;
   int direction=Trend(support,resistance);
   // A pending setup is no longer valid if its higher-timeframe direction changes.
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong ticket=OrderGetTicket(i);
      if(ticket==0 || !OwnOrder()) continue;
      int order_direction=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)==ORDER_TYPE_BUY_LIMIT ? 1 : -1;
      if(direction!=order_direction) TradeSucceeded(trade.OrderDelete(ticket),"Trend changed");
   }
   if(direction==0 || AnyExposure()) { setup_direction=0; return; }
   MqlRates rates[];
   double atr=0;
   if(!LoadRates(PERIOD_M5,rates) || !IndicatorValue(atr_handle,2,atr) || atr<=0) return;
   if(rates[1].high-rates[1].low>InpMaxRangeATR*atr) { setup_direction=0; return; }
   if(setup_direction!=0)
   {
      setup_age++;
      if(direction!=setup_direction || setup_age>InpConfirmBars ||
         (direction>0 ? rates[1].low<setup_extreme : rates[1].high>setup_extreme)) setup_direction=0;
      else
      {
         bool confirmation=direction>0 ? (rates[1].close>setup_break && rates[1].close>rates[1].open)
                                       : (rates[1].close<setup_break && rates[1].close<rates[1].open);
         if(confirmation)
         {
            bool momentum=MathAbs(rates[1].close-rates[1].open)>=InpMinBodyATR*atr;
            if(InpUseRSI)
            {
               double rsi=0,previous=0;
               momentum=momentum && IndicatorValue(rsi_handle,1,rsi) && IndicatorValue(rsi_handle,2,previous);
               momentum=momentum && (direction>0 ? rsi>50 && rsi>previous : rsi<50 && rsi<previous);
            }
            if(momentum) PlaceSetup(direction,rates[1],atr,direction>0 ? resistance : support,tick);
            setup_direction=0;
            return;
         }
      }
   }
   if(setup_direction!=0) return;
   double high1,high2,low1,low2;
   // These pivots must already have been confirmed BEFORE the sweep candle.
   if(!TwoSwings(rates,true,2+InpPivotWidth,high1,high2) || !TwoSwings(rates,false,2+InpPivotWidth,low1,low2)) return;
   bool sweep=direction>0 ? rates[1].low<low1 && rates[1].close>low1
                           : rates[1].high>high1 && rates[1].close<high1;
   double extreme=direction>0 ? rates[1].low : rates[1].high;
   double zone=direction>0 ? support : resistance;
   if(sweep && MathAbs(extreme-zone)<=InpM15ZoneToleranceM5ATR*atr)
   {
      setup_direction=direction; setup_age=0; setup_extreme=extreme;
      setup_break=direction>0 ? high1 : low1;
   }
}

void Run(bool allow_signal)
{
   UpdateRiskState();
   if(State("dayLock")>0 || State("weekLock")>0 || State("hard")>0)
   {
      setup_direction=0; CancelOrders(); ClosePositions(); return;
   }
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick) || tick.bid<=0 || tick.ask<tick.bid) return;
   if(TimeCurrent()-tick.time>30) { setup_direction=0; CancelOrders(); return; }
   ManageBreakEven(tick);
   bool blocked=RiskLocked() || !SessionOpen(TimeCurrent()) || NewsBlocked() || EntriesToday()>=InpMaxEntriesPerDay;
   if(blocked) { setup_direction=0; CancelOrders(); return; }
   ValidatePending(tick);
   if(!allow_signal) return;
   datetime bar=iTime(_Symbol,PERIOD_M5,0);
   if(bar==0 || bar==last_bar) return;
   datetime previous=last_bar;
   last_bar=bar;
   if(previous==0 || bar-previous>PeriodSeconds(PERIOD_M5)) { setup_direction=0; return; }
   ProcessBar(tick);
}

bool ValidInputs()
{
   return InpMagic>0 && InpRiskPercent>0 && InpRiskPercent<=1.0 &&
      InpDailyLossPercent>=InpRiskPercent && InpDailyLossPercent<=3.0 &&
      InpWeeklyLossPercent>InpDailyLossPercent && InpWeeklyLossPercent<=6.0 &&
      InpReduceRiskDrawdown>0 && InpPauseDrawdown>InpReduceRiskDrawdown &&
      InpHardDrawdown>InpPauseDrawdown && InpHardDrawdown<=20.0 &&
      InpRewardRisk>=2.0 && InpRewardRisk<=5.0 && InpMaxEntriesPerDay>=1 && InpMaxEntriesPerDay<=10 &&
      InpMaxMarginPercent>0 && InpMaxMarginPercent<=30 && InpMaxLots>0 &&
      InpCommissionPerLotRoundTurn>=0 && InpSlippageReservePoints>=0 && InpBEExtraTicks>=0 &&
      InpMaxCostFraction>0 && InpMaxCostFraction<=0.3 && InpPendingBars>=1 && InpPendingBars<=6 &&
      InpMaxHoldingMinutes>=5 && InpMaxHoldingMinutes<=240 &&
      InpRSIPeriod>=2 && InpEMAPeriod>=20 && InpEMASlopeBars>=1 && InpATRPeriod>=2 &&
      InpPivotWidth>=1 && InpPivotWidth<=10 && InpSwingLookback>=20 && InpSwingLookback<=1000 &&
      InpConfirmBars>=1 && InpConfirmBars<=10 && InpMinBodyATR>0 && InpStopBufferATR>0 &&
      InpM15ZoneToleranceM5ATR>0 && InpMaxRangeATR>InpMinBodyATR &&
      InpSessionStartHour>=0 && InpSessionStartHour<=23 && InpSessionEndHour>=0 && InpSessionEndHour<=23 &&
      InpSessionStartHour!=InpSessionEndHour && InpNewsMinutesBefore>=1 && InpNewsMinutesAfter>=1;
}

int OnInit()
{
   if(!ValidInputs()) { Print("Invalid or unsafe inputs."); return INIT_PARAMETERS_INCORRECT; }
   if(StringFind(_Symbol,"XAU")<0 || _Period!=PERIOD_M5)
   { Print("Attach to an XAU symbol, M5 chart (suffixes supported)."); return INIT_PARAMETERS_INCORRECT; }
   if(AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL && !InpAllowRealTrading)
   { Print("Live trading disabled. Validate on demo first."); return INIT_PARAMETERS_INCORRECT; }
   if(MQLInfoInteger(MQL_TESTER) && InpNewsMode==NEWS_MT5_CALENDAR)
   { Print("Tester has no calendar: supply manual news timestamps or explicitly disable news for a baseline test."); return INIT_PARAMETERS_INCORRECT; }
   if(InpNewsMode==NEWS_MANUAL_TIMES)
   {
      string parts[];
      int n=StringSplit(InpManualNewsTimes,';',parts);
      if(n<1) { Print("Manual news mode requires timestamps."); return INIT_PARAMETERS_INCORRECT; }
      ArrayResize(manual_news,n);
      for(int i=0;i<n;i++)
      {
         StringTrimLeft(parts[i]); StringTrimRight(parts[i]);
         manual_news[i]=StringToTime(parts[i]);
         if(StringLen(parts[i])!=16 || TimeToString(manual_news[i],TIME_DATE|TIME_MINUTES)!=parts[i])
         { Print("Invalid news timestamp: ",parts[i]); return INIT_PARAMETERS_INCORRECT; }
      }
   }
   prefix="GTS."+(string)AccountInfoInteger(ACCOUNT_LOGIN)+"."+(string)InpMagic+".";
   // Tester runs must never inherit terminal risk state from another pass.
   if(MQLInfoInteger(MQL_TESTER)) GlobalVariablesDeleteAll(prefix);
   instance_key=Key("instance");
   if(!GlobalVariableCheck(instance_key)) GlobalVariableTemp(instance_key);
   instance_token=(double)ChartID();
   if(instance_token==0) instance_token=1;
   if(!GlobalVariableSetOnCondition(instance_key,instance_token,0))
   { Print("This account/magic already has an EA instance in this terminal."); return INIT_FAILED; }
   instance_owned=true;
   ema_handle=iMA(_Symbol,PERIOD_H1,InpEMAPeriod,0,MODE_EMA,PRICE_CLOSE);
   atr_handle=iATR(_Symbol,PERIOD_M5,InpATRPeriod);
   rsi_handle=iRSI(_Symbol,PERIOD_M5,InpRSIPeriod,PRICE_CLOSE);
   if(ema_handle==INVALID_HANDLE || atr_handle==INVALID_HANDLE || rsi_handle==INVALID_HANDLE) return INIT_FAILED;
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippageReservePoints);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetAsyncMode(false);
   UpdateRiskState();
   GlobalVariablesFlush();
   last_bar=iTime(_Symbol,PERIOD_M5,0);
   if(!EventSetTimer(5)) return INIT_FAILED;
   Print("GoldTrendSweep initialized. Risk state prefix: ",prefix,"; commission is in account currency.");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   // Do not leave an unattended limit order when the strategy is removed.
   if(instance_owned)
   {
      CancelOrders();
      GlobalVariableSetOnCondition(instance_key,0,instance_token);
      GlobalVariablesFlush();
   }
   if(ema_handle!=INVALID_HANDLE) IndicatorRelease(ema_handle);
   if(atr_handle!=INVALID_HANDLE) IndicatorRelease(atr_handle);
   if(rsi_handle!=INVALID_HANDLE) IndicatorRelease(rsi_handle);
}

void OnTick() { Run(true); }
void OnTimer() { Run(false); }
