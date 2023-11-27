import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class Assets extends StatelessWidget {
  static const okIcon = Icon(Icons.check, color: Colors.green),
      missingIcon = Icon(Icons.cancel, color: Colors.red),
      errorIcon = Icon(Icons.error, color: Colors.red);

  final Uri? uri;
  final double progress;
  final Object? error;

  final void Function(Uri)? onPick;

  const Assets({
    super.key,
    this.uri,
    this.progress = 1.0,
    this.error,
    this.onPick,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        leading: uri == null
            ? missingIcon
            : progress == 1.0
                ? (error != null
                    ? Tooltip(message: error.toString(), child: errorIcon)
                    : okIcon)
                : error != null
                    ? Tooltip(
                        message: error.toString(),
                        child: CircularProgressIndicator(
                          value: progress,
                          color: Colors.red,
                        ),
                      )
                    : CircularProgressIndicator(value: progress),
        title: const Text('Assets'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed:
                  onPick == null || uri == null ? null : () => onPick!(uri!),
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              onPressed: onPick == null
                  ? null
                  : () async {
                      final result = await FilePicker.platform.pickFiles();
                      if (result != null) {
                        onPick!(Uri.parse(result.files.first.identifier!));
                      }
                    },
              icon: const Icon(Icons.file_open),
            ),
          ],
        ),
      );
}
