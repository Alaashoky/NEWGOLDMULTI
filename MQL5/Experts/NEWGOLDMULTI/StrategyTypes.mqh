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
