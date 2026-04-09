#property strict
#include "StrategyTypes.mqh"

int SigSupportResistance(StrategySignal &s, ENUM_TIMEFRAMES tf)
{
   MqlRates r[]; ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, tf, 0, 220, r) < 120) return 0;

   // ATR-based proximity (replaces fixed percentage)
   int hATR = iATR(_Symbol, tf, 14);
   if(hATR < 0) return 0;
   double atr[]; ArraySetAsSeries(atr, true);
   bool ok = (CopyBuffer(hATR, 0, 0, 1, atr) >= 1);
   IndicatorRelease(hATR);
   if(!ok || atr[0] <= 0.0) return 0;
   double atrVal    = atr[0];
   double nearProx  = atrVal * 0.3;  // "near" a level = within 30% ATR
   double brkConfirm = atrVal * 0.15; // confirmed breakout = 15% ATR beyond level

   // Collect swing-based support and resistance levels
   double sups[10], ress[10]; int sc = 0, rc = 0;
   for(int i = 3; i < 110 && (sc < 10 || rc < 10); i++)
   {
      if(i + 2 >= ArraySize(r)) break;
      if(sc < 10
      && r[i].low < r[i-1].low && r[i].low < r[i+1].low
      && r[i].low < r[i-2].low && r[i].low < r[i+2].low)
         sups[sc++] = r[i].low;

      if(rc < 10
      && r[i].high > r[i-1].high && r[i].high > r[i+1].high
      && r[i].high > r[i-2].high && r[i].high > r[i+2].high)
         ress[rc++] = r[i].high;
   }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   int b = 0, se = 0;

   // Bullish: price at support with bullish confirmation candle
   for(int i = 0; i < sc; i++)
   {
      if(MathAbs(bid - sups[i]) < nearProx && r[0].close >= r[0].open)
      { b++; break; }
   }
   // Bearish: price at resistance with bearish confirmation candle
   for(int i = 0; i < rc; i++)
   {
      if(MathAbs(ask - ress[i]) < nearProx && r[0].close <= r[0].open)
      { se++; break; }
   }
   // Bullish: confirmed breakout above resistance
   for(int i = 0; i < rc; i++)
   {
      if(r[0].close > ress[i] + brkConfirm && r[1].close <= ress[i])
      { b++; break; }
   }
   // Bearish: confirmed breakout below support
   for(int i = 0; i < sc; i++)
   {
      if(r[0].close < sups[i] - brkConfirm && r[1].close >= sups[i])
      { se++; break; }
   }

   // Normalize to 0..5
   b  = MathMin(b,  5);
   se = MathMin(se, 5);

   if(b > 0 && b >= se)
      { s.direction = SIGNAL_BUY;  s.strength = b;  s.reason = "support resistance buy"; }
   else if(se > 0 && se > b)
      { s.direction = SIGNAL_SELL; s.strength = se; s.reason = "support resistance sell"; }
   return MathMax(b, se);
}

