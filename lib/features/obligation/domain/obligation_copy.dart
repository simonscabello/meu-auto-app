import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/domain/phrases.dart';
import 'package:meu_auto/features/obligation/domain/obligation.dart';
import 'package:meu_auto/features/obligation/domain/seguro.dart';

String obligationKindLabel(ObligationKind kind) {
  return switch (kind) {
    ObligationKind.ipva => 'IPVA',
    ObligationKind.licenciamento => 'Licenciamento',
    ObligationKind.desconhecido => 'Obrigação',
  };
}

String obligationTitle(Obligation obligation) {
  return '${obligationKindLabel(obligation.kind)} ${obligation.referenceYear}';
}

/// Words for a status the server already decided. Never compares dates.
String obligationStatusPhrase(Obligation obligation) {
  switch (obligation.status) {
    case ObligationStatus.pago:
      return paidLatePhrase(obligation.remainingDays) ?? 'Em dia';
    case ObligationStatus.vencido:
    case ObligationStatus.venceEmBreve:
    case ObligationStatus.pendente:
      return remainingDaysPhrase(obligation.remainingDays) ?? '';
    case ObligationStatus.desconhecido:
      return '';
  }
}

String obligationConflictMessage({
  required ObligationKind kind,
  required int year,
}) {
  return switch (kind) {
    ObligationKind.ipva => 'Já existe um IPVA de $year para este carro.',
    ObligationKind.licenciamento =>
      'Já existe um licenciamento de $year para este carro.',
    ObligationKind.desconhecido =>
      'Já existe um registro de $year para este carro.',
  };
}

String obligationRegisteredMessage(ObligationKind kind) {
  return switch (kind) {
    ObligationKind.ipva => 'IPVA registrado.',
    ObligationKind.licenciamento => 'Licenciamento registrado.',
    ObligationKind.desconhecido => 'Registro criado.',
  };
}

String obligationUpdatedMessage(ObligationKind kind) {
  return switch (kind) {
    ObligationKind.ipva => 'IPVA atualizado.',
    ObligationKind.licenciamento => 'Licenciamento atualizado.',
    ObligationKind.desconhecido => 'Registro atualizado.',
  };
}

String obligationDeletedMessage(ObligationKind kind) {
  return switch (kind) {
    ObligationKind.ipva => 'IPVA excluído.',
    ObligationKind.licenciamento => 'Licenciamento excluído.',
    ObligationKind.desconhecido => 'Registro excluído.',
  };
}

String seguroStatusPhrase(Seguro seguro) {
  switch (seguro.status) {
    case SeguroStatus.futuro:
      return seguroStartsPhrase(seguro.remainingDays);
    case SeguroStatus.vigente:
      return '';
    case SeguroStatus.venceEmBreve:
      return remainingDaysPhrase(seguro.remainingDays) ?? '';
    case SeguroStatus.vencido:
      return 'O carro está sem cobertura.';
    case SeguroStatus.desconhecido:
      return '';
  }
}

/// Days until cover begins. The count comes from the server; this only
/// chooses words. [remainingDaysPhrase] talks about vencimento and would
/// misread a policy that has not started yet.
String seguroStartsPhrase(int remainingDays) {
  if (remainingDays == 0) return 'Começa hoje';
  if (remainingDays == 1) return 'Começa amanhã';
  if (remainingDays < 0) return '';
  if (remainingDays <= 45) return 'Começa em $remainingDays dias';
  final months = (remainingDays + 15) ~/ 30;
  final count = months < 1 ? 1 : months;
  final unit = count == 1 ? 'mês' : 'meses';
  return 'Começa em cerca de $count $unit';
}

String seguroVigenciaPhrase(Seguro seguro) {
  return '${formatCivilDateLong(seguro.startsOn)} a ${formatCivilDateLong(seguro.endsOn)}';
}

/// The single line under an obligation in the Cuidados list.
///
/// The status used to arrive as a coloured chip beside the title. In a list
/// of rows the state has to be readable as text, both because the chip is
/// gone and because a chip is a poor thing to hand a screen reader. The word
/// comes first, the figure after it.
///
/// "Pago · Em dia" would be saying it twice, so a policy paid on time is just
/// "Pago"; only a late payment adds its clause.
String obligationListSubtitle(Obligation obligation) {
  if (obligation.status == ObligationStatus.pago) {
    final late = paidLatePhrase(obligation.remainingDays);
    return late == null ? 'Pago' : 'Pago · $late';
  }
  final label = switch (obligation.status) {
    ObligationStatus.vencido => 'Vencido',
    ObligationStatus.venceEmBreve => 'Vence em breve',
    ObligationStatus.pendente => 'A pagar',
    ObligationStatus.pago || ObligationStatus.desconhecido => '',
  };
  final phrase = obligationStatusPhrase(obligation);
  if (label.isEmpty) return phrase;
  if (phrase.isEmpty) return label;
  return '$label · $phrase';
}

/// The same, for a policy.
///
/// `vigente` has no phrase of its own — a policy that is simply in force has
/// nothing to add — so the word stands alone rather than trailing a
/// separator with nothing after it.
String seguroListSubtitle(Seguro seguro) {
  final label = switch (seguro.status) {
    SeguroStatus.futuro => 'Ainda não começou',
    SeguroStatus.vigente => 'Vigente',
    SeguroStatus.venceEmBreve => 'Vence em breve',
    SeguroStatus.vencido => 'Vencido',
    SeguroStatus.desconhecido => '',
  };
  final phrase = seguroStatusPhrase(seguro);
  if (label.isEmpty) return phrase;
  if (phrase.isEmpty) return label;
  return '$label · $phrase';
}

List<Obligation> obligationsOfKind(
  List<Obligation> obligations,
  ObligationKind kind,
) {
  return [
    for (final obligation in obligations)
      if (obligation.kind == kind) obligation,
  ];
}
