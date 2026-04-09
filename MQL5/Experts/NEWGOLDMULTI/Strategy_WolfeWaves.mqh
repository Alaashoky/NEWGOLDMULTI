#property strict
#include "StrategyTypes.mqh"

int SigWolfeWaves(StrategySignal &s, ENUM_TIMEFRAMES tf)
{
   MqlRates r[]; ArraySetAsSeries(r,true); if(CopyRates(_Symbol,tf,0,140,r)<100) return 0;
   // 5-point approximate structure using sampled swings
   double p1=r[90].low, p2=r[75].high, p3=r[60].low, p4=r[45].high, p5=r[30].low;
   int b=0,se=0;

   // Bullish Wolfe approximation: 1-3-5 descending lows and breakout above 2-4 line area
   if(p1>p3 && p3>p5 && r[0].close>r[20].high) b=2;

   // Bearish Wolfe approximation: mirrored highs
   double q1=r[90].high, q2=r[75].low, q3=r[60].high, q4=r[45].low, q5=r[30].high;
   if(q1<q3 && q3<q5 && r[0].close<r[20].low) se=2;

   if(b>0&&b>=se){s.direction=SIGNAL_BUY;s.strength=b;s.reason="wolfe wave bullish";}
   else if(se>0&&se>b){s.direction=SIGNAL_SELL;s.strength=se;s.reason="wolfe wave bearish";}
   return MathMax(b,se);
}
