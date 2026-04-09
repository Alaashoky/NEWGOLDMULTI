#property strict
#include "StrategyTypes.mqh"

bool _HP_Near(double a,double b,double tol){return MathAbs(a-b)<=tol;}

int SigHarmonicPatterns(StrategySignal &s, ENUM_TIMEFRAMES tf)
{
   MqlRates r[]; ArraySetAsSeries(r,true); if(CopyRates(_Symbol,tf,0,160,r)<120) return 0;
   int b=0,se=0;

   // Use 5 pivots X,A,B,C,D approximations by sampled swings
   double X=r[100].close, A=r[80].close, B=r[60].close, C=r[40].close, D=r[20].close;
   double XA=MathAbs(A-X), AB=MathAbs(B-A), BC=MathAbs(C-B), CD=MathAbs(D-C);
   if(XA<=0||AB<=0||BC<=0||CD<=0) return 0;

   double rAB=AB/XA, rBC=BC/AB, rCD=CD/BC;
   double tol=0.18;

   // Generic harmonic bullish completion near D (gartley/bat/butterfly/crab approximations)
   bool bullish = _HP_Near(rAB,0.618,tol) && (_HP_Near(rBC,0.382,tol)||_HP_Near(rBC,0.886,tol)) && (rCD>1.2&&rCD<3.8) && r[0].close>r[1].close;
   bool bearish = _HP_Near(rAB,0.618,tol) && (_HP_Near(rBC,0.382,tol)||_HP_Near(rBC,0.886,tol)) && (rCD>1.2&&rCD<3.8) && r[0].close<r[1].close;

   if(bullish) b=2;
   if(bearish) se=2;

   if(b>0&&b>=se){s.direction=SIGNAL_BUY;s.strength=b;s.reason="harmonic bullish completion";}
   else if(se>0&&se>b){s.direction=SIGNAL_SELL;s.strength=se;s.reason="harmonic bearish completion";}
   return MathMax(b,se);
}
