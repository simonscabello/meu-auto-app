import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/domain/client_id.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/auth/application/auth_controller.dart';
import 'package:meu_auto/features/catalog/domain/vehicle_catalog.dart';
import 'package:meu_auto/features/catalog/presentation/vehicle_catalog_sheet.dart';
import 'package:meu_auto/features/auth/presentation/auth_form_banner.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/features/vehicle/domain/vehicle.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_confirm.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_number_field.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_section_header.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';

class VehicleFormScreen extends ConsumerStatefulWidget {
  const VehicleFormScreen({super.key, this.vehicleId});

  final String? vehicleId;

  bool get isEditing => vehicleId != null;

  @override
  ConsumerState<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends ConsumerState<VehicleFormScreen> {
  final _nickname = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _version = TextEditingController();
  final _manufactureYear = TextEditingController();
  final _modelYear = TextEditingController();
  final _plate = TextEditingController();
  final _color = TextEditingController();
  final _mileage = TextEditingController();
  final _renavam = TextEditingController();
  final _chassis = TextEditingController();
  final _createId = newClientId();

  FuelType? _fuel;
  FuelType? _fuelInitial;

  /// The catalogue entry the owner picked, or null when they are typing the
  /// vehicle by hand — which stays a first-class path and always will.
  VehicleCatalogSelection? _catalog;

  /// The FIPE code snapshot travelling with the write. Comes from the picker
  /// and is never typed: there is no field for it and there should not be.
  String? _fipeCode;

  /// The link the vehicle already had when editing. Kept separately from
  /// [_catalog] because a PATCH that does not mention the catalogue must leave
  /// the existing link alone, and null means exactly that: say nothing.
  String? _existingCatalogId;

  bool _filled = false;
  bool _submitting = false;
  bool _loggingOut = false;
  bool _offline = false;
  String? _banner;
  Map<String, String> _fieldErrors = {};

  @override
  void dispose() {
    _nickname.dispose();
    _brand.dispose();
    _model.dispose();
    _version.dispose();
    _manufactureYear.dispose();
    _modelYear.dispose();
    _plate.dispose();
    _color.dispose();
    _mileage.dispose();
    _renavam.dispose();
    _chassis.dispose();
    super.dispose();
  }

  void _fill(Vehicle vehicle) {
    if (_filled) {
      return;
    }
    _filled = true;
    _nickname.text = vehicle.nickname ?? '';
    _brand.text = vehicle.brand;
    _model.text = vehicle.model;
    _version.text = vehicle.version ?? '';
    _manufactureYear.text = vehicle.manufactureYear?.toString() ?? '';
    _modelYear.text = vehicle.modelYear?.toString() ?? '';
    _plate.text = vehicle.plate ?? '';
    _color.text = vehicle.color ?? '';
    _renavam.text = vehicle.renavam ?? '';
    _chassis.text = vehicle.chassis ?? '';
    _fuel = vehicle.fuelType == FuelType.desconhecido ? null : vehicle.fuelType;
    _fuelInitial = _fuel;
    _existingCatalogId = vehicle.catalogModelYearId;
    _fipeCode = vehicle.fipeCode;
  }

  /// Opens the picker and copies what came back into the fields.
  ///
  /// The text is copied rather than referenced: those fields are the snapshot
  /// the vehicle stores, and they stay editable afterwards. Someone who picks
  /// a Prius and then corrects the version keeps their correction.
  Future<void> _pickFromCatalog() async {
    final selection = await VehicleCatalogSheet.show(context);
    if (selection == null || !mounted) {
      return;
    }
    setState(() {
      _catalog = selection;
      _brand.text = selection.brandName;
      _model.text = selection.modelName;
      if (selection.modelYear != null) {
        _modelYear.text = selection.modelYear.toString();
      }
      if (selection.fuelType != null &&
          selection.fuelType != FuelType.desconhecido) {
        _fuel = selection.fuelType;
        _fuelInitial = _fuel;
      }
      _fipeCode = selection.fipeCode;
      // The picker just replaced the four fields it owns, so whatever the
      // server said about them is stale.
      _fieldErrors.remove('brand');
      _fieldErrors.remove('model');
      _fieldErrors.remove('model_year');
      _fieldErrors.remove('fuel_type');
    });
  }

  /// Drops the link but keeps the text. The person asked to stop tracking the
  /// catalogue entry, not to clear the form they just filled.
  void _clearCatalog() {
    setState(() {
      _catalog = null;
      _fipeCode = null;
    });
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _banner = null;
      _offline = false;
      _fieldErrors = {};
    });
    try {
      final notifier = ref.read(vehiclesProvider.notifier);
      final wasFirstVehicle =
          !widget.isEditing &&
          (ref.read(vehiclesProvider).value?.vehicles.isEmpty ?? true);
      if (widget.isEditing) {
        await notifier.updateVehicle(
          id: widget.vehicleId!,
          brand: _brand.text,
          model: _model.text,
          version: _version.text,
          manufactureYear: _intOf(_manufactureYear),
          modelYear: _intOf(_modelYear),
          plate: _plate.text,
          renavam: _renavam.text,
          chassis: _chassis.text,
          fuelType: _fuel,
          color: _color.text,
          nickname: _nickname.text,
          catalogModelYearId: _catalog?.modelYearId,
          fipeCode: _fipeCode,
        );
      } else {
        await notifier.create(
          id: _createId,
          brand: _brand.text,
          model: _model.text,
          version: _version.text,
          manufactureYear: _intOf(_manufactureYear),
          modelYear: _intOf(_modelYear),
          plate: _plate.text,
          renavam: _renavam.text,
          chassis: _chassis.text,
          fuelType: _fuel,
          color: _color.text,
          nickname: _nickname.text,
          catalogModelYearId: _catalog?.modelYearId,
          fipeCode: _fipeCode,
          currentMileageKm: kmFromField(_mileage.text),
        );
      }
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      if (widget.isEditing) {
        context.pop();
        showAppSnackBar(messenger, message: 'Veículo atualizado.');
        return;
      }
      if (wasFirstVehicle) {
        context.go(AppRoutes.calibrar(_createId));
        return;
      }
      context.go(AppRoutes.home);
      showAppSnackBar(messenger, message: 'Veículo cadastrado.');
    } on ApiFailure catch (failure) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _fieldErrors = ApiFormErrors.fieldsOf(failure);
        _banner = ApiFormErrors.bannerOf(failure);
        _offline = ApiFormErrors.isOffline(failure);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _banner = 'Algo deu errado. Tente novamente.';
      });
    }
  }

  Future<void> _logout() async {
    if (!await confirmLogout(context) || !mounted) {
      return;
    }
    setState(() => _loggingOut = true);
    await ref.read(authControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(vehiclesProvider);
    final onboarding =
        !widget.isEditing && (list.value?.vehicles.isEmpty ?? false);
    if (widget.isEditing) {
      return list.when(
        loading: () => const AppScaffold(
          title: 'Editar veículo',
          body: Padding(
            padding: EdgeInsets.all(AppSpacing.s24),
            child: AppSkeletonList(),
          ),
        ),
        error: (error, _) => AppScaffold(
          title: 'Editar veículo',
          body: AppErrorState.fromError(
            error: error,
            onRetry: () => ref.read(vehiclesProvider.notifier).reload(),
          ),
        ),
        data: (state) {
          final vehicle = _find(state.vehicles, widget.vehicleId!);
          if (vehicle == null) {
            return AppScaffold(
              title: 'Editar veículo',
              body: AppErrorState(
                message: 'Este veículo não foi encontrado.',
                onRetry: () => ref.read(vehiclesProvider.notifier).reload(),
              ),
            );
          }
          _fill(vehicle);
          return _form(onboarding: false);
        },
      );
    }
    return _form(onboarding: onboarding);
  }

  Widget _form({required bool onboarding}) {
    final title = widget.isEditing ? 'Editar veículo' : 'Novo veículo';
    // The picker fills brand, model, year and fuel. Once it has, those four
    // fold away behind one row rather than staying open as work still to do.
    // They remain editable, one tap in, because the snapshot is the owner's
    // to correct and always was.
    final identified = _catalog != null && !_carFieldsHaveError;

    return AppScaffold(
      title: title,
      actions: [
        if (onboarding)
          TextButton(
            onPressed: _loggingOut || _submitting ? null : _logout,
            child: const Text('Sair'),
          ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.s24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          if (onboarding) ...[
            Text(
              'Seu primeiro carro',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'Marca e modelo bastam para começar. O resto pode vir depois.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.s24),
          ],
          if (_banner != null) AuthFormBanner(message: _banner!),
          // Above the fields it fills, because it is the shortcut past them.
          // Typing everything by hand still works and is never hidden.
          if (_catalog != null)
            VehicleCatalogSummary(
              selection: _catalog!,
              enabled: !_submitting,
              onChange: _pickFromCatalog,
              onClear: _clearCatalog,
            )
          else
            VehicleCatalogPrompt(
              enabled: !_submitting,
              alreadyLinked: _existingCatalogId != null,
              onPressed: _pickFromCatalog,
            ),
          if (identified)
            VehicleFoldedSection(
              title: 'Marca, modelo, ano e combustível',
              subtitle: 'Preenchidos pela tabela FIPE. Dá para corrigir.',
              children: _carFields(),
            )
          else ...[
            const AppSectionHeader(title: 'O carro'),
            const SizedBox(height: AppSpacing.s8),
            ..._carFields(),
          ],
          if (!widget.isEditing) ...[
            const SizedBox(height: AppSpacing.s8),
            const AppSectionHeader(title: 'Quilometragem'),
            const SizedBox(height: AppSpacing.s8),
            AppKmField(
              controller: _mileage,
              label: 'Quilometragem atual',
              enabled: !_submitting,
              helperText: 'É daqui que o Meu Auto conta os próximos cuidados.',
              errorText: _fieldErrors['current_mileage_km'],
              onChanged: (_) => _clearError('current_mileage_km'),
            ),
            const SizedBox(height: AppSpacing.s24),
          ],
          const AppSectionHeader(title: 'Como você reconhece'),
          const SizedBox(height: AppSpacing.s8),
          _textField(
            controller: _nickname,
            label: 'Apelido',
            hint: 'como você chama o carro',
            fieldKey: 'nickname',
            optional: true,
            textCapitalization: TextCapitalization.sentences,
          ),
          _textField(
            controller: _plate,
            label: 'Placa',
            hint: 'ABC1D23',
            fieldKey: 'plate',
            optional: true,
            inputFormatters: const [PlateInputFormatter()],
          ),
          _textField(
            controller: _color,
            label: 'Cor',
            fieldKey: 'color',
            optional: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
          ),
          VehicleFoldedSection(
            title: 'Dados do documento',
            subtitle: 'Renavam e chassi, se você tiver o CRLV à mão.',
            children: [
              _textField(
                controller: _renavam,
                label: 'Renavam',
                fieldKey: 'renavam',
                optional: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
              ),
              _textField(
                controller: _chassis,
                label: 'Chassi',
                fieldKey: 'chassis',
                optional: true,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [LengthLimitingTextInputFormatter(17)],
                textInputAction: TextInputAction.done,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s24),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: _offline
                  ? 'Tentar de novo'
                  : widget.isEditing
                  ? 'Salvar'
                  : 'Cadastrar veículo',
              loading: _submitting,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }

  /// True while the server is complaining about one of the four the catalogue
  /// owns — the fold has to open so the message is not hidden behind a tap.
  bool get _carFieldsHaveError {
    for (final key in const ['brand', 'model', 'model_year', 'fuel_type']) {
      if (_fieldErrors.containsKey(key)) return true;
    }
    return false;
  }

  void _clearError(String fieldKey) {
    if (!_fieldErrors.containsKey(fieldKey)) return;
    setState(() => _fieldErrors.remove(fieldKey));
  }

  List<Widget> _carFields() {
    return [
      _textField(
        controller: _brand,
        label: 'Marca',
        fieldKey: 'brand',
        textCapitalization: TextCapitalization.words,
      ),
      _textField(
        controller: _model,
        label: 'Modelo',
        fieldKey: 'model',
        textCapitalization: TextCapitalization.words,
      ),
      _textField(
        controller: _version,
        label: 'Versão',
        fieldKey: 'version',
        optional: true,
        textCapitalization: TextCapitalization.sentences,
      ),
      _textField(
        controller: _manufactureYear,
        label: 'Ano de fabricação',
        fieldKey: 'manufacture_year',
        optional: true,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(4),
        ],
      ),
      _textField(
        controller: _modelYear,
        label: 'Ano do modelo',
        fieldKey: 'model_year',
        optional: true,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(4),
        ],
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.s16),
        child: DropdownButtonFormField<FuelType?>(
          initialValue: _fuelInitial,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Combustível (opcional)',
            errorText: _fieldErrors['fuel_type'],
            errorMaxLines: 3,
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('Não informado')),
            for (final fuel in FuelType.values)
              if (fuel != FuelType.desconhecido)
                DropdownMenuItem(value: fuel, child: Text(fuel.label)),
          ],
          onChanged: _submitting
              ? null
              : (value) {
                  setState(() {
                    _fuel = value;
                    _fieldErrors.remove('fuel_type');
                  });
                },
        ),
      ),
    ];
  }

  /// One field of the form.
  ///
  /// [optional] appends the word rather than marking the two required ones
  /// with an asterisk: brand and model are the only things the server insists
  /// on, so labelling nine fields as optional is shorter and kinder than
  /// implying the other nine are homework.
  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String fieldKey,
    String? hint,
    bool optional = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
      child: TextField(
        controller: controller,
        enabled: !_submitting,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        textCapitalization: textCapitalization,
        inputFormatters: [
          LengthLimitingTextInputFormatter(120),
          ...?inputFormatters,
        ],
        onChanged: (_) => _clearError(fieldKey),
        decoration: InputDecoration(
          labelText: optional ? '$label (opcional)' : label,
          hintText: hint,
          errorText: _fieldErrors[fieldKey],
          errorMaxLines: 3,
        ),
      ),
    );
  }
}

/// A group of fields that starts closed.
///
/// Used where the fields inside are real but rarely the reason someone opened
/// the screen — the document numbers, and the four the catalogue already
/// filled. Closed is not hidden: the row says what is inside.
class VehicleFoldedSection extends StatelessWidget {
  const VehicleFoldedSection({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
        children: children,
      ),
    );
  }
}

/// Uppercases and keeps only the seven characters a Brazilian plate has.
///
/// Both formats are seven: `ABC1234` and the Mercosul `ABC1D23`. The server
/// strips punctuation and uppercases before it validates, so this is the same
/// rule applied where the person can still see it happen — a hyphen typed out
/// of habit disappears instead of surviving to a 422.
class PlateInputFormatter extends TextInputFormatter {
  const PlateInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final buffer = StringBuffer();
    for (final char in newValue.text.toUpperCase().split('')) {
      if (buffer.length == 7) break;
      final unit = char.codeUnitAt(0);
      final isLetter = unit >= 0x41 && unit <= 0x5A;
      final isDigit = unit >= 0x30 && unit <= 0x39;
      if (isLetter || isDigit) buffer.write(char);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

Vehicle? _find(List<Vehicle> vehicles, String id) {
  for (final vehicle in vehicles) {
    if (vehicle.id == id) {
      return vehicle;
    }
  }
  return null;
}

int? _intOf(TextEditingController controller) {
  final text = controller.text.trim();
  if (text.isEmpty) {
    return null;
  }
  return int.tryParse(text);
}
