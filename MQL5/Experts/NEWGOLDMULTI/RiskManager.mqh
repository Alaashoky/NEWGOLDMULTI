#property strict

struct RiskConfig
{
   bool   useFixedLot;
   double fixedLot;
   double riskPercent;
   double stopLossPoints;
   double takeProfitPoints;
   double maxDrawdownPercent;
   double maxSpreadPoints;
   int    maxSlippagePoints;
};

class CRiskManager
{
private:
   RiskConfig m_cfg;
   double     m_peakEquity;

public:
   void Init(RiskConfig &cfg)
   {
      m_cfg = cfg;
      m_peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   }

   RiskConfig GetConfig() const { return m_cfg; }

   bool EquityProtectionOk(string &reason)
   {
      double eq = AccountInfoDouble(ACCOUNT_EQUITY);
      if(eq > m_peakEquity) m_peakEquity = eq;
      if(m_peakEquity <= 0.0 || m_cfg.maxDrawdownPercent <= 0.0) return true;

      double dd = 100.0 * (m_peakEquity - eq) / m_peakEquity;
      if(dd >= m_cfg.maxDrawdownPercent)
      {
         reason = StringFormat("drawdown %.2f%% >= max %.2f%%", dd, m_cfg.maxDrawdownPercent);
         return false;
      }
      return true;
   }

   bool SpreadOk(string &reason)
   {
      if(m_cfg.maxSpreadPoints <= 0.0) return true;
      double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > m_cfg.maxSpreadPoints)
      {
         reason = StringFormat("spread %.1f > max %.1f points", spread, m_cfg.maxSpreadPoints);
         return false;
      }
      return true;
   }

   double CalcLots()
   {
      if(m_cfg.useFixedLot) return NormalizeVolume(m_cfg.fixedLot);

      double eq = AccountInfoDouble(ACCOUNT_EQUITY);
      double riskMoney = eq * (m_cfg.riskPercent / 100.0);
      if(riskMoney <= 0.0 || m_cfg.stopLossPoints <= 0.0) return NormalizeVolume(m_cfg.fixedLot);

      double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tickVal <= 0.0 || tickSize <= 0.0) return NormalizeVolume(m_cfg.fixedLot);

      double valuePerPointPerLot = tickVal * (_Point / tickSize);
      if(valuePerPointPerLot <= 0.0) return NormalizeVolume(m_cfg.fixedLot);

      double lots = riskMoney / (m_cfg.stopLossPoints * valuePerPointPerLot);
      return NormalizeVolume(lots);
   }

   double CalcSL(ENUM_ORDER_TYPE type, double price)
   {
      if(m_cfg.stopLossPoints <= 0) return 0.0;
      if(type == ORDER_TYPE_BUY) return NormalizeDouble(price - m_cfg.stopLossPoints * _Point, _Digits);
      return NormalizeDouble(price + m_cfg.stopLossPoints * _Point, _Digits);
   }

   double CalcTP(ENUM_ORDER_TYPE type, double price)
   {
      if(m_cfg.takeProfitPoints <= 0) return 0.0;
      if(type == ORDER_TYPE_BUY) return NormalizeDouble(price + m_cfg.takeProfitPoints * _Point, _Digits);
      return NormalizeDouble(price - m_cfg.takeProfitPoints * _Point, _Digits);
   }

private:
   double NormalizeVolume(double v)
   {
      double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      if(step <= 0) step = 0.01;
      v = MathMax(vmin, MathMin(vmax, v));
      v = MathFloor(v / step) * step;
      return NormalizeDouble(v, 2);
   }
};

//------------------------------------------------------------------
// CDailyDDGuard — daily drawdown protection
//
// At the start of each broker day (server time) the equity is
// captured.  Once the intra-day drawdown from that equity reaches
// the configured threshold (default 5%), new trade entries are
// blocked.  The block resets automatically at the next day.
//
// Integration:
//   • Call DailyDDGuard.Update() on every tick (lightweight).
//   • Gate new entries with DailyDDGuard.AllowNewTrade(reason).
//   • Trailing stop management is intentionally NOT blocked.
//------------------------------------------------------------------
class CDailyDDGuard
{
private:
   bool    m_enabled;
   double  m_threshold;      // e.g. 5.0 %
   double  m_dayStartEquity;
   int     m_dayStartDay;    // MQL5 DayOfYear

   int TodayDayOfYear()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      return dt.day_of_year;
   }

public:
   void Init(bool enabled, double thresholdPct)
   {
      m_enabled        = enabled;
      m_threshold      = (thresholdPct > 0.0 ? thresholdPct : 5.0);
      m_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      m_dayStartDay    = TodayDayOfYear();
   }

   // Call every tick — resets the daily baseline when the day rolls over.
   void Update()
   {
      if(!m_enabled) return;
      int today = TodayDayOfYear();
      if(today != m_dayStartDay)
      {
         m_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
         m_dayStartDay    = today;
         Print(StringFormat("[DailyDDGuard] New day — baseline equity reset to %.2f",
                            m_dayStartEquity));
      }
   }

   // Returns true when a new entry is permitted; false + reason when blocked.
   bool AllowNewTrade(string &reason)
   {
      if(!m_enabled) return true;
      if(m_dayStartEquity <= 0.0) return true;

      double eq = AccountInfoDouble(ACCOUNT_EQUITY);
      double dd = 100.0 * (m_dayStartEquity - eq) / m_dayStartEquity;
      if(dd >= m_threshold)
      {
         reason = StringFormat(
            "daily drawdown %.2f%% >= limit %.2f%% (start=%.2f cur=%.2f)",
            dd, m_threshold, m_dayStartEquity, eq);
         return false;
      }
      return true;
   }
};

