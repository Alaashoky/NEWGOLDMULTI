#property strict
#include "StrategyTypes.mqh"

int SigSupportResistance(StrategySignal &s, ENUM_TIMEFRAMES tf)
{
   MqlRates r[]; ArraySetAsSeries(r, true);
   if(!GetCachedRates(tf, 220, r) || ArraySize(r) < 120) return 0;

   // ATR-based proximity (replaces fixed percentage)
   int hATR = IndGet_ATR(tf, 14);
   if(hATR == INVALID_HANDLE) return 0;
   double atr[]; ArraySetAsSeries(atr, true);
   if(CopyBuffer(hATR, 0, 0, 1, atr) < 1 || atr[0] <= 0.0) return 0;
   double atrVal    = atr[0];
   double nearProx  = atrVal * 0.3;  // "near" a level = within 30% ATR
   double brkConfirm = atrVal * 0.15; // confirmed breakout = 15% ATR beyond level
   double touchProx = atrVal * 0.3;  // touch zone for strength counting

   // Collect swing-based support and resistance levels with age and strength
   double sups[10], ress[10];
   int    supBar[10], resBar[10];   // bar index of swing (for age decay)
   int    supStrength[10], resStrength[10];
   int sc = 0, rc = 0;

   for(int i = 3; i < 110 && (sc < 10 || rc < 10); i++)
   {
      if(i + 2 >= ArraySize(r)) break;
      if(sc < 10
      && r[i].low < r[i-1].low && r[i].low < r[i+1].low
      && r[i].low < r[i-2].low && r[i].low < r[i+2].low)
      {
         sups[sc]      = r[i].low;
         supBar[sc]    = i;
         // Count touches in 200-bar window
         int touches = 0;  // count price touches within 100-bar window
         for(int k = 1; k < 100 && k < ArraySize(r); k++)
            if(MathAbs(r[k].low - r[i].low) <= touchProx
            || MathAbs(r[k].high - r[i].low) <= touchProx
            || MathAbs(r[k].close - r[i].low) <= touchProx)
               touches++;
         supStrength[sc] = MathMin(touches, 3);
         sc++;
      }

      if(rc < 10
      && r[i].high > r[i-1].high && r[i].high > r[i+1].high
      && r[i].high > r[i-2].high && r[i].high > r[i+2].high)
      {
         ress[rc]      = r[i].high;
         resBar[rc]    = i;
         int touches = 0;  // count price touches within 100-bar window
         for(int k = 1; k < 100 && k < ArraySize(r); k++)
            if(MathAbs(r[k].high - r[i].high) <= touchProx
            || MathAbs(r[k].low - r[i].high) <= touchProx
            || MathAbs(r[k].close - r[i].high) <= touchProx)
               touches++;
         resStrength[rc] = MathMin(touches, 3);
         rc++;
      }
   }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   int b = 0, se = 0;

   // Helper: age weight — full weight for bars 3..30, half for 31..80, zero for older
   #define AGE_WEIGHT(barIdx) ((barIdx) <= 30 ? 1.0 : ((barIdx) <= 80 ? 0.5 : 0.0))

   // Bullish: price at support with bullish confirmation candle
   for(int i = 0; i < sc; i++)
   {
      if(supStrength[i] < 2) continue;          // only strong levels
      if(AGE_WEIGHT(supBar[i]) <= 0.0) continue; // too old
      if(MathAbs(bid - sups[i]) < nearProx && r[0].close >= r[0].open)
      { b++; break; }
   }
   // Bearish: price at resistance with bearish confirmation candle
   for(int i = 0; i < rc; i++)
   {
      if(resStrength[i] < 2) continue;
      if(AGE_WEIGHT(resBar[i]) <= 0.0) continue;
      if(MathAbs(ask - ress[i]) < nearProx && r[0].close <= r[0].open)
      { se++; break; }
   }
   // Bullish: confirmed breakout above resistance
   for(int i = 0; i < rc; i++)
   {
      if(resStrength[i] < 2) continue;
      if(AGE_WEIGHT(resBar[i]) <= 0.0) continue;
      if(r[0].close > ress[i] + brkConfirm && r[1].close <= ress[i])
      { b++; break; }
   }
   // Bearish: confirmed breakout below support
   for(int i = 0; i < sc; i++)
   {
      if(supStrength[i] < 2) continue;
      if(AGE_WEIGHT(supBar[i]) <= 0.0) continue;
      if(r[0].close < sups[i] - brkConfirm && r[1].close >= sups[i])
      { se++; break; }
   }

   #undef AGE_WEIGHT

   // Normalize to 0..5
   b  = MathMin(b,  5);
   se = MathMin(se, 5);

   if(b > 0 && b >= se)
      { s.direction = SIGNAL_BUY;  s.strength = b;  s.reason = "support resistance buy"; }
   else if(se > 0 && se > b)
      { s.direction = SIGNAL_SELL; s.strength = se; s.reason = "support resistance sell"; }
   return MathMax(b, se);
}
