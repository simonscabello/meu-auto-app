import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/core/network/api_paths.dart';
import 'package:meu_auto/features/abastecimento/data/abastecimento_repository.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento.dart';

void main() {
  late _RecordingAdapter adapter;
  late AbastecimentoRepository repo;

  setUp(() {
    adapter = _RecordingAdapter();
    final api = ApiClient(adapter: adapter, logPrint: (_) {});
    addTearDown(api.close);
    repo = AbastecimentoRepository(api: api, newId: () => _clientId);
  });

  test('list hits the vehicle collection with the opaque cursor', () async {
    adapter.response = _json(200, {
      'data': [_fillJson()],
      'next_cursor': 'opaque-token',
    });

    final page = await repo.list(_vehicleId, limit: 30, cursor: 'prev');

    expect(adapter.method, 'GET');
    expect(adapter.path, ApiPaths.vehicleAbastecimentos(_vehicleId));
    expect(adapter.query, {'limit': 30, 'cursor': 'prev'});
    expect(page.items, hasLength(1));
    expect(page.nextCursor, 'opaque-token');
  });

  test('get hits the member path', () async {
    adapter.response = _json(200, _fillJson());

    final fill = await repo.get(_id);

    expect(adapter.method, 'GET');
    expect(adapter.path, ApiPaths.abastecimento(_id));
    expect(fill.id, _id);
  });

  test('create posts a client id and volume_ml, never litres', () async {
    adapter.response = _json(201, _fillJson());

    await repo.create(
      vehicleId: _vehicleId,
      mileageKm: 96420,
      volumeMl: 34700,
      totalCostCents: 23840,
      fuel: AbastecimentoFuel.gasolina,
      occurredOn: const CivilDate(2026, 8, 27),
      fullTank: true,
    );

    expect(adapter.method, 'POST');
    expect(adapter.path, ApiPaths.vehicleAbastecimentos(_vehicleId));
    expect(adapter.body['id'], _clientId);
    expect(adapter.body['mileage_km'], 96420);
    expect(adapter.body['volume_ml'], 34700);
    expect(adapter.body['total_cost_cents'], 23840);
    expect(adapter.body['fuel'], 'gasolina');
    expect(adapter.body['occurred_on'], '2026-08-27');
    expect(adapter.body['full_tank'], isTrue);
    expect(adapter.body['source'], 'manual');
    expect(adapter.body.containsKey('volume_l'), isFalse);
  });

  test('create as a correction sends source correction', () async {
    adapter.response = _json(201, _fillJson());

    await repo.create(
      vehicleId: _vehicleId,
      mileageKm: 90000,
      volumeMl: 34700,
      totalCostCents: 23840,
      fuel: AbastecimentoFuel.etanol,
      force: true,
      id: _clientId,
    );

    expect(adapter.body['source'], 'correction');
    expect(adapter.body['id'], _clientId);
  });

  test('update patches the member path and can force a correction', () async {
    adapter.response = _json(200, _fillJson());

    await repo.update(
      _id,
      mileageKm: 96500,
      volumeMl: 35000,
      totalCostCents: 24000,
      fuel: AbastecimentoFuel.gasolina,
      fullTank: true,
      force: true,
    );

    expect(adapter.method, 'PATCH');
    expect(adapter.path, ApiPaths.abastecimento(_id));
    expect(adapter.body['mileage_km'], 96500);
    expect(adapter.body['source'], 'correction');
  });

  test('delete hits the member path', () async {
    adapter.response = ResponseBody.fromString('', 204);

    await repo.delete(_id);

    expect(adapter.method, 'DELETE');
    expect(adapter.path, ApiPaths.abastecimento(_id));
  });
}

const _id = 'bbbbbbbb-bbbb-7bbb-8bbb-bbbbbbbbbbbb';
const _vehicleId = '22222222-2222-7222-8222-222222222222';
const _clientId = 'cccccccc-cccc-7ccc-8ccc-cccccccccccc';

Map<String, dynamic> _fillJson() {
  return {
    'id': _id,
    'vehicle_id': _vehicleId,
    'occurred_on': '2026-08-10',
    'mileage_km': 96420,
    'volume_ml': 34700,
    'total_cost_cents': 23840,
    'price_per_liter_cents': 687,
    'fuel': 'gasolina',
    'full_tank': true,
    'station_name': null,
    'notes': null,
    'consumption': {
      'value': null,
      'unit': 'km_per_liter',
      'status': 'insufficient_data',
    },
    'created_at': '2026-08-10T15:00:00Z',
    'updated_at': '2026-08-10T15:00:00Z',
  };
}

ResponseBody _json(int status, Map<String, dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _RecordingAdapter implements HttpClientAdapter {
  ResponseBody? response;
  String? method;
  String? path;
  Map<String, dynamic> query = {};
  Map<String, dynamic> body = {};

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    method = options.method;
    path = options.path;
    query = Map<String, dynamic>.from(options.queryParameters);
    if (options.data is Map) {
      body = Map<String, dynamic>.from(options.data as Map);
    }
    if (requestStream != null) {
      await requestStream.drain<void>();
    }
    return response ?? _json(500, {});
  }
}
