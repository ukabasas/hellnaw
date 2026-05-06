import 'dart:js_interop';

import 'package:flutter/foundation.dart';

@JS('nova3dModelCache.store')
external JSPromise<JSString?> _storeModel(JSString src);

@JS('nova3dModelCache.revoke')
external void _revokeObjectUrl(JSString src);

class GlbAssetCache {
  const GlbAssetCache._();

  static Future<String> resolve(String src) async {
    if (!kIsWeb || src.startsWith('assets/')) return src;

    try {
      final resolved = await _storeModel(src.toJS).toDart;
      return resolved?.toDart ?? src;
    } catch (_) {
      return src;
    }
  }

  static void revoke(String src) {
    if (!kIsWeb || !src.startsWith('blob:')) return;

    try {
      _revokeObjectUrl(src.toJS);
    } catch (_) {}
  }
}
