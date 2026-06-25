import 'dart:io';
import 'package:args/command_runner.dart';
import '../src/commands/setup_command.dart';
import '../src/commands/scan_command.dart';
import '../src/commands/build_command.dart';
import '../src/commands/check_command.dart';

Future<void> main(List<String> args) async {
  final runner = CommandRunner<void>(
    'envified',
    'envified v4 CLI — AES-256-GCM secret management for Flutter.\n'
        'Set ENVIFIED_MASTER_KEY in your environment before running build.',
  )
    ..addCommand(SetupCommand())
    ..addCommand(ScanCommand())
    ..addCommand(BuildCommand())
    ..addCommand(CheckCommand());

  try {
    await runner.run(args);
  } on UsageException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln(e.usage);
    exitCode = 64; // EX_USAGE
  } catch (e) {
    stderr.writeln('Error: $e');
    exitCode = 1;
  }
}
