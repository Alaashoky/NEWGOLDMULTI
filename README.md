# NEWGOLDMULTI v2

Unified **MQL5 multi-strategy EA** for `XAUUSD`/gold-style trading.

## What's new in v2

- **VotingEngine**: consensus voting system — a trade is only placed when at
  least `InpMinVotes` strategies agree on the same direction.
- **TrailingStop + Break-even**: automatic profit protection for all open
  positions managed by this EA.
- **Professional strategy rewrites**: all 14 strategy modules upgraded with
  ATR-based tolerances, proper swing-point detection, normalized signal
  strength (0–5 scale), and no hardcoded bar indices.

---

## Files

| File | Purpose |
|---|---|
| `NEWGOLDMULTI.mq5` | Main EA entry point |
| `StrategyTypes.mqh` | Shared types, `SignalReset`, `SwingHigh`/`SwingLow` helpers |
| `RiskManager.mqh` | Lot sizing, SL/TP, spread/equity guards |
| `TradeGuard.mqh` | Order execution, one-bar duplicate prevention |
| `VotingEngine.mqh` | Multi-strategy consensus voting |
| `TrailingStop.mqh` | Break-even + trailing stop management |
| `Strategy_*.mqh` | 14 individual strategy modules (see below) |

---

## Strategy modules

| # | File | Logic summary |
|---|---|---|
| 1 | `Strategy_Indicators.mqh` | RSI, MACD, Stochastic, EMA cross, Bollinger — confluence voting |
| 2 | `Strategy_MACrossover.mqh` | Fast/slow EMA cross with long-period MA trend filter |
| 3 | `Strategy_CandlePatterns.mqh` | Pin bar, doji, engulfing, morning/evening star, soldiers/crows |
| 4 | `Strategy_PriceAction.mqh` | Range breakout, higher-lows/lower-highs, ATR-scaled tolerances |
| 5 | `Strategy_SupportResistance.mqh` | Swing-based SR levels, ATR proximity, breakout confirmation |
| 6 | `Strategy_PivotPoints.mqh` | Classic daily pivots (PP, R1/R2, S1/S2), ATR proximity |
| 7 | `Strategy_MultiTimeframe.mqh` | H4/D1/W1 trend agreement via EMA + ADX weighting |
| 8 | `Strategy_Divergence.mqh` | RSI & MACD divergence with proper swing-point detection |
| 9 | `Strategy_ElliottWaves.mqh` | Rising/falling swing sequence approximation (documented limits) |
| 10 | `Strategy_HarmonicPatterns.mqh` | XABCD pivot detection with Fibonacci ratio validation (ATR tol) |
| 11 | `Strategy_ChartPatterns.mqh` | Double top/bottom, H&S, inverse H&S, wedge breakout |
| 12 | `Strategy_VolumeAnalysis.mqh` | Relative volume, OBV direction, climax-volume confirmation |
| 13 | `Strategy_TimeAnalysis.mqh` | Session filter (London/NY); abstains outside active hours |
| 14 | `Strategy_WolfeWaves.mqh` | 5-swing convergence/divergence with breakout confirmation |

---

## Voting system

The voting engine (`VotingEngine.mqh`) replaces the old "winner by priority"
approach.

**How it works:**
1. Every enabled strategy evaluates the current bar and emits
   `SIGNAL_BUY`, `SIGNAL_SELL`, or `SIGNAL_NONE`.
2. Votes are counted separately for BUY and SELL.
3. If the leading side has **≥ `InpMinVotes`** votes, a trade is placed.
4. If *both* sides reach `InpMinVotes` (rare), tie-breaking rules apply:
   - Side with higher **total strength** wins.
   - If still tied: side with more votes wins.
   - Complete tie → no trade.

**Key input:**

| Input | Default | Description |
|---|---|---|
| `InpMinVotes` | `3` | Minimum votes required to execute a trade (range 1–14) |

**Enabling / disabling strategies:**

Each strategy has its own toggle and priority input:

```
InpUseIndicators = true/false    InpPriIndicators = 10
InpUseMACrossover = true/false   InpPriMACrossover = 20
...
```

Setting a strategy's `InpUseXxx = false` removes it from voting entirely.
The priority value (lower = higher priority) is used only as a final
tie-breaker between equal-strength signals.

**Verbose log example:**
```
[VotingEngine] BUY=4(str=14.0) SELL=1(str=2.0) minVotes=3 | BUY:[Indicators(3) MACrossover(4) ...] SELL:[...]
[NEWGOLDMULTI] ORDER EXECUTED | winner=MACrossover dir=1 lots=0.01 sl=...
```

---

## Trailing stop / break-even

Managed by `TrailingStop.mqh`, applied on every tick to positions opened
by this EA (magic-number scoped).

| Input | Default | Description |
|---|---|---|
| `InpBEStartPts` | `200` | Points of floating profit before break-even SL is placed |
| `InpBEBufferPts` | `50` | Extra points above/below entry for the break-even SL |
| `InpTrailStartPts` | `400` | Points of floating profit before trailing begins |
| `InpTrailDistPts` | `200` | Trailing distance from current price (points) |

Set `InpBEStartPts = 0` to disable break-even.  
Set `InpTrailStartPts = 0` to disable trailing.

All values are in **`_Point` units** (e.g. for XAUUSD with 3-digit prices,
1 pip ≈ 10 points; 200 points ≈ 20 pips).

**Safety guarantees:**
- SL only ever moves in the favorable direction (ratchet).
- `SYMBOL_TRADE_STOPS_LEVEL` and `SYMBOL_TRADE_FREEZE_LEVEL` are respected.

---

## Risk management

Provided by `RiskManager.mqh`:

| Input | Default | Description |
|---|---|---|
| `InpUseFixedLot` | `true` | Use fixed lot (otherwise % risk) |
| `InpFixedLot` | `0.01` | Fixed lot size |
| `InpRiskPercent` | `1.0` | % of equity to risk per trade (if not fixed lot) |
| `InpStopLossPoints` | `800` | Initial SL distance in points |
| `InpTakeProfitPoints` | `1200` | Initial TP distance in points |
| `InpMaxDrawdownPercent` | `20.0` | Halt trading if drawdown exceeds this % |
| `InpMaxSpreadPoints` | `80` | Skip signal if spread exceeds this |

---

## Quick start (MT5 Strategy Tester)

1. Copy the `NEWGOLDMULTI` folder to `MQL5/Experts/`.
2. Open MetaEditor and compile `NEWGOLDMULTI.mq5` (zero errors expected).
3. In Strategy Tester:
   - Symbol: `XAUUSD` (or equivalent gold symbol)
   - Timeframe: `M15` (default signal timeframe)
   - Enable "Every tick based on real ticks" for best accuracy.
4. Adjust `InpMinVotes` to control selectivity:
   - `1` = execute on any single signal (most active)
   - `3` = default (balanced)
   - `5+` = very selective (fewest trades, higher quality filter)

---

## Changelog

### v2.0 (2026-04-09)
- Added `VotingEngine.mqh` — consensus voting replaces single-winner resolution.
- Added `TrailingStop.mqh` — break-even + trailing stop with broker-level safety.
- Rewrote all 14 strategy modules:
  - ATR-based tolerances throughout (no more hardcoded point values).
  - Proper swing high/low detection via `SwingHigh`/`SwingLow` helpers.
  - Normalized signal strength to 0–5 scale across all strategies.
  - `Strategy_TimeAnalysis`: complete rewrite — abstains outside London/NY hours.
  - `Strategy_ElliottWaves`: proper swing-sequence detection (no hardcoded bar indices).
  - `Strategy_HarmonicPatterns`: pivot-based XABCD detection with ATR ratio tolerance.
  - `Strategy_ChartPatterns`: neckline-confirmed double top/bottom and H&S patterns.
  - `Strategy_WolfeWaves`: 5-swing convergence detection with breakout confirmation.
  - `Strategy_CandlePatterns`: added Doji, improved inside-bar breakout.
  - `Strategy_MultiTimeframe`: added ADX trend-strength weighting.
  - `Strategy_Divergence`: RSI+MACD divergence using `SwingHigh`/`SwingLow`.
- Added `InpMinVotes` input with validation in `OnInit`.
- `NEWGOLDMULTI.mq5`: trailing stop runs on every tick; signal generation
  blocked on same-bar duplicate but trailing continues uninterrupted.

### v1.1 (2026-04-09)
- Fixed MQL5 compilation errors (struct pass-by-reference, dynamic arrays,
  literal array sizes).

### v1.0
- Initial port of 14 strategy modules from `mehdi-jahani/GoldTraderEA`.

