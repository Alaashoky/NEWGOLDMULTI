#property strict
#include "StrategyTypes.mqh"

int SigTimeAnalysis(StrategySignal &s, ENUM_TIMEFRAMES tf)
{
   MqlDateTime t; TimeToStruct(TimeCurrent(), t);
   MqlRates r[]; ArraySetAsSeries(r,true); if(CopyRates(_Symbol,tf,0,120,r)<100) return 0;

   int b=0,se=0;
   // Key hours from source style (GMT broker time dependent)
   if(t.hour==8||t.hour==12||t.hour==14||t.hour==16||t.hour==20) { b++; se++; }

   // Monday/Friday significance
   if(t.day_of_week==1) b++;
   if(t.day_of_week==5) se++;

   // Repeated cycle approximation (interval similarities)
   int idxH1=10, idxH2=30, idxH3=50;
   long d1=(long)(r[idxH1].time-r[idxH2].time), d2=(long)(r[idxH2].time-r[idxH3].time);
   if(MathAbs(d1-d2)<3600) { b++; se++; }

   // Fib-time inspired check based on recent swing duration
   long base=(long)(r[10].time-r[30].time);
   long proj=(long)(base*1.618);
   if(MathAbs((long)(r[0].time-r[10].time)-proj)<3600) { b++; se++; }

   // assign direction by latest candle momentum
   if(b>0||se>0)
   {
      if(r[0].close>=r[1].close){ s.direction=SIGNAL_BUY; s.strength=b; s.reason="time window bullish bias"; }
      else { s.direction=SIGNAL_SELL; s.strength=se; s.reason="time window bearish bias"; }
   }
   return MathMax(b,se);
}
