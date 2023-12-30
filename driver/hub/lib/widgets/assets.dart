import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'icons.dart';

class Assets extends StatelessWidget {
  final String? assets;
  final double progress;
  final Object? error;

  final void Function(String)? onPick;

  const Assets({
    super.key,
    this.assets,
    this.progress = 1.0,
    this.error,
    this.onPick,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        leading: assets == null
            ? missingIcon
            : progress == 1.0
                ? (error != null
                    ? Tooltip(message: error.toString(), child: errorIcon)
                    : okIcon)
                : SizedBox.square(
                    dimension: 24.0,
                    child: error != null
                        ? Tooltip(
                            message: error.toString(),
                            child: CircularProgressIndicator(
                              value: progress,
                              color: Colors.red,
                            ),
                          )
                        : CircularProgressIndicator(value: progress),
                  ),
        title: const Text('Assets'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onPick == null || assets == null
                  ? null
                  : () => onPick!(assets!),
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              onPressed: onPick == null
                  ? null
                  : () async {
                      final result = await FilePicker.platform.pickFiles();
                      if (result != null) {
                        onPick!(
                          kIsWeb
                              ? 'fake assets'
                              : result.files.first.identifier!,
                        );
                      }
                    },
              icon: const Icon(Icons.file_open),
            ),
          ],
        ),
      );
}
