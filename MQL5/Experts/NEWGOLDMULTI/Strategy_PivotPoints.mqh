#property strict
#include "StrategyTypes.mqh"

int SigPivotPoints(StrategySignal &s, ENUM_TIMEFRAMES signalTf)
{
   MqlRates d[]; ArraySetAsSeries(d,true); if(CopyRates(_Symbol,PERIOD_D1,1,1,d)<1) return 0;
   double H=d[0].high, L=d[0].low, C=d[0].close;
   double pp=(H+L+C)/3.0, r1=2*pp-L, s1=2*pp-H, r2=pp+(H-L), s2=pp-(H-L);

   MqlRates r[]; ArraySetAsSeries(r,true); if(CopyRates(_Symbol,signalTf,0,3,r)<2) return 0;
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double prox=200*_Point;
   int b=0,se=0;
   if(MathAbs(bid-s1)<=prox||MathAbs(bid-s2)<=prox) b++;
   if(MathAbs(ask-r1)<=prox||MathAbs(ask-r2)<=prox) se++;
   if(r[0].close>pp&&r[1].close<=pp) b++;
   if(r[0].close<pp&&r[1].close>=pp) se++;

   if(b>0&&b>=se){s.direction=SIGNAL_BUY;s.strength=b;s.reason="pivot buy";}
   else if(se>0&&se>b){s.direction=SIGNAL_SELL;s.strength=se;s.reason="pivot sell";}
   return MathMax(b,se);
}
