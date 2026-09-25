import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_tones.dart';
import 'package:meu_auto/shared/widgets/app_section_header.dart';

/// A named part of a form: a quiet label and the fields under it, evenly
/// spaced.
///
/// A form that is one column of twelve fields is a wall. Cut into three or
/// four named parts — what was done, when, where and how much — it is read
/// in the order it is filled, and the person always knows how far along they
/// are. The gap between sections is [AppSpacing.block]; between fields,
/// [AppSpacing.s12].
class AppFormSection extends StatelessWidget {
  const AppFormSection({
    super.key,
    required this.children,
    this.title,
    this.subtitle,
    this.gap = AppSpacing.s12,
  });

  final String? title;
  final String? subtitle;
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          AppSectionHeader(
            title: title!,
            subtitle: subtitle,
            emphasis: AppSectionEmphasis.label,
          ),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          children[i],
        ],
      ],
    );
  }
}

/// The gap between two [AppFormSection]s.
class AppFormGap extends StatelessWidget {
  const AppFormGap({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: AppSpacing.block);
  }
}

/// The primary action pinned under a scrolling form, on a fade so the last
/// field is never hidden behind it.
class AppFormFooter extends StatelessWidget {
  const AppFormFooter({super.key, required this.child, this.hint});

  final Widget child;

  /// A quiet line above the button — why it is disabled, what will happen.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = AppTones.of(context);
    return DecoratedBox(
      // The bar the button rests on: the page's own tone, with a hairline
      // along its top so the fields scrolling under it end somewhere.
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: tones.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.s12,
            AppSpacing.page,
            AppSpacing.s12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hint != null) ...[
                Text(
                  hint!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.s8),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}
