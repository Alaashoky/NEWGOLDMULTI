#property strict
#include "StrategyTypes.mqh"

int SigChartPatterns(StrategySignal &s, ENUM_TIMEFRAMES tf)
{
   MqlRates r[]; ArraySetAsSeries(r,true); if(CopyRates(_Symbol,tf,0,120,r)<80) return 0;
   int b=0,se=0;

   // Double bottom / double top approximation
   double lowA=r[40].low, lowB=r[20].low, highA=r[40].high, highB=r[20].high;
   if(MathAbs(lowA-lowB)<=30*_Point && r[0].close>r[10].high) b++;
   if(MathAbs(highA-highB)<=30*_Point && r[0].close<r[10].low) se++;

   // Wedge breakout approximation
   if(r[0].close>r[1].high && r[1].high<r[2].high && r[2].high<r[3].high) b++;
   if(r[0].close<r[1].low  && r[1].low >r[2].low  && r[2].low >r[3].low ) se++;

   // Head and shoulders / inverse H&S approximation
   if(r[30].high>r[20].high && r[30].high>r[40].high && r[0].close<MathMin(r[20].low,r[40].low)) se++;
   if(r[30].low <r[20].low  && r[30].low <r[40].low  && r[0].close>MathMax(r[20].high,r[40].high)) b++;

   if(b>0&&b>=se){s.direction=SIGNAL_BUY;s.strength=b;s.reason="chart pattern bullish";}
   else if(se>0&&se>b){s.direction=SIGNAL_SELL;s.strength=se;s.reason="chart pattern bearish";}
   return MathMax(b,se);
}
