import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/core/push/push_registration.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/push_fakes.dart';

/// Which phone an account's reminders go to. Every call is best-effort: a
/// phone not reminded is a smaller failure than a sign-in, a sign-out or a
/// switch that breaks.
void main() {
  late FakePushDevice device;
  late DeviceApi server;
  late MemoryPushOptOut optOut;
  late PushRegistration registration;

  setUp(() async {
    device = FakePushDevice();
    await device.init();
    server = DeviceApi();
    optOut = MemoryPushOptOut();
    final api = ApiClient(adapter: server, logPrint: (_) {});
    addTearDown(api.close);
    registration = PushRegistration(api: api, device: device, optOut: optOut);
  });

  test('registers this phone as an Android one', () async {
    await registration.register('u1');

    expect(server.registrations.single.body, {
      'token': 'token-1',
      'platform': 'android',
    });
  });

  test('a phone the owner turned off is not registered again', () async {
    optOut.optedOut.add('u1');

    await registration.register('u1');
    await registration.send('u1', 'rotated');

    expect(server.requests, isEmpty);
  });

  test('without push there is nothing to register or forget', () async {
    device.firebase = false;

    await registration.register('u1');
    await registration.forgetThisDevice();

    expect(server.requests, isEmpty);
    expect(device.tokenDeletions, 0);
  });

  test('signing out forgets the phone and retires its token', () async {
    await registration.forgetThisDevice();

    expect(server.forgets.single.body, {'token': 'token-1'});
    // Even when the request above finds no signal, a retired token makes the
    // server forget the phone on its next send.
    expect(device.tokenDeletions, 1);
  });

  test('no signal never breaks a sign-out or a sign-in', () async {
    server.fail = true;

    await registration.register('u1');
    await registration.forgetThisDevice();

    expect(device.tokenDeletions, 1);
  });

  test('the switch: off forgets and stays off; on registers again', () async {
    await registration.setEnabled('u1', enabled: false);
    expect(await registration.isEnabled('u1'), isFalse);
    expect(server.forgets, hasLength(1));

    await registration.register('u1');
    expect(server.registrations, isEmpty, reason: 'off holds at sign-in');

    await registration.setEnabled('u1', enabled: true);
    expect(await registration.isEnabled('u1'), isTrue);
    expect(server.registrations, hasLength(1));
  });

  test('one account’s "off" is not another’s', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesPushOptOut();

    await store.setOptedOut('ana', optedOut: true);

    expect(await store.isOptedOut('ana'), isTrue);
    expect(await store.isOptedOut('bia'), isFalse);
    await store.setOptedOut('ana', optedOut: false);
    expect(await store.isOptedOut('ana'), isFalse);
  });
}
