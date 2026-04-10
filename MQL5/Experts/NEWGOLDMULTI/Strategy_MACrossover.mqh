#property strict
#include "StrategyTypes.mqh"

int SigMACrossover(StrategySignal &s, ENUM_TIMEFRAMES tf,
                   int fastP, int slowP, int longP, int minConf)
{
   int hf   = IndGet_EMA(tf, fastP);
   int hs   = IndGet_EMA(tf, slowP);
   int hl   = IndGet_EMA(tf, longP);
   int hADX = IndGet_ADX(tf, 14);
   int hATR = IndGet_ATR(tf, 14);
   if(hf == INVALID_HANDLE || hs == INVALID_HANDLE || hl == INVALID_HANDLE
   || hADX == INVALID_HANDLE || hATR == INVALID_HANDLE) return 0;

   double f[], sl[], lg[], adx[], atr[];
   ArraySetAsSeries(f,   true);
   ArraySetAsSeries(sl,  true);
   ArraySetAsSeries(lg,  true);
   ArraySetAsSeries(adx, true);
   ArraySetAsSeries(atr, true);

   MqlRates r[]; ArraySetAsSeries(r, true);
   bool ok = GetCachedRates(tf, longP + 5, r) && ArraySize(r) >= longP + 2
          && CopyBuffer(hf,   0, 0, 3, f)   >= 3
          && CopyBuffer(hs,   0, 0, 3, sl)  >= 3
          && CopyBuffer(hl,   0, 0, 2, lg)  >= 1
          && CopyBuffer(hADX, 0, 0, 1, adx) >= 1
          && CopyBuffer(hATR, 0, 0, 1, atr) >= 1;
   if(!ok) return 0;

   double adxVal = adx[0];
   double atrVal = atr[0];

   int b = 0, se = 0;

   // Fast EMA crosses above/below slow EMA (confirmed on closed bar)
   // ADX trend strength filter: only award crossover vote when ADX > 20
   if(f[0] > sl[0] && f[1] <= sl[1] && adxVal > 20.0) b++;
   if(f[0] < sl[0] && f[1] >= sl[1] && adxVal > 20.0) se++;

   // ADX > 30 bonus: strongly trending market
   if(adxVal > 30.0)
   {
      if(f[0] > sl[0]) b++;
      if(f[0] < sl[0]) se++;
   }

   // Price on correct side of long-period MA (trend filter)
   if(r[0].close > lg[0]) b++;
   if(r[0].close < lg[0]) se++;

   // Fast EMA is accelerating in the right direction
   if(f[0] > f[1] && f[1] > f[2]) b++;
   if(f[0] < f[1] && f[1] < f[2]) se++;

   // Slope confirmation: fast EMA slope normalised by ATR
   // slope = (f[0] - f[2]) / (2 * atrVal); meaningful when |slope| > 0.1
   if(atrVal > 0.0)
   {
      double slope = (f[0] - f[2]) / (2.0 * atrVal);
      if(slope >  0.1) b++;
      if(slope < -0.1) se++;
   }

   // Slow EMA also aligned (adds confluence)
   if(sl[0] > sl[1]) b++;
   if(sl[0] < sl[1]) se++;

   // Normalize to 0..5
   b  = MathMin(b,  5);
   se = MathMin(se, 5);

   if(b >= minConf && b >= se)
      { s.direction = SIGNAL_BUY;  s.strength = b;  s.reason = "ma crossover buy"; }
   else if(se >= minConf && se > b)
      { s.direction = SIGNAL_SELL; s.strength = se; s.reason = "ma crossover sell"; }
   return MathMax(b, se);
}
