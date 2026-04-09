#property strict
#include <Trade/Trade.mqh>

//------------------------------------------------------------------
// CMoneyTrailing  (Profit-step trailing in account currency)
//
// Implements step-based trailing stop denominated in account currency
// (e.g. USD), independent of symbol price scale.
//
// Behaviour (BUY example):
//   • Step 1  (profit ≥   1 × stepMoney) → SL moved to entry price.
//     This is the first ratchet step — it is part of the trailing
//     mechanism, not a separate break-even feature.
//   • Step N  (profit ≥   N × stepMoney) → SL is positioned to lock
//     in (N-1) steps of profit: SL = entryPrice + (N-1) × stepPts.
//
//   The SL only ever moves in the favourable direction (ratchet).
//   SYMBOL_TRADE_STOPS_LEVEL and SYMBOL_TRADE_FREEZE_LEVEL are
//   respected; a skipped modification is logged.
//
// Inputs exposed via NEWGOLDMULTI.mq5:
//   InpUseProfitTrailMoney  — enable/disable this trailing system
//   InpTrailStepMoney       — step size in account currency (default $25)
//------------------------------------------------------------------
class CMoneyTrailing
{
private:
   CTrade  m_trade;
   long    m_magic;
   double  m_stepMoney;   // profit step in account currency (e.g. 25.0 USD)
   bool    m_active;

   // Convert an account-currency profit amount to price points for a
   // given position volume.  Returns 0 if data unavailable.
   double MoneyToPoints(double money, double volume)
   {
      if(volume <= 0.0 || money <= 0.0) return 0.0;
      double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double pt       = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      // All three must be positive before any division
      if(tickVal <= 0.0 || tickSize <= 0.0 || pt <= 0.0) return 0.0;
      // value per point per 1 lot; tickSize > 0 verified above (no div-by-zero)
      double valPerPt = tickVal * (pt / tickSize);
      if(valPerPt <= 0.0) return 0.0;
      return money / (valPerPt * volume);
   }

public:
   void Init(long magic, int slippage, double stepMoney)
   {
      m_magic     = magic;
      m_stepMoney = (stepMoney > 0.0 ? stepMoney : 25.0);
      m_active    = (stepMoney > 0.0);
      m_trade.SetExpertMagicNumber(magic);
      m_trade.SetDeviationInPoints(slippage);
   }

   void Manage()
   {
      if(!m_active) return;

      double pt     = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      int    stpLvl = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
      int    frzLvl = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);

      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if((long)PositionGetInteger(POSITION_MAGIC) != m_magic) continue;

         ENUM_POSITION_TYPE pType  = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double openPx  = PositionGetDouble(POSITION_PRICE_OPEN);
         double curSL   = PositionGetDouble(POSITION_SL);
         double curTP   = PositionGetDouble(POSITION_TP);
         double volume  = PositionGetDouble(POSITION_VOLUME);
         double profit  = PositionGetDouble(POSITION_PROFIT)
                        + PositionGetDouble(POSITION_SWAP)
                        + PositionGetDouble(POSITION_COMMISSION);

         // Only manage positions that are in profit
         if(profit < m_stepMoney) continue;

         // How many steps have been reached?
         int steps = (int)MathFloor(profit / m_stepMoney);
         if(steps < 1) continue;

         // Convert (steps - 1) steps of locked profit to price distance
         double lockMoney  = (double)(steps - 1) * m_stepMoney;
         double lockPts    = MoneyToPoints(lockMoney, volume);
         // lockPts is always >= 0 (MoneyToPoints returns 0 when lockMoney=0)

         double minDist = (double)MathMax(stpLvl, 1) * pt;

         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

         if(pType == POSITION_TYPE_BUY)
         {
            // Target SL = entry + locked points
            double newSL = NormalizeDouble(openPx + lockPts * pt, _Digits);

            // Must be strictly above current SL (ratchet)
            if(newSL <= curSL) continue;

            // Broker stop-level check: SL must be at least stpLvl below bid
            if(newSL > bid - minDist)
            {
               Print(StringFormat(
                  "[MoneyTrailing] ticket=%I64u BUY: newSL=%.5f violates stop level (bid=%.5f minDist=%.5f) — skipped",
                  ticket, newSL, bid, minDist));
               continue;
            }

            // Freeze-level check
            if(frzLvl > 0 && curSL > 0.0
               && MathAbs(bid - curSL) <= (double)frzLvl * pt)
            {
               Print(StringFormat(
                  "[MoneyTrailing] ticket=%I64u BUY: position frozen (frzLvl=%d) — skipped",
                  ticket, frzLvl));
               continue;
            }

            if(m_trade.PositionModify(ticket, newSL, curTP))
               Print(StringFormat(
                  "[MoneyTrailing] ticket=%I64u BUY SL moved: %.5f→%.5f (step %d, profit=%.2f)",
                  ticket, curSL, newSL, steps, profit));
            else
               Print(StringFormat(
                  "[MoneyTrailing] ticket=%I64u BUY modify failed retcode=%d",
                  ticket, m_trade.ResultRetcode()));
         }
         else if(pType == POSITION_TYPE_SELL)
         {
            // For SELL: price moves DOWN for profit.  lockPts below entry.
            double newSL = NormalizeDouble(openPx - lockPts * pt, _Digits);

            // Must be strictly below current SL (ratchet — lower is better for SELL)
            if(curSL > 0.0 && newSL >= curSL) continue;

            // Broker stop-level check: SL must be at least stpLvl above ask
            if(newSL < ask + minDist)
            {
               Print(StringFormat(
                  "[MoneyTrailing] ticket=%I64u SELL: newSL=%.5f violates stop level (ask=%.5f minDist=%.5f) — skipped",
                  ticket, newSL, ask, minDist));
               continue;
            }

            // Freeze-level check
            if(frzLvl > 0 && curSL > 0.0
               && MathAbs(ask - curSL) <= (double)frzLvl * pt)
            {
               Print(StringFormat(
                  "[MoneyTrailing] ticket=%I64u SELL: position frozen (frzLvl=%d) — skipped",
                  ticket, frzLvl));
               continue;
            }

            if(m_trade.PositionModify(ticket, newSL, curTP))
               Print(StringFormat(
                  "[MoneyTrailing] ticket=%I64u SELL SL moved: %.5f→%.5f (step %d, profit=%.2f)",
                  ticket, curSL, newSL, steps, profit));
            else
               Print(StringFormat(
                  "[MoneyTrailing] ticket=%I64u SELL modify failed retcode=%d",
                  ticket, m_trade.ResultRetcode()));
         }
      }
   }
};
