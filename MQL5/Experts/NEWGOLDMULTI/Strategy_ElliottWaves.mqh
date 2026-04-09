#property strict
#include "StrategyTypes.mqh"

int SigElliottWaves(StrategySignal &s, ENUM_TIMEFRAMES tf)
{
   MqlRates r[]; ArraySetAsSeries(r,true); if(CopyRates(_Symbol,tf,0,120,r)<80) return 0;
   // Approximate 5-wave impulse detection using alternating swing sequence
   int b=0,se=0;
   bool bullishImpulse = (r[60].low < r[50].low && r[50].high < r[40].high && r[40].low > r[30].low && r[30].high < r[20].high && r[20].low > r[10].low && r[0].close > r[20].high);
   bool bearishImpulse = (r[60].high > r[50].high && r[50].low > r[40].low && r[40].high < r[30].high && r[30].low > r[20].low && r[20].high < r[10].high && r[0].close < r[20].low);
   if(bullishImpulse) b = 2;
   if(bearishImpulse) se = 2;

   // ABC correction completion approximation
   if(r[8].low < r[16].low && r[4].close > r[8].high) b++;
   if(r[8].high > r[16].high && r[4].close < r[8].low) se++;

   if(b>0&&b>=se){s.direction=SIGNAL_BUY;s.strength=b;s.reason="elliott wave bullish";}
   else if(se>0&&se>b){s.direction=SIGNAL_SELL;s.strength=se;s.reason="elliott wave bearish";}
   return MathMax(b,se);
}
