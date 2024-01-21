import 'dart:io';

Future<String> run(
  String executable, [
  List<String> arguments = const [],
]) async {
  final result = await Process.run(executable, arguments);
  final stderr = result.stderr as String;
  if (stderr.isNotEmpty) throw stderr;
  if (result.exitCode != 0) throw result.exitCode;
  return result.stdout as String;
}
