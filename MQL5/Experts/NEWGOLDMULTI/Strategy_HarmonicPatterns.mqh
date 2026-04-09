#property strict
#include "StrategyTypes.mqh"

//------------------------------------------------------------------
// Harmonic Pattern approximation (XABCD structure)
//
// Uses 5 swing pivots identified by the SwingHigh/SwingLow helpers.
// Ratios are validated against Gartley / Bat / Butterfly / Crab
// Fibonacci zones.  ATR-based tolerance adapts to current volatility.
//
// NOTE: This is a simplified approximation.  It does not validate
// all harmonic rules rigorously (e.g. precise BC ratio ranges per
// pattern type) but is deterministic and consistent.
//------------------------------------------------------------------
int SigHarmonicPatterns(StrategySignal &s, ENUM_TIMEFRAMES tf)
{
   MqlRates r[]; ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, tf, 0, 200, r) < 150) return 0;

   // ATR-based tolerance
   int hATR = iATR(_Symbol, tf, 14);
   if(hATR < 0) return 0;
   double atr[]; ArraySetAsSeries(atr, true);
   bool ok = (CopyBuffer(hATR, 0, 0, 1, atr) >= 1);
   IndicatorRelease(hATR);
   if(!ok || atr[0] <= 0.0) return 0;
   // Harmonic ratios (e.g. 0.618) are dimensionless.  We use a fixed ±3% tolerance
   // as the standard harmonic validation zone (e.g. 0.618 ± 0.03 = 0.588..0.648).
   // ATR is used to guard against noise — if a leg is smaller than one ATR, skip.
   static const double HP_RATIO_TOL = 0.03;
   double atrVal = atr[0];

   // Collect 5 alternating swing points (X, A, B, C, D pattern)
   // We look for alternating high/low pivots using 3-bar-side strength
   int pivIdx[5]; double pivVal[5]; int nPiv = 0;
   bool seekHigh = true;  // start by seeking a swing high (X point)
   for(int i = 3; i < 180 && nPiv < 5; i++)
   {
      if(i + 3 >= ArraySize(r)) break;
      if(seekHigh)
      {
         bool isH = true;
         for(int j = 1; j <= 3 && isH; j++)
            if(r[i].high <= r[i-j].high || r[i].high <= r[i+j].high) isH = false;
         if(isH) { pivIdx[nPiv] = i; pivVal[nPiv] = r[i].high; nPiv++; seekHigh = false; }
      }
      else
      {
         bool isL = true;
         for(int j = 1; j <= 3 && isL; j++)
            if(r[i].low >= r[i-j].low || r[i].low >= r[i+j].low) isL = false;
         if(isL) { pivIdx[nPiv] = i; pivVal[nPiv] = r[i].low; nPiv++; seekHigh = true; }
      }
   }
   if(nPiv < 5) return 0;

   // XABCD legs
   double XA = MathAbs(pivVal[1] - pivVal[0]);
   double AB = MathAbs(pivVal[2] - pivVal[1]);
   double BC = MathAbs(pivVal[3] - pivVal[2]);
   double CD = MathAbs(pivVal[4] - pivVal[3]);
   if(XA <= 0.0 || AB <= 0.0 || BC <= 0.0 || CD <= 0.0) return 0;
   // Skip if the XA leg is too small (likely noise — require at least one ATR)
   if(XA < atrVal) return 0;

   double rAB = AB / XA;
   double rBC = BC / AB;
   double rCD = CD / BC;

   // Harmonic ratio validation (Gartley/Bat/Butterfly/Crab approximation)
   bool abOk  = (rAB >= 0.382 - HP_RATIO_TOL && rAB <= 0.886 + HP_RATIO_TOL);
   bool bcOk  = (rBC >= 0.382 - HP_RATIO_TOL && rBC <= 0.886 + HP_RATIO_TOL);
   bool cdOk  = (rCD >= 1.13  - HP_RATIO_TOL && rCD <= 3.618 + HP_RATIO_TOL);
   if(!abOk || !bcOk || !cdOk) return 0;

   int b = 0, se = 0;

   // Bullish completion (D is a swing low with price showing reversal)
   bool bullish = (pivVal[4] < pivVal[2]          // D below B
               && r[0].close > pivVal[4]           // price recovering from D
               && r[0].close > r[1].close);        // current bar bullish
   // Bearish completion (D is a swing high with price showing reversal)
   bool bearish = (pivVal[4] > pivVal[2]           // D above B
               && r[0].close < pivVal[4]           // price falling from D
               && r[0].close < r[1].close);        // current bar bearish

   if(bullish) b = 3;
   if(bearish) se = 3;

   // Normalize to 0..5
   b  = MathMin(b,  5);
   se = MathMin(se, 5);

   if(b > 0 && b >= se)
      { s.direction = SIGNAL_BUY;  s.strength = b;  s.reason = "harmonic bullish completion"; }
   else if(se > 0 && se > b)
      { s.direction = SIGNAL_SELL; s.strength = se; s.reason = "harmonic bearish completion"; }
   return MathMax(b, se);
}

