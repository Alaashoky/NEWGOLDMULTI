#property strict
#include "StrategyTypes.mqh"

int SigMultiTimeframe(StrategySignal &s)
{
   ENUM_TIMEFRAMES tfs[3]={PERIOD_H4,PERIOD_D1,PERIOD_W1};
   int weights[3]={1,1,2};
   int b=0,se=0;

   for(int i=0;i<3;i++)
   {
      MqlRates r[]; ArraySetAsSeries(r,true); if(CopyRates(_Symbol,tfs[i],0,15,r)<10) continue;
      int h20=iMA(_Symbol,tfs[i],20,0,MODE_EMA,PRICE_CLOSE), h50=iMA(_Symbol,tfs[i],50,0,MODE_EMA,PRICE_CLOSE);
      if(h20<0||h50<0) continue;
      double ma20[],ma50[]; ArraySetAsSeries(ma20,true);ArraySetAsSeries(ma50,true);
      bool ok=CopyBuffer(h20,0,0,2,ma20)>=1&&CopyBuffer(h50,0,0,2,ma50)>=1; IndicatorRelease(h20);IndicatorRelease(h50); if(!ok) continue;

      if(ma20[0]>ma50[0]&&r[0].close>ma20[0]) b+=weights[i];
      if(ma20[0]<ma50[0]&&r[0].close<ma20[0]) se+=weights[i];
      bool strongBull=(r[0].close>r[0].open&&(r[0].close-r[0].open)>0.7*(r[0].high-r[0].low));
      bool strongBear=(r[0].close<r[0].open&&(r[0].open-r[0].close)>0.7*(r[0].high-r[0].low));
      if(strongBull) b+=1;
      if(strongBear) se+=1;
   }

   if(b>3)b=3; if(se>3)se=3;
   if(b>0&&b>=se){s.direction=SIGNAL_BUY;s.strength=b;s.reason="multi timeframe buy";}
   else if(se>0&&se>b){s.direction=SIGNAL_SELL;s.strength=se;s.reason="multi timeframe sell";}
   return MathMax(b,se);
}
