import 'dart:io';
import 'package:flutter/services.dart';

abstract class ScreenPlatformInterface {
  Future<void> showOverlay(List<PositionMarker> markers);
  Future<void> hideOverlay();
  Future<ScreenSize> getScreenSize();
}

class ScreenService {
  static late final ScreenPlatformInterface _platformImpl;
  static bool _isInitialized = false;

  static void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;
    _platformImpl = _createPlatformImpl();
  }

  static ScreenPlatformInterface _createPlatformImpl() {
    if (Platform.isWindows) {
      return WindowsScreenService();
    } else if (Platform.isMacOS) {
      return MacOSScreenService();
    }
    throw UnsupportedError('当前平台不支持屏幕覆盖层');
  }

  static Future<void> showOverlay(List<PositionMarker> markers) async {
    return _platformImpl.showOverlay(markers);
  }

  static Future<void> hideOverlay() async {
    return _platformImpl.hideOverlay();
  }

  static Future<ScreenSize> getScreenSize() async {
    return _platformImpl.getScreenSize();
  }
}

class WindowsScreenService implements ScreenPlatformInterface {
  static const _channel = MethodChannel('screen_overlay');

  @override
  Future<void> showOverlay(List<PositionMarker> markers) async {
    try {
      final markerData = markers.map((m) => {
        'x': m.x,
        'y': m.y,
        'name': m.name,
      }).toList();

      await _channel.invokeMethod('showOverlay', {'markers': markerData});
    } catch (e) {
      throw Exception('显示覆盖层失败: $e');
    }
  }

  @override
  Future<void> hideOverlay() async {
    try {
      await _channel.invokeMethod('hideOverlay');
    } catch (e) {
      throw Exception('隐藏覆盖层失败: $e');
    }
  }

  @override
  Future<ScreenSize> getScreenSize() async {
    try {
      final result = await _channel.invokeMethod('getScreenSize');
      return ScreenSize(
        width: result['width'] as int,
        height: result['height'] as int,
      );
    } catch (e) {
      // 返回默认值
      return ScreenSize(width: 1920, height: 1080);
    }
  }
}

class MacOSScreenService implements ScreenPlatformInterface {
  @override
  Future<void> showOverlay(List<PositionMarker> markers) async {
    throw UnimplementedError('macOS 覆盖层功能待实现');
  }

  @override
  Future<void> hideOverlay() async {
    throw UnimplementedError('macOS 覆盖层功能待实现');
  }

  @override
  Future<ScreenSize> getScreenSize() async {
    return ScreenSize(width: 1920, height: 1080);
  }
}

class PositionMarker {
  final int x;
  final int y;
  final String name;

  PositionMarker({required this.x, required this.y, required this.name});
}

class ScreenSize {
  final int width;
  final int height;

  ScreenSize({required this.width, required this.height});
}
