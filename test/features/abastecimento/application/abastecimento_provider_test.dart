import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/core/network/api_paths.dart';
import 'package:meu_auto/features/abastecimento/application/abastecimento_provider.dart';
import 'package:meu_auto/features/abastecimento/data/abastecimento_repository.dart';

void main() {
  late _PagingAdapter adapter;
  late ProviderContainer container;

  setUp(() {
    adapter = _PagingAdapter();
    final api = ApiClient(adapter: adapter, logPrint: (_) {});
    addTearDown(api.close);
    container = ProviderContainer(
      overrides: [
        abastecimentoRepositoryProvider.overrideWith(
          (ref) => AbastecimentoRepository(api: api),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  test('history loads the first page for the vehicle', () async {
    adapter.pages = [
      {
        'data': [_fillJson('a')],
        'next_cursor': 'c1',
      },
    ];

    final state = await container.read(
      abastecimentoHistoryProvider(_vehicleId).future,
    );

    expect(state.items, hasLength(1));
    expect(state.items.single.id, 'a');
    expect(state.hasMore, isTrue);
    expect(adapter.requested, [
      (ApiPaths.vehicleAbastecimentos(_vehicleId), null),
    ]);
  });

  test('loadMore follows the cursor and keeps the first page', () async {
    adapter.pages = [
      {
        'data': [_fillJson('a')],
        'next_cursor': 'c1',
      },
      {
        'data': [_fillJson('b')],
        'next_cursor': null,
      },
    ];

    await container.read(abastecimentoHistoryProvider(_vehicleId).future);
    await container
        .read(abastecimentoHistoryProvider(_vehicleId).notifier)
        .loadMore();

    final state = container.read(abastecimentoHistoryProvider(_vehicleId)).value!;
    expect(state.items.map((fill) => fill.id), ['a', 'b']);
    expect(state.hasMore, isFalse);
    expect(adapter.requested, [
      (ApiPaths.vehicleAbastecimentos(_vehicleId), null),
      (ApiPaths.vehicleAbastecimentos(_vehicleId), 'c1'),
    ]);
  });

  test('invalidating the family refetches', () async {
    adapter.pages = [
      {
        'data': [_fillJson('a')],
        'next_cursor': null,
      },
      {
        'data': [_fillJson('a'), _fillJson('b')],
        'next_cursor': null,
      },
    ];

    await container.read(abastecimentoHistoryProvider(_vehicleId).future);
    container.invalidate(abastecimentoHistoryProvider(_vehicleId));
    final state = await container.read(
      abastecimentoHistoryProvider(_vehicleId).future,
    );

    expect(state.items, hasLength(2));
    expect(adapter.requested, hasLength(2));
  });

  test('get by id hits the member path', () async {
    adapter.member = _fillJson('a');

    final fill = await container.read(abastecimentoProvider('a').future);

    expect(fill.id, 'a');
    expect(adapter.memberGets, [ApiPaths.abastecimento('a')]);
  });
}

const _vehicleId = '22222222-2222-7222-8222-222222222222';

Map<String, dynamic> _fillJson(String id) {
  return {
    'id': id,
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

class _PagingAdapter implements HttpClientAdapter {
  List<Map<String, dynamic>> pages = const [];
  Map<String, dynamic>? member;
  final List<(String, String?)> requested = [];
  final List<String> memberGets = [];
  int _served = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (requestStream != null) {
      await requestStream.drain<void>();
    }
    if (options.method == 'GET' &&
        options.path.contains('/abastecimentos/') &&
        !options.path.contains('/vehicles/')) {
      memberGets.add(options.path);
      return _json(200, member ?? {});
    }
    requested.add((options.path, options.queryParameters['cursor'] as String?));
    final page = pages[_served];
    _served++;
    return _json(200, page);
  }
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
