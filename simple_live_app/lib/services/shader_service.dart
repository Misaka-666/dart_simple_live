import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:simple_live_app/app/log.dart';

/// 超分着色器服务
///
/// 将内置的 mpv 用户着色器释放到应用数据目录，供 mpv 通过
/// `glsl-shaders` 属性加载（mpv 无法直接读取 Flutter assets）
class ShaderService {
  static const String kAssetPrefix = 'assets/shaders/';
  static const String kShaderDirName = 'shaders';

  /// 着色器版本，更新内置着色器后递增，触发本地重新释放
  static const String kShaderVersion = '1';

  static String? _shaderDir;

  /// 确保着色器已释放到本地，返回着色器目录
  static Future<String> ensureExtracted() async {
    if (_shaderDir != null) return _shaderDir!;

    var supportDir = await getApplicationSupportDirectory();
    var shaderDir = Directory(
      '${supportDir.path}${Platform.pathSeparator}$kShaderDirName',
    );
    if (!await shaderDir.exists()) {
      await shaderDir.create(recursive: true);
    }

    // 版本标记不一致时重新释放，避免升级后本地残留旧着色器
    var versionFile = File(
      '${shaderDir.path}${Platform.pathSeparator}version.txt',
    );
    var versionMatch = false;
    if (await versionFile.exists()) {
      versionMatch = (await versionFile.readAsString()) == kShaderVersion;
    }
    var forceExtract = !versionMatch;

    var manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    var shaderAssets = manifest.listAssets().where(
          (asset) =>
              asset.startsWith(kAssetPrefix) && asset.endsWith('.glsl'),
        );

    var copied = 0;
    for (var asset in shaderAssets) {
      var fileName = asset.substring(kAssetPrefix.length);
      var target = File(
        '${shaderDir.path}${Platform.pathSeparator}$fileName',
      );
      if (!forceExtract && await target.exists()) continue;
      try {
        var data = await rootBundle.load(asset);
        await target.writeAsBytes(data.buffer.asUint8List(), flush: true);
        copied++;
      } catch (e, s) {
        Log.e("释放着色器失败: $asset, $e", s);
      }
    }
    if (forceExtract) {
      await versionFile.writeAsString(kShaderVersion, flush: true);
    }
    if (copied > 0) {
      Log.d("已释放 $copied 个超分着色器到 ${shaderDir.path}");
    }

    _shaderDir = shaderDir.path;
    return _shaderDir!;
  }

  /// FSR 着色器绝对路径
  static Future<String> fsrShaderPath() async {
    var dir = await ensureExtracted();
    return '$dir${Platform.pathSeparator}FSR.glsl';
  }

  /// ArtCNN 着色器绝对路径
  static Future<String> artcnnShaderPath() async {
    var dir = await ensureExtracted();
    return '$dir${Platform.pathSeparator}ArtCNN_C4F32.glsl';
  }
}
