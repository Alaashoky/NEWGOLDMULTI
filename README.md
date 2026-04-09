# NEWGOLDMULTI

Unified **MQL5 multi-strategy EA** for `XAUUSD`/gold-style trading, mapped from strategies in:
- Source reference: `mehdi-jahani/GoldTraderEA`

## Files

Main EA:
- `MQL5/Experts/NEWGOLDMULTI/NEWGOLDMULTI.mq5`

Shared modules:
- `MQL5/Experts/NEWGOLDMULTI/StrategyTypes.mqh`
- `MQL5/Experts/NEWGOLDMULTI/RiskManager.mqh`
- `MQL5/Experts/NEWGOLDMULTI/TradeGuard.mqh`

Strategy modules (all discovered source strategy areas are included):
1. `Strategy_Indicators.mqh`
2. `Strategy_MACrossover.mqh`
3. `Strategy_CandlePatterns.mqh`
4. `Strategy_PriceAction.mqh`
5. `Strategy_SupportResistance.mqh`
6. `Strategy_PivotPoints.mqh`
7. `Strategy_MultiTimeframe.mqh`
8. `Strategy_Divergence.mqh`
9. `Strategy_ElliottWaves.mqh`
10. `Strategy_HarmonicPatterns.mqh`
11. `Strategy_ChartPatterns.mqh`
12. `Strategy_VolumeAnalysis.mqh`
13. `Strategy_TimeAnalysis.mqh`
14. `Strategy_WolfeWaves.mqh`

## Strategy mapping to source repository

- `Indicators.mqh` -> `Strategy_Indicators.mqh`
- `MACrossover.mqh` -> `Strategy_MACrossover.mqh`
- `CandlePatterns.mqh` -> `Strategy_CandlePatterns.mqh`
- `PriceAction.mqh` (+ trend aspects) -> `Strategy_PriceAction.mqh`
- `SupportResistance.mqh` -> `Strategy_SupportResistance.mqh`
- `PivotPoints.mqh` -> `Strategy_PivotPoints.mqh`
- `MultiTimeframe.mqh` -> `Strategy_MultiTimeframe.mqh`
- `Divergence.mqh` -> `Strategy_Divergence.mqh`
- `ElliottWaves.mqh` -> `Strategy_ElliottWaves.mqh`
- `HarmonicPatterns.mqh` -> `Strategy_HarmonicPatterns.mqh`
- `ChartPatterns.mqh` -> `Strategy_ChartPatterns.mqh`
- `VolumeAnalysis.mqh` -> `Strategy_VolumeAnalysis.mqh`
- `TimeAnalysis.mqh` -> `Strategy_TimeAnalysis.mqh`
- `WolfeWaves.mqh` -> `Strategy_WolfeWaves.mqh`

## Coordination and conflict handling

- All strategies can run concurrently.
- Each strategy has:
  - enable/disable input
  - priority input (lower number = higher priority)
- Signals are resolved by:
  1. higher signal strength
  2. if tie: higher priority
  3. if exact opposite tie: cancel trade
- Duplicate entries are blocked on the same signal bar.

## Risk management

Provided by `RiskManager.mqh`:
- Fixed lot or risk-percent lot sizing
- SL/TP in points
- Max drawdown/equity protection guard
- Spread guard
- Slippage passed to execution layer

## Execution guard

Provided by `TradeGuard.mqh`:
- Trade context checks
- One-bar duplicate prevention
- Position conflict prevention (via `InpAllowMultiplePositions`)
- Detailed reject reasons in logs

## Inputs and safe defaults

In `NEWGOLDMULTI.mq5`:
- Master toggle: `InpEnableTrading`
- Safe lot default: `0.01`
- Spread guard default: `80` points
- Drawdown guard default: `20%`
- All strategy toggles and priorities exposed

## Logging / observability

- Per-strategy logs:
  - signal/no-signal
  - direction
  - strength
  - reason
- Final order logs:
  - selected winner strategy
  - executed/rejected
  - rejection reason

## Backtesting

In MT5 Strategy Tester:
1. Place folder under `MQL5/Experts/NEWGOLDMULTI`
2. Compile `NEWGOLDMULTI.mq5`
3. Run tests in two modes:
   - individual strategy: enable one toggle, disable others
   - combined mode: enable all toggles

## Changelog

### Compilation fixes (2026-04-09)
- **RiskManager.mqh**: Changed `Init(RiskConfig cfg)` → `Init(RiskConfig &cfg)` — MQL5 requires structs/objects to be passed by reference.
- **NEWGOLDMULTI.mq5**: Replaced `StrategySignal signals[STRATEGY_COUNT]` with a literal size `signals[14]` — MQL5 array dimensions must be compile-time integer literals, not `const int` variables.
- **Strategy_Indicators.mqh**: Changed all fixed-size indicator copy buffers (`rsi[3]`, `mm[3]`, `adx[2]`, etc.) to dynamic arrays — `ArraySetAsSeries` and `CopyBuffer` require dynamic (unsized) arrays.
- **Strategy_MACrossover.mqh**: Changed `f[3]`, `sl[3]`, `lg[2]` to dynamic arrays for the same reason.
- **Strategy_MultiTimeframe.mqh**: Changed `ma20[2]`, `ma50[2]` to dynamic arrays.
- **Strategy_Divergence.mqh**: Changed `rsi[80]`, `macd[80]` to dynamic arrays.

## Assumptions and ambiguity notes

Because source modules contain mixed rigor and some ambiguous heuristics, this port applies **equivalent modular logic** and preserves the same strategy categories/signaling intent. Pattern-based modules (`Elliott/Harmonic/Chart/Wolfe/Time`) use deterministic approximations suitable for compile-ready automated execution and coordinated multi-strategy operation.
