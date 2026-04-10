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
//   3. London–NY overlap bonus (highest quality window).
//
// Session times assume broker server is at GMT+0 to GMT+2.
// Adjust via InpTimeGMTOffset if your broker differs.
//------------------------------------------------------------------
int SigTimeAnalysis(StrategySignal &s, ENUM_TIMEFRAMES tf)
{
   MqlDateTime t; TimeToStruct(TimeCurrent(), t);

   MqlRates r[]; ArraySetAsSeries(r, true);
   if(!GetCachedRates(tf, 10, r) || ArraySize(r) < 5) return 0;

   // Session windows — high-momentum open hours only (broker server time)
   bool londonActive  = (t.hour >= 7  && t.hour < 12);   // 07:00–11:59 (London Open momentum)
   bool nyActive      = (t.hour >= 13 && t.hour < 18);   // 13:00–17:59 (NY Open momentum)
   bool overlapActive = (t.hour >= 13 && t.hour < 16);   // 13:00–15:59 (true London-NY overlap)

   // Abstain outside main sessions
   if(!londonActive && !nyActive) return 0;

   // Avoid the high-risk Friday afternoon close
   if(t.day_of_week == 5 && t.hour >= 18) return 0;

   int b = 0, se = 0;

   // Momentum: 2 consecutive closed bars (r[1] and r[2])
   if(r[1].close > r[2].close) b++; else if(r[1].close < r[2].close) se++;
   if(r[2].close > r[3].close) b++; else if(r[2].close < r[3].close) se++;

   // Bar-body quality of the last closed bar
   double body  = MathAbs(r[1].close - r[1].open);
   double range = r[1].high - r[1].low;
   if(range > 0.0 && body >= 0.5 * range)
   {
      if(r[1].close > r[1].open) b++;
      else                       se++;
   }

   // London–NY overlap (13:00–15:59): amplify the leading side (+1 to winner)
   if(overlapActive)
   {
      if(b > se) b++;
      else if(se > b) se++;
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

