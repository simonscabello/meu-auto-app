import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/shared/widgets/app_bottom_sheet.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_setting_row.dart';
import 'package:meu_auto/shared/widgets/app_sheet_header.dart';

enum PhotoAction { camera, gallery, remove }

/// What tapping the avatar on Perfil offers: take a photo, pick one, or —
/// only when there is one — remove it. A picker, so it closes by dragging.
class PhotoSourceSheet extends StatelessWidget {
  const PhotoSourceSheet({super.key, required this.hasPhoto});

  final bool hasPhoto;

  static Future<PhotoAction?> show(
    BuildContext context, {
    required bool hasPhoto,
  }) {
    return showAppSheet<PhotoAction>(
      context,
      builder: (_) => PhotoSourceSheet(hasPhoto: hasPhoto),
    );
  }

  @override
  Widget build(BuildContext context) {
    void choose(PhotoAction action) => Navigator.pop(context, action);
    return AppSheetBody(
      children: [
        AppSheetHeader(
          title: hasPhoto ? 'Foto do perfil' : 'Adicionar foto',
          closable: false,
        ),
        const SizedBox(height: AppSpacing.s8),
        AppGroup(
          children: [
            AppListRow(
              icon: Icons.photo_camera_outlined,
              title: 'Tirar foto',
              onTap: () => choose(PhotoAction.camera),
            ),
            AppListRow(
              icon: Icons.photo_library_outlined,
              title: 'Escolher da galeria',
              onTap: () => choose(PhotoAction.gallery),
            ),
          ],
        ),
        if (hasPhoto) ...[
          const SizedBox(height: appGroupGap),
          AppGroup(
            children: [
              AppSettingRow(
                label: 'Remover foto',
                icon: Icons.delete_outline,
                destructive: true,
                trailing: const SizedBox.shrink(),
                onTap: () => choose(PhotoAction.remove),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
