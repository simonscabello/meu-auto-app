abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const passwordReset = '/password-reset';

  /// Deep link from the password-reset e-mail: `meuauto://redefinir-senha?token=`.
  static const passwordResetConfirm = '/redefinir-senha';

  static const deleteAccount = '/excluir-conta';
  static const home = '/';
  static const care = '/cuidados';
  static const history = '/historico';
  static const profile = '/perfil';
  static const vehicles = '/vehicles';
  static const vehicleNew = '/vehicles/new';

  /// Mileage history of the selected vehicle. No id in the path — everything
  /// inside the shell is about the car currently chosen.
  static const odometer = '/quilometragem';

  /// Service history of the selected vehicle, and one record inside it.
  static const maintenance = '/manutencoes';

  static const maintenanceNew = '/manutencoes/nova';

  static String maintenanceRecord(String id) => '/manutencoes/$id';

  /// Registered-cost summary of the selected vehicle. Same `/dashboard`
  /// payload, with a chosen `cost_months`.
  static const costs = '/custos';

  /// One IPVA or licenciamento.
  static const obligationDetail = '/obrigacoes/:obligationId';

  static String obligation(String id) => '/obrigacoes/$id';

  static const abastecimentos = '/abastecimentos';

  /// Pattern for the GoRoute.
  static const abastecimentoDetail = '/abastecimentos/:abastecimentoId';

  static String abastecimento(String id) => '/abastecimentos/$id';

  static const seguroNew = '/seguros/novo';

  /// Pattern for the GoRoute. The literal lives here so `api_paths_test`
  /// does not treat `/seguros/` in the router as an API path.
  static const seguroDetail = '/seguros/:seguroId';

  static String seguro(String id) => '/seguros/$id';

  static String seguroEdit(String id) => '/seguros/$id/editar';

  /// One maintenance plan. Lives outside the shell so the tab bar is not
  /// competing with the actions on the detail.
  static String plan(String id) => '/planos/$id';

  static String vehicle(String id) => '/vehicles/$id';

  static String vehicleEdit(String id) => '/vehicles/$id/edit';

  /// First-use questions: when each main care item last happened.
  static String calibrar(String vehicleId) => '/calibrar/$vehicleId';

  /// What the selected car has, and what we still do not know about it. The one
  /// screen that lists the items the vehicle does not use — everywhere else they
  /// are absent, not disabled.
  static const vehicleProfile = '/perfil-do-carro';
}
