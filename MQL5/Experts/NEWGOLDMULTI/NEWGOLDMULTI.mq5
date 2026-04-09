#property strict
#property version   "1.00"
#property description "NEWGOLDMULTI - Unified multi-strategy EA (ported from GoldTraderEA strategies)"

#include "StrategyTypes.mqh"
#include "RiskManager.mqh"
#include "TradeGuard.mqh"

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
input bool   InpVerboseLogs              = true;

// ===== Risk Inputs =====
input bool   InpUseFixedLot              = true;
input double InpFixedLot                 = 0.01;
input double InpRiskPercent              = 1.0;
input double InpStopLossPoints           = 800;
input double InpTakeProfitPoints         = 1200;
input double InpMaxDrawdownPercent       = 20.0;
input double InpMaxSpreadPoints          = 80;
input int    InpMaxSlippagePoints        = 20;

// ===== Strategy Toggles + Priority =====
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
input int InpMAFast=8, InpMASlow=21, InpMALong=200, InpMAMinConf=2;

CRiskManager g_risk;
CTradeGuard  g_guard;

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

   RiskConfig cfg;
   cfg.useFixedLot = InpUseFixedLot;
   cfg.fixedLot = InpFixedLot;
   cfg.riskPercent = InpRiskPercent;
   cfg.stopLossPoints = InpStopLossPoints;
   cfg.takeProfitPoints = InpTakeProfitPoints;
   cfg.maxDrawdownPercent = InpMaxDrawdownPercent;
   cfg.maxSpreadPoints = InpMaxSpreadPoints;
   cfg.maxSlippagePoints = InpMaxSlippagePoints;

   g_risk.Init(cfg);
   g_guard.Init(InpMagicNumber, InpMaxSlippagePoints);

   LogMsg("Initialized successfully");
   return INIT_SUCCEEDED;
}

void OnTick()
{
   if(!InpEnableTrading) return;

   string reason="";
   if(!g_risk.EquityProtectionOk(reason))
   {
      LogMsg("Trading blocked: " + reason);
      return;
   }

   if(!g_risk.SpreadOk(reason))
   {
      LogMsg("Signal rejected: " + reason);
      return;
   }

   datetime barTime = iTime(_Symbol, InpSignalTF, 0);
   if(!g_guard.AllowSignalOnBar(barTime, reason))
   {
      LogMsg("Signal rejected: " + reason);
      return;
   }

   if(!InpAllowMultiplePositions && g_guard.HasOpenPosition())
   {
      LogMsg("Signal rejected: open position already exists");
      return;
   }

   const int STRATEGY_COUNT = 14;
   StrategySignal signals[STRATEGY_COUNT];
   int n=0;

   SignalReset(signals[n], "Indicators", InpUseIndicators, InpPriIndicators);
   if(InpUseIndicators) SigIndicators(signals[n], InpSignalTF, InpIndicatorsMinVotes); n++;

   SignalReset(signals[n], "MACrossover", InpUseMACrossover, InpPriMACrossover);
   if(InpUseMACrossover) SigMACrossover(signals[n], InpSignalTF, InpMAFast, InpMASlow, InpMALong, InpMAMinConf); n++;

   SignalReset(signals[n], "CandlePatterns", InpUseCandlePatterns, InpPriCandlePatterns);
   if(InpUseCandlePatterns) SigCandlePatterns(signals[n], InpSignalTF); n++;

   SignalReset(signals[n], "PriceAction", InpUsePriceAction, InpPriPriceAction);
   if(InpUsePriceAction) SigPriceAction(signals[n], InpSignalTF); n++;

   SignalReset(signals[n], "SupportResistance", InpUseSupportResistance, InpPriSupportResistance);
   if(InpUseSupportResistance) SigSupportResistance(signals[n], InpSRTF); n++;

   SignalReset(signals[n], "PivotPoints", InpUsePivotPoints, InpPriPivotPoints);
   if(InpUsePivotPoints) SigPivotPoints(signals[n], InpSignalTF); n++;

   SignalReset(signals[n], "MultiTimeframe", InpUseMultiTimeframe, InpPriMultiTimeframe);
   if(InpUseMultiTimeframe) SigMultiTimeframe(signals[n]); n++;

   SignalReset(signals[n], "Divergence", InpUseDivergence, InpPriDivergence);
   if(InpUseDivergence) SigDivergence(signals[n], InpSignalTF); n++;

   SignalReset(signals[n], "ElliottWaves", InpUseElliottWaves, InpPriElliottWaves);
   if(InpUseElliottWaves) SigElliottWaves(signals[n], InpSignalTF); n++;

   SignalReset(signals[n], "HarmonicPatterns", InpUseHarmonicPatterns, InpPriHarmonicPatterns);
   if(InpUseHarmonicPatterns) SigHarmonicPatterns(signals[n], InpSignalTF); n++;

   SignalReset(signals[n], "ChartPatterns", InpUseChartPatterns, InpPriChartPatterns);
   if(InpUseChartPatterns) SigChartPatterns(signals[n], InpSignalTF); n++;

   SignalReset(signals[n], "VolumeAnalysis", InpUseVolumeAnalysis, InpPriVolumeAnalysis);
   if(InpUseVolumeAnalysis) SigVolumeAnalysis(signals[n], InpSignalTF); n++;

   SignalReset(signals[n], "TimeAnalysis", InpUseTimeAnalysis, InpPriTimeAnalysis);
   if(InpUseTimeAnalysis) SigTimeAnalysis(signals[n], InpSignalTF); n++;

   SignalReset(signals[n], "WolfeWaves", InpUseWolfeWaves, InpPriWolfeWaves);
   if(InpUseWolfeWaves) SigWolfeWaves(signals[n], InpSignalTF); n++;

   for(int i=0;i<n;i++)
   {
      if(!signals[i].enabled) continue;
      if(signals[i].direction==SIGNAL_NONE)
         LogMsg(StringFormat("%s -> no signal", signals[i].name));
      else
         LogMsg(StringFormat("%s -> dir=%d strength=%d reason=%s", signals[i].name, (int)signals[i].direction, signals[i].strength, signals[i].reason));
   }

   string winner="";
   ENUM_SIGNAL_DIR dir = g_guard.Resolve(signals, n, winner);
   if(dir == SIGNAL_NONE)
   {
      LogMsg("No executable winner signal");
      return;
   }

   double lots = g_risk.CalcLots();
   ENUM_ORDER_TYPE orderType = (dir==SIGNAL_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   double refPrice = (dir==SIGNAL_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID));
   double sl = g_risk.CalcSL(orderType, refPrice);
   double tp = g_risk.CalcTP(orderType, refPrice);

   string execReason="";
   string cmt = "NEWGOLDMULTI|" + winner;
   if(g_guard.Execute(dir, lots, sl, tp, cmt, execReason))
   {
      g_guard.MarkSignalBar(barTime);
      LogMsg(StringFormat("ORDER EXECUTED by %s dir=%d lots=%.2f", winner, (int)dir, lots));
   }
   else
   {
      LogMsg("ORDER REJECTED: " + execReason);
   }
}
