import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/domain/client_id.dart';
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
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
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
          currentMileageKm: _intOf(_mileage),
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
              'Bem-vindo ao Meu Auto',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'Cadastre o carro que você quer acompanhar.',
              style: Theme.of(context).textTheme.bodyLarge,
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
          _textField(
            controller: _nickname,
            label: 'Apelido',
            hint: 'como você chama o carro',
            fieldKey: 'nickname',
            textCapitalization: TextCapitalization.sentences,
          ),
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
            textCapitalization: TextCapitalization.sentences,
          ),
          _textField(
            controller: _manufactureYear,
            label: 'Ano de fabricação',
            fieldKey: 'manufacture_year',
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
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
          ),
          _textField(
            controller: _plate,
            label: 'Placa',
            fieldKey: 'plate',
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [LengthLimitingTextInputFormatter(10)],
          ),
          _textField(
            controller: _color,
            label: 'Cor',
            fieldKey: 'color',
            textCapitalization: TextCapitalization.sentences,
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s16),
            child: DropdownButtonFormField<FuelType?>(
              initialValue: _fuelInitial,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Combustível',
                errorText: _fieldErrors['fuel_type'],
                errorMaxLines: 3,
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Não informado'),
                ),
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
          if (!widget.isEditing)
            _textField(
              controller: _mileage,
              label: 'Quilometragem atual',
              fieldKey: 'current_mileage_km',
              keyboardType: TextInputType.number,
              suffixText: 'km',
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.done,
            ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: const Text('Dados do documento'),
            children: [
              _textField(
                controller: _renavam,
                label: 'Renavam',
                fieldKey: 'renavam',
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
                  : 'Cadastrar',
              loading: _submitting,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String fieldKey,
    String? hint,
    String? suffixText,
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
        onChanged: (_) {
          if (_fieldErrors.containsKey(fieldKey)) {
            setState(() => _fieldErrors.remove(fieldKey));
          }
        },
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixText: suffixText,
          errorText: _fieldErrors[fieldKey],
          errorMaxLines: 3,
        ),
      ),
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
