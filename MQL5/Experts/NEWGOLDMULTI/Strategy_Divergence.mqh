#property strict
#include "StrategyTypes.mqh"

int SigDivergence(StrategySignal &s, ENUM_TIMEFRAMES tf)
{
   MqlRates r[]; ArraySetAsSeries(r,true); if(CopyRates(_Symbol,tf,0,80,r)<30) return 0;
   int hRSI=iRSI(_Symbol,tf,14,PRICE_CLOSE), hMACD=iMACD(_Symbol,tf,12,26,9,PRICE_CLOSE);
   if(hRSI<0||hMACD<0) return 0;
   double rsi[80], macd[80]; ArraySetAsSeries(rsi,true);ArraySetAsSeries(macd,true);
   bool ok=CopyBuffer(hRSI,0,0,80,rsi)>=30 && CopyBuffer(hMACD,0,0,80,macd)>=30; IndicatorRelease(hRSI);IndicatorRelease(hMACD); if(!ok) return 0;

   int b=0,se=0;
   // simple 2-swing divergence approximation
   int low1=2,low2=12,high1=2,high2=12;
   for(int i=2;i<25;i++){ if(r[i].low<r[low1].low) low1=i; if(r[i].high>r[high1].high) high1=i; }
   for(int i=25;i<60;i++){ if(r[i].low<r[low2].low) low2=i; if(r[i].high>r[high2].high) high2=i; }

   if(r[low1].low<r[low2].low && rsi[low1]>rsi[low2]) b++; // RSI bullish div
   if(r[low1].low<r[low2].low && macd[low1]>macd[low2]) b++; // MACD bullish div
   if(r[high1].high>r[high2].high && rsi[high1]<rsi[high2]) se++; // RSI bearish div
   if(r[high1].high>r[high2].high && macd[high1]<macd[high2]) se++; // MACD bearish div

   if(b>0&&b>=se){s.direction=SIGNAL_BUY;s.strength=b;s.reason="divergence buy";}
   else if(se>0&&se>b){s.direction=SIGNAL_SELL;s.strength=se;s.reason="divergence sell";}
   return MathMax(b,se);
}
