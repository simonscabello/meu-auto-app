import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/core/network/api_error_code.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_paths.dart';
import 'package:meu_auto/features/maintenance/data/maintenance_plan_repository.dart';

void main() {
  late _RecordingAdapter adapter;
  late MaintenancePlanRepository repo;

  setUp(() {
    adapter = _RecordingAdapter();
    final api = ApiClient(adapter: adapter, logPrint: (_) {});
    addTearDown(api.close);
    repo = MaintenancePlanRepository(api: api);
  });

  test('get hits the member path', () async {
    adapter.enqueue(_json(200, _planJson()));

    final plan = await repo.get(_planId);

    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.method, 'GET');
    expect(adapter.requests.single.path, ApiPaths.maintenancePlan(_planId));
    expect(plan.id, _planId);
    expect(plan.itemName, 'Troca de óleo do motor');
  });

  test('getWithFallback uses the member and does not list', () async {
    adapter.enqueue(_json(200, _planJson()));

    final plan = await repo.getWithFallback(
      planId: _planId,
      vehicleId: _vehicleId,
    );

    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.path, ApiPaths.maintenancePlan(_planId));
    expect(plan.id, _planId);
  });

  test('getWithFallback falls back to the list on 404', () async {
    adapter.enqueue(
      _json(404, {
        'error': {'code': 'not_found', 'message': 'Não encontrado.'},
      }),
    );
    adapter.enqueue(
      _json(200, {
        'data': [_planJson()],
      }),
    );

    final plan = await repo.getWithFallback(
      planId: _planId,
      vehicleId: _vehicleId,
    );

    expect(adapter.requests, hasLength(2));
    expect(adapter.requests[0].path, ApiPaths.maintenancePlan(_planId));
    expect(
      adapter.requests[1].path,
      ApiPaths.vehicleMaintenancePlans(_vehicleId),
    );
    expect(plan.id, _planId);
  });

  test('getWithFallback rethrows a 404 that the list also lacks', () async {
    adapter.enqueue(
      _json(404, {
        'error': {'code': 'not_found', 'message': 'Não encontrado.'},
      }),
    );
    adapter.enqueue(_json(200, {'data': <Map<String, dynamic>>[]}));

    try {
      await repo.getWithFallback(planId: _planId, vehicleId: _vehicleId);
      fail('expected ApiFailure');
    } on ApiFailure catch (failure) {
      expect(failure.code, ApiErrorCode.notFound);
    }
  });
}

const _planId = 'aaaaaaaa-aaaa-7aaa-8aaa-aaaaaaaaaaaa';
const _vehicleId = '22222222-2222-7222-8222-222222222222';

Map<String, dynamic> _planJson() {
  return jsonDecode(
        File('test/fixtures/maintenance_plans_list.json').readAsStringSync(),
      )['data']
      .first as Map<String, dynamic>;
}

ResponseBody _json(int status, Object body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

final class _Request {
  const _Request({required this.method, required this.path});

  final String method;
  final String path;
}

class _RecordingAdapter implements HttpClientAdapter {
  final List<ResponseBody> _responses = [];
  final List<_Request> requests = [];

  void enqueue(ResponseBody response) => _responses.add(response);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(_Request(method: options.method, path: options.path));
    if (requestStream != null) {
      await requestStream.drain<void>();
    }
    if (_responses.isEmpty) {
      return _json(500, {
        'error': {'code': 'internal', 'message': 'no response queued'},
      });
    }
    return _responses.removeAt(0);
  }
}
