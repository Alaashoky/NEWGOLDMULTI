#property strict

//------------------------------------------------------------------
// BarRatesCache
//
// Lightweight per-bar cache for CopyRates results.  Multiple strategy
// modules that request rates for the same (symbol, TF) on the same
// bar receive a single shared copy — avoiding redundant data-provider
// round-trips in the Strategy Tester.
//
// Usage (inside strategy functions):
//   MqlRates r[];  ArraySetAsSeries(r, true);
//   if(!GetCachedRates(tf, 200, r)) return 0;
//
// Key guarantees:
//   • Cache is keyed on (timeframe, barTime).  A new bar flushes the
//     slot for that TF automatically.
//   • If a later caller requests MORE bars than are stored, the slot is
//     refreshed with the larger count so subsequent callers benefit.
//   • Thread-safety is not required for MQL5 single-thread execution.
//------------------------------------------------------------------
#define BAR_CACHE_SLOTS 10   // support up to 10 different (TF) slots

struct _BarRatesCacheEntry
{
   ENUM_TIMEFRAMES tf;
   datetime        barTime;
   MqlRates        data[];
};

static _BarRatesCacheEntry _g_brc[BAR_CACHE_SLOTS];
static int                 _g_brc_n = 0;

bool GetCachedRates(ENUM_TIMEFRAMES tf, int needed, MqlRates &rates[])
{
   datetime barTime = iTime(_Symbol, tf, 0);
   if(barTime <= 0) return false;

   // Search existing slots
   for(int i = 0; i < _g_brc_n; i++)
   {
      if(_g_brc[i].tf != tf) continue;

      if(_g_brc[i].barTime == barTime && ArraySize(_g_brc[i].data) >= needed)
      {
         // Cache hit — copy to caller
         ArraySetAsSeries(rates, true);
         ArrayCopy(rates, _g_brc[i].data, 0, 0, needed);
         return true;
      }
      // Same TF but stale bar or insufficient data — fall through to refetch
      break;
   }

   // Cache miss — fetch fresh data
   MqlRates tmp[];
   ArraySetAsSeries(tmp, true);
   int got = CopyRates(_Symbol, tf, 0, needed, tmp);
   if(got < needed) return false;

   // Find or allocate slot
   int slot = -1;
   for(int i = 0; i < _g_brc_n; i++)
      if(_g_brc[i].tf == tf) { slot = i; break; }
   if(slot < 0)
   {
      if(_g_brc_n < BAR_CACHE_SLOTS) slot = _g_brc_n++;
      else                            slot = 0;   // fallback: overwrite first
   }

   _g_brc[slot].tf      = tf;
   _g_brc[slot].barTime = barTime;
   ArraySetAsSeries(_g_brc[slot].data, true);
   ArrayResize(_g_brc[slot].data, got);
   ArrayCopy(_g_brc[slot].data, tmp);

   ArraySetAsSeries(rates, true);
   ArrayCopy(rates, tmp);
   return true;
}

//------------------------------------------------------------------

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
