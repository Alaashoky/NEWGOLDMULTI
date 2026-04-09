#property strict
#include "StrategyTypes.mqh"

//------------------------------------------------------------------
// Elliott Wave approximation
// Uses proper swing high/low detection to identify:
//   Bullish: 3 rising swing lows (higher lows = impulsive structure)
//            + price above most-recent swing high (wave 5 / breakout)
//   Bearish: 3 falling swing highs (lower highs)
//            + price below most-recent swing low
//
// This is a simplified, deterministic approximation — not a full
// Elliott wave counter.  Clearly documented as such.
//------------------------------------------------------------------
int SigElliottWaves(StrategySignal &s, ENUM_TIMEFRAMES tf)
{
   MqlRates r[]; ArraySetAsSeries(r, true);
   if(!GetCachedRates(tf, 150, r) || ArraySize(r) < 100) return 0;

   int b = 0, se = 0;
   int nBars = 100;

   // --- Bullish impulse: 3 rising swing lows ---
   int sl[3]; int nSL = 0;
   for(int i = 2; i < nBars - 2 && nSL < 3; i++)
   {
      if(i + 2 >= ArraySize(r)) break;
      if(r[i].low < r[i-1].low && r[i].low < r[i+1].low
      && r[i].low < r[i-2].low && r[i].low < r[i+2].low)
         sl[nSL++] = i;
   }
   if(nSL >= 3
   && r[sl[0]].low > r[sl[1]].low   // most-recent swing low > previous
   && r[sl[1]].low > r[sl[2]].low)  // previous > oldest → rising lows
   {
      b++;
      // Extra confirmation: recent close above the most-recent swing high
      int sh1 = SwingHigh(r, 2, sl[0] - 1, 2);
      if(sh1 >= 0 && r[0].close > r[sh1].high) b++;
   }

   // --- Bearish impulse: 3 falling swing highs ---
   int sh[3]; int nSH = 0;
   for(int i = 2; i < nBars - 2 && nSH < 3; i++)
   {
      if(i + 2 >= ArraySize(r)) break;
      if(r[i].high > r[i-1].high && r[i].high > r[i+1].high
      && r[i].high > r[i-2].high && r[i].high > r[i+2].high)
         sh[nSH++] = i;
   }
   if(nSH >= 3
   && r[sh[0]].high < r[sh[1]].high
   && r[sh[1]].high < r[sh[2]].high)
   {
      se++;
      int sl1 = SwingLow(r, 2, sh[0] - 1, 2);
      if(sl1 >= 0 && r[0].close < r[sl1].low) se++;
   }

   // Normalize to 0..5
   b  = MathMin(b,  5);
   se = MathMin(se, 5);

   if(b > 0 && b >= se)
      { s.direction = SIGNAL_BUY;  s.strength = b;  s.reason = "elliott wave bullish"; }
   else if(se > 0 && se > b)
      { s.direction = SIGNAL_SELL; s.strength = se; s.reason = "elliott wave bearish"; }
   return MathMax(b, se);
}

