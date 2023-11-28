import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/server.dart';
import 'icons.dart';

class Server extends StatelessWidget {
  final ServerLifecycleState state;
  final Object? error;

  final TextEditingController? portFieldController;
  final int? connectionCount;
  final void Function()? start;
  final void Function()? stop;
  final void Function(int port)? setPort;

  const Server({
    super.key,
    this.state = ServerLifecycleState.stopped,
    this.error,
    this.portFieldController,
    this.connectionCount,
    this.start,
    this.stop,
    this.setPort,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          ListTile(
            leading: () {
              if (error != null) {
                return Tooltip(
                  message: error!.toString(),
                  child: const {
                        ServerLifecycleState.stopped: errorIcon,
                        ServerLifecycleState.started: warningIcon,
                        ServerLifecycleState.invalid: errorIcon,
                      }[state] ??
                      const SizedBox.square(
                        dimension: 24.0,
                        child: CircularProgressIndicator(),
                      ),
                );
              } else {
                return const {
                      ServerLifecycleState.stopped: missingIcon,
                      ServerLifecycleState.started: okIcon,
                      ServerLifecycleState.invalid: missingIcon,
                    }[state] ??
                    const SizedBox.square(
                      dimension: 24.0,
                      child: CircularProgressIndicator(),
                    );
              }
            }(),
            title: const Text('Server'),
            subtitle: connectionCount == null
                ? const {
                    ServerLifecycleState.stopped: Text('Not started.'),
                    ServerLifecycleState.starting: Text('Starting...'),
                    ServerLifecycleState.stopping: Text('Stopping...'),
                    ServerLifecycleState.invalid: Text('Unknown state.'),
                  }[state]!
                : connectionCount == 0
                    ? const Text('No devices connected')
                    : connectionCount == 1
                        ? const Text('1 device connected.')
                        : Text('$connectionCount devices connected.'),
            trailing: IconButton(
              onPressed: state == ServerLifecycleState.stopped ||
                      state == ServerLifecycleState.invalid
                  ? start
                  : state == ServerLifecycleState.started
                      ? stop
                      : null,
              icon: const {
                ServerLifecycleState.stopped: Icon(Icons.play_arrow),
                ServerLifecycleState.starting: Icon(Icons.stop),
                ServerLifecycleState.started: Icon(Icons.stop),
                ServerLifecycleState.stopping: Icon(Icons.play_arrow),
                ServerLifecycleState.invalid: Icon(Icons.play_arrow),
              }[state]!,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 44.0, top: 8.0, right: 16.0),
            child: TextField(
              controller: portFieldController,
              decoration: const InputDecoration(
                labelText: 'Port',
                border: OutlineInputBorder(),
                // TODO(AsturaPhoenix): Query for hotspot and for deviations
                // from this default address.
                prefixText: '192.168.1.43:',
              ),
              keyboardType: TextInputType.number,
              // TODO(AsturaPhoenix): Validate in [0, 65535].
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              enabled: setPort != null,
              // onSubmitted is a bit too conservative as it doesn't fire if
              // the user backs out of the IME or focuses elsewhere, which can
              // be unintuitive.
              onChanged: setPort == null
                  ? null
                  : (value) => setPort!(int.tryParse(value) ?? 0),
            ),
          ),
        ],
      );
}
