/// Net worth calculation. Pure functions over lightweight inputs. Port of
/// `app/services/networth.py`.
library;

import 'types.dart';

class AssetInput {
  const AssetInput(
    this.kind,
    this.currency,
    this.manualValueMinor, [
    this.costBasisMinor,
  ]);
  final String kind, currency;
  final int? manualValueMinor, costBasisMinor;

  /// Current value; falls back to cost basis when never revalued, else zero.
  int get valueMinor => manualValueMinor ?? costBasisMinor ?? 0;
}

class LiabilityInput {
  const LiabilityInput(this.kind, this.currency, this.outstandingMinor);
  final String kind, currency;
  final int outstandingMinor;
}

class NetWorthResult {
  NetWorthResult(this.baseCurrency);
  final String baseCurrency;
  int totalAssetsMinor = 0, totalLiabilitiesMinor = 0;
  Map<String, int> assetsByKind = {}, liabilitiesByKind = {};

  /// Currencies with no FX rate: excluded from totals and reported here,
  /// never silently dropped.
  List<String> unconvertedCurrencies = [];
  int get netWorthMinor => totalAssetsMinor - totalLiabilitiesMinor;
}

int convertMinor(int amountMinor, double rate) =>
    roundHalfEven((amountMinor * rate * 1e6).round() / 1e6);

/// [fxRates] maps currency -> units of base currency per 1 unit of it.
NetWorthResult computeNetWorth(
  Iterable<AssetInput> assets,
  Iterable<LiabilityInput> liabilities, {
  String baseCurrency = 'AED',
  Map<String, double> fxRates = const {},
}) {
  final rates = {baseCurrency: 1.0, ...fxRates};
  final res = NetWorthResult(baseCurrency);
  final missing = <String>{};
  final aKind = <String, int>{}, lKind = <String, int>{};
  for (final a in assets) {
    final r = rates[a.currency];
    if (r == null) {
      missing.add(a.currency);
      continue;
    }
    aKind[a.kind] = (aKind[a.kind] ?? 0) + convertMinor(a.valueMinor, r);
  }
  for (final l in liabilities) {
    final r = rates[l.currency];
    if (r == null) {
      missing.add(l.currency);
      continue;
    }
    lKind[l.kind] = (lKind[l.kind] ?? 0) + convertMinor(l.outstandingMinor, r);
  }
  res.assetsByKind = aKind;
  res.liabilitiesByKind = lKind;
  res.totalAssetsMinor = aKind.values.fold(0, (a, b) => a + b);
  res.totalLiabilitiesMinor = lKind.values.fold(0, (a, b) => a + b);
  res.unconvertedCurrencies = missing.toList()..sort();
  return res;
}
