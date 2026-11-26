import 'dart:typed_data';

import '../../core/engine/amfi.dart';
import '../../core/engine/cas_parser.dart';
import '../wealth_models.dart';
import '../wealth_service.dart';
import 'live_prices.dart';
import 'statement_service.dart' show PdfReadStatus, PdfTextExtractor;
import 'wealth_store.dart' show newWealthId;

enum CasReadStatus {
  ok,
  needsPassword,
  wrongPassword,
  notAFundStatement,
  demat,
  unreadable,
}

class CasReadOutcome {
  const CasReadOutcome(this.status, {this.statement, this.message});
  final CasReadStatus status;
  final CasStatement? statement;
  final String? message;
}

enum MatchBasis { isin, name, none }

/// One fund on the statement, ready to review: what it maps to, what will
/// happen on confirm, and every reason its numbers are only approximate.
class CasCandidate {
  CasCandidate({
    required this.name,
    required this.units,
    this.avgCostNav,
    this.nav,
    this.navDate,
    this.schemeCode,
    this.basis = MatchBasis.none,
    this.existing,
    this.sip,
    this.folios = 1,
    this.flags = const [],
  });

  final String name;
  final double units;
  final double? avgCostNav, nav;
  final String? navDate, schemeCode;
  final MatchBasis basis;

  /// A holding already in Wealth for the same scheme: this import updates it.
  final FundHolding? existing;
  final SipHint? sip;
  final int folios;
  final List<String> flags;

  bool include = true;

  /// Save the SIP hint on the holding. On by default only for a SIP the
  /// statement itself labels.
  late bool useSip = sip != null && sip!.labelled;

  bool get matched => schemeCode != null;
  bool get approximate => flags.isNotEmpty;
  bool get isUpdate => existing != null;
}

class CasPreview {
  CasPreview({
    required this.candidates,
    this.periodTo,
    this.amfiAsOf,
    this.amfiOffline = false,
    this.closedSchemes = 0,
  });
  final List<CasCandidate> candidates;
  final String? periodTo, amfiAsOf;
  final bool amfiOffline;

  /// Schemes on the statement with no units left, which are not imported.
  final int closedSchemes;
}

class CasApplyReport {
  const CasApplyReport({
    this.added = 0,
    this.updated = 0,
    this.sips = 0,
    this.manual = 0,
  });
  final int added, updated, sips;

  /// Saved without a scheme match, so without a live NAV.
  final int manual;
  int get saved => added + updated;
}

String _norm(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

/// Reads a CAMS/KFintech CAS entirely on the phone. The PDF bytes and the
/// password live in memory for the call and are never stored, logged or sent;
/// only the resulting holdings (units, cost, NAV, SIP) are saved. The only
/// network use is AMFI's public NAV file, which carries nothing about the user.
class CasImportService {
  CasImportService({
    required this.extractor,
    required this.amfi,
    required this.wealth,
  });
  final PdfTextExtractor extractor;
  final AmfiService amfi;
  final WealthService wealth;

  /// Opens the PDF with [password] (null when it has none) and parses it.
  Future<CasReadOutcome> read(Uint8List bytes, {String? password}) async {
    final r = await extractor.extract(bytes, [
      if (password != null && password.isNotEmpty) password,
    ]);
    switch (r.status) {
      case PdfReadStatus.needsPassword:
        return CasReadOutcome(
          password == null || password.isEmpty
              ? CasReadStatus.needsPassword
              : CasReadStatus.wrongPassword,
        );
      case PdfReadStatus.failed:
        return const CasReadOutcome(
          CasReadStatus.unreadable,
          message: 'Could not read this PDF.',
        );
      case PdfReadStatus.read:
        final st = parseCas(r.text);
        if (st.isEmpty) {
          return CasReadOutcome(
            st.kind == CasKind.demat
                ? CasReadStatus.demat
                : CasReadStatus.notAFundStatement,
            message: st.warnings.firstOrNull,
          );
        }
        return CasReadOutcome(CasReadStatus.ok, statement: st);
    }
  }

  /// Maps the statement to review rows: matched to AMFI schemes by ISIN (else
  /// name), same-scheme folios combined, existing holdings found, SIPs hinted.
  Future<CasPreview> preview(CasStatement st) async {
    final res = await amfi.book();
    final book = res.book;
    final existing = await wealth.store.funds();
    final groups = <String, List<(CasScheme, AmfiScheme?, MatchBasis)>>{};
    var closed = 0;
    for (final s in st.schemes) {
      if (s.units <= 0.0005) {
        closed++;
        continue;
      }
      AmfiScheme? m;
      var basis = MatchBasis.none;
      if (book != null) {
        final byIsin = s.isin == null ? null : book.byIsin(s.isin!);
        if (byIsin != null) {
          m = byIsin;
          basis = MatchBasis.isin;
        } else {
          m = book.match(name: s.name);
          if (m != null) basis = MatchBasis.name;
        }
      }
      groups
          .putIfAbsent(m?.code ?? 'x:${s.isin ?? s.name}:${s.folio}', () => [])
          .add((s, m, basis));
    }
    final out = <CasCandidate>[];
    for (final g in groups.values) {
      final m = g.first.$2;
      final basis = g.first.$3;
      final units = g.fold<double>(0, (a, e) => a + e.$1.units);
      final costed = g.every(
        (e) => e.$1.costMinor != null && e.$1.costMinor! > 0,
      );
      final cost = costed
          ? g.fold<int>(0, (a, e) => a + e.$1.costMinor!)
          : null;
      // Latest statement NAV among the folios.
      final withNav =
          g.where((e) => e.$1.nav != null && e.$1.navDate != null).toList()
            ..sort((a, b) => b.$1.navDate!.compareTo(a.$1.navDate!));
      final stNav = withNav.firstOrNull?.$1;
      var nav = stNav?.nav, navDate = stNav?.navDate;
      if (m != null && (navDate == null || m.date.compareTo(navDate) >= 0)) {
        nav = m.nav;
        navDate = m.date;
      }
      nav ??= g.first.$1.valueMinor != null
          ? g.first.$1.valueMinor! / 100 / g.first.$1.units
          : null;
      final flags = <String>[];
      if (g.any((e) => e.$1.unitsApproximate))
        flags.add(
          'Units may be incomplete: the statement period does not cover every transaction',
        );
      if (!costed) flags.add('No cost on the statement, so no profit or loss');
      if (basis == MatchBasis.name)
        flags.add('Matched to the AMFI scheme by name, please check');
      if (m == null)
        flags.add(
          book == null
              ? 'Could not reach AMFI to find a live NAV'
              : 'Not found in the AMFI list: saved by hand, no live NAV',
        );
      if (nav == null) flags.add('No NAV on the statement');
      SipHint? sip;
      for (final e in g) {
        final h = detectSip(e.$1, asOf: st.periodTo);
        if (h != null && (sip == null || h.labelled && !sip.labelled)) sip = h;
      }
      if (sip != null && sip.approximate)
        flags.add(
          'SIP inferred from a monthly pattern, not labelled on the statement',
        );
      final scheme = g.first.$1;
      final code = m?.code;
      // A matched scheme is the same holding by its AMFI code; one saved by
      // hand is the same when it is a hand-entered INR fund of the same name.
      final key = _norm(scheme.name);
      final ex = code != null
          ? existing.where((f) => f.schemeCode == code).firstOrNull
          : existing
                .where(
                  (f) =>
                      f.schemeCode == null &&
                      f.currency == 'INR' &&
                      _norm(f.name) == key,
                )
                .firstOrNull;
      out.add(
        CasCandidate(
          name: m?.name ?? scheme.name,
          units: units,
          avgCostNav: cost == null ? null : cost / 100 / units,
          nav: nav,
          navDate: navDate,
          schemeCode: code,
          basis: basis,
          existing: ex,
          sip: sip,
          folios: g.length,
          flags: flags,
        ),
      );
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return CasPreview(
      candidates: out,
      periodTo: st.periodTo,
      amfiAsOf: book?.asOf,
      amfiOffline: book == null || res.fromCache && res.error != null,
      closedSchemes: closed,
    );
  }

  /// Saves the included rows. A statement is a snapshot, so an existing
  /// holding of the same scheme takes the statement's units and cost; its
  /// SIP is only changed when the user kept the hint on.
  Future<CasApplyReport> apply(CasPreview p) async {
    var added = 0, updated = 0, sips = 0, manual = 0;
    final now = DateTime.now().toUtc();
    for (final c in p.candidates) {
      if (!c.include || c.nav == null) continue;
      final sip = c.useSip ? c.sip : null;
      final ex = c.existing;
      if (ex != null) {
        await wealth.saveFund(
          ex.copyWith(
            units: c.units,
            avgCostNav: c.avgCostNav,
            nav: c.nav,
            navDate: c.navDate,
            navSource: c.matched ? 'market' : 'statement',
            navFetchedAt: now,
            sipAmountMinor: sip?.amountMinor,
            sipDay: sip?.day,
          ),
        );
        updated++;
      } else {
        await wealth.saveFund(
          FundHolding(
            id: newWealthId(),
            kind: c.matched ? 'india_mf' : 'manual',
            schemeCode: c.schemeCode,
            name: c.name,
            units: c.units,
            avgCostNav: c.avgCostNav,
            nav: c.nav!,
            navDate: c.navDate,
            navSource: c.matched ? 'market' : 'statement',
            navFetchedAt: now,
            sipAmountMinor: sip?.amountMinor,
            sipDay: sip?.day,
            createdAt: now,
          ),
        );
        added++;
      }
      if (sip != null) sips++;
      if (!c.matched) manual++;
    }
    return CasApplyReport(
      added: added,
      updated: updated,
      sips: sips,
      manual: manual,
    );
  }
}
