import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/features/update/application/app_update_provider.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';

/// The first row of Início while a newer APK is published: which version, and
/// one tap to download it.
///
/// It rides in the header's slot, above the car, for two reasons. It is about
/// the app and not about the car, so it does not belong among the five things
/// Início answers about the car. And the header is drawn in every state —
/// loading, error, content — so the notice still shows when an old build can
/// no longer read the dashboard, which is exactly when it is needed.
///
/// With nothing to offer it is nothing at all, not an empty gap.
class AppUpdateNotice extends ConsumerWidget {
  const AppUpdateNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final release = ref.watch(appUpdateProvider).valueOrNull;
    if (release == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: appGroupGap),
      child: AppUpdateRow(
        version: release.displayVersion,
        onUpdate: () => _download(context, release.apkUrl),
      ),
    );
  }

  /// Hands the link to the browser, which downloads the APK; opening the
  /// file installs it over this one. The app never installs anything itself.
  Future<void> _download(BuildContext context, Uri url) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    } on Exception {
      opened = false;
    }
    if (!opened) {
      showAppSnackBar(
        messenger,
        message: 'Não foi possível abrir o download. Tente de novo.',
      );
    }
  }
}

/// The row itself, with no provider, so its words can be tested on their own.
class AppUpdateRow extends StatelessWidget {
  const AppUpdateRow({
    super.key,
    required this.version,
    required this.onUpdate,
  });

  /// As a person reads it — `1.2.0`, without the build number.
  final String version;

  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    return AppGroup(
      children: [
        AppListRow(
          icon: Icons.system_update_alt,
          iconTone: AppIconWellTone.accent,
          title: 'Atualizar o Meu Auto',
          subtitle: 'Versão $version disponível',
          onTap: onUpdate,
          showChevron: true,
        ),
      ],
    );
  }
}
