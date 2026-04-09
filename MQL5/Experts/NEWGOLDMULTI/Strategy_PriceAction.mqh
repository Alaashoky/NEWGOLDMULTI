#property strict
#include "StrategyTypes.mqh"

int SigPriceAction(StrategySignal &s, ENUM_TIMEFRAMES tf)
{
   MqlRates r[]; ArraySetAsSeries(r,true); if(CopyRates(_Symbol,tf,0,60,r)<30) return 0;
   int b=0,se=0;

   double hi=0, lo=DBL_MAX;
   for(int i=1;i<=10;i++){if(r[i].high>hi)hi=r[i].high;if(r[i].low<lo)lo=r[i].low;}
   if(r[0].close>hi) b++; // breakout resistance
   if(r[0].close<lo) se++; // breakout support

   int hl=0,hh=0,ll=0,lh=0;
   double pl=r[9].low, ph=r[9].high;
   for(int i=8;i>=0;i-=2){ if(r[i].low>pl){hl++;pl=r[i].low;} if(r[i].low<pl){ll++;pl=r[i].low;} if(r[i].high>ph){hh++;ph=r[i].high;} if(r[i].high<ph){lh++;ph=r[i].high;} }
   if(hl>=2||hh>=2) b++;
   if(ll>=2||lh>=2) se++;

   // trendline breakout approx via last 3 swing highs/lows
   if(r[0].close>r[1].high && r[1].high>r[2].high) b++;
   if(r[0].close<r[1].low  && r[1].low<r[2].low)   se++;

   // active support/resistance hold
   if(r[0].close>r[0].open && r[0].low<=lo*1.002) b++;
   if(r[0].close<r[0].open && r[0].high>=hi*0.998) se++;

   if(b>0&&b>=se){s.direction=SIGNAL_BUY;s.strength=b;s.reason="price action buy";}
   else if(se>0&&se>b){s.direction=SIGNAL_SELL;s.strength=se;s.reason="price action sell";}
   return MathMax(b,se);
}
