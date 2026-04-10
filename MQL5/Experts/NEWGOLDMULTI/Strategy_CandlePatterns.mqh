#property strict
#include "StrategyTypes.mqh"

// --- Individual pattern detectors ---

// Bull pin bar: lower shadow dominates range, body small, shadow > upper shadow
bool CP_BullPin(MqlRates &r)
{
   double range = r.high - r.low;
   if(range <= 0) return false;
   double body  = MathAbs(r.close - r.open);
   double upper = r.high  - MathMax(r.open, r.close);
   double lower = MathMin(r.open, r.close) - r.low;
   return (lower > 0.6 * range && lower > upper * 2.0 && body < 0.3 * range);
}

// Bear pin bar: upper shadow dominates range, body small, shadow > lower shadow
bool CP_BearPin(MqlRates &r)
{
   double range = r.high - r.low;
   if(range <= 0) return false;
   double body  = MathAbs(r.close - r.open);
   double upper = r.high  - MathMax(r.open, r.close);
   double lower = MathMin(r.open, r.close) - r.low;
   return (upper > 0.6 * range && upper > lower * 2.0 && body < 0.3 * range);
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
   if(!GetCachedRates(tf, 10, r) || ArraySize(r) < 5) return 0;

   // ATR-based candle size filter: skip patterns where bar range < 0.3 × ATR
   int hATR = IndGet_ATR(tf, 14);
   if(hATR == INVALID_HANDLE) return 0;
   double atr[]; ArraySetAsSeries(atr, true);
   if(CopyBuffer(hATR, 0, 0, 1, atr) < 1 || atr[0] <= 0.0) return 0;
   double atrVal      = atr[0];
   double minBarRange = atrVal * 0.3;

   int b = 0, se = 0;

   // Single-bar patterns (only count when bar range is significant)
   double range1 = r[1].high - r[1].low;
   if(range1 >= minBarRange)
   {
      if(CP_BullPin(r[1]))  b++;
      if(CP_BearPin(r[1]))  se++;
      // Context filter: Hammer only in downtrend context (close < prior close)
      if(CP_Hammer(r[1])   && r[1].close < r[2].close) b++;
      // Context filter: Shooting Star only in uptrend context (close > prior close)
      if(CP_Shooting(r[1]) && r[1].close > r[2].close) se++;
   }

   // Doji at swing extremes — direction by following bar
   double range2 = r[2].high - r[2].low;
   if(range2 >= minBarRange && CP_Doji(r[2]))
   {
      if(r[1].close > r[2].high) b++;
      if(r[1].close < r[2].low)  se++;
   }

   // Two-bar patterns (use r[1] vs r[2] — both closed)
   if(CP_BullEng(r[1], r[2])) b++;
   if(CP_BearEng(r[1], r[2])) se++;

   // Inside-bar breakout: r[2] = mother bar, r[1] = inside bar, confirmed by r[1] close
   // (r[1] is already closed, avoiding forming-bar trigger issues)
   if(r[2].high < r[3].high && r[2].low > r[3].low)
   {
      if(r[1].close > r[3].high) b++;   // r[1] closed above mother bar's high
      if(r[1].close < r[3].low)  se++;  // r[1] closed below mother bar's low
   }

   // Three-bar patterns
   // Morning Star: bearish bar, small body bar, bullish bar closing above midpoint of bar 1
   if(r[3].close < r[3].open
   && MathAbs(r[2].close - r[2].open) < MathAbs(r[3].close - r[3].open) * 0.5
   && r[1].close > r[1].open
   && r[1].close > (r[3].open + r[3].close) * 0.5)
      b++;

   // Evening Star: bullish bar, small body bar, bearish bar closing below midpoint of bar 1
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

