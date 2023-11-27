import 'package:flutter/material.dart';

import 'assets.dart';

class Config extends StatefulWidget {
  const Config({super.key});

  @override
  State<StatefulWidget> createState() => ConfigState();
}

class ConfigState extends State {
  Uri? assets;

  @override
  Widget build(BuildContext context) => Assets(
        uri: assets,
        onPick: (uri) => setState(() => assets = uri),
      );
}
