#property strict
#include "StrategyTypes.mqh"

int SigMACrossover(StrategySignal &s, ENUM_TIMEFRAMES tf, int fastP, int slowP, int longP, int minConf)
{
   int hf=iMA(_Symbol,tf,fastP,0,MODE_EMA,PRICE_CLOSE), hs=iMA(_Symbol,tf,slowP,0,MODE_EMA,PRICE_CLOSE), hl=iMA(_Symbol,tf,longP,0,MODE_EMA,PRICE_CLOSE);
   if(hf<0||hs<0||hl<0) return 0;
   double f[],sl[],lg[]; ArraySetAsSeries(f,true);ArraySetAsSeries(sl,true);ArraySetAsSeries(lg,true);
   MqlRates r[]; ArraySetAsSeries(r,true);
   bool ok=CopyRates(_Symbol,tf,0,longP+5,r)>=longP+2 && CopyBuffer(hf,0,0,3,f)>=3 && CopyBuffer(hs,0,0,3,sl)>=3 && CopyBuffer(hl,0,0,2,lg)>=1;
   IndicatorRelease(hf);IndicatorRelease(hs);IndicatorRelease(hl);
   if(!ok) return 0;

   int b=0,se=0;
   if(f[0]>sl[0]&&f[1]<=sl[1]) b++;
   if(f[0]<sl[0]&&f[1]>=sl[1]) se++;
   if(r[0].close>lg[0]) b++;
   if(r[0].close<lg[0]) se++;
   if(f[0]>f[1]&&f[1]>f[2]) b++;
   if(f[0]<f[1]&&f[1]<f[2]) se++;

   if(b>=minConf&&b>=se){s.direction=SIGNAL_BUY;s.strength=b;s.reason="ma crossover buy";}
   else if(se>=minConf&&se>b){s.direction=SIGNAL_SELL;s.strength=se;s.reason="ma crossover sell";}
   return MathMax(b,se);
}
