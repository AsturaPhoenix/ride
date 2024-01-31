import 'package:crypto/crypto.dart';

String computeAssetsVersion(List<int> assetsArchiveData) =>
    md5.convert(assetsArchiveData).toString();
