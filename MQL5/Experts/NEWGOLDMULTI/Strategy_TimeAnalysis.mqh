#property strict
#include "StrategyTypes.mqh"

//------------------------------------------------------------------
// Time Analysis — session-based filter
//
// Only participates in voting during active trading sessions
// (London and/or New York).  Returns SIGNAL_NONE outside those
// windows so it never adds noise when markets are quiet.
//
// Strength is built from multiple confirming factors:
//   1. Consecutive-bar momentum on closed bars.
//   2. Strong-body candle in the direction.
//   3. London–NY overlap bonus (highest quality window) — requires
//      at least 2 out of 3 momentum signals to agree.
//
// Session times assume broker server is at GMT+0 to GMT+2.
// Adjust via InpTimeGMTOffset if your broker differs.
//------------------------------------------------------------------
int SigTimeAnalysis(StrategySignal &s, ENUM_TIMEFRAMES tf)
{
   MqlDateTime t; TimeToStruct(TimeCurrent(), t);

   // Asian session avoidance: no trading during quiet Asian hours
   if(t.hour >= 0 && t.hour < 7) return 0;

   MqlRates r[]; ArraySetAsSeries(r, true);
   if(!GetCachedRates(tf, 10, r) || ArraySize(r) < 5) return 0;

   // News/spike filter: if current bar range > 3×ATR → abnormal bar, skip
   int hATR = IndGet_ATR(tf, 14);
   if(hATR != INVALID_HANDLE)
   {
      double atr[]; ArraySetAsSeries(atr, true);
      if(CopyBuffer(hATR, 0, 0, 1, atr) >= 1 && atr[0] > 0.0)
      {
         double currentRange = r[0].high - r[0].low;
         if(currentRange > 3.0 * atr[0]) return 0;
      }
   }

   // Session windows — high-momentum open hours only (broker server time)
   bool londonActive  = (t.hour >= 7  && t.hour < 12);   // 07:00–11:59 (London Open momentum)
   bool nyActive      = (t.hour >= 13 && t.hour < 18);   // 13:00–17:59 (NY Open momentum)
   bool overlapActive = (t.hour >= 13 && t.hour < 16);   // 13:00–15:59 (true London-NY overlap)

   // Abstain outside main sessions
   if(!londonActive && !nyActive) return 0;

   // Avoid the high-risk Friday afternoon close
   if(t.day_of_week == 5 && t.hour >= 18) return 0;

   int b = 0, se = 0;

   // Count the 3 individual momentum signals separately for the overlap quality check
   int mBull = 0, mBear = 0;
   // Signal 1: r[1] vs r[2] close-to-close momentum
   if(r[1].close > r[2].close) mBull++; else if(r[1].close < r[2].close) mBear++;
   // Signal 2: r[2] vs r[3] close-to-close momentum
   if(r[2].close > r[3].close) mBull++; else if(r[2].close < r[3].close) mBear++;
   // Signal 3: bar-body quality of the last closed bar
   double body  = MathAbs(r[1].close - r[1].open);
   double range = r[1].high - r[1].low;
   if(range > 0.0 && body >= 0.5 * range)
   {
      if(r[1].close > r[1].open) mBull++;
      else                       mBear++;
   }

   // Award votes based on individual signals
   b  += mBull;
   se += mBear;

   // London–NY overlap (13:00–15:59): award bonus only when at least 2 of 3
   // specific momentum signals agree in the leading direction
   if(overlapActive)
   {
      if(mBull >= 2 && mBull > mBear) b++;
      else if(mBear >= 2 && mBear > mBull) se++;
   }

   // Normalize to 0..5
   b  = MathMin(b,  5);
   se = MathMin(se, 5);

   if(b > se && b > 0)
      { s.direction = SIGNAL_BUY;  s.strength = b;  s.reason = "time session bullish"; }
   else if(se > b && se > 0)
      { s.direction = SIGNAL_SELL; s.strength = se; s.reason = "time session bearish"; }
   return MathMax(b, se);
}

