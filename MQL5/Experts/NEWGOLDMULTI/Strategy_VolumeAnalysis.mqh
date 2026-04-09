#property strict
#include "StrategyTypes.mqh"

const double VA_SPIKE_MULTIPLIER = 2.0;

int SigVolumeAnalysis(StrategySignal &s, ENUM_TIMEFRAMES tf)
{
   MqlRates r[]; ArraySetAsSeries(r,true); if(CopyRates(_Symbol,tf,0,60,r)<30) return 0;
   long v[]; ArraySetAsSeries(v,true); if(CopyTickVolume(_Symbol,tf,0,60,v)<30) return 0;

   int b=0,se=0;
   // Rising volume with bullish closes
   if(v[0]>v[1]&&v[1]>v[2]&&r[0].close>r[0].open&&r[1].close>r[1].open) b++;
   // Rising volume with bearish closes
   if(v[0]>v[1]&&v[1]>v[2]&&r[0].close<r[0].open&&r[1].close<r[1].open) se++;

   // Volume spike near breakout
   double avg=0.0; for(int i=5;i<25;i++) avg+=(double)v[i]; avg/=20.0;
   if(v[0] > avg*VA_SPIKE_MULTIPLIER && r[0].close>r[10].high) b++;
   if(v[0] > avg*VA_SPIKE_MULTIPLIER && r[0].close<r[10].low ) se++;

   // Simple OBV-like direction
   long obv=0; for(int i=20;i>=1;i--){ if(r[i-1].close>r[i].close) obv+=v[i-1]; else if(r[i-1].close<r[i].close) obv-=v[i-1]; }
   if(obv>0) b++; else if(obv<0) se++;

   if(b>0&&b>=se){s.direction=SIGNAL_BUY;s.strength=b;s.reason="volume bullish";}
   else if(se>0&&se>b){s.direction=SIGNAL_SELL;s.strength=se;s.reason="volume bearish";}
   return MathMax(b,se);
}
