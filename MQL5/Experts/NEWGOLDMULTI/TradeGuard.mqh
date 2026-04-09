#property strict

#include <Trade/Trade.mqh>
#include "StrategyTypes.mqh"

class CTradeGuard
{
private:
   CTrade m_trade;
   long   m_magic;
   datetime m_lastSignalBar;

public:
   void Init(long magic, int slippage)
   {
      m_magic = magic;
      m_lastSignalBar = 0;
      m_trade.SetExpertMagicNumber(magic);
      m_trade.SetDeviationInPoints(slippage);
   }

   bool HasOpenPosition()
   {
      for(int i=PositionsTotal()-1; i>=0; --i)
      {
         if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if((long)PositionGetInteger(POSITION_MAGIC) != m_magic) continue;
         return true;
      }
      return false;
   }

   bool AllowSignalOnBar(datetime barTime, string &reason)
   {
      if(m_lastSignalBar == barTime)
      {
         reason = "duplicate signal on same bar";
         return false;
      }
      return true;
   }

   void MarkSignalBar(datetime barTime)
   {
      m_lastSignalBar = barTime;
   }

   bool Execute(ENUM_SIGNAL_DIR dir, double lots, double sl, double tp, string comment, string &reason)
   {
      if(dir == SIGNAL_NONE)
      {
         reason = "no direction";
         return false;
      }

      bool ok = false;
      if(dir == SIGNAL_BUY)
         ok = m_trade.Buy(lots, _Symbol, 0.0, sl, tp, comment);
      else if(dir == SIGNAL_SELL)
         ok = m_trade.Sell(lots, _Symbol, 0.0, sl, tp, comment);

      if(!ok)
      {
         reason = StringFormat("Order failed retcode=%d", m_trade.ResultRetcode());
         return false;
      }
      return true;
   }

   ENUM_SIGNAL_DIR Resolve(StrategySignal &signals[], int count, string &winner)
   {
      int bestIdx = -1;
      for(int i=0; i<count; ++i)
      {
         if(!signals[i].enabled) continue;
         if(signals[i].direction == SIGNAL_NONE) continue;

         if(bestIdx < 0)
         {
            bestIdx = i;
            continue;
         }

         // higher strength first, then smaller priority value (lower number = higher priority)
         if(signals[i].strength > signals[bestIdx].strength ||
            (signals[i].strength == signals[bestIdx].strength && signals[i].priority < signals[bestIdx].priority))
         {
            bestIdx = i;
         }
      }

      if(bestIdx < 0)
      {
         winner = "none";
         return SIGNAL_NONE;
      }

      // if same strength+priority with opposite direction => cancel
      for(int i=0; i<count; ++i)
      {
         if(i == bestIdx || !signals[i].enabled || signals[i].direction == SIGNAL_NONE) continue;
         bool sameRank = (signals[i].strength == signals[bestIdx].strength && signals[i].priority == signals[bestIdx].priority);
         bool opposite = (signals[i].direction != signals[bestIdx].direction);
         if(sameRank && opposite)
         {
            winner = "conflict-cancel";
            return SIGNAL_NONE;
         }
      }

      winner = signals[bestIdx].name;
      return signals[bestIdx].direction;
   }
};
