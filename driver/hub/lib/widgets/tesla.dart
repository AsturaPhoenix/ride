import 'package:flutter/material.dart';
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:webview_flutter/webview_flutter.dart';

import '../core/tesla.dart' as tesla;
import 'icons.dart';

class Tesla extends StatefulWidget {
  final tesla.Client? client;
  final int? vehicleId;
  final Object? error;
  final void Function(oauth2.Credentials? cedentials) setCredentials;
  final void Function(int vehicleId) setVehicle;

  const Tesla({
    super.key,
    this.client,
    this.vehicleId,
    this.error,
    required this.setCredentials,
    required this.setVehicle,
  });

  bool get hasCredentials => client != null;

  @override
  State<Tesla> createState() => _TeslaState();
}

class _TeslaState extends State<Tesla> {
  oauth2.AuthorizationCodeGrant? grant;

  WebViewController? webViewController;
  bool busy = false;
  Object? authError;
  Object? get error => authError ?? widget.error;

  final _pages = <int, Future<List<tesla.Vehicle>>>{};
  int? _pageSize, _vehicleCount;

  @override
  void didUpdateWidget(covariant Tesla oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.client != oldWidget.client) {
      if (widget.client != null) {
        busy = false;
      }
      _pages.clear();
    }
  }

  void auth() {
    grant = oauth2.AuthorizationCodeGrant(
      tesla.clientId,
      tesla.authEndpoint,
      tesla.tokenEndpoint,
      // Since we'll mostly be using the API client from the background server,
      // there's no need to set a credential refresh handler here.
    );

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (navReq) {
            if (navReq.url.startsWith(tesla.authRedirectUrl)) {
              setState(() {
                busy = true;
                webViewController = null;
              });

              () async {
                try {
                  final responseUrl = Uri.parse(navReq.url);
                  final client = await grant!.handleAuthorizationResponse(
                    responseUrl.queryParameters,
                  );
                  // We'll be using the client from the background server. We
                  // shouldn't use the oauth credentials directly from here
                  // because credential refreshes need to happen with a single
                  // source of truth.
                  client.close();

                  if (mounted) {
                    widget.setCredentials(client.credentials);
                  } else {
                    client.close();
                  }
                  // busy will be set to false in didUpdateWidget
                } catch (e) {
                  if (mounted) {
                    setState(() {
                      authError = e;
                      busy = false;
                    });
                  }
                }
              }();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(
        grant!.getAuthorizationUrl(
          Uri.parse(tesla.authRedirectUrl),
          scopes: tesla.authScopes,
        ),
      );

    setState(() {
      authError = null;
      webViewController = controller;
    });
  }

  void cancel() {
    grant!.close();
    grant = null;
    setState(() => webViewController = null);
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          ListTile(
            leading: busy
                ? const SizedBox.square(
                    dimension: 24.0,
                    child: CircularProgressIndicator(),
                  )
                : !widget.hasCredentials
                    ? missingIcon
                    : error != null
                        ? errorIcon
                        : okIcon,
            title: const Text('Tesla'),
            subtitle: error == null ? null : Text(error.toString()),
            trailing: IconButton(
              onPressed: () {
                if (widget.hasCredentials) {
                  widget.setCredentials(null);
                  // TODO: logout
                  // https://github.com/timdorr/tesla-api/discussions/311
                } else if (webViewController == null) {
                  auth();
                } else {
                  cancel();
                }
              },
              icon: widget.hasCredentials
                  ? const Tooltip(
                      message: 'Sign out',
                      child: Icon(Icons.logout),
                    )
                  : webViewController == null
                      ? const Tooltip(
                          message: 'Sign in',
                          child: Icon(Icons.login),
                        )
                      : const Tooltip(
                          message: 'Cancel',
                          child: Icon(Icons.block),
                        ),
            ),
          ),
          if (webViewController != null)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8.0, 0.0, 8.0, 8.0),
                child: WebViewWidget(controller: webViewController!),
              ),
            ),
          if (widget.client != null)
            AspectRatio(
              aspectRatio: 3,
              child: ListView.builder(
                itemCount: _vehicleCount,
                itemBuilder: (context, i) {
                  final page = _pageSize == null ? 0 : i ~/ _pageSize!;
                  return FutureBuilder(
                    future: _pages[page] ??= () async {
                      final client = widget.client;
                      // For now, always evict. We might consider making this an LRU
                      // cache of size 2. Don't bother setStateing right now.
                      _pages.clear();
                      final (vehicles, count) =
                          await widget.client!.vehicles(page: page + 1);
                      if (mounted && widget.client == client) {
                        if (vehicles.length < count && page == 0) {
                          _pageSize = vehicles.length;
                        }
                        setState(() => _vehicleCount = count);

                        if (widget.vehicleId == null && vehicles.isNotEmpty) {
                          widget.setVehicle(vehicles.first.id);
                        }
                      }
                      return vehicles;
                    }(),
                    builder: (context, vehicles) {
                      if (vehicles.hasData) {
                        final vehicle =
                            vehicles.data![page == 0 ? i : i % _pageSize!];
                        return ListTile(
                          title:
                              Text(vehicle.displayName ?? (i + 1).toString()),
                          subtitle: Text(vehicle.vin ?? ''),
                          selected: vehicle.id == widget.vehicleId,
                          onTap: () => widget.setVehicle(vehicle.id),
                        );
                      } else if (vehicles.hasError) {
                        return ListTile(title: Text(vehicles.error.toString()));
                      } else {
                        return const ListTile(title: LinearProgressIndicator());
                      }
                    },
                  );
                },
              ),
            ),
        ],
      );
}
