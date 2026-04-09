#property strict
#include "StrategyTypes.mqh"

int SigSupportResistance(StrategySignal &s, ENUM_TIMEFRAMES tf)
{
   MqlRates r[]; ArraySetAsSeries(r,true); if(CopyRates(_Symbol,tf,0,220,r)<120) return 0;
   double sups[10], ress[10]; int sc=0, rc=0;
   for(int i=10;i<100 && sc<10;i++) if(r[i].low<r[i-1].low&&r[i].low<r[i+1].low&&r[i].low<r[i-2].low&&r[i].low<r[i+2].low) sups[sc++]=r[i].low;
   for(int i=10;i<100 && rc<10;i++) if(r[i].high>r[i-1].high&&r[i].high>r[i+1].high&&r[i].high>r[i-2].high&&r[i].high>r[i+2].high) ress[rc++]=r[i].high;

   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   int b=0,se=0;
   for(int i=0;i<sc;i++) if(MathAbs(bid-sups[i])<0.01*bid && bid>sups[i]){b++;break;}
   for(int i=0;i<rc;i++) if(MathAbs(ask-ress[i])<0.01*ask && ask<ress[i]){se++;break;}
   for(int i=0;i<rc;i++) if(bid>ress[i] && bid<ress[i]*1.01){b++;break;}
   for(int i=0;i<sc;i++) if(ask<sups[i] && ask>sups[i]*0.99){se++;break;}

   if(b>0&&b>=se){s.direction=SIGNAL_BUY;s.strength=b;s.reason="support resistance buy";}
   else if(se>0&&se>b){s.direction=SIGNAL_SELL;s.strength=se;s.reason="support resistance sell";}
   return MathMax(b,se);
}
