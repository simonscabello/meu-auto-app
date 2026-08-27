import 'package:flutter/material.dart';

/// An icon for a catalogue item, chosen by its slug.
///
/// A small map on purpose. The catalogue has twenty-seven items and can grow
/// server-side at any time, so this groups them into a handful of families and
/// falls back to a wrench for anything it does not recognise. The item's name
/// is always beside the icon and carries the meaning; the icon is scanning aid,
/// not identification.
IconData maintenanceIconFor(String slug) {
  return switch (slug) {
    'troca_oleo' ||
    'filtro_oleo' ||
    'oleo_cambio' ||
    'verificar_oleo' => Icons.oil_barrel,
    'filtro_ar' || 'filtro_cabine' || 'filtro_combustivel' => Icons.air,
    'velas' => Icons.bolt,
    'correia_dentada' || 'corrente_comando' => Icons.settings,
    'bateria' => Icons.battery_full,
    'bateria_tracao' => Icons.electric_car,
    'pneus' ||
    'rodizio_pneus' ||
    'alinhamento' ||
    'balanceamento' ||
    'calibrar_pneus' ||
    'verificar_pneus' => Icons.tire_repair,
    'fluido_arrefecimento' || 'verificar_arrefecimento' => Icons.ac_unit,
    'palhetas' => Icons.water_drop,
    'lavar_carro' => Icons.local_car_wash,
    'revisao' => Icons.fact_check,
    _ => Icons.build,
  };
}
