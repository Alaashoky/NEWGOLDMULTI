#property strict
#include "StrategyTypes.mqh"

int SigMultiTimeframe(StrategySignal &s)
{
   // Higher timeframes: H4 (weight 1), D1 (weight 2), W1 (weight 3)
   ENUM_TIMEFRAMES tfs[3]     = {PERIOD_H4, PERIOD_D1, PERIOD_W1};
   int             weights[3] = {1, 2, 3};
   int b = 0, se = 0;

   double ma20[], ma50[], adx[];
   ArraySetAsSeries(ma20, true);
   ArraySetAsSeries(ma50, true);
   ArraySetAsSeries(adx,  true);

   for(int i = 0; i < 3; i++)
   {
      MqlRates r[]; ArraySetAsSeries(r, true);
      if(!GetCachedRates(tfs[i], 15, r) || ArraySize(r) < 10) continue;

      int hMA20 = IndGet_EMA(tfs[i], 20);
      int hMA50 = IndGet_EMA(tfs[i], 50);
      int hADX  = IndGet_ADX(tfs[i], 14);
      if(hMA20 == INVALID_HANDLE || hMA50 == INVALID_HANDLE || hADX == INVALID_HANDLE) continue;

      bool ok = CopyBuffer(hMA20, 0, 0, 2, ma20) >= 1
             && CopyBuffer(hMA50, 0, 0, 2, ma50) >= 1
             && CopyBuffer(hADX,  0, 0, 1, adx)  >= 1;
      if(!ok) continue;

      bool adxTrending = (adx[0] > 20.0);

      // Bullish: fast MA above slow MA, price above fast MA, and trend confirmed by ADX
      if(ma20[0] > ma50[0] && r[0].close > ma20[0])
         b += adxTrending ? weights[i] + 1 : weights[i];

      // Bearish: fast MA below slow MA, price below fast MA
      if(ma20[0] < ma50[0] && r[0].close < ma20[0])
         se += adxTrending ? weights[i] + 1 : weights[i];
   }

   // Normalize to 0..5
   b  = MathMin(b,  5);
   se = MathMin(se, 5);

   if(b > 0 && b >= se)
      { s.direction = SIGNAL_BUY;  s.strength = b;  s.reason = "multi timeframe buy"; }
   else if(se > 0 && se > b)
      { s.direction = SIGNAL_SELL; s.strength = se; s.reason = "multi timeframe sell"; }
   return MathMax(b, se);
}
