#property strict
#include "StrategyTypes.mqh"

int SigDivergence(StrategySignal &s, ENUM_TIMEFRAMES tf)
{
   MqlRates r[]; ArraySetAsSeries(r, true);
   if(!GetCachedRates(tf, 100, r) || ArraySize(r) < 50) return 0;

   int hRSI  = IndGet_RSI(tf, 14);
   int hMACD = IndGet_MACD(tf, 12, 26, 9);
   if(hRSI == INVALID_HANDLE || hMACD == INVALID_HANDLE) return 0;

   double rsi[], macd[];
   ArraySetAsSeries(rsi,  true);
   ArraySetAsSeries(macd, true);

   bool ok = CopyBuffer(hRSI,  0, 0, 100, rsi)  >= 50
          && CopyBuffer(hMACD, 0, 0, 100, macd) >= 50;
   if(!ok) return 0;

   int b = 0, se = 0;
   int nBars = 80;

   // Find two recent swing lows (price) using 2-bar-each-side strength
   int sl1 = SwingLow(r,  2, nBars / 2,     2);   // more recent
   int sl2 = SwingLow(r,  sl1 + 3, nBars,   2);   // older
   // Find two recent swing highs
   int sh1 = SwingHigh(r, 2, nBars / 2,     2);   // more recent
   int sh2 = SwingHigh(r, sh1 + 3, nBars,   2);   // older

   // Bullish RSI divergence: price lower low, RSI higher low
   if(sl1 >= 0 && sl2 >= 0
   && r[sl1].low  < r[sl2].low
   && rsi[sl1]    > rsi[sl2])
      b++;

   // Bullish MACD divergence: price lower low, MACD higher low
   if(sl1 >= 0 && sl2 >= 0
   && r[sl1].low  < r[sl2].low
   && macd[sl1]   > macd[sl2])
      b++;

   // Bearish RSI divergence: price higher high, RSI lower high
   if(sh1 >= 0 && sh2 >= 0
   && r[sh1].high > r[sh2].high
   && rsi[sh1]    < rsi[sh2])
      se++;

   // Bearish MACD divergence: price higher high, MACD lower high
   if(sh1 >= 0 && sh2 >= 0
   && r[sh1].high > r[sh2].high
   && macd[sh1]   < macd[sh2])
      se++;

   // Normalize to 0..5
   b  = MathMin(b,  5);
   se = MathMin(se, 5);

   if(b > 0 && b >= se)
      { s.direction = SIGNAL_BUY;  s.strength = b;  s.reason = "divergence buy"; }
   else if(se > 0 && se > b)
      { s.direction = SIGNAL_SELL; s.strength = se; s.reason = "divergence sell"; }
   return MathMax(b, se);
}
