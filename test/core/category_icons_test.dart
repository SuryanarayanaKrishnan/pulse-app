import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/icons/category_painter.dart';
import 'package:pulse/core/icons/category_tint.dart';
import 'package:pulse/core/icons/glyphs.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/core/widgets/widgets.dart';
import 'package:pulse/data/local/default_categories.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/categories/categories_screen.dart';

void main() {
  group('the glyph family', () {
    test(
      'every default category resolves to its own glyph, not the fallback',
      () {
        for (final c in SpendCategory.defaults) {
          expect(hasOwnGlyph(c), isTrue, reason: c.id);
        }
        // the seeded rows too (other_income, transfer have no SpendCategory const)
        for (final d in defaultCategories) {
          expect(
            hasOwnGlyph(SpendCategory(d.slug, d.name)),
            isTrue,
            reason: d.slug,
          );
        }
        for (final id in ['subscriptions', 'gifts', 'charity']) {
          expect(hasOwnGlyph(SpendCategory(id, id)), isTrue, reason: id);
        }
      },
    );

    test('unknown and unpicked categories fall back to the generic tag', () {
      expect(
        glyphFor(const SpendCategory.custom('c_1', 'Mine')),
        same(genericGlyph),
      );
      expect(
        glyphFor(const SpendCategory.custom('c_1', 'Mine', iconKey: 'nope')),
        same(genericGlyph),
      );
      expect(
        glyphFor(const SpendCategory.custom('c_1', 'Mine', iconKey: 'coffee'))
            .key,
        'coffee',
      );
      // a default ignores a stray key
      expect(
        glyphFor(
          const SpendCategory('groceries', 'Groceries', iconKey: 'coffee'),
        ).key,
        'groceries',
      );
    });

    test('24 custom glyphs, unique keys, none of them the fallback', () {
      expect(customGlyphs, hasLength(24));
      final keys = [
        ...defaultGlyphs,
        ...customGlyphs,
      ].map((g) => g.key).toList();
      expect(keys.toSet(), hasLength(keys.length));
      expect(customGlyphs.map((g) => g.key), isNot(contains('generic')));
    });

    test('every default has a colour token that exists', () {
      for (final d in defaultCategories) {
        expect(defaultCategoryTokens[d.slug], d.color, reason: d.slug);
      }
    });

    test('every glyph stays inside the live area of the 24 grid', () {
      for (final g in [...defaultGlyphs, ...customGlyphs]) {
        for (final s in g.shapes) {
          // getBounds uses control points; sample the real outline instead.
          for (final m in s.path.computeMetrics()) {
            for (var d = 0.0; d <= m.length; d += 0.25) {
              final o = m.getTangentForOffset(d)!.position;
              expect(o.dx, inInclusiveRange(2.4, 21.6), reason: g.key);
              expect(o.dy, inInclusiveRange(2.4, 21.6), reason: g.key);
            }
          }
        }
      }
    });

    test('painters do not throw at sizes 16 to 48, filled or not', () {
      for (final g in [...defaultGlyphs, ...customGlyphs]) {
        for (var size = 16.0; size <= 48; size += 4) {
          for (final filled in [false, true]) {
            final rec = ui.PictureRecorder();
            final canvas = ui.Canvas(rec);
            CategoryGlyphPainter(
              g,
              const ui.Color(0xFF336699),
              filled: filled,
            ).paint(canvas, ui.Size.square(size));
            rec.endRecording().dispose();
          }
        }
      }
    });
  });

  group('CategoryIcon', () {
    testWidgets('renders every category in light and dark at several sizes', (
      t,
    ) async {
      PulseTheme.useGoogleFonts = false;
      for (final theme in [PulseTheme.light, PulseTheme.dark]) {
        await t.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Wrap(
                children: [
                  for (final c in SpendCategory.defaults) ...[
                    for (final s in [16.0, 24.0, 48.0])
                      CategoryIcon(c, size: s),
                    CategoryIcon.well(c, filled: true),
                  ],
                  const CategoryIcon(
                    SpendCategory.custom('c_x', 'X', iconKey: 'paw'),
                  ),
                ],
              ),
            ),
          ),
        );
        expect(tester(t), isNull);
        expect(
          find.byType(CategoryIcon),
          findsNWidgets(SpendCategory.defaults.length * 4 + 1),
        );
      }
    });
  });

  group('icon picker in the custom category editor', () {
    testWidgets('the picked icon is saved with the new category', (t) async {
      PulseTheme.useGoogleFonts = false;
      t.view.physicalSize = const ui.Size(390 * 3, 1200 * 3);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final repo = MockPulseRepository(latency: Duration.zero);
      await t.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            theme: PulseTheme.light,
            home: const Scaffold(body: NewCategorySheet()),
          ),
        ),
      );
      await t.enterText(find.byType(EditableText).first, 'Coffee runs');
      await t.tap(find.byKey(const ValueKey('icon_coffee')));
      await t.pump();
      await t.tap(find.text('Create'));
      await t.pumpAndSettle();
      final made = (await repo.categories()).firstWhere(
        (c) => c.label == 'Coffee runs',
      );
      expect(made.custom, isTrue);
      expect(made.iconKey, 'coffee');
      expect(glyphFor(made).key, 'coffee');
    });

    testWidgets('changing the icon of an existing custom category persists', (
      t,
    ) async {
      PulseTheme.useGoogleFonts = false;
      t.view.physicalSize = const ui.Size(390 * 3, 1200 * 3);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final repo = MockPulseRepository(latency: Duration.zero);
      final cat = await repo.createCategory(name: 'Hobbies');
      await t.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            theme: PulseTheme.dark,
            home: Scaffold(body: BudgetSheet(category: cat)),
          ),
        ),
      );
      await t.tap(find.byKey(const ValueKey('icon_palette')));
      await t.pumpAndSettle();
      final after = (await repo.categories()).firstWhere((c) => c.id == cat.id);
      expect(after.iconKey, 'palette');
    });

    testWidgets('a default category has no icon picker', (t) async {
      PulseTheme.useGoogleFonts = false;
      final repo = MockPulseRepository(latency: Duration.zero);
      await t.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            theme: PulseTheme.light,
            home: const Scaffold(
              body: BudgetSheet(category: SpendCategory.groceries),
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('icon_coffee')), findsNothing);
    });
  });
}

Object? tester(WidgetTester t) => t.takeException();
