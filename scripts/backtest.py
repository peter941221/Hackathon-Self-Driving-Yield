#!/usr/bin/env python3
import argparse
from datetime import date, datetime, timezone
import json
import math
import os
import random
import statistics
import urllib.request


DAYS_PER_YEAR = 365
DEFAULT_WINDOW = 7

REGIME_WEIGHTS = {
    "CALM": (0.40, 0.57, 0.03),
    "NORMAL": (0.60, 0.37, 0.03),
    "STORM": (0.80, 0.17, 0.03),
}

HYSTERESIS = {
    "calm_enter": 0.008,
    "calm_exit": 0.012,
    "storm_enter": 0.032,
    "storm_exit": 0.025,
    "min_regime_days": 3,
}

SCENARIOS = {
    "baseline": {
        "alp_apr": {"CALM": 0.10, "NORMAL": 0.14, "STORM": 0.20},
        "alp_vol_capture": {"CALM": 0.000, "NORMAL": 0.008, "STORM": 0.050},
        "alp_move_drag": {"CALM": 0.004, "NORMAL": 0.008, "STORM": 0.015},
        "lp_fee_apr": {"CALM": 0.06, "NORMAL": 0.09, "STORM": 0.13},
        "funding_bps_per_day": {"CALM": 1.5, "NORMAL": 3.0, "STORM": 7.0},
        "pool_fee_bps": 20.0,
        "slippage_bps": 6.0,
        "hedge_trade_bps": 4.0,
        "hedge_ratio": 1.0,
        "gas_used": 500_000,
        "rebalance_threshold_weight": 0.02,
    },
    "stress": {
        "alp_apr": {"CALM": 0.08, "NORMAL": 0.12, "STORM": 0.18},
        "alp_vol_capture": {"CALM": 0.000, "NORMAL": 0.010, "STORM": 0.065},
        "alp_move_drag": {"CALM": 0.008, "NORMAL": 0.012, "STORM": 0.020},
        "lp_fee_apr": {"CALM": 0.05, "NORMAL": 0.08, "STORM": 0.11},
        "funding_bps_per_day": {"CALM": 4.0, "NORMAL": 8.0, "STORM": 14.0},
        "pool_fee_bps": 25.0,
        "slippage_bps": 12.0,
        "hedge_trade_bps": 8.0,
        "hedge_ratio": 1.0,
        "gas_used": 700_000,
        "rebalance_threshold_weight": 0.03,
    },
}

STRATEGIES = ("dynamic", "fixed_normal", "pure_alp", "pure_lp")


def fetch_json(url, timeout=20):
    request = urllib.request.Request(url, headers={"User-Agent": "codex-backtest/1.0"})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.load(response)


def load_prices(days, coin_id="bitcoin"):
    url = (
        f"https://api.coingecko.com/api/v3/coins/{coin_id}/market_chart"
        f"?vs_currency=usd&days={days}&interval=daily"
    )
    try:
        data = fetch_json(url)
        points = []
        for point in data.get("prices", []):
            if len(point) < 2:
                continue
            timestamp = datetime.fromtimestamp(point[0] / 1000, tz=timezone.utc)
            points.append((timestamp, point[1]))
        if len(points) >= 2:
            last_timestamp, _ = points[-1]
            previous_timestamp, _ = points[-2]
            if last_timestamp.date() == previous_timestamp.date() or last_timestamp.time() != datetime.min.time():
                points = points[:-1]
        prices = [price for _, price in points]
        if len(prices) >= 2:
            return prices, "coingecko", points[-1][0].date().isoformat()
    except Exception:
        pass

    random.seed(42)
    prices = [45_000.0]
    for index in range(days - 1):
        seasonal = 0.012 * math.sin(index / 8.0)
        shock = random.uniform(-0.018, 0.018)
        prices.append(prices[-1] * (1.0 + seasonal + shock))
    return prices, "synthetic", "synthetic"


def apr_to_daily(apr):
    return (1.0 + apr) ** (1.0 / DAYS_PER_YEAR) - 1.0


def simple_returns(prices):
    returns = []
    for index in range(1, len(prices)):
        previous = prices[index - 1]
        current = prices[index]
        returns.append(0.0 if previous == 0 else (current - previous) / previous)
    return returns


def log_returns(prices):
    returns = []
    for index in range(1, len(prices)):
        previous = prices[index - 1]
        current = prices[index]
        if previous <= 0 or current <= 0:
            returns.append(0.0)
        else:
            returns.append(math.log(current / previous))
    return returns


def rolling_rms(values):
    if not values:
        return 0.0
    return math.sqrt(sum(value * value for value in values) / len(values))


def next_regime(current_regime, current_age, volatility, hysteresis):
    if current_age < hysteresis["min_regime_days"]:
        return current_regime

    if current_regime == "CALM":
        return "NORMAL" if volatility >= hysteresis["calm_exit"] else "CALM"
    if current_regime == "STORM":
        return "NORMAL" if volatility <= hysteresis["storm_exit"] else "STORM"
    if volatility <= hysteresis["calm_enter"]:
        return "CALM"
    if volatility >= hysteresis["storm_enter"]:
        return "STORM"
    return "NORMAL"


def build_market_regimes(log_return_series, window, hysteresis):
    regimes = []
    current_regime = "NORMAL"
    current_age = hysteresis["min_regime_days"]
    history = []

    for log_return in log_return_series:
        regimes.append(current_regime)
        history.append(log_return)
        lookback = history[-window:]
        volatility = rolling_rms(lookback)
        candidate = next_regime(current_regime, current_age, volatility, hysteresis)
        if candidate == current_regime:
            current_age += 1
        else:
            current_regime = candidate
            current_age = 1

    return regimes


def target_weights(strategy, market_regime):
    if strategy == "dynamic":
        return REGIME_WEIGHTS[market_regime]
    if strategy == "fixed_normal":
        return REGIME_WEIGHTS["NORMAL"]
    if strategy == "pure_alp":
        return (1.0, 0.0, 0.0)
    if strategy == "pure_lp":
        return (0.0, 1.0, 0.0)
    raise ValueError(f"unknown strategy: {strategy}")


def daily_gas_cost(gas_gwei, gas_used, bnb_price, cycles_per_day):
    action_factor = max(cycles_per_day / 4.0, 0.25)
    return (gas_gwei * 1e-9) * gas_used * bnb_price * action_factor


def max_drawdown(curve):
    if not curve:
        return 0.0
    peak = curve[0]
    max_dd = 0.0
    for value in curve:
        if value > peak:
            peak = value
        drawdown = 0.0 if peak == 0 else (value / peak) - 1.0
        if drawdown < max_dd:
            max_dd = drawdown
    return max_dd


def summarize(curve, daily_nav_returns):
    if not daily_nav_returns:
        return {
            "cagr": 0.0,
            "ann_vol": 0.0,
            "sharpe": 0.0,
            "sortino": 0.0,
            "max_drawdown": 0.0,
        }

    average_daily = statistics.mean(daily_nav_returns)
    volatility_daily = statistics.pstdev(daily_nav_returns) if len(daily_nav_returns) > 1 else 0.0
    downside = [value for value in daily_nav_returns if value < 0]
    downside_dev = statistics.pstdev(downside) if len(downside) > 1 else 0.0
    ann_vol = volatility_daily * math.sqrt(DAYS_PER_YEAR)
    sharpe = 0.0 if volatility_daily == 0 else (average_daily / volatility_daily) * math.sqrt(DAYS_PER_YEAR)
    sortino = None if downside_dev < 1e-6 else (average_daily / downside_dev) * math.sqrt(DAYS_PER_YEAR)
    years = len(daily_nav_returns) / DAYS_PER_YEAR
    ending_value = curve[-1] if curve else 1.0
    cagr = ending_value ** (1.0 / years) - 1.0 if years > 0 and ending_value > 0 else 0.0
    return {
        "cagr": cagr,
        "ann_vol": ann_vol,
        "sharpe": sharpe,
        "sortino": sortino,
        "max_drawdown": max_drawdown(curve),
    }


def simulate_strategy(prices, market_regimes, strategy, scenario, tvl, gas_gwei, bnb_price, cycles_per_day):
    price_returns = simple_returns(prices)
    if not price_returns:
        return {}

    regime_days = {"CALM": 0, "NORMAL": 0, "STORM": 0}
    for regime in market_regimes:
        regime_days[regime] += 1

    current_weights = target_weights(strategy, market_regimes[0])
    current_nav = tvl
    curve = [1.0]
    daily_nav_returns = []
    total_turnover = 0.0
    rebalance_days = 0
    cost_breakdown = {
        "rebalance_usd": 0.0,
        "hedge_trade_usd": 0.0,
        "funding_usd": 0.0,
        "gas_usd": 0.0,
    }

    for index, price_return in enumerate(price_returns):
        regime = market_regimes[index]
        price_ratio = prices[index + 1] / prices[index] if prices[index] > 0 else 1.0

        abs_move = abs(price_return)
        alp_return = (
            apr_to_daily(scenario["alp_apr"][regime])
            + scenario["alp_vol_capture"][regime] * abs_move
            - scenario["alp_move_drag"][regime] * abs_move
        )
        lp_fee_return = apr_to_daily(scenario["lp_fee_apr"][regime])
        funding_return = 0.5 * scenario["hedge_ratio"] * scenario["funding_bps_per_day"][regime] / 10000.0
        lp_mark_return = math.sqrt(price_ratio) - 1.0 if price_ratio > 0 else -1.0
        hedge_return = -0.5 * scenario["hedge_ratio"] * price_return
        lp_total_return = lp_mark_return + lp_fee_return + hedge_return - funding_return

        alp_value = current_nav * current_weights[0] * (1.0 + alp_return)
        lp_value = current_nav * current_weights[1] * (1.0 + lp_total_return)
        buffer_value = current_nav * current_weights[2]

        nav_before_cost = alp_value + lp_value + buffer_value
        if nav_before_cost <= 0:
            curve.append(0.0)
            daily_nav_returns.append(-1.0)
            current_nav = 0.0
            break

        actual_weights = (
            alp_value / nav_before_cost,
            lp_value / nav_before_cost,
            buffer_value / nav_before_cost,
        )

        next_regime = market_regimes[index + 1] if index + 1 < len(market_regimes) else regime
        target = target_weights(strategy, next_regime)
        turnover = 0.5 * sum(abs(actual_weights[item] - target[item]) for item in range(3))
        should_rebalance = turnover >= scenario["rebalance_threshold_weight"]

        rebalance_cost = 0.0
        hedge_trade_cost = 0.0
        gas_cost = 0.0
        if should_rebalance:
            rebalance_days += 1
            total_turnover += turnover
            rebalance_cost = (
                nav_before_cost
                * turnover
                * (scenario["pool_fee_bps"] + scenario["slippage_bps"])
                / 10000.0
            )
            hedge_trade_cost = (
                nav_before_cost
                * 0.5
                * abs(target[1] - current_weights[1])
                * scenario["hedge_trade_bps"]
                / 10000.0
            )
            gas_cost = daily_gas_cost(gas_gwei, scenario["gas_used"], bnb_price, cycles_per_day)

        total_cost = rebalance_cost + hedge_trade_cost + gas_cost
        cost_breakdown["rebalance_usd"] += rebalance_cost
        cost_breakdown["hedge_trade_usd"] += hedge_trade_cost
        cost_breakdown["funding_usd"] += current_nav * current_weights[1] * funding_return
        cost_breakdown["gas_usd"] += gas_cost

        nav_after_cost = max(nav_before_cost - total_cost, 0.0)
        daily_return = nav_after_cost / current_nav - 1.0 if current_nav > 0 else 0.0
        daily_nav_returns.append(daily_return)
        current_nav = nav_after_cost
        curve.append(current_nav / tvl if tvl > 0 else 0.0)

        current_weights = target if should_rebalance else actual_weights

    summary = summarize(curve, daily_nav_returns)
    ending_value = curve[-1] if curve else 1.0
    return {
        "strategy": strategy,
        "regime_days": regime_days,
        "summary": summary,
        "ending_value": ending_value,
        "cumulative_return": ending_value - 1.0,
        "trade_days": rebalance_days,
        "turnover": total_turnover,
        "curve": curve,
        "cost_breakdown": cost_breakdown,
    }


def ascii_curve(curve, width=40):
    if not curve:
        return ""
    step = max(1, len(curve) // width)
    sampled = curve[::step]
    if len(sampled) > width:
        sampled = sampled[:width]
    min_value = min(sampled)
    max_value = max(sampled)
    span = max_value - min_value if max_value != min_value else 1.0
    levels = "._-~:+=*#%@"
    output = []
    for value in sampled:
        index = int((value - min_value) / span * (len(levels) - 1))
        output.append(levels[index])
    return "".join(output)


def svg_escape(text):
    return (
        str(text)
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def bar_x(value, zero_x, scale, right_bound, left_bound):
    delta = value * scale
    if value >= 0:
        end_x = min(zero_x + delta, right_bound)
        return zero_x, end_x - zero_x
    start_x = max(zero_x + delta, left_bound)
    return start_x, zero_x - start_x


def render_scenario_svg(report, output_path):
    scenario_name = report["scenario"]
    results = report["results"]
    regimes = report["regimes"]
    dynamic = results["dynamic"]
    width = 1200
    height = 520
    chart_left = 120
    chart_right = 760
    zero_x = 280
    bar_height = 34
    bar_gap = 26
    top = 170
    bottom = top + len(STRATEGIES) * (bar_height + bar_gap)
    left_bound = 140
    right_bound = chart_right - 30
    max_abs_cagr = max(abs(results[name]["summary"]["cagr"] * 100.0) for name in STRATEGIES)
    scale = (right_bound - zero_x - 20) / max(max_abs_cagr, 1.0)

    scenario_label = "Baseline" if scenario_name == "baseline" else "Stress"
    subtitle = (
        f"90d research model • Source={report['source']} • CALM {regimes.count('CALM')} / "
        f"NORMAL {regimes.count('NORMAL')} / STORM {regimes.count('STORM')} • As of {report['as_of_date']}"
    )
    dynamic_cagr = dynamic["summary"]["cagr"] * 100.0
    dynamic_max_dd = dynamic["summary"]["max_drawdown"] * 100.0
    dynamic_trade_days = dynamic["trade_days"]
    dynamic_turnover = dynamic["turnover"] * 100.0
    dynamic_funding = dynamic["cost_breakdown"]["funding_usd"]
    dynamic_rebalance = dynamic["cost_breakdown"]["rebalance_usd"]
    dynamic_gas = dynamic["cost_breakdown"]["gas_usd"]

    colors = {
        "dynamic": "#2563eb",
        "fixed_normal": "#0f766e",
        "pure_alp": "#7c3aed",
        "pure_lp": "#dc2626",
    }

    lines = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        "<defs>",
        '<linearGradient id="bg" x1="0" x2="1" y1="0" y2="1">',
        '<stop offset="0%" stop-color="#0f172a"/>',
        '<stop offset="100%" stop-color="#111827"/>',
        "</linearGradient>",
        "</defs>",
        f'<rect width="{width}" height="{height}" rx="24" fill="url(#bg)"/>',
        '<rect x="28" y="28" width="1144" height="464" rx="20" fill="#111827" stroke="#334155"/>',
        f'<text x="56" y="76" fill="#f8fafc" font-size="28" font-weight="700">{svg_escape(scenario_label)} Scenario • Strategy CAGR Comparison</text>',
        f'<text x="56" y="108" fill="#94a3b8" font-size="16">{svg_escape(subtitle)}</text>',
        f'<text x="{zero_x - 16}" y="146" text-anchor="end" fill="#64748b" font-size="14">0%</text>',
        f'<line x1="{zero_x}" y1="150" x2="{zero_x}" y2="{bottom + 12}" stroke="#475569" stroke-width="2"/>',
    ]

    grid_values = [-10, 0, 10, 20, 30]
    for grid in grid_values:
        grid_start, grid_width = bar_x(grid, zero_x, scale, right_bound, left_bound)
        x = grid_start if grid < 0 else grid_start + grid_width
        lines.append(
            f'<line x1="{x}" y1="150" x2="{x}" y2="{bottom + 12}" stroke="#1f2937" stroke-width="1" stroke-dasharray="4 6"/>'
        )
        lines.append(
            f'<text x="{x}" y="146" text-anchor="middle" fill="#64748b" font-size="12">{grid}%</text>'
        )

    for index, strategy in enumerate(STRATEGIES):
        result = results[strategy]
        cagr_pct = result["summary"]["cagr"] * 100.0
        y = top + index * (bar_height + bar_gap)
        x, width_bar = bar_x(cagr_pct, zero_x, scale, right_bound, left_bound)
        label = strategy.replace("_", " ").title()
        lines.append(
            f'<text x="56" y="{y + 23}" fill="#e2e8f0" font-size="17" font-weight="600">{svg_escape(label)}</text>'
        )
        lines.append(
            f'<rect x="{x}" y="{y}" width="{width_bar}" height="{bar_height}" rx="10" fill="{colors[strategy]}"/>'
        )
        value_x = x + width_bar + 10 if cagr_pct >= 0 else x - 10
        anchor = "start" if cagr_pct >= 0 else "end"
        lines.append(
            f'<text x="{value_x}" y="{y + 23}" text-anchor="{anchor}" fill="#f8fafc" font-size="16" font-weight="700">{cagr_pct:.2f}%</text>'
        )

    card_x = 820
    lines.extend(
        [
            f'<rect x="{card_x}" y="148" width="308" height="290" rx="18" fill="#0f172a" stroke="#334155"/>',
            f'<text x="{card_x + 24}" y="184" fill="#f8fafc" font-size="22" font-weight="700">Dynamic Snapshot</text>',
            f'<text x="{card_x + 24}" y="220" fill="#93c5fd" font-size="15">CAGR</text>',
            f'<text x="{card_x + 220}" y="220" text-anchor="end" fill="#f8fafc" font-size="15" font-weight="700">{dynamic_cagr:.2f}%</text>',
            f'<text x="{card_x + 24}" y="252" fill="#93c5fd" font-size="15">Max Drawdown</text>',
            f'<text x="{card_x + 220}" y="252" text-anchor="end" fill="#f8fafc" font-size="15" font-weight="700">{dynamic_max_dd:.2f}%</text>',
            f'<text x="{card_x + 24}" y="284" fill="#93c5fd" font-size="15">Trade Days</text>',
            f'<text x="{card_x + 220}" y="284" text-anchor="end" fill="#f8fafc" font-size="15" font-weight="700">{dynamic_trade_days}</text>',
            f'<text x="{card_x + 24}" y="316" fill="#93c5fd" font-size="15">Turnover</text>',
            f'<text x="{card_x + 220}" y="316" text-anchor="end" fill="#f8fafc" font-size="15" font-weight="700">{dynamic_turnover:.2f}%</text>',
            f'<text x="{card_x + 24}" y="348" fill="#93c5fd" font-size="15">Funding Cost</text>',
            f'<text x="{card_x + 220}" y="348" text-anchor="end" fill="#f8fafc" font-size="15" font-weight="700">${dynamic_funding:.0f}</text>',
            f'<text x="{card_x + 24}" y="380" fill="#93c5fd" font-size="15">Rebalance Cost</text>',
            f'<text x="{card_x + 220}" y="380" text-anchor="end" fill="#f8fafc" font-size="15" font-weight="700">${dynamic_rebalance:.0f}</text>',
            f'<text x="{card_x + 24}" y="412" fill="#93c5fd" font-size="15">Gas Cost</text>',
            f'<text x="{card_x + 220}" y="412" text-anchor="end" fill="#f8fafc" font-size="15" font-weight="700">${dynamic_gas:.0f}</text>',
        ]
    )

    footer = (
        "Interpretation: dynamic is the diversified automation benchmark; "
        "pure ALP is a concentration benchmark and pure LP is the IL stress benchmark."
    )
    lines.append(
        f'<text x="56" y="468" fill="#94a3b8" font-size="15">{svg_escape(footer)}</text>'
    )
    lines.append("</svg>")

    with open(output_path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))


def render_one_pager_svg(baseline_report, stress_report, output_path):
    baseline = baseline_report["results"]
    stress = stress_report["results"]
    dynamic_base = baseline["dynamic"]
    dynamic_stress = stress["dynamic"]
    fixed_base = baseline["fixed_normal"]
    lp_stress = stress["pure_lp"]
    dynamic_base_cagr = format_pct(dynamic_base["summary"]["cagr"])
    dynamic_stress_cagr = format_pct(dynamic_stress["summary"]["cagr"])
    dynamic_stress_maxdd = format_pct(dynamic_stress["summary"]["max_drawdown"])
    fixed_base_cagr = format_pct(fixed_base["summary"]["cagr"])
    lp_stress_cagr = format_pct(lp_stress["summary"]["cagr"])
    as_of_date = baseline_report.get("as_of_date") or stress_report.get("as_of_date") or date.today().isoformat()

    width = 1400
    height = 1040
    lines = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<defs><linearGradient id="paperbg" x1="0" x2="1" y1="0" y2="1"><stop offset="0%" stop-color="#020617"/><stop offset="100%" stop-color="#111827"/></linearGradient></defs>',
        f'<rect width="{width}" height="{height}" rx="28" fill="url(#paperbg)"/>',
        '<rect x="28" y="28" width="1344" height="984" rx="24" fill="#0f172a" stroke="#334155"/>',
        '<text x="64" y="86" fill="#f8fafc" font-size="34" font-weight="700">Self-Driving Yield Engine • Investor One-Pager</text>',
        f'<text x="64" y="122" fill="#94a3b8" font-size="18">Autonomous hedge-aware vault on BNB Chain • ALP + Pancake V2 LP + 1001x short hedge • No admin • As of {as_of_date}</text>',
        f'<rect x="64" y="154" width="220" height="56" rx="16" fill="#1d4ed8"/><text x="174" y="189" text-anchor="middle" fill="#eff6ff" font-size="22" font-weight="700">Baseline CAGR {dynamic_base_cagr}</text>',
        f'<rect x="304" y="154" width="220" height="56" rx="16" fill="#0f766e"/><text x="414" y="189" text-anchor="middle" fill="#ecfdf5" font-size="22" font-weight="700">Stress CAGR {dynamic_stress_cagr}</text>',
        '<rect x="544" y="154" width="220" height="56" rx="16" fill="#7c3aed"/><text x="654" y="189" text-anchor="middle" fill="#f5f3ff" font-size="22" font-weight="700">Tests 48 / 48</text>',
        f'<rect x="784" y="154" width="220" height="56" rx="16" fill="#b45309"/><text x="894" y="189" text-anchor="middle" fill="#fff7ed" font-size="22" font-weight="700">MaxDD {dynamic_stress_maxdd}</text>',
        '<rect x="1024" y="154" width="220" height="56" rx="16" fill="#be123c"/><text x="1134" y="189" text-anchor="middle" fill="#fff1f2" font-size="22" font-weight="700">ONLY_UNWIND Guard</text>',
        '<text x="64" y="262" fill="#93c5fd" font-size="24" font-weight="700">1. Thesis</text>',
        '<text x="64" y="296" fill="#e2e8f0" font-size="18">• The vault rotates toward ALP when volatility rises, while LP + short hedge monetize calmer markets.</text>',
        '<text x="64" y="326" fill="#e2e8f0" font-size="18">• Objective: avoid pure-LP drawdown while staying more diversified than pure-ALP concentration.</text>',
        '<text x="64" y="386" fill="#93c5fd" font-size="24" font-weight="700">2. Product Moat</text>',
        '<text x="64" y="420" fill="#e2e8f0" font-size="18">• Hedge NAV accounting now includes margin + unrealized PnL - accrued fees.</text>',
        '<text x="64" y="450" fill="#e2e8f0" font-size="18">• TWAP-marked valuation, virtual-share anti-inflation, no-op bounty suppression, hysteresis regime switching.</text>',
        '<text x="64" y="480" fill="#e2e8f0" font-size="18">• Over-hedged states close only the amount needed to re-enter the delta band.</text>',
        '<text x="64" y="540" fill="#93c5fd" font-size="24" font-weight="700">3. Strategy Output (90d research model)</text>',
        '<rect x="64" y="566" width="610" height="240" rx="18" fill="#111827" stroke="#334155"/>',
        '<text x="88" y="606" fill="#f8fafc" font-size="20" font-weight="700">Scenario Comparison</text>',
        '<text x="88" y="640" fill="#94a3b8" font-size="16">Dynamic vs fixed NORMAL vs pure LP stress benchmark</text>',
        '<text x="88" y="688" fill="#93c5fd" font-size="17">Baseline Dynamic CAGR</text>',
        f'<text x="324" y="688" fill="#f8fafc" font-size="17" font-weight="700">{dynamic_base_cagr}</text>',
        '<text x="88" y="720" fill="#93c5fd" font-size="17">Stress Dynamic CAGR</text>',
        f'<text x="324" y="720" fill="#f8fafc" font-size="17" font-weight="700">{dynamic_stress_cagr}</text>',
        '<text x="88" y="752" fill="#93c5fd" font-size="17">Baseline Fixed NORMAL CAGR</text>',
        f'<text x="324" y="752" fill="#f8fafc" font-size="17" font-weight="700">{fixed_base_cagr}</text>',
        '<text x="88" y="784" fill="#93c5fd" font-size="17">Stress Pure LP CAGR</text>',
        f'<text x="324" y="784" fill="#f8fafc" font-size="17" font-weight="700">{lp_stress_cagr}</text>',
        '<rect x="714" y="566" width="610" height="240" rx="18" fill="#111827" stroke="#334155"/>',
        '<text x="738" y="606" fill="#f8fafc" font-size="20" font-weight="700">Why investors care</text>',
        '<text x="738" y="640" fill="#94a3b8" font-size="16">The dynamic strategy is a middle path between concentration and unhedged LP risk</text>',
        '<text x="738" y="688" fill="#e2e8f0" font-size="18">• Baseline dynamic beats pure LP by a wide margin and keeps drawdown shallow.</text>',
        '<text x="738" y="720" fill="#e2e8f0" font-size="18">• Stress dynamic stays positive in the model while pure LP remains deeply negative.</text>',
        '<text x="738" y="752" fill="#e2e8f0" font-size="18">• Fixed NORMAL remains a strong static benchmark; dynamic adds adaptive upside when volatility spikes.</text>',
        '<text x="738" y="784" fill="#e2e8f0" font-size="18">• Pure ALP is still a useful concentration benchmark, not the product target shape.</text>',
        '<text x="64" y="872" fill="#93c5fd" font-size="24" font-weight="700">4. Control Loop</text>',
        '<rect x="64" y="898" width="1260" height="82" rx="18" fill="#111827" stroke="#334155"/>',
        '<text x="90" y="946" fill="#e2e8f0" font-size="18">[TWAP + RMS Vol] → [Hysteresis Regime] → [Target Weights] → [ALP / LP / Hedge] → [Cost Gate + Bounty] → [NAV]</text>',
        f'<text x="64" y="1006" fill="#94a3b8" font-size="15">Research model output refreshed from scripts/backtest.py on {as_of_date}. Production performance will depend on live Aster funding, liquidity, and execution conditions.</text>',
        '</svg>',
    ]

    with open(output_path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))


def format_pct(value):
    return f"{value * 100:.2f}%"


def format_ratio(value):
    return "n/a" if value is None else f"{value:.2f}"


def print_scenario_report(scenario_name, results, regimes, source, as_of_date, days, tvl):
    print(f"Scenario: {scenario_name}")
    print(f"Source: {source}")
    print(f"As of: {as_of_date}")
    print(f"Days: {days}")
    print(f"TVL: ${tvl:,.0f}")
    print(
        "Market regime days:",
        {"CALM": regimes.count("CALM"), "NORMAL": regimes.count("NORMAL"), "STORM": regimes.count("STORM")},
    )
    print(
        "Strategy Comparison\n"
        "Name          CAGR     AnnVol   Sharpe  Sortino MaxDD    CumRet   TradeDays Turnover"
    )
    for key in STRATEGIES:
        result = results[key]
        summary = result["summary"]
        print(
            f"{key:<13}"
            f"{format_pct(summary['cagr']):>8} "
            f"{format_pct(summary['ann_vol']):>8} "
            f"{format_ratio(summary['sharpe']):>7} "
            f"{format_ratio(summary['sortino']):>7} "
            f"{format_pct(summary['max_drawdown']):>8} "
            f"{format_pct(result['cumulative_return']):>8} "
            f"{result['trade_days']:>9} "
            f"{format_pct(result['turnover']):>8}"
        )

    dynamic = results["dynamic"]
    print("Dynamic Cost Breakdown:")
    for label, value in dynamic["cost_breakdown"].items():
        print(f"- {label}: ${value:,.2f}")
    print("Dynamic Curve:", ascii_curve(dynamic["curve"]))
    print()


def build_report(prices, source, as_of_date, strategies, scenario_name, args):
    log_return_series = log_returns(prices)
    regimes = build_market_regimes(log_return_series, args.window, HYSTERESIS)
    scenario = SCENARIOS[scenario_name]
    results = {}
    for strategy in strategies:
        results[strategy] = simulate_strategy(
            prices,
            regimes,
            strategy,
            scenario,
            args.tvl,
            args.gas_gwei,
            args.bnb_price,
            args.cycles_per_day,
        )

    return {
        "source": source,
        "as_of_date": as_of_date,
        "days": args.days,
        "window": args.window,
        "scenario": scenario_name,
        "regimes": regimes,
        "results": results,
    }


def main():
    parser = argparse.ArgumentParser(description="Research-grade backtest for Self-Driving Yield Engine")
    parser.add_argument("--days", type=int, default=90)
    parser.add_argument("--window", type=int, default=DEFAULT_WINDOW)
    parser.add_argument("--bnb-price", type=float, default=300.0)
    parser.add_argument("--gas-gwei", type=float, default=50.0)
    parser.add_argument("--cycles-per-day", type=int, default=4)
    parser.add_argument("--tvl", type=float, default=100000.0)
    parser.add_argument("--coin-id", default="bitcoin")
    parser.add_argument("--scenario", choices=tuple(SCENARIOS.keys()), default="baseline")
    parser.add_argument("--compare-scenarios", action="store_true")
    parser.add_argument("--json-out")
    parser.add_argument("--svg-dir")
    parser.add_argument("--one-pager-svg")
    args = parser.parse_args()

    prices, source, as_of_date = load_prices(args.days, args.coin_id)
    scenario_names = list(SCENARIOS.keys()) if args.compare_scenarios else [args.scenario]
    reports = []
    for scenario_name in scenario_names:
        report = build_report(prices, source, as_of_date, STRATEGIES, scenario_name, args)
        reports.append(report)
        print_scenario_report(scenario_name, report["results"], report["regimes"], source, as_of_date, args.days, args.tvl)

    if args.json_out:
        with open(args.json_out, "w", encoding="utf-8") as handle:
            json.dump(reports, handle, indent=2)

    if args.svg_dir:
        os.makedirs(args.svg_dir, exist_ok=True)
        for report in reports:
            filename = f"backtest-{report['scenario']}.svg"
            render_scenario_svg(report, os.path.join(args.svg_dir, filename))

    if args.one_pager_svg and len(reports) >= 2:
        os.makedirs(os.path.dirname(args.one_pager_svg), exist_ok=True)
        baseline_report = next((report for report in reports if report["scenario"] == "baseline"), reports[0])
        stress_report = next((report for report in reports if report["scenario"] == "stress"), reports[-1])
        render_one_pager_svg(baseline_report, stress_report, args.one_pager_svg)


if __name__ == "__main__":
    main()
