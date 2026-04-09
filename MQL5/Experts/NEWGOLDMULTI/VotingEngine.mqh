#property strict
#include "StrategyTypes.mqh"

//------------------------------------------------------------------
// VotingResolve
//
// Counts BUY / SELL votes from all *enabled* strategies.
// A trade is only triggered when ONE side reaches InpMinVotes.
//
// Tie-break order (both sides ≥ minVotes):
//   1. Higher total strength (sum of per-strategy strength values).
//   2. More votes on that side.
//   3. Complete tie → SIGNAL_NONE (cancel, do not trade).
//
// 'winner' is set to the name of the strongest strategy on the
// winning side (highest strength, then lowest priority number).
// 'verbose' controls per-call log output.
//------------------------------------------------------------------
ENUM_SIGNAL_DIR VotingResolve(StrategySignal &signals[], int count,
                               int minVotes, string &winner, bool verbose)
{
   int    buyVotes   = 0,   sellVotes  = 0;
   double buyStr     = 0.0, sellStr    = 0.0;
   int    topBuyIdx  = -1,  topSellIdx = -1;

   for(int i = 0; i < count; i++)
   {
      if(!signals[i].enabled) continue;

      if(signals[i].direction == SIGNAL_BUY)
      {
         buyVotes++;
         buyStr += (double)signals[i].strength;
         if(topBuyIdx < 0
            || signals[i].strength > signals[topBuyIdx].strength
            || (signals[i].strength == signals[topBuyIdx].strength
                && signals[i].priority < signals[topBuyIdx].priority))
            topBuyIdx = i;
      }
      else if(signals[i].direction == SIGNAL_SELL)
      {
         sellVotes++;
         sellStr += (double)signals[i].strength;
         if(topSellIdx < 0
            || signals[i].strength > signals[topSellIdx].strength
            || (signals[i].strength == signals[topSellIdx].strength
                && signals[i].priority < signals[topSellIdx].priority))
            topSellIdx = i;
      }
   }

   if(verbose)
   {
      string buyNames = "", sellNames = "";
      for(int i = 0; i < count; i++)
      {
         if(!signals[i].enabled) continue;
         if(signals[i].direction == SIGNAL_BUY)
            buyNames += signals[i].name + StringFormat("(%d) ", signals[i].strength);
         else if(signals[i].direction == SIGNAL_SELL)
            sellNames += signals[i].name + StringFormat("(%d) ", signals[i].strength);
      }
      Print(StringFormat(
         "[VotingEngine] BUY=%d(str=%.0f) SELL=%d(str=%.0f) minVotes=%d | BUY:[%s] SELL:[%s]",
         buyVotes, buyStr, sellVotes, sellStr, minVotes, buyNames, sellNames));
   }

   bool buyOk  = (buyVotes  >= minVotes);
   bool sellOk = (sellVotes >= minVotes);

   if(!buyOk && !sellOk) { winner = "no consensus";    return SIGNAL_NONE; }

   if( buyOk && !sellOk)
   {
      winner = (topBuyIdx  >= 0 ? signals[topBuyIdx].name  : "buy-consensus");
      return SIGNAL_BUY;
   }
   if(!buyOk &&  sellOk)
   {
      winner = (topSellIdx >= 0 ? signals[topSellIdx].name : "sell-consensus");
      return SIGNAL_SELL;
   }

   // Both sides reached minVotes — tie-break by strength then vote count
   if(buyStr > sellStr)
   {
      winner = (topBuyIdx  >= 0 ? signals[topBuyIdx].name  : "buy-strength");
      return SIGNAL_BUY;
   }
   if(sellStr > buyStr)
   {
      winner = (topSellIdx >= 0 ? signals[topSellIdx].name : "sell-strength");
      return SIGNAL_SELL;
   }
   if(buyVotes > sellVotes)
   {
      winner = (topBuyIdx  >= 0 ? signals[topBuyIdx].name  : "buy-votes");
      return SIGNAL_BUY;
   }
   if(sellVotes > buyVotes)
   {
      winner = (topSellIdx >= 0 ? signals[topSellIdx].name : "sell-votes");
      return SIGNAL_SELL;
   }

   winner = "vote-tie-cancel";
   return SIGNAL_NONE;
}
