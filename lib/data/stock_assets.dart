import '../core/engine/investing.dart';
import '../core/engine/prices.dart';
import '../core/engine/valuation.dart';
import 'models.dart';
import 'wealth_models.dart';

/// Value of a stock/ETF position: units x last price (or cost when no price
/// is known yet), converted to AED at the cached FX rate.
FundValue valueStock(StockHolding h, PriceBook b) => valuePosition(
  units: h.quantity,
  price: h.lastPrice ?? h.avgCost ?? 0,
  avgCost: h.avgCost,
  fxToAed: b.fx(h.currency),
);

String _units(double u) =>
    u == u.roundToDouble() ? u.toStringAsFixed(0) : u.toStringAsFixed(3);

/// Stock holdings as net-worth assets. A holding in a currency with no FX
/// rate is left out rather than guessed.
List<Asset> stockAssets(Iterable<StockHolding> holdings, PriceBook b) {
  final out = <Asset>[];
  for (final h in holdings) {
    final v = valueStock(h, b);
    if (v.valueAedMinor == null) continue;
    out.add(
      Asset(
        id: 'stock:${h.id}',
        name: h.title,
        kind: AssetKind.stocks,
        value: v.valueAedMinor! / 100,
        note:
            '${_units(h.quantity)} × ${h.symbol}${h.approximate ? ' · approx' : ''}',
      ),
    );
  }
  return out;
}
