#property strict
#include "StrategyTypes.mqh"

int SigVolumeAnalysis(StrategySignal &s, ENUM_TIMEFRAMES tf)
{
   MqlRates r[]; ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, tf, 0, 60, r) < 30) return 0;

   long vol[]; ArraySetAsSeries(vol, true);
   if(CopyTickVolume(_Symbol, tf, 0, 60, vol) < 30) return 0;

   // Rolling average volume (bars 5..24, skip most-recent 5 for stability)
   double avgVol = 0.0;
   for(int i = 5; i < 25; i++) avgVol += (double)vol[i];
   avgVol /= 20.0;
   if(avgVol <= 0.0) return 0;

   int b = 0, se = 0;

   // Relative volume of current bar
   double relVol = (double)vol[0] / avgVol;

   // Climax / spike volume with directional confirmation
   if(relVol >= 2.0 && r[0].close > r[0].open) b++;
   if(relVol >= 2.0 && r[0].close < r[0].open) se++;

   // Consecutive rising volume with consistent direction (trend continuation)
   if(vol[0] > vol[1] && vol[1] > vol[2]
   && r[0].close > r[0].open && r[1].close > r[1].open) b++;
   if(vol[0] > vol[1] && vol[1] > vol[2]
   && r[0].close < r[0].open && r[1].close < r[1].open) se++;

   // OBV net direction over last 20 bars
   double obv = 0.0;
   for(int i = 1; i < 20; i++)
   {
      if(r[i-1].close > r[i].close)      obv += (double)vol[i-1];
      else if(r[i-1].close < r[i].close) obv -= (double)vol[i-1];
   }
   // Significant net OBV = more than 2x average per bar over 20 bars
   if(obv >  avgVol * 2.0) b++;
   if(obv < -avgVol * 2.0) se++;

   // Normalize to 0..5
   b  = MathMin(b,  5);
   se = MathMin(se, 5);

   if(b > 0 && b >= se)
      { s.direction = SIGNAL_BUY;  s.strength = b;  s.reason = "volume bullish"; }
   else if(se > 0 && se > b)
      { s.direction = SIGNAL_SELL; s.strength = se; s.reason = "volume bearish"; }
   return MathMax(b, se);
}

