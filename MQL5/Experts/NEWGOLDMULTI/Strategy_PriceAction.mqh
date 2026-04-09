#property strict
#include "StrategyTypes.mqh"

// Fraction of ATR used as tolerance for range-breakout detection.
static const double BREAKOUT_ATR_TOL = 0.1;
// Fraction of ATR for support/resistance proximity (bounce detection).
static const double SR_PROXIMITY_ATR = 0.2;

int SigPriceAction(StrategySignal &s, ENUM_TIMEFRAMES tf)
{
   MqlRates r[]; ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, tf, 0, 60, r) < 30) return 0;

   // ATR for adaptive tolerances
   int hATR = iATR(_Symbol, tf, 14);
   if(hATR < 0) return 0;
   double atr[]; ArraySetAsSeries(atr, true);
   bool ok = (CopyBuffer(hATR, 0, 0, 1, atr) >= 1);
   IndicatorRelease(hATR);
   if(!ok || atr[0] <= 0.0) return 0;
   double atrVal = atr[0];

   int b = 0, se = 0;

   // Range high/low of last 10 closed bars
   double hi = r[1].high, lo = r[1].low;
   for(int i = 2; i <= 10; i++)
   {
      if(r[i].high > hi) hi = r[i].high;
      if(r[i].low  < lo) lo = r[i].low;
   }

   // Clean breakout of range (price beyond extremes by at least 10% of ATR)
   double brkTol = atrVal * BREAKOUT_ATR_TOL;
   if(r[0].close > hi + brkTol) b++;
   if(r[0].close < lo - brkTol) se++;

   // Higher-lows structure (3 swing lows rising) — uptrend confirmation
   int swL[3]; int nL = 0;
   for(int i = 2; i < 28 && nL < 3; i++)
   {
      if(i + 2 >= ArraySize(r)) break;
      if(r[i].low < r[i-1].low && r[i].low < r[i+1].low
      && r[i].low < r[i-2].low && r[i].low < r[i+2].low)
         swL[nL++] = i;
   }
   if(nL >= 3 && r[swL[0]].low > r[swL[1]].low && r[swL[1]].low > r[swL[2]].low) b++;

   // Lower-highs structure (3 swing highs falling) — downtrend confirmation
   int swH[3]; int nH = 0;
   for(int i = 2; i < 28 && nH < 3; i++)
   {
      if(i + 2 >= ArraySize(r)) break;
      if(r[i].high > r[i-1].high && r[i].high > r[i+1].high
      && r[i].high > r[i-2].high && r[i].high > r[i+2].high)
         swH[nH++] = i;
   }
   if(nH >= 3 && r[swH[0]].high < r[swH[1]].high && r[swH[1]].high < r[swH[2]].high) se++;

   // Bullish support bounce: bullish bar near 10-bar low (within 20% ATR)
   if(r[0].close > r[0].open && r[0].low <= lo + atrVal * SR_PROXIMITY_ATR) b++;
   // Bearish resistance rejection: bearish bar near 10-bar high (within 20% ATR)
   if(r[0].close < r[0].open && r[0].high >= hi - atrVal * SR_PROXIMITY_ATR) se++;

   // Normalize to 0..5
   b  = MathMin(b,  5);
   se = MathMin(se, 5);

   if(b > 0 && b >= se)
      { s.direction = SIGNAL_BUY;  s.strength = b;  s.reason = "price action buy"; }
   else if(se > 0 && se > b)
      { s.direction = SIGNAL_SELL; s.strength = se; s.reason = "price action sell"; }
   return MathMax(b, se);
}

