#property strict
#property version   "3.00"
#property description "NEWGOLDMULTI - Unified multi-strategy EA with voting consensus engine"

#include "StrategyTypes.mqh"
#include "RiskManager.mqh"
#include "TradeGuard.mqh"
#include "VotingEngine.mqh"
#include "PositionManager.mqh"

#include "Strategy_Indicators.mqh"
#include "Strategy_MACrossover.mqh"
#include "Strategy_CandlePatterns.mqh"
#include "Strategy_PriceAction.mqh"
#include "Strategy_SupportResistance.mqh"
#include "Strategy_PivotPoints.mqh"
#include "Strategy_MultiTimeframe.mqh"
#include "Strategy_Divergence.mqh"
#include "Strategy_ElliottWaves.mqh"
#include "Strategy_HarmonicPatterns.mqh"
#include "Strategy_ChartPatterns.mqh"
#include "Strategy_VolumeAnalysis.mqh"
#include "Strategy_TimeAnalysis.mqh"
#include "Strategy_WolfeWaves.mqh"

// ===== Master Inputs =====
input bool   InpEnableTrading            = true;
input long   InpMagicNumber              = 5102026;
input bool   InpAllowMultiplePositions   = false;
input bool   InpVerboseLogs              = false;

// ===== Risk Inputs =====
input bool   InpUseFixedLot              = true;
input double InpFixedLot                 = 0.01;
input double InpRiskPercent              = 1.0;
input double InpStopLossPoints           = 800;
input double InpTakeProfitPoints         = 1200;
input double InpMaxDrawdownPercent       = 20.0;
input double InpMaxSpreadPoints          = 80;
input int    InpMaxSlippagePoints        = 20;

// ===== Voting Engine =====
// InpMinVotes: minimum number of strategies that must agree on
//   the same direction before a trade is placed (default 3).
//   Range: 1..14.  Higher = more selective / fewer trades.
input int  InpMinVotes = 3;

// ===== Strategy Toggles + Priority =====
// Enable/disable each strategy independently.
// Priority (lower number = higher priority) is used for tie-breaking
// when multiple strategies disagree on strength.
input bool InpUseIndicators          = true;  input int InpPriIndicators          = 10;
input bool InpUseMACrossover         = true;  input int InpPriMACrossover         = 20;
input bool InpUseCandlePatterns      = true;  input int InpPriCandlePatterns      = 30;
input bool InpUsePriceAction         = true;  input int InpPriPriceAction         = 40;
input bool InpUseSupportResistance   = true;  input int InpPriSupportResistance   = 50;
input bool InpUsePivotPoints         = true;  input int InpPriPivotPoints         = 60;
input bool InpUseMultiTimeframe      = true;  input int InpPriMultiTimeframe      = 70;
input bool InpUseDivergence          = true;  input int InpPriDivergence          = 80;
input bool InpUseElliottWaves        = true;  input int InpPriElliottWaves        = 90;
input bool InpUseHarmonicPatterns    = true;  input int InpPriHarmonicPatterns    = 100;
input bool InpUseChartPatterns       = true;  input int InpPriChartPatterns       = 110;
input bool InpUseVolumeAnalysis      = true;  input int InpPriVolumeAnalysis      = 120;
input bool InpUseTimeAnalysis        = true;  input int InpPriTimeAnalysis        = 130;
input bool InpUseWolfeWaves          = true;  input int InpPriWolfeWaves          = 140;

// ===== Strategy Timeframes =====
input ENUM_TIMEFRAMES InpSignalTF    = PERIOD_M15;
input ENUM_TIMEFRAMES InpSRTF        = PERIOD_H1;

// ===== Specific Strategy Params =====
input int InpIndicatorsMinVotes = 3;
input int InpMAFast = 8, InpMASlow = 21, InpMALong = 200, InpMAMinConf = 2;

// ===== Profit-Step Trailing (USD) =====
// Currency-denominated step trailing independent of symbol price scale.
// InpUseProfitTrailMoney : enable/disable this trailing system.
// InpTrailStepMoney      : step size in account currency (default $25).
//   Behaviour: when floating profit reaches N × step, SL is moved to
//   lock in (N-1) × step of profit.  At step 1 SL moves to entry price.
input bool   InpUseProfitTrailMoney = true;
input double InpTrailStepMoney      = 25.0;

// ===== Daily Drawdown Guard =====
// InpUseDailyDDGuard    : enable/disable daily drawdown protection.
// InpMaxDailyDDPercent  : max intra-day equity drawdown (%) before new
//                         entries are blocked.  Resets automatically next day.
input bool   InpUseDailyDDGuard    = true;
input double InpMaxDailyDDPercent  = 5.0;

// ===== Globals =====
CRiskManager   g_risk;
CTradeGuard    g_guard;
CMoneyTrailing g_moneyTrail;
CDailyDDGuard  g_ddGuard;

void LogMsg(string msg)
{
   if(InpVerboseLogs) Print("[NEWGOLDMULTI] ", msg);
}

int OnInit()
{
   if(!SymbolInfoInteger(_Symbol, SYMBOL_SELECT))
   {
      Print("[NEWGOLDMULTI] Symbol not selected: ", _Symbol);
      return INIT_FAILED;
   }

   if(InpMinVotes < 1 || InpMinVotes > 14)
   {
      Print("[NEWGOLDMULTI] InpMinVotes must be 1..14 (total number of strategy modules), got ", InpMinVotes);
      return INIT_PARAMETERS_INCORRECT;
   }

   RiskConfig cfg;
   cfg.useFixedLot        = InpUseFixedLot;
   cfg.fixedLot           = InpFixedLot;
   cfg.riskPercent        = InpRiskPercent;
   cfg.stopLossPoints     = InpStopLossPoints;
   cfg.takeProfitPoints   = InpTakeProfitPoints;
   cfg.maxDrawdownPercent = InpMaxDrawdownPercent;
   cfg.maxSpreadPoints    = InpMaxSpreadPoints;
   cfg.maxSlippagePoints  = InpMaxSlippagePoints;

   g_risk.Init(cfg);
   g_guard.Init(InpMagicNumber, InpMaxSlippagePoints);
   g_moneyTrail.Init(InpMagicNumber, InpMaxSlippagePoints,
                     InpUseProfitTrailMoney ? InpTrailStepMoney : 0.0);
   g_ddGuard.Init(InpUseDailyDDGuard, InpMaxDailyDDPercent);

   LogMsg(StringFormat(
      "Initialized | minVotes=%d | MoneyTrail=%s step=$%.2f | DailyDD=%s limit=%.1f%%",
      InpMinVotes,
      InpUseProfitTrailMoney ? "ON" : "OFF", InpTrailStepMoney,
      InpUseDailyDDGuard ? "ON" : "OFF", InpMaxDailyDDPercent));
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   IndPoolReleaseAll();
}

void OnTick()
{
   if(!InpEnableTrading) return;

   // --- Daily drawdown guard: update day baseline (lightweight) ---
   g_ddGuard.Update();

   // --- Manage open positions (profit-step trailing) ---
   g_moneyTrail.Manage();

   // --- Equity and spread guards ---
   string reason = "";
   if(!g_risk.EquityProtectionOk(reason))
   {
      LogMsg("Trading blocked: " + reason);
      return;
   }

   // --- Daily drawdown check (blocks new entries only) ---
   if(!g_ddGuard.AllowNewTrade(reason))
   {
      LogMsg("Trading blocked (daily DD): " + reason);
      return;
   }

   if(!g_risk.SpreadOk(reason))
   {
      LogMsg("Signal rejected: " + reason);
      return;
   }

   // --- New-bar gate: skip strategy evaluation on non-new bars (performance) ---
   static datetime s_lastSignalBar = 0;
   datetime curBarTime = iTime(_Symbol, InpSignalTF, 0);
   if(curBarTime == s_lastSignalBar) return;   // same bar — guards already ran, no new signal

   // --- One-bar signal guard (prevents re-entry on the same bar) ---
   datetime barTime = curBarTime;
   if(!g_guard.AllowSignalOnBar(barTime, reason))
   {
      // Trailing stop still runs, just skip new signal generation
      return;
   }

   if(!InpAllowMultiplePositions && g_guard.HasOpenPosition())
   {
      LogMsg("Signal rejected: open position already exists");
      return;
   }

   // --- Collect strategy signals ---
   StrategySignal signals[14];
   int n = 0;

   SignalReset(signals[n], "Indicators",        InpUseIndicators,        InpPriIndicators);
   if(InpUseIndicators)        SigIndicators(signals[n],       InpSignalTF, InpIndicatorsMinVotes); n++;

   SignalReset(signals[n], "MACrossover",        InpUseMACrossover,       InpPriMACrossover);
   if(InpUseMACrossover)       SigMACrossover(signals[n],      InpSignalTF, InpMAFast, InpMASlow, InpMALong, InpMAMinConf); n++;

   SignalReset(signals[n], "CandlePatterns",     InpUseCandlePatterns,    InpPriCandlePatterns);
   if(InpUseCandlePatterns)    SigCandlePatterns(signals[n],   InpSignalTF); n++;

   SignalReset(signals[n], "PriceAction",        InpUsePriceAction,       InpPriPriceAction);
   if(InpUsePriceAction)       SigPriceAction(signals[n],      InpSignalTF); n++;

   SignalReset(signals[n], "SupportResistance",  InpUseSupportResistance, InpPriSupportResistance);
   if(InpUseSupportResistance) SigSupportResistance(signals[n], InpSRTF); n++;

   SignalReset(signals[n], "PivotPoints",        InpUsePivotPoints,       InpPriPivotPoints);
   if(InpUsePivotPoints)       SigPivotPoints(signals[n],      InpSignalTF); n++;

   SignalReset(signals[n], "MultiTimeframe",     InpUseMultiTimeframe,    InpPriMultiTimeframe);
   if(InpUseMultiTimeframe)    SigMultiTimeframe(signals[n]); n++;

   SignalReset(signals[n], "Divergence",         InpUseDivergence,        InpPriDivergence);
   if(InpUseDivergence)        SigDivergence(signals[n],       InpSignalTF); n++;

   SignalReset(signals[n], "ElliottWaves",       InpUseElliottWaves,      InpPriElliottWaves);
   if(InpUseElliottWaves)      SigElliottWaves(signals[n],     InpSignalTF); n++;

   SignalReset(signals[n], "HarmonicPatterns",   InpUseHarmonicPatterns,  InpPriHarmonicPatterns);
   if(InpUseHarmonicPatterns)  SigHarmonicPatterns(signals[n], InpSignalTF); n++;

   SignalReset(signals[n], "ChartPatterns",      InpUseChartPatterns,     InpPriChartPatterns);
   if(InpUseChartPatterns)     SigChartPatterns(signals[n],    InpSignalTF); n++;

   SignalReset(signals[n], "VolumeAnalysis",     InpUseVolumeAnalysis,    InpPriVolumeAnalysis);
   if(InpUseVolumeAnalysis)    SigVolumeAnalysis(signals[n],   InpSignalTF); n++;

   SignalReset(signals[n], "TimeAnalysis",       InpUseTimeAnalysis,      InpPriTimeAnalysis);
   if(InpUseTimeAnalysis)      SigTimeAnalysis(signals[n],     InpSignalTF); n++;

   SignalReset(signals[n], "WolfeWaves",         InpUseWolfeWaves,        InpPriWolfeWaves);
   if(InpUseWolfeWaves)        SigWolfeWaves(signals[n],       InpSignalTF); n++;

   // --- Log individual results ---
   if(InpVerboseLogs)
   {
      for(int i = 0; i < n; i++)
      {
         if(!signals[i].enabled) continue;
         if(signals[i].direction == SIGNAL_NONE)
            LogMsg(StringFormat("%s -> no signal", signals[i].name));
         else
            LogMsg(StringFormat("%s -> dir=%d strength=%d reason=%s",
               signals[i].name, (int)signals[i].direction,
               signals[i].strength, signals[i].reason));
      }
   }

   // --- Voting consensus ---
   string winner = "";
   ENUM_SIGNAL_DIR dir = VotingResolve(signals, n, InpMinVotes, winner, InpVerboseLogs);
   if(dir == SIGNAL_NONE)
   {
      LogMsg("No consensus (" + winner + ")");
      return;
   }

   // --- Build and execute order ---
   double lots     = g_risk.CalcLots();
   ENUM_ORDER_TYPE otype  = (dir == SIGNAL_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   double refPrice = (dir == SIGNAL_BUY
                      ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                      : SymbolInfoDouble(_Symbol, SYMBOL_BID));
   double sl = g_risk.CalcSL(otype, refPrice);
   double tp = g_risk.CalcTP(otype, refPrice);

   string execReason = "";
   string cmt        = "NEWGOLDMULTI|" + winner;
   if(g_guard.Execute(dir, lots, sl, tp, cmt, execReason))
   {
      g_guard.MarkSignalBar(barTime);
      s_lastSignalBar = curBarTime;
      LogMsg(StringFormat("ORDER EXECUTED | winner=%s dir=%d lots=%.2f sl=%.5f tp=%.5f",
         winner, (int)dir, lots, sl, tp));
   }
   else
   {
      LogMsg("ORDER REJECTED: " + execReason);
   }
}
