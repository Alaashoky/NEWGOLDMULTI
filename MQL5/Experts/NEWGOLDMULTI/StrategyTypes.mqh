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
         // Full cache hit — copy subset to caller
         ArraySetAsSeries(rates, true);
         ArrayCopy(rates, _g_brc[i].data, 0, 0, needed);
         return true;
      }
      // Same TF slot found but either stale bar or too few bars stored.
      // Exit loop and fall through to refetch; the slot will be reused below.
      break;
   }

   // Cache miss / refresh — fetch fresh data
   MqlRates tmp[];
   ArraySetAsSeries(tmp, true);
   int got = CopyRates(_Symbol, tf, 0, needed, tmp);
   if(got < needed) return false;

   // Reuse the existing slot for this TF, or allocate a new one.
   // If the table is full use a simple round-robin to avoid always evicting
   // slot 0 when many timeframes are active.
   static int _g_brc_evict = 0;
   int slot = -1;
   for(int i = 0; i < _g_brc_n; i++)
      if(_g_brc[i].tf == tf) { slot = i; break; }
   if(slot < 0)
   {
      if(_g_brc_n < BAR_CACHE_SLOTS)
         slot = _g_brc_n++;
      else
      {
         slot = _g_brc_evict;
         _g_brc_evict = (_g_brc_evict + 1) % BAR_CACHE_SLOTS;
      }
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
// Indicator Handle Pool
//
// Handles are created lazily on first use and reused for the entire
// EA session.  This eliminates the per-tick/per-bar overhead of
// creating and releasing indicator instances inside strategy
// functions, which is the primary cause of backtest slowness.
//
// Usage inside strategy functions:
//   int h = IndGet_ATR(tf, 14);
//   if(h == INVALID_HANDLE) return 0;
//   CopyBuffer(h, 0, 0, 1, buf);   // no IndicatorRelease needed
//
// Call IndPoolReleaseAll() inside OnDeinit() to free handles.
//------------------------------------------------------------------
#define IND_POOL_SIZE 64

struct _IndPoolEntry
{
   string key;
   int    handle;
};

static _IndPoolEntry _g_indPool[IND_POOL_SIZE];
static int           _g_indPool_n = 0;

int IndPoolGet(const string &key)
{
   for(int i = 0; i < _g_indPool_n; i++)
      if(_g_indPool[i].key == key) return _g_indPool[i].handle;
   return INVALID_HANDLE;
}

void IndPoolAdd(const string &key, int handle)
{
   if(_g_indPool_n < IND_POOL_SIZE)
   {
      _g_indPool[_g_indPool_n].key    = key;
      _g_indPool[_g_indPool_n].handle = handle;
      _g_indPool_n++;
   }
   else
   {
      Print(StringFormat("[IndPool] WARNING: pool full (%d slots). Handle for '%s' will not be cached — consider increasing IND_POOL_SIZE.", IND_POOL_SIZE, key));
   }
}

void IndPoolReleaseAll()
{
   for(int i = 0; i < _g_indPool_n; i++)
      if(_g_indPool[i].handle != INVALID_HANDLE)
         IndicatorRelease(_g_indPool[i].handle);
   _g_indPool_n = 0;
}

// Convenience: get-or-create helpers for each indicator type used

int IndGet_ATR(ENUM_TIMEFRAMES tf, int period)
{
   string key = StringFormat("ATR_%d_%d", (int)tf, period);
   int h = IndPoolGet(key);
   if(h == INVALID_HANDLE)
   {
      h = iATR(_Symbol, tf, period);
      if(h != INVALID_HANDLE) IndPoolAdd(key, h);
   }
   return h;
}

int IndGet_RSI(ENUM_TIMEFRAMES tf, int period)
{
   string key = StringFormat("RSI_%d_%d", (int)tf, period);
   int h = IndPoolGet(key);
   if(h == INVALID_HANDLE)
   {
      h = iRSI(_Symbol, tf, period, PRICE_CLOSE);
      if(h != INVALID_HANDLE) IndPoolAdd(key, h);
   }
   return h;
}

int IndGet_MACD(ENUM_TIMEFRAMES tf, int fast, int slow, int sig)
{
   string key = StringFormat("MACD_%d_%d_%d_%d", (int)tf, fast, slow, sig);
   int h = IndPoolGet(key);
   if(h == INVALID_HANDLE)
   {
      h = iMACD(_Symbol, tf, fast, slow, sig, PRICE_CLOSE);
      if(h != INVALID_HANDLE) IndPoolAdd(key, h);
   }
   return h;
}

int IndGet_ADX(ENUM_TIMEFRAMES tf, int period)
{
   string key = StringFormat("ADX_%d_%d", (int)tf, period);
   int h = IndPoolGet(key);
   if(h == INVALID_HANDLE)
   {
      h = iADX(_Symbol, tf, period);
      if(h != INVALID_HANDLE) IndPoolAdd(key, h);
   }
   return h;
}

int IndGet_Stoch(ENUM_TIMEFRAMES tf, int kp, int dp, int slowing)
{
   string key = StringFormat("STOCH_%d_%d_%d_%d", (int)tf, kp, dp, slowing);
   int h = IndPoolGet(key);
   if(h == INVALID_HANDLE)
   {
      h = iStochastic(_Symbol, tf, kp, dp, slowing, MODE_SMA, STO_LOWHIGH);
      if(h != INVALID_HANDLE) IndPoolAdd(key, h);
   }
   return h;
}

int IndGet_EMA(ENUM_TIMEFRAMES tf, int period)
{
   string key = StringFormat("EMA_%d_%d", (int)tf, period);
   int h = IndPoolGet(key);
   if(h == INVALID_HANDLE)
   {
      h = iMA(_Symbol, tf, period, 0, MODE_EMA, PRICE_CLOSE);
      if(h != INVALID_HANDLE) IndPoolAdd(key, h);
   }
   return h;
}

int IndGet_BB(ENUM_TIMEFRAMES tf, int period, double dev)
{
   string key = StringFormat("BB_%d_%d_%d", (int)tf, period, (int)(dev * 100.0));
   int h = IndPoolGet(key);
   if(h == INVALID_HANDLE)
   {
      h = iBands(_Symbol, tf, period, 0, dev, PRICE_CLOSE);
      if(h != INVALID_HANDLE) IndPoolAdd(key, h);
   }
   return h;
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
