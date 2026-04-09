#property strict
#include <Trade/Trade.mqh>

//------------------------------------------------------------------
// CTrailingStop
//
// Manages break-even and trailing stop for open positions that
// belong to the configured magic number on the current symbol.
//
// All distance parameters are in **points** (_Point units).
//
// Break-even logic (BUY example):
//   Once floating profit >= beStartPts, the SL is raised to
//   (openPrice + beBufferPts).  beBufferPts = 0 means exact
//   entry; a small positive value locks in a few points of profit.
//
// Trailing logic (BUY example):
//   Once floating profit >= trailStartPts, the SL tracks
//   (currentBid - trailDistPts).  The SL is only ever moved
//   upward (never lowered), ensuring ratchet protection.
//
// Broker safety:
//   Both SYMBOL_TRADE_STOPS_LEVEL and SYMBOL_TRADE_FREEZE_LEVEL
//   are respected; a modification is skipped when the new SL
//   would violate either constraint.
//------------------------------------------------------------------
class CTrailingStop
{
private:
   CTrade  m_trade;
   long    m_magic;
   double  m_beStart;      // points profit before BE activates
   double  m_beBuffer;     // extra points above/below entry for BE SL
   double  m_trailStart;   // points profit before trailing activates
   double  m_trailDist;    // trailing distance from price (points)
   bool    m_active;

public:
   void Init(long magic, int slippage,
             double beStartPts, double beBufferPts,
             double trailStartPts, double trailDistPts)
   {
      m_magic      = magic;
      m_beStart    = beStartPts;
      m_beBuffer   = beBufferPts;
      m_trailStart = trailStartPts;
      m_trailDist  = trailDistPts;
      m_active     = (beStartPts > 0.0 || trailStartPts > 0.0);
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
         double bid     = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double ask     = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

         if(pType == POSITION_TYPE_BUY)
         {
            double profitPts = (bid - openPx) / pt;
            double newSL     = 0.0;   // 0 = "no candidate yet"
            // --- Break-even ---
            if(m_beStart > 0.0 && profitPts >= m_beStart)
            {
               double beSL = NormalizeDouble(openPx + m_beBuffer * pt, _Digits);
               if(beSL > newSL) newSL = beSL;
            }

            // --- Trailing stop ---
            if(m_trailStart > 0.0 && profitPts >= m_trailStart)
            {
               double tSL = NormalizeDouble(bid - m_trailDist * pt, _Digits);
               if(tSL > newSL) newSL = tSL;
            }

            if(newSL <= 0.0) continue;

            // Only move SL upward (strict ratchet — never lower the SL for BUY)
            if(newSL <= curSL) continue;

            // Respect broker stop level (SL must be below bid by at least stpLvl points)
            double minDist = (double)MathMax(stpLvl, 1) * pt;
            if(newSL > bid - minDist) continue;

            // Respect freeze level
            if(frzLvl > 0 && curSL > 0.0)
               if(MathAbs(bid - curSL) <= (double)frzLvl * pt) continue;

            m_trade.PositionModify(ticket, newSL, curTP);
         }
         else if(pType == POSITION_TYPE_SELL)
         {
            double profitPts = (openPx - ask) / pt;
            double newSL     = 0.0;   // 0 = "no candidate yet"

            // --- Break-even ---
            if(m_beStart > 0.0 && profitPts >= m_beStart)
            {
               double beSL = NormalizeDouble(openPx - m_beBuffer * pt, _Digits);
               if(newSL == 0.0 || beSL < newSL) newSL = beSL;
            }

            // --- Trailing stop ---
            if(m_trailStart > 0.0 && profitPts >= m_trailStart)
            {
               double tSL = NormalizeDouble(ask + m_trailDist * pt, _Digits);
               if(newSL == 0.0 || tSL < newSL) newSL = tSL;
            }

            if(newSL <= 0.0) continue;

            // Only move SL downward (strict ratchet — never raise the SL for SELL)
            if(curSL > 0.0 && newSL >= curSL) continue;

            // Respect broker stop level (SL must be above ask by at least stpLvl points)
            double minDist = (double)MathMax(stpLvl, 1) * pt;
            if(newSL < ask + minDist) continue;

            // Respect freeze level
            if(frzLvl > 0 && curSL > 0.0)
               if(MathAbs(ask - curSL) <= (double)frzLvl * pt) continue;

            m_trade.PositionModify(ticket, newSL, curTP);
         }
      }
   }
};
