import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:yaml/yaml.dart';

import 'config.dart';
import 'random_cycler.dart';

typedef ImageSource = ImageProvider<Object> Function();

class Slide {
  final String text;
  final ImageSource imageSource;

  Slide(this.text, this.imageSource);
}

Future<List<Slide>> load(Random random, [String? directory]) async {
  directory ??= '${await Config.getAssetsPath()}/greetings';

  final Map<String?, Future<ImageSource>> imageSources = {};

  Future<ImageSource> directoryImageSource(Directory directory) async {
    final ls = await directory.list().toList();
    final cycler = RandomCycler(random, ls.length);
    return () => FileImage(ls[cycler.next()] as File);
  }

  Future<ImageSource> getDefaultImageSource() => imageSources[null] ??=
      directoryImageSource(Directory('$directory/default'));

  Future<ImageSource> getImageSet(String imageSet) => imageSources[imageSet] ??=
      directoryImageSource(Directory('$directory/$imageSet'));

  final yaml = await () async {
    final config = File('$directory/greetings.yaml');
    return loadYaml(await config.readAsString(), sourceUrl: config.uri);
  }();

  return [
    for (final item in yaml as List<dynamic>)
      await () async {
        switch (item) {
          case final String text:
            return Slide(
              text,
              await getDefaultImageSource(),
            );
          case {
              'text': final String text,
              'image set': final String imageSet,
            }:
            return Slide(
              text,
              await getImageSet(imageSet),
            );
          case {
              'text': final String text,
              'image': final String image,
            }:
            return Slide(
              text,
              () => FileImage(File('$directory/$image')),
            );
          default:
            throw FormatException('Could not interpret slide: $item');
        }
      }(),
  ];
}
