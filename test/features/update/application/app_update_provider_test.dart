import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/features/update/application/app_update_provider.dart';
import 'package:meu_auto/features/update/data/app_release_repository.dart';

const _apkUrl =
    'https://github.com/simonscabello/meu-auto-app/releases/latest/download/meu-auto.apk';

void main() {
  // The provider listens to the app's lifecycle, which needs a binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  late _VersionAdapter adapter;

  setUp(() => adapter = _VersionAdapter());

  ProviderContainer containerFor({required String? installed}) {
    final api = ApiClient(adapter: adapter, logPrint: (_) {});
    addTearDown(api.close);
    final container = ProviderContainer(
      overrides: [
        installedAppVersionProvider.overrideWithValue(installed),
        appReleaseRepositoryProvider.overrideWith(
          (ref) => AppReleaseRepository(api: api),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a newer published build is offered', () async {
    adapter.body = {'latest_version': '1.2.0', 'apk_url': _apkUrl};

    final release = await containerFor(
      installed: '1.1.0+2',
    ).read(appUpdateProvider.future);

    expect(release?.version, '1.2.0');
    expect(release?.apkUrl, Uri.parse(_apkUrl));
    expect(adapter.requested, hasLength(1));
    expect(adapter.requested.single, endsWith('/app-version'));
  });

  test('the build already installed is not offered again', () async {
    adapter.body = {'latest_version': '1.2.0', 'apk_url': _apkUrl};

    final release = await containerFor(
      installed: '1.2.0+3',
    ).read(appUpdateProvider.future);

    expect(release, isNull);
  });

  test('nothing announced offers nothing', () async {
    adapter.body = {'latest_version': null, 'apk_url': null};

    final release = await containerFor(
      installed: '1.1.0+2',
    ).read(appUpdateProvider.future);

    expect(release, isNull);
  });

  // The notice is an invitation. Not being able to ask for it must never turn
  // into an error on Início.
  test('a failed request is silence, not an error', () async {
    adapter.status = 503;
    adapter.body = {
      'error': {'code': 'internal', 'message': 'Erro interno.'},
    };

    final release = await containerFor(
      installed: '1.1.0+2',
    ).read(appUpdateProvider.future);

    expect(release, isNull);
  });

  // A development build, iOS and the web have no APP_VERSION to compare, and
  // are never told to replace themselves with the published APK.
  test('a build the workflow did not make never asks', () async {
    adapter.body = {'latest_version': '9.9.9', 'apk_url': _apkUrl};

    final release = await containerFor(
      installed: null,
    ).read(appUpdateProvider.future);

    expect(release, isNull);
    expect(adapter.requested, isEmpty);
  });
}

class _VersionAdapter implements HttpClientAdapter {
  int status = 200;
  Map<String, dynamic> body = const {};
  final List<String> requested = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requested.add(options.uri.path);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
