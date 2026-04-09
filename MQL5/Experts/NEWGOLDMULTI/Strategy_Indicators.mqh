#property strict
#include "StrategyTypes.mqh"

int SigIndicators(StrategySignal &s, ENUM_TIMEFRAMES tf, int minVotes)
{
   MqlRates rates[]; ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, tf, 0, 50, rates) < 5) return 0;

   int hRSI  = iRSI(_Symbol,  tf, 14, PRICE_CLOSE);
   int hMACD = iMACD(_Symbol, tf, 12, 26, 9, PRICE_CLOSE);
   int hADX  = iADX(_Symbol,  tf, 14);
   int hSt   = iStochastic(_Symbol, tf, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
   int hF    = iMA(_Symbol,   tf, 20, 0, MODE_EMA, PRICE_CLOSE);
   int hSlow = iMA(_Symbol,   tf, 50, 0, MODE_EMA, PRICE_CLOSE);
   int hBB   = iBands(_Symbol, tf, 20, 0, 2.0, PRICE_CLOSE);

   if(hRSI < 0 || hMACD < 0 || hADX < 0 || hSt < 0 || hF < 0 || hSlow < 0 || hBB < 0)
   {
      if(hRSI  >= 0) IndicatorRelease(hRSI);
      if(hMACD >= 0) IndicatorRelease(hMACD);
      if(hADX  >= 0) IndicatorRelease(hADX);
      if(hSt   >= 0) IndicatorRelease(hSt);
      if(hF    >= 0) IndicatorRelease(hF);
      if(hSlow >= 0) IndicatorRelease(hSlow);
      if(hBB   >= 0) IndicatorRelease(hBB);
      return 0;
   }

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

   IndicatorRelease(hRSI);  IndicatorRelease(hMACD); IndicatorRelease(hADX);
   IndicatorRelease(hSt);   IndicatorRelease(hF);    IndicatorRelease(hSlow);
   IndicatorRelease(hBB);
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

