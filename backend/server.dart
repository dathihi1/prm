import 'dart:io';

import 'facebook_auth_server.dart';

Future<void> main(List<String> arguments) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final server = FacebookAuthServer();
  await server.start(port: port);
  stdout.writeln('Demo auth backend: http://0.0.0.0:${server.port}');
  stdout.writeln('Facebook: ${server.account} / ${server.password}');
  stdout.writeln(
    'Instagram: ${server.instagramAccount} / ${server.instagramPassword}',
  );

  ProcessSignal.sigint.watch().listen((_) async {
    await server.close();
    exit(0);
  });
}
