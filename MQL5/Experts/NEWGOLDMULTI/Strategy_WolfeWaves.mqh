#property strict
#include "StrategyTypes.mqh"

//------------------------------------------------------------------
// Wolfe Wave approximation
//
// Bullish Wolfe Wave: 5 swing points with descending highs and
//   lows (1-3-5 converging to a low at point 5).  Target = above
//   the 1-4 line projection.  Confirmed when price breaks above
//   the most-recent swing high.
//   EPA (Expected Price at Arrival) bonus: if the 1-4 line projects
//   a target above current price, award an extra +1 bull vote.
//
// Bearish Wolfe Wave: mirrored (ascending highs and lows, point 5
//   at a high, confirmed break below most-recent swing low).
//   EPA bonus: if target is below current price, award +1 bear vote.
//
// Uses proper swing detection (SwingHigh/SwingLow from
// StrategyTypes.mqh) instead of hardcoded bar indices.
//------------------------------------------------------------------
int SigWolfeWaves(StrategySignal &s, ENUM_TIMEFRAMES tf)
{
   MqlRates r[]; ArraySetAsSeries(r, true);
   if(!GetCachedRates(tf, 200, r) || ArraySize(r) < 150) return 0;

   int b = 0, se = 0;
   int nBars = 150;

   // --- Collect 5 alternating swing lows (for bullish Wolfe) ---
   int swL[5]; int nSL = 0;
   for(int i = 3; i < nBars - 3 && nSL < 5; i++)
   {
      if(i + 3 >= ArraySize(r)) break;
      bool isL = true;
      for(int j = 1; j <= 3 && isL; j++)
         if(r[i].low >= r[i-j].low || r[i].low >= r[i+j].low) isL = false;
      if(isL) swL[nSL++] = i;
   }

   // --- Collect 5 alternating swing highs (for bearish Wolfe) ---
   int swH[5]; int nSH = 0;
   for(int i = 3; i < nBars - 3 && nSH < 5; i++)
   {
      if(i + 3 >= ArraySize(r)) break;
      bool isH = true;
      for(int j = 1; j <= 3 && isH; j++)
         if(r[i].high <= r[i-j].high || r[i].high <= r[i+j].high) isH = false;
      if(isH) swH[nSH++] = i;
   }

   // --- Bullish Wolfe: descending swing lows converging to a bottom ---
   // swL[0] = most recent (point 5), swL[2] = point 3, swL[4] = oldest (point 1)
   // Pattern: lower lows forming a descending wedge; expect breakout UP.
   if(nSL >= 5
   && r[swL[0]].low < r[swL[2]].low   // point 5 is lowest (most recent)
   && r[swL[2]].low < r[swL[4]].low   // point 3 below point 1 → descending lows
   && nSH >= 1 && r[0].close > r[swH[0]].high)  // confirmed breakout above recent high
   {
      b = 2;

      // EPA line: project the 1-4 line (points at swL[4] and swL[1]) to current bar
      // Point 1 = swL[4], Point 4 = swL[1]
      int   p1bar = swL[4], p4bar = swL[1];
      double p1price = r[p1bar].low, p4price = r[p4bar].low;
      int   barSpan = p1bar - p4bar;  // bars from point4 to point1 (p1bar > p4bar in series)
      if(barSpan > 0)
      {
         // EPA slope (price change per bar, moving forward in time = decreasing bar index)
         double epaSlope = (p4price - p1price) / (double)barSpan;
         // Project to current bar (bar index 0 is barSpan bars ahead of p4bar)
         double epaTarget = p4price + epaSlope * (double)p4bar;
         if(epaTarget > r[0].close) b++;  // target above current price → upside potential
      }
   }

   // --- Bearish Wolfe: ascending swing highs (1 < 3 < 5) ---
   // swH[0] = point 5 (most recent, highest), swH[2] = point 3, swH[4] = point 1
   if(nSH >= 5
   && r[swH[0]].high > r[swH[2]].high  // point 5 is highest
   && r[swH[2]].high > r[swH[4]].high  // point 3 above point 1
   && nSL >= 1 && r[0].close < r[swL[0]].low)  // confirmed breakdown
   {
      se = 2;

      // EPA line for bearish: project the 1-4 line of swing highs
      int   p1bar = swH[4], p4bar = swH[1];
      double p1price = r[p1bar].high, p4price = r[p4bar].high;
      int   barSpan = p1bar - p4bar;
      if(barSpan > 0)
      {
         double epaSlope = (p4price - p1price) / (double)barSpan;
         double epaTarget = p4price + epaSlope * (double)p4bar;
         if(epaTarget < r[0].close) se++;  // target below current price → downside potential
      }
   }

   // Normalize to 0..5
   b  = MathMin(b,  5);
   se = MathMin(se, 5);

   if(b > 0 && b >= se)
      { s.direction = SIGNAL_BUY;  s.strength = b;  s.reason = "wolfe wave bullish"; }
   else if(se > 0 && se > b)
      { s.direction = SIGNAL_SELL; s.strength = se; s.reason = "wolfe wave bearish"; }
   return MathMax(b, se);
}

