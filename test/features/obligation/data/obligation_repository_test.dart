import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/core/network/api_paths.dart';
import 'package:meu_auto/features/obligation/data/obligation_repository.dart';
import 'package:meu_auto/features/obligation/domain/obligation.dart';

void main() {
  late _RecordingAdapter adapter;
  late ObligationRepository repo;

  setUp(() {
    adapter = _RecordingAdapter();
    final api = ApiClient(adapter: adapter, logPrint: (_) {});
    addTearDown(api.close);
    repo = ObligationRepository(api: api, newId: () => _clientId);
  });

  test('listObligations hits the vehicle collection', () async {
    adapter.response = _json(200, {
      'data': [_obligationJson()],
    });

    final list = await repo.listObligations(_vehicleId);

    expect(adapter.method, 'GET');
    expect(adapter.path, ApiPaths.vehicleObligations(_vehicleId));
    expect(list, hasLength(1));
    expect(list.single.kind, ObligationKind.ipva);
  });

  test('getObligation hits the member path', () async {
    adapter.response = _json(200, _obligationJson());

    final obligation = await repo.getObligation(_id);

    expect(adapter.method, 'GET');
    expect(adapter.path, ApiPaths.obligation(_id));
    expect(obligation.id, _id);
  });

  test('createObligation posts a client id and the form fields', () async {
    adapter.response = _json(201, _obligationJson());

    await repo.createObligation(
      vehicleId: _vehicleId,
      kind: ObligationKind.ipva,
      referenceYear: 2026,
      dueOn: const CivilDate(2026, 3, 15),
      amountCents: 184237,
    );

    expect(adapter.method, 'POST');
    expect(adapter.path, ApiPaths.vehicleObligations(_vehicleId));
    expect(adapter.body['id'], _clientId);
    expect(adapter.body['kind'], 'ipva');
    expect(adapter.body['reference_year'], 2026);
    expect(adapter.body['due_on'], '2026-03-15');
    expect(adapter.body['amount_cents'], 184237);
  });

  test('updateObligation with clearPayment sends only that flag', () async {
    adapter.response = _json(200, _obligationJson(status: 'pendente'));

    await repo.updateObligation(_id, clearPayment: true);

    expect(adapter.method, 'PATCH');
    expect(adapter.path, ApiPaths.obligation(_id));
    expect(adapter.body, {'clear_payment': true});
  });

  test('marking paid sends paid_on and optional amount', () async {
    adapter.response = _json(200, _obligationJson(status: 'pago'));

    await repo.updateObligation(
      _id,
      paidOn: const CivilDate(2026, 3, 18),
      paidAmountCents: 190000,
    );

    expect(adapter.body['paid_on'], '2026-03-18');
    expect(adapter.body['paid_amount_cents'], 190000);
    expect(adapter.body.containsKey('clear_payment'), isFalse);
  });

  test('deleteObligation hits the member path', () async {
    adapter.response = ResponseBody.fromString('', 204);

    await repo.deleteObligation(_id);

    expect(adapter.method, 'DELETE');
    expect(adapter.path, ApiPaths.obligation(_id));
  });

  test('listSeguros and getSeguro hit the seguro paths', () async {
    adapter.response = _json(200, {
      'data': [_seguroJson()],
    });
    await repo.listSeguros(_vehicleId);
    expect(adapter.path, ApiPaths.vehicleSeguros(_vehicleId));

    adapter.response = _json(200, _seguroJson());
    await repo.getSeguro(_seguroId);
    expect(adapter.path, ApiPaths.seguro(_seguroId));
  });

  test('createSeguro posts the policy fields', () async {
    adapter.response = _json(201, _seguroJson());

    await repo.createSeguro(
      vehicleId: _vehicleId,
      insurerName: 'Porto Seguro',
      startsOn: const CivilDate(2026, 1, 10),
      endsOn: const CivilDate(2027, 1, 10),
      emergencyPhone: '080012340800',
    );

    expect(adapter.method, 'POST');
    expect(adapter.path, ApiPaths.vehicleSeguros(_vehicleId));
    expect(adapter.body['id'], _clientId);
    expect(adapter.body['insurer_name'], 'Porto Seguro');
    expect(adapter.body['emergency_phone'], '080012340800');
  });

  test('deleteSeguro hits the member path', () async {
    adapter.response = ResponseBody.fromString('', 204);

    await repo.deleteSeguro(_seguroId);

    expect(adapter.method, 'DELETE');
    expect(adapter.path, ApiPaths.seguro(_seguroId));
  });
}

const _id = 'aaaaaaaa-aaaa-7aaa-8aaa-aaaaaaaaaaaa';
const _seguroId = 'bbbbbbbb-bbbb-7bbb-8bbb-bbbbbbbbbbbb';
const _vehicleId = '11111111-1111-7111-8111-111111111111';
const _clientId = 'cccccccc-cccc-7ccc-8ccc-cccccccccccc';

Map<String, dynamic> _obligationJson({String status = 'pendente'}) {
  return {
    'id': _id,
    'vehicle_id': _vehicleId,
    'kind': 'ipva',
    'reference_year': 2026,
    'due_on': '2026-03-15',
    'amount_cents': 184237,
    'paid_on': null,
    'paid_amount_cents': null,
    'notes': null,
    'status': status,
    'remaining_days': 200,
    'created_at': '2026-01-10T12:00:00Z',
    'updated_at': '2026-01-10T12:00:00Z',
  };
}

Map<String, dynamic> _seguroJson() {
  return {
    'id': _seguroId,
    'vehicle_id': _vehicleId,
    'insurer_name': 'Porto Seguro',
    'policy_number': '12345',
    'starts_on': '2026-01-10',
    'ends_on': '2027-01-10',
    'premium_cents': 250000,
    'emergency_phone': '0800 727 0800',
    'broker_name': 'Ana',
    'broker_phone': '11999999999',
    'notes': null,
    'status': 'vigente',
    'remaining_days': 136,
    'created_at': '2026-01-10T12:00:00Z',
    'updated_at': '2026-01-10T12:00:00Z',
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
    if (options.data is Map) {
      body = Map<String, dynamic>.from(options.data as Map);
    }
    if (requestStream != null) {
      await requestStream.drain<void>();
    }
    return response ?? _json(500, {});
  }
}
