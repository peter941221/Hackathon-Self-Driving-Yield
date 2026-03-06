#!/usr/bin/env python3
import argparse
import json
import math
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
        prices = [point[1] for point in data.get("prices", [])]
        if len(prices) >= 2:
            return prices, "coingecko"
    except Exception:
        pass

    random.seed(42)
    prices = [45_000.0]
    for index in range(days - 1):
        seasonal = 0.012 * math.sin(index / 8.0)
        shock = random.uniform(-0.018, 0.018)
        prices.append(prices[-1] * (1.0 + seasonal + shock))
    return prices, "synthetic"


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


def format_pct(value):
    return f"{value * 100:.2f}%"


def format_ratio(value):
    return "n/a" if value is None else f"{value:.2f}"


def print_scenario_report(scenario_name, results, regimes, source, days, tvl):
    print(f"Scenario: {scenario_name}")
    print(f"Source: {source}")
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


def build_report(prices, source, strategies, scenario_name, args):
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
    args = parser.parse_args()

    prices, source = load_prices(args.days, args.coin_id)
    scenario_names = list(SCENARIOS.keys()) if args.compare_scenarios else [args.scenario]
    reports = []
    for scenario_name in scenario_names:
        report = build_report(prices, source, STRATEGIES, scenario_name, args)
        reports.append(report)
        print_scenario_report(scenario_name, report["results"], report["regimes"], source, args.days, args.tvl)

    if args.json_out:
        with open(args.json_out, "w", encoding="utf-8") as handle:
            json.dump(reports, handle, indent=2)


if __name__ == "__main__":
    main()
