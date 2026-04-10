#property strict
#include "StrategyTypes.mqh"

int SigPivotPoints(StrategySignal &s, ENUM_TIMEFRAMES signalTf)
{
   // Previous day's OHLC for classic pivot point calculation
   MqlRates d[]; ArraySetAsSeries(d, true);
   if(!GetCachedRates(PERIOD_D1, 3, d) || ArraySize(d) < 2) return 0;
   double H = d[1].high, L = d[1].low, C = d[1].close;   // d[1] = previous completed day
   double pp = (H + L + C) / 3.0;
   double r1 = 2.0*pp - L,  s1 = 2.0*pp - H;
   double r2 = pp + (H - L), s2 = pp - (H - L);

   // ATR-based proximity tolerance
   int hATR = IndGet_ATR(signalTf, 14);
   if(hATR == INVALID_HANDLE) return 0;
   double atr[]; ArraySetAsSeries(atr, true);
   if(CopyBuffer(hATR, 0, 0, 1, atr) < 1 || atr[0] <= 0.0) return 0;
   double prox = atr[0] * 0.5;   // within 50% of ATR = "near" a pivot

   MqlRates r[]; ArraySetAsSeries(r, true);
   if(!GetCachedRates(signalTf, 3, r) || ArraySize(r) < 2) return 0;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   int b = 0, se = 0;

   // Price near support pivots with bullish bar
   if((MathAbs(bid - s1) <= prox || MathAbs(bid - s2) <= prox)
   && r[0].close >= r[0].open) b++;

   // Price near resistance pivots with bearish bar
   if((MathAbs(ask - r1) <= prox || MathAbs(ask - r2) <= prox)
   && r[0].close <= r[0].open) se++;

   // Pivot point crossover (direction change through PP)
   if(r[0].close > pp && r[1].close <= pp) b++;
   if(r[0].close < pp && r[1].close >= pp) se++;

   // Clean breakout beyond R1 / S1
   if(r[0].close > r1 && r[1].close <= r1) b++;
   if(r[0].close < s1 && r[1].close >= s1) se++;

   // Normalize to 0..5
   b  = MathMin(b,  5);
   se = MathMin(se, 5);

   if(b > 0 && b >= se)
      { s.direction = SIGNAL_BUY;  s.strength = b;  s.reason = "pivot buy"; }
   else if(se > 0 && se > b)
      { s.direction = SIGNAL_SELL; s.strength = se; s.reason = "pivot sell"; }
   return MathMax(b, se);
}
