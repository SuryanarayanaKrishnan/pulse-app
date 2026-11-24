import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';

/// Placeholder for the nominees and legacy vault. Describes what is coming;
/// holds no data.
class LegacyScreen extends StatelessWidget {
  const LegacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nominees & legacy'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Space.xxxl),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.sm,
              Space.gutter,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.sm + 2,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: c.surfaceElevated,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Text('Coming soon', style: context.tt.labelMedium),
                ),
                const SizedBox(height: Space.lg),
                Text(
                  'A calm place for the things your family would need to know.',
                  style: context.tt.headlineSmall,
                ),
                const SizedBox(height: Space.sm),
                Text(
                  'Nothing is stored here yet. When it opens, everything in it '
                  'is encrypted and only released on your terms.',
                  style: context.tt.bodyMedium,
                ),
              ],
            ),
          ),
          const SectionHeader('What it will hold'),
          const RowGroup(
            indent: ListRow.leadingInset,
            children: [
              ListRow(
                leading: IconWell(Icons.how_to_reg_outlined),
                title: 'Nominees',
                subtitle:
                    'Who receives each account, asset and insurance policy',
              ),
              ListRow(
                leading: IconWell(Icons.inventory_2_outlined),
                title: 'If something happens to me',
                subtitle: 'An inventory of accounts, policies, documents and contacts',
              ),
              ListRow(
                leading: IconWell(Icons.lock_clock_outlined),
                title: 'Trusted contact release',
                subtitle: 'Shared with a person you choose only after a long period of inactivity, and only after they confirm',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
