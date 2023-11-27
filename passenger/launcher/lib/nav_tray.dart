import 'package:device_apps/device_apps.dart';
import 'package:flutter/material.dart';

import 'parallelogram_border.dart';

class NavTray extends StatefulWidget {
  const NavTray({super.key});

  @override
  State<StatefulWidget> createState() => NavTrayState();
}

class NavTrayState extends State {
  late Future<List<ApplicationWithIcon>> _apps;

  @override
  void initState() {
    super.initState();

    _apps = DeviceApps.getInstalledApplications(
      includeAppIcons: true,
      onlyAppsWithLaunchIntent: true,
    ).then((apps) => apps.cast());
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
        heightFactor: .4,
        child: Material(
          elevation: 1.0,
          color: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
          child: FutureBuilder(
            future: _apps,
            builder: (context, apps) => apps.hasData
                ? GridView.count(
                    crossAxisCount: 2,
                    childAspectRatio: 8,
                    crossAxisSpacing: 24,
                    mainAxisSpacing: 24,
                    padding: const EdgeInsets.all(64),
                    children: [
                      for (final app in apps.data!)
                        NavButton(text: app.appName),
                    ],
                  )
                : const LinearProgressIndicator(),
          ),
        ),
      );
}

class NavButton extends StatelessWidget {
  final String text;
  const NavButton({super.key, required this.text});

  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          shape: const ParallelogramBorder(skew: .4),
        ),
        child: Text(text),
      );
}
