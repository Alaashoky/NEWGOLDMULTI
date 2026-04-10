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

   // Determine raw winning direction
   ENUM_SIGNAL_DIR rawDir = SIGNAL_NONE;
   string rawWinner = "";

   if(!buyOk && !sellOk) { winner = "no consensus"; return SIGNAL_NONE; }

   if(buyOk && !sellOk)
   {
      rawDir    = SIGNAL_BUY;
      rawWinner = (topBuyIdx >= 0 ? signals[topBuyIdx].name : "buy-consensus");
   }
   else if(!buyOk && sellOk)
   {
      rawDir    = SIGNAL_SELL;
      rawWinner = (topSellIdx >= 0 ? signals[topSellIdx].name : "sell-consensus");
   }
   else
   {
      // Both sides reached minVotes — tie-break by strength then vote count
      if(buyStr > sellStr)
      { rawDir = SIGNAL_BUY;  rawWinner = (topBuyIdx  >= 0 ? signals[topBuyIdx].name  : "buy-strength"); }
      else if(sellStr > buyStr)
      { rawDir = SIGNAL_SELL; rawWinner = (topSellIdx >= 0 ? signals[topSellIdx].name : "sell-strength"); }
      else if(buyVotes > sellVotes)
      { rawDir = SIGNAL_BUY;  rawWinner = (topBuyIdx  >= 0 ? signals[topBuyIdx].name  : "buy-votes"); }
      else if(sellVotes > buyVotes)
      { rawDir = SIGNAL_SELL; rawWinner = (topSellIdx >= 0 ? signals[topSellIdx].name : "sell-votes"); }
      else
      { winner = "vote-tie-cancel"; return SIGNAL_NONE; }
   }

   // --- Mandatory MultiTimeframe trend filter ---
   // If MTF is enabled and disagrees with the winning direction → cancel the trade.
   for(int i = 0; i < count; i++)
   {
      if(!signals[i].enabled) continue;
      if(signals[i].name != "MultiTimeframe") continue;
      if(signals[i].direction != SIGNAL_NONE && signals[i].direction != rawDir)
      {
         winner = "mtf-trend-conflict";
         if(verbose)
            Print("[VotingEngine] Trade cancelled: MTF conflict (MTF=",
                  (int)signals[i].direction, " vs winner=", (int)rawDir, ")");
         return SIGNAL_NONE;
      }
      break;
   }

   winner = rawWinner;
   return rawDir;
}
