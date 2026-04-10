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
//     price with ATR-based tolerance + confirmed neckline break
//     + volume confirmation (breakout bar volume > 1.2× avg 10 bars).
//   Wedge / Triangle breakout — consecutive compression then break.
//   Inverse Head & Shoulders / Head & Shoulders — three-swing
//     approximation (lowest/highest central swing) with neckline
//     slope validation (must be nearly flat ±0.5×ATR over pattern).
//------------------------------------------------------------------
int SigChartPatterns(StrategySignal &s, ENUM_TIMEFRAMES tf)
{
   MqlRates r[]; ArraySetAsSeries(r, true);
   if(!GetCachedRates(tf, 150, r) || ArraySize(r) < 80) return 0;

   int hATR = IndGet_ATR(tf, 14);
   if(hATR == INVALID_HANDLE) return 0;
   double atr[]; ArraySetAsSeries(atr, true);
   if(CopyBuffer(hATR, 0, 0, 1, atr) < 1 || atr[0] <= 0.0) return 0;
   double atrVal = atr[0];
   double tol = atrVal * 0.5; // similar level = within 50% ATR

   // Volume data for breakout confirmation
   long vol[]; ArraySetAsSeries(vol, true);
   bool hasVol = (CopyTickVolume(_Symbol, tf, 0, 12, vol) >= 11);
   double avgVol10 = 0.0;
   if(hasVol)
   {
      for(int i = 1; i <= 10; i++) avgVol10 += (double)vol[i];
      avgVol10 /= 10.0;
   }

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
      int neckStart = sh1 + 1;
      if(neckStart < ArraySize(r))
      {
         double neck = r[neckStart].low;
         for(int i = neckStart; i < sh2 && i < ArraySize(r); i++)
            if(r[i].low < neck) neck = r[i].low;
         if(r[1].close < neck - atrVal * NECKLINE_BREAK_ATR)
         {
            // Volume confirmation: breakout bar volume > 1.2× avg 10 bars
            bool volOk = (!hasVol || avgVol10 <= 0.0 || (double)vol[1] > 1.2 * avgVol10);
            if(volOk) se++;
         }
      }
   }

   // --- Double Bottom ---
   if(sl1 >= 0 && sl2 >= 0 && MathAbs(r[sl1].low - r[sl2].low) <= tol)
   {
      int neckStart = sl1 + 1;
      if(neckStart < ArraySize(r))
      {
         double neck = r[neckStart].high;
         for(int i = neckStart; i < sl2 && i < ArraySize(r); i++)
            if(r[i].high > neck) neck = r[i].high;
         if(r[1].close > neck + atrVal * NECKLINE_BREAK_ATR)
         {
            bool volOk = (!hasVol || avgVol10 <= 0.0 || (double)vol[1] > 1.2 * avgVol10);
            if(volOk) b++;
         }
      }
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
         int neckStart = sh1 + 1;
         if(neckStart < ArraySize(r))
         {
            // Neckline: line from left-shoulder trough to right-shoulder trough
            double neckLeft  = r[neckStart].low;
            int    neckLBar  = neckStart;
            for(int i = neckStart; i < sh2 && i < ArraySize(r); i++)
               if(r[i].low < neckLeft) { neckLeft = r[i].low; neckLBar = i; }
            double neckRight = r[sh1 + 1].low;
            for(int i = sh1 + 1; i < sh1 + (sh2 - sh1) && i < ArraySize(r); i++)
               if(r[i].low < neckRight) neckRight = r[i].low;

            // Neckline slope validation: must be nearly flat (within ±0.5×ATR)
            bool neckFlat = (MathAbs(neckLeft - neckRight) <= atrVal * 0.5);
            double neck = neckLeft;
            if(neckFlat && r[1].close < neck - atrVal * NECKLINE_BREAK_ATR) se++;
         }
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
         int neckStart = sl1 + 1;
         if(neckStart < ArraySize(r))
         {
            double neckLeft  = r[neckStart].high;
            for(int i = neckStart; i < sl2 && i < ArraySize(r); i++)
               if(r[i].high > neckLeft) neckLeft = r[i].high;
            double neckRight = r[sl1 + 1].high;
            for(int i = sl1 + 1; i < sl1 + (sl2 - sl1) && i < ArraySize(r); i++)
               if(r[i].high > neckRight) neckRight = r[i].high;

            bool neckFlat = (MathAbs(neckLeft - neckRight) <= atrVal * 0.5);
            double neck = neckLeft;
            if(neckFlat && r[1].close > neck + atrVal * NECKLINE_BREAK_ATR) b++;
         }
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
