#property strict

enum ENUM_SIGNAL_DIR
{
   SIGNAL_NONE = 0,
   SIGNAL_BUY  = 1,
   SIGNAL_SELL = -1
};

struct StrategySignal
{
   string          name;
   bool            enabled;
   int             priority;
   ENUM_SIGNAL_DIR direction;
   int             strength;
   string          reason;
};

void SignalReset(StrategySignal &s, string n, bool e, int p)
{
   s.name      = n;
   s.enabled   = e;
   s.priority  = p;
   s.direction = SIGNAL_NONE;
   s.strength  = 0;
   s.reason    = "no signal";
}

//------------------------------------------------------------------
// Swing-point helpers
// Arrays must be ArraySetAsSeries(true) — index 0 = most recent.
// 'start' and 'end' are inclusive bar indices to search.
// 'side' = number of bars on each side that must be lower/higher.
// Returns the index of the first (most-recent) qualifying swing,
// or -1 if none found.
//------------------------------------------------------------------
int SwingHigh(MqlRates &r[], int start, int end, int side)
{
   int total = ArraySize(r);
   for(int i = start; i <= end; i++)
   {
      if(i - side < 0 || i + side >= total) continue;
      bool ok = true;
      for(int j = 1; j <= side && ok; j++)
         if(r[i].high <= r[i - j].high || r[i].high <= r[i + j].high) ok = false;
      if(ok) return i;
   }
   return -1;
}

int SwingLow(MqlRates &r[], int start, int end, int side)
{
   int total = ArraySize(r);
   for(int i = start; i <= end; i++)
   {
      if(i - side < 0 || i + side >= total) continue;
      bool ok = true;
      for(int j = 1; j <= side && ok; j++)
         if(r[i].low >= r[i - j].low || r[i].low >= r[i + j].low) ok = false;
      if(ok) return i;
   }
   return -1;
}
