import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/tokens.dart';
import 'empty_state.dart';
import 'primary_button.dart';
import 'skeleton.dart';

/// Renders loading skeleton / error state / data for an [AsyncValue].
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.builder,
    this.loading,
    this.onRetry,
  });
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final Widget? loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => value.when(
    data: builder,
    loading: () => loading ?? const SkeletonList(),
    error: (e, _) => EmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'Something went wrong',
      message: 'We could not load this right now.',
      action: onRetry == null
          ? null
          : PrimaryButton(
              label: 'Try again',
              expand: false,
              onPressed: onRetry,
            ),
    ),
  );
}

/// Standard screen gutter.
const screenPad = EdgeInsets.symmetric(horizontal: Space.gutter);
