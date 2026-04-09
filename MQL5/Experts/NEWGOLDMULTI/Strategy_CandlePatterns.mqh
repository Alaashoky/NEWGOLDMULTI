#property strict
#include "StrategyTypes.mqh"

bool CP_BullPin(MqlRates &r){double b=MathAbs(r.close-r.open),u=r.high-MathMax(r.open,r.close),l=MathMin(r.open,r.close)-r.low,t=r.high-r.low;return l>2*b&&l>u&&l>0.6*t;}
bool CP_BearPin(MqlRates &r){double b=MathAbs(r.close-r.open),u=r.high-MathMax(r.open,r.close),l=MathMin(r.open,r.close)-r.low,t=r.high-r.low;return u>2*b&&u>l&&u>0.6*t;}
bool CP_Hammer(MqlRates &r){return CP_BullPin(r)&&r.close>r.open;}
bool CP_Shooting(MqlRates &r){return CP_BearPin(r)&&r.close<r.open;}
bool CP_BullEng(MqlRates &c,MqlRates &p){return p.close<p.open&&c.close>c.open&&c.close>=p.open&&c.open<=p.close;}
bool CP_BearEng(MqlRates &c,MqlRates &p){return p.close>p.open&&c.close<c.open&&c.open>=p.open&&c.close<=p.close;}

int SigCandlePatterns(StrategySignal &s, ENUM_TIMEFRAMES tf)
{
   MqlRates r[]; ArraySetAsSeries(r,true); if(CopyRates(_Symbol,tf,0,10,r)<3) return 0;
   int b=0,se=0;
   if(CP_BullPin(r[0])) b++; if(CP_BearPin(r[0])) se++;
   if(CP_Hammer(r[0])) b++; if(CP_Shooting(r[0])) se++;
   if(CP_BullEng(r[0],r[1])) b++; if(CP_BearEng(r[0],r[1])) se++;
   if(r[0].high<r[1].high&&r[0].low>r[1].low&&r[0].close>r[0].open) b++;
   if(r[0].high<r[1].high&&r[0].low>r[1].low&&r[0].close<r[0].open) se++;
   if(r[2].close<r[2].open&&MathAbs(r[1].close-r[1].open)<MathAbs(r[2].close-r[2].open)*0.5&&r[0].close>r[0].open) b++; // morning star approx
   if(r[2].close>r[2].open&&MathAbs(r[1].close-r[1].open)<MathAbs(r[2].close-r[2].open)*0.5&&r[0].close<r[0].open) se++; // evening star approx
   if(r[2].close>r[2].open&&r[1].close>r[1].open&&r[0].close>r[0].open&&r[1].close>r[2].close&&r[0].close>r[1].close) b++;
   if(r[2].close<r[2].open&&r[1].close<r[1].open&&r[0].close<r[0].open&&r[1].close<r[2].close&&r[0].close<r[1].close) se++;

   if(b>0&&b>=se){s.direction=SIGNAL_BUY;s.strength=b;s.reason="candle pattern buy";}
   else if(se>0&&se>b){s.direction=SIGNAL_SELL;s.strength=se;s.reason="candle pattern sell";}
   return MathMax(b,se);
}
