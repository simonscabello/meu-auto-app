import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/features/update/domain/app_release.dart';

const _apkUrl =
    'https://github.com/simonscabello/meu-auto-app/releases/latest/download/meu-auto.apk';

void main() {
  group('isNewerVersion', () {
    test('a later version or a later build is newer', () {
      expect(isNewerVersion('1.2.0', '1.1.9+30'), isTrue);
      expect(isNewerVersion('1.2.0+8', '1.2.0+7'), isTrue);
      expect(isNewerVersion('2.0.0', '1.99.99+999'), isTrue);
      // Number by number, not letter by letter: "10" comes after "9".
      expect(isNewerVersion('1.10.0', '1.9.0+4'), isTrue);
    });

    // The server may name the version without the build. That must never ask
    // a phone to reinstall what it already has.
    test('the same version is not newer, with or without the build', () {
      expect(isNewerVersion('1.2.0', '1.2.0+7'), isFalse);
      expect(isNewerVersion('1.2.0+7', '1.2.0+7'), isFalse);
      expect(isNewerVersion('1.2.0', '1.2.0'), isFalse);
    });

    test('an older version is not newer', () {
      expect(isNewerVersion('1.1.0', '1.2.0+1'), isFalse);
      expect(isNewerVersion('1.2.0+6', '1.2.0+7'), isFalse);
    });

    test("the tag's v reads as the version", () {
      expect(isNewerVersion('v1.2.0', '1.1.0+2'), isTrue);
    });

    test('anything unreadable invites nobody', () {
      expect(isNewerVersion('latest', '1.0.0+1'), isFalse);
      expect(isNewerVersion('1.2', '1.0.0+1'), isFalse);
      expect(isNewerVersion('2.0.0', ''), isFalse);
      expect(isNewerVersion('99999999999999999999.0.0', '1.0.0'), isFalse);
    });
  });

  group('AppRelease.fromJson', () {
    test('reads an announced release', () {
      final release = AppRelease.fromJson({
        'latest_version': '1.2.0+7',
        'apk_url': _apkUrl,
      });

      expect(release, isNotNull);
      expect(release!.version, '1.2.0+7');
      expect(release.displayVersion, '1.2.0');
      expect(release.apkUrl, Uri.parse(_apkUrl));
    });

    test('nothing announced is no release', () {
      expect(
        AppRelease.fromJson({'latest_version': null, 'apk_url': null}),
        isNull,
      );
      expect(AppRelease.fromJson({}), isNull);
    });

    // A bad value typed on the server becomes no notice, never an error.
    test('what cannot be acted on is no release', () {
      const bad = [
        {'latest_version': '1.2.0', 'apk_url': null},
        {'latest_version': 'latest', 'apk_url': _apkUrl},
        {'latest_version': 120, 'apk_url': _apkUrl},
        {'latest_version': '1.2.0', 'apk_url': 'meu-auto.apk'},
        {'latest_version': '1.2.0', 'apk_url': 'ftp://example.test/a.apk'},
      ];
      for (final json in bad) {
        expect(AppRelease.fromJson(json), isNull, reason: '$json');
      }
    });
  });
}
