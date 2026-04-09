#property strict
#include "StrategyTypes.mqh"

// --- Individual pattern detectors ---

// Bull pin bar: long lower shadow > 2x body, lower shadow > upper shadow, lower shadow > 60% of range
bool CP_BullPin(MqlRates &r)
{
   double body  = MathAbs(r.close - r.open);
   double upper = r.high  - MathMax(r.open, r.close);
   double lower = MathMin(r.open, r.close) - r.low;
   double range = r.high  - r.low;
   if(range <= 0) return false;
   return (lower > 2.0 * MathMax(body, _Point) && lower > upper && lower > 0.6 * range);
}

// Bear pin bar: long upper shadow > 2x body, upper > lower, upper > 60% of range
bool CP_BearPin(MqlRates &r)
{
   double body  = MathAbs(r.close - r.open);
   double upper = r.high  - MathMax(r.open, r.close);
   double lower = MathMin(r.open, r.close) - r.low;
   double range = r.high  - r.low;
   if(range <= 0) return false;
   return (upper > 2.0 * MathMax(body, _Point) && upper > lower && upper > 0.6 * range);
}

// Doji: body < 10% of range
bool CP_Doji(MqlRates &r)
{
   double range = r.high - r.low;
   if(range <= 0) return false;
   return (MathAbs(r.close - r.open) < 0.1 * range);
}

bool CP_Hammer(MqlRates   &r) { return CP_BullPin(r) && r.close >= r.open; }
bool CP_Shooting(MqlRates &r) { return CP_BearPin(r) && r.close <= r.open; }

// Bullish engulfing: current bar fully engulfs the previous bearish bar
bool CP_BullEng(MqlRates &c, MqlRates &p)
{
   return (p.close < p.open && c.close > c.open
        && c.close >= p.open && c.open <= p.close);
}

// Bearish engulfing: current bar fully engulfs the previous bullish bar
bool CP_BearEng(MqlRates &c, MqlRates &p)
{
   return (p.close > p.open && c.close < c.open
        && c.open >= p.open && c.close <= p.close);
}

// ---------------------------------------------------------------

int SigCandlePatterns(StrategySignal &s, ENUM_TIMEFRAMES tf)
{
   MqlRates r[]; ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, tf, 0, 10, r) < 4) return 0;

   int b = 0, se = 0;

   // Single-bar patterns
   if(CP_BullPin(r[1]))  b++;
   if(CP_BearPin(r[1]))  se++;
   if(CP_Hammer(r[1]))   b++;
   if(CP_Shooting(r[1])) se++;

   // Doji at swing extremes — direction by following bar
   if(CP_Doji(r[2]))
   {
      if(r[1].close > r[2].high) b++;
      if(r[1].close < r[2].low)  se++;
   }

   // Two-bar patterns (use r[1] vs r[2] — both closed)
   if(CP_BullEng(r[1], r[2])) b++;
   if(CP_BearEng(r[1], r[2])) se++;

   // Inside-bar breakout (r[1] inside r[2])
   if(r[1].high < r[2].high && r[1].low > r[2].low)
   {
      if(r[0].close > r[2].high) b++;   // breakout above mother bar
      if(r[0].close < r[2].low)  se++;  // breakout below mother bar
   }

   // Three-bar patterns
   // Morning star approximation
   if(r[3].close < r[3].open
   && MathAbs(r[2].close - r[2].open) < MathAbs(r[3].close - r[3].open) * 0.5
   && r[1].close > r[1].open
   && r[1].close > (r[3].open + r[3].close) * 0.5)
      b++;

   // Evening star approximation
   if(r[3].close > r[3].open
   && MathAbs(r[2].close - r[2].open) < MathAbs(r[3].close - r[3].open) * 0.5
   && r[1].close < r[1].open
   && r[1].close < (r[3].open + r[3].close) * 0.5)
      se++;

   // Three white soldiers
   if(r[3].close > r[3].open && r[2].close > r[2].open && r[1].close > r[1].open
   && r[2].close > r[3].close && r[1].close > r[2].close
   && r[2].open > r[3].open   && r[1].open  > r[2].open)
      b++;

   // Three black crows
   if(r[3].close < r[3].open && r[2].close < r[2].open && r[1].close < r[1].open
   && r[2].close < r[3].close && r[1].close < r[2].close
   && r[2].open  < r[3].open  && r[1].open  < r[2].open)
      se++;

   // Normalize to 0..5
   b  = MathMin(b,  5);
   se = MathMin(se, 5);

   if(b > 0 && b >= se)
      { s.direction = SIGNAL_BUY;  s.strength = b;  s.reason = "candle pattern buy"; }
   else if(se > 0 && se > b)
      { s.direction = SIGNAL_SELL; s.strength = se; s.reason = "candle pattern sell"; }
   return MathMax(b, se);
}

