import 'package:flutter/material.dart';

/// An icon for a catalogue item, chosen by its slug.
///
/// A small map on purpose. The catalogue has twenty-seven items and can grow
/// server-side at any time, so this groups them into a handful of families and
/// falls back to a wrench for anything it does not recognise. The item's name
/// is always beside the icon and carries the meaning; the icon is scanning aid,
/// not identification.
///
/// One family, one weight: outline glyphs wherever Material has one, because
/// these sit in the same rows as the outline icons the rest of the app uses
/// and a filled glyph beside them reads as a different level of emphasis.
IconData maintenanceIconFor(String slug) {
  return switch (slug) {
    'troca_oleo' ||
    'filtro_oleo' ||
    'oleo_cambio' ||
    'verificar_oleo' => Icons.oil_barrel,
    'filtro_ar' || 'filtro_cabine' || 'filtro_combustivel' => Icons.air,
    'velas' => Icons.bolt_outlined,
    'correia_dentada' || 'corrente_comando' => Icons.sync,
    'bateria' => Icons.battery_charging_full_outlined,
    'bateria_tracao' => Icons.electric_car_outlined,
    'pneus' ||
    'rodizio_pneus' ||
    'alinhamento' ||
    'balanceamento' ||
    'calibrar_pneus' ||
    'verificar_pneus' => Icons.tire_repair,
    'fluido_arrefecimento' || 'verificar_arrefecimento' => Icons.ac_unit,
    'palhetas' => Icons.water_drop_outlined,
    'lavar_carro' => Icons.local_car_wash_outlined,
    'revisao' => Icons.fact_check_outlined,
    _ => Icons.build_outlined,
  };
}
