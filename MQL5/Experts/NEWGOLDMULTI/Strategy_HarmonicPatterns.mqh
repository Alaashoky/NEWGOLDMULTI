#property strict
#include "StrategyTypes.mqh"

//------------------------------------------------------------------
// Harmonic Pattern approximation (XABCD structure)
//
// Uses 5 swing pivots identified by the SwingHigh/SwingLow helpers.
// Per-pattern XAD ratio validation instead of a single range.
// ATR-based tolerance adapts to current volatility.
//
// Pattern XAD ratios (D relative to X, measured as |XD|/|XA|):
//   Gartley Bull : XAD ∈ [0.75, 0.85]  (ideal 0.786)
//   Bat Bull     : XAD ∈ [0.82, 0.92]  (ideal 0.886)
//   Butterfly Bull: XAD ∈ [1.20, 1.32] (ideal 1.272)
//   Crab Bull    : XAD ∈ [1.55, 1.72]  (ideal 1.618)
//   Bear versions: same XAD ranges but D is above X (inverted direction)
//------------------------------------------------------------------
int SigHarmonicPatterns(StrategySignal &s, ENUM_TIMEFRAMES tf)
{
   MqlRates r[]; ArraySetAsSeries(r, true);
   if(!GetCachedRates(tf, 200, r) || ArraySize(r) < 150) return 0;

   // ATR-based tolerance
   int hATR = IndGet_ATR(tf, 14);
   if(hATR == INVALID_HANDLE) return 0;
   double atr[]; ArraySetAsSeries(atr, true);
   if(CopyBuffer(hATR, 0, 0, 1, atr) < 1 || atr[0] <= 0.0) return 0;
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

   // XAD ratio: distance from X to D relative to XA leg
   double XD  = MathAbs(pivVal[4] - pivVal[0]);
   double xad = XD / XA;

   int b = 0, se = 0;

   // Bullish completion: D is a swing low (below X), price recovering
   bool dBelowX = (pivVal[4] < pivVal[0]);
   // Bearish completion: D is a swing high (above X)
   bool dAboveX = (pivVal[4] > pivVal[0]);

   // Per-pattern XAD range checks
   // Gartley
   if(xad >= 0.75 && xad <= 0.85)
   {
      if(dBelowX) b++;
      if(dAboveX) se++;
   }
   // Bat
   if(xad >= 0.82 && xad <= 0.92)
   {
      if(dBelowX) b++;
      if(dAboveX) se++;
   }
   // Butterfly
   if(xad >= 1.20 && xad <= 1.32)
   {
      if(dBelowX) b++;
      if(dAboveX) se++;
   }
   // Crab
   if(xad >= 1.55 && xad <= 1.72)
   {
      if(dBelowX) b++;
      if(dAboveX) se++;
   }

   // Normalize to 0..5
   b  = MathMin(b,  5);
   se = MathMin(se, 5);

   if(b > 0 && b >= se)
      { s.direction = SIGNAL_BUY;  s.strength = b;  s.reason = "harmonic bullish completion"; }
   else if(se > 0 && se > b)
      { s.direction = SIGNAL_SELL; s.strength = se; s.reason = "harmonic bearish completion"; }
   return MathMax(b, se);
}
