import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:envified/envified.dart';

final _urls = {
  Env.dev: 'https://dev.api.appamania.in',
  Env.staging: 'https://staging.api.appamania.in',
  Env.prod: 'https://api.appamania.in',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  final svc = EnvConfigService.instance;

  test('init defaults to dev', () async {
    await svc.init(urls: _urls);
    expect(svc.current.value.env, Env.dev);
    expect(svc.current.value.baseUrl, _urls[Env.dev]);
  });

  test('switchTo changes env and url', () async {
    await svc.init(urls: _urls);
    await svc.switchTo(Env.prod);
    expect(svc.current.value.env, Env.prod);
    expect(svc.current.value.baseUrl, _urls[Env.prod]);
  });

  test('setCustomUrl sets Env.custom', () async {
    await svc.init(urls: _urls);
    await svc.setCustomUrl('https://ngrok.io/test');
    expect(svc.current.value.env, Env.custom);
    expect(svc.current.value.baseUrl, 'https://ngrok.io/test');
  });

  test('reset returns to dev', () async {
    await svc.init(urls: _urls);
    await svc.switchTo(Env.prod);
    await svc.reset();
    expect(svc.current.value.env, Env.dev);
  });
}
