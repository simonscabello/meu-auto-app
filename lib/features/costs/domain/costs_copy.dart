/// Rolling window measured back from `since`, never a calendar month.
///
/// `cost_months=1` is thirty days, not "este mês" — on any day but the 1st
/// those two would disagree.
String costWindowLabel(int periodMonths) {
  if (periodMonths == 1) {
    return 'últimos 30 dias';
  }
  return 'últimos $periodMonths meses';
}

/// What the tracked total leaves out, inferred from the category keys the
/// server says it counted — `categories[].key` on a current payload,
/// `tracked_categories` on an older one.
///
/// Required by the contract: without this, the total reads as the cost of
/// running the car. Fuel and day-to-day expenses are named only when they
/// are actually absent from [categoryKeys], so the sentence follows the
/// payload if a later build starts counting them.
String? excludedCategoriesNote(List<String> categoryKeys) {
  final tracked = categoryKeys.toSet();
  final missing = <String>[
    if (!tracked.contains('abastecimento')) 'Combustível',
    if (!tracked.contains('expenses')) 'despesas do dia a dia',
  ];
  if (missing.isEmpty) return null;
  if (missing.length == 1) {
    final item = missing.single;
    final verb = item == 'Combustível' ? 'entra' : 'entram';
    return '$item ainda não $verb nesta conta.';
  }
  return '${missing.first} e ${missing.last} ainda não entram nesta conta.';
}

String emptyPeriodPhrase(int periodMonths) {
  return 'Nenhum custo nos ${costWindowLabel(periodMonths)}. '
      'Troque o intervalo ou registre um serviço.';
}
