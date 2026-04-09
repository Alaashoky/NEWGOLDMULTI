#property strict
#include "StrategyTypes.mqh"

int SigIndicators(StrategySignal &s, ENUM_TIMEFRAMES tf, int minVotes)
{
   MqlRates rates[]; ArraySetAsSeries(rates, true);
   if(!GetCachedRates(tf, 50, rates) || ArraySize(rates) < 5) return 0;

   int hRSI  = IndGet_RSI(tf, 14);
   int hMACD = IndGet_MACD(tf, 12, 26, 9);
   int hADX  = IndGet_ADX(tf, 14);
   int hSt   = IndGet_Stoch(tf, 5, 3, 3);
   int hF    = IndGet_EMA(tf, 20);
   int hSlow = IndGet_EMA(tf, 50);
   int hBB   = IndGet_BB(tf, 20, 2.0);
   if(hRSI == INVALID_HANDLE || hMACD == INVALID_HANDLE || hADX == INVALID_HANDLE
   || hSt  == INVALID_HANDLE || hF    == INVALID_HANDLE || hSlow == INVALID_HANDLE
   || hBB  == INVALID_HANDLE) return 0;

   double rsi[], mm[], ms[], adx[], sk[], sd[], mf[], msl[], bup[], bmid[], blo[];
   ArraySetAsSeries(rsi,  true); ArraySetAsSeries(mm,   true); ArraySetAsSeries(ms,   true);
   ArraySetAsSeries(adx,  true); ArraySetAsSeries(sk,   true); ArraySetAsSeries(sd,   true);
   ArraySetAsSeries(mf,   true); ArraySetAsSeries(msl,  true);
   ArraySetAsSeries(bup,  true); ArraySetAsSeries(bmid, true); ArraySetAsSeries(blo,  true);

   bool ok = CopyBuffer(hRSI,  0, 0, 3, rsi)  >= 3
          && CopyBuffer(hMACD, 0, 0, 3, mm)   >= 3
          && CopyBuffer(hMACD, 1, 0, 3, ms)   >= 3
          && CopyBuffer(hADX,  0, 0, 2, adx)  >= 1
          && CopyBuffer(hSt,   0, 0, 3, sk)   >= 3
          && CopyBuffer(hSt,   1, 0, 3, sd)   >= 3
          && CopyBuffer(hF,    0, 0, 3, mf)   >= 3
          && CopyBuffer(hSlow, 0, 0, 3, msl)  >= 3
          && CopyBuffer(hBB,   1, 0, 3, bup)  >= 3
          && CopyBuffer(hBB,   0, 0, 3, bmid) >= 3
          && CopyBuffer(hBB,   2, 0, 3, blo)  >= 3;
   if(!ok) return 0;

   int buy = 0, sell = 0;

   // RSI oversold/overbought with trend
   if(rsi[1] < 30 && rsi[0] > rsi[1] && rsi[0] > rsi[2]) buy++;
   if(rsi[1] > 70 && rsi[0] < rsi[1] && rsi[0] < rsi[2]) sell++;

   // MACD line crossing signal line
   if(mm[0] > ms[0] && mm[1] <= ms[1]) buy++;
   if(mm[0] < ms[0] && mm[1] >= ms[1]) sell++;

   // Stochastic cross with overbought/oversold filter
   if(sk[0] > sd[0] && sk[1] <= sd[1] && sk[0] < 80) buy++;
   if(sk[0] < sd[0] && sk[1] >= sd[1] && sk[0] > 20) sell++;

   // ADX confirms trend strength (counts for both sides equally)
   if(adx[0] > 25) { buy++; sell++; }

   // Fast EMA crosses slow EMA
   if(mf[0] > msl[0] && mf[1] <= msl[1]) buy++;
   if(mf[0] < msl[0] && mf[1] >= msl[1]) sell++;

   // Bollinger band extremes
   if(rates[0].close < blo[0]) buy++;
   if(rates[0].close > bup[0]) sell++;

   // Normalize strength to 0..5
   buy  = MathMin(buy,  5);
   sell = MathMin(sell, 5);

   if(buy >= minVotes && buy >= sell)
      { s.direction = SIGNAL_BUY;  s.strength = buy;  s.reason = "indicator confluence buy"; }
   else if(sell >= minVotes && sell > buy)
      { s.direction = SIGNAL_SELL; s.strength = sell; s.reason = "indicator confluence sell"; }
   return MathMax(buy, sell);
}
