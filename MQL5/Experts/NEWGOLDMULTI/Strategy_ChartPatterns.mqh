#property strict
#include "StrategyTypes.mqh"

// Tolerance for neckline breakout confirmation:
//   price must close beyond neckline by this fraction of ATR.
static const double NECKLINE_BREAK_ATR = 0.15;

//------------------------------------------------------------------
// Chart Pattern approximation
//
// Patterns detected:
//   Double Bottom / Double Top — two swing lows/highs at similar
//     price with ATR-based tolerance + confirmed neckline break.
//   Wedge / Triangle breakout — consecutive compression then break.
//   Inverse Head & Shoulders / Head & Shoulders — three-swing
//     approximation (lowest/highest central swing).
//------------------------------------------------------------------
int SigChartPatterns(StrategySignal &s, ENUM_TIMEFRAMES tf)
{
   MqlRates r[]; ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, tf, 0, 150, r) < 80) return 0;

   int hATR = iATR(_Symbol, tf, 14);
   if(hATR < 0) return 0;
   double atr[]; ArraySetAsSeries(atr, true);
   bool ok = (CopyBuffer(hATR, 0, 0, 1, atr) >= 1);
   IndicatorRelease(hATR);
   if(!ok || atr[0] <= 0.0) return 0;
   double atrVal = atr[0];
   double tol = atrVal * 0.5; // similar level = within 50% ATR

   int b = 0, se = 0;

   // --- Find two most-recent swing highs and swing lows ---
   int sh1 = -1, sh2 = -1, sl1 = -1, sl2 = -1;
   for(int i = 2; i < 100 && (sh2 < 0 || sl2 < 0); i++)
   {
      if(i + 2 >= ArraySize(r)) break;
      if(sh2 < 0)
      {
         bool isH = (r[i].high > r[i-1].high && r[i].high > r[i+1].high
                  && r[i].high > r[i-2].high && r[i].high > r[i+2].high);
         if(isH) { if(sh1 < 0) sh1 = i; else sh2 = i; }
      }
      if(sl2 < 0)
      {
         bool isL = (r[i].low < r[i-1].low && r[i].low < r[i+1].low
                  && r[i].low < r[i-2].low && r[i].low < r[i+2].low);
         if(isL) { if(sl1 < 0) sl1 = i; else sl2 = i; }
      }
   }

   // --- Double Top ---
   if(sh1 >= 0 && sh2 >= 0 && MathAbs(r[sh1].high - r[sh2].high) <= tol)
   {
      // Neckline = lowest low between the two tops
      double neck = r[sh1 + 1].low;
      for(int i = sh1 + 1; i < sh2 && i < ArraySize(r); i++)
         if(r[i].low < neck) neck = r[i].low;
      if(r[0].close < neck - atrVal * NECKLINE_BREAK_ATR) se++;   // confirmed break below neckline
   }

   // --- Double Bottom ---
   if(sl1 >= 0 && sl2 >= 0 && MathAbs(r[sl1].low - r[sl2].low) <= tol)
   {
      double neck = r[sl1 + 1].high;
      for(int i = sl1 + 1; i < sl2 && i < ArraySize(r); i++)
         if(r[i].high > neck) neck = r[i].high;
      if(r[0].close > neck + atrVal * NECKLINE_BREAK_ATR) b++;    // confirmed break above neckline
   }

   // --- Head & Shoulders (bearish) ---
   // Need 3 swing highs: left shoulder (sh3), head (sh2, highest), right shoulder (sh1)
   if(sh1 >= 0 && sh2 >= 0)
   {
      int sh3 = -1;
      for(int i = sh2 + 2; i < 120; i++)
      {
         if(i + 2 >= ArraySize(r)) break;
         if(r[i].high > r[i-1].high && r[i].high > r[i+1].high
         && r[i].high > r[i-2].high && r[i].high > r[i+2].high)
         { sh3 = i; break; }
      }
      if(sh3 >= 0
      && r[sh2].high > r[sh1].high && r[sh2].high > r[sh3].high  // head is highest
      && MathAbs(r[sh1].high - r[sh3].high) <= tol)              // shoulders roughly equal
      {
         double neck = r[sh1 + 1].low;
         for(int i = sh1; i < sh2 && i < ArraySize(r); i++)
            if(r[i].low < neck) neck = r[i].low;
         if(r[0].close < neck - atrVal * NECKLINE_BREAK_ATR) se++;
      }
   }

   // --- Inverse Head & Shoulders (bullish) ---
   if(sl1 >= 0 && sl2 >= 0)
   {
      int sl3 = -1;
      for(int i = sl2 + 2; i < 120; i++)
      {
         if(i + 2 >= ArraySize(r)) break;
         if(r[i].low < r[i-1].low && r[i].low < r[i+1].low
         && r[i].low < r[i-2].low && r[i].low < r[i+2].low)
         { sl3 = i; break; }
      }
      if(sl3 >= 0
      && r[sl2].low < r[sl1].low && r[sl2].low < r[sl3].low   // head is lowest
      && MathAbs(r[sl1].low - r[sl3].low) <= tol)             // shoulders roughly equal
      {
         double neck = r[sl1 + 1].high;
         for(int i = sl1; i < sl2 && i < ArraySize(r); i++)
            if(r[i].high > neck) neck = r[i].high;
         if(r[0].close > neck + atrVal * NECKLINE_BREAK_ATR) b++;
      }
   }

   // --- Wedge / Triangle breakout (simple 3-bar compression breakout) ---
   if(r[0].close > r[1].high && r[1].high < r[2].high && r[2].high < r[3].high) b++;
   if(r[0].close < r[1].low  && r[1].low  > r[2].low  && r[2].low  > r[3].low)  se++;

   // Normalize to 0..5
   b  = MathMin(b,  5);
   se = MathMin(se, 5);

   if(b > 0 && b >= se)
      { s.direction = SIGNAL_BUY;  s.strength = b;  s.reason = "chart pattern bullish"; }
   else if(se > 0 && se > b)
      { s.direction = SIGNAL_SELL; s.strength = se; s.reason = "chart pattern bearish"; }
   return MathMax(b, se);
}

