#property strict
#include "StrategyTypes.mqh"

const double SR_NEAR_PCT = 0.01;
const double SR_BREAK_ABOVE = 1.01;
const double SR_BREAK_BELOW = 0.99;

int SigSupportResistance(StrategySignal &s, ENUM_TIMEFRAMES tf)
{
   MqlRates r[]; ArraySetAsSeries(r,true); if(CopyRates(_Symbol,tf,0,220,r)<120) return 0;
   double sups[10], ress[10]; int sc=0, rc=0;
   for(int i=10;i<100 && sc<10;i++) if(r[i].low<r[i-1].low&&r[i].low<r[i+1].low&&r[i].low<r[i-2].low&&r[i].low<r[i+2].low) sups[sc++]=r[i].low;
   for(int i=10;i<100 && rc<10;i++) if(r[i].high>r[i-1].high&&r[i].high>r[i+1].high&&r[i].high>r[i-2].high&&r[i].high>r[i+2].high) ress[rc++]=r[i].high;

   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   int b=0,se=0;
   for(int i=0;i<sc;i++) if(MathAbs(bid-sups[i])<SR_NEAR_PCT*bid && bid>sups[i]){b++;break;}
   for(int i=0;i<rc;i++) if(MathAbs(ask-ress[i])<SR_NEAR_PCT*ask && ask<ress[i]){se++;break;}
   for(int i=0;i<rc;i++) if(bid>ress[i] && bid<ress[i]*SR_BREAK_ABOVE){b++;break;}
   for(int i=0;i<sc;i++) if(ask<sups[i] && ask>sups[i]*SR_BREAK_BELOW){se++;break;}

   if(b>0&&b>=se){s.direction=SIGNAL_BUY;s.strength=b;s.reason="support resistance buy";}
   else if(se>0&&se>b){s.direction=SIGNAL_SELL;s.strength=se;s.reason="support resistance sell";}
   return MathMax(b,se);
}
