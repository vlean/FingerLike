import 'dart:async';
import 'dart:io';
import 'dart:math';
import '../services/mouse_service.dart';
import '../models/position.dart';

/// 点击任务执行服务
/// 支持按位置或坐标执行点击任务
class ClickExecutorService {
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  /// 执行点击任务
  ///
  /// [position] - 位置对象（包含坐标）
  /// [repeatCount] - 重复次数
  /// [intervalMs] - 重复间隔（毫秒）
  /// [onProgress] - 进度回调 (current, total)
  /// [onComplete] - 完成回调
  /// [onError] - 错误回调
  Future<void> executeClickTask({
    Position? position,
    int? x,
    int? y,
    int repeatCount = 1,
    int intervalMs = 100,
    void Function(int current, int total)? onProgress,
    VoidCallback? onComplete,
    void Function(String error)? onError,
  }) async {
    if (_isRunning) {
      onError?.call('已有任务正在执行中');
      return;
    }

    // 确定坐标
    int targetX;
    int targetY;

    if (position != null) {
      targetX = position.x;
      targetY = position.y;
    } else if (x != null && y != null) {
      targetX = x;
      targetY = y;
    } else {
      onError?.call('未指定有效位置');
      return;
    }

    if (repeatCount <= 0) {
      onError?.call('重复次数必须大于0');
      return;
    }

    _isRunning = true;
    final random = Random();

    try {
      for (int i = 0; i < repeatCount; i++) {
        if (!_isRunning) break;

        try {
          // 执行点击
          final clickPoint = Point(targetX.toDouble(), targetY.toDouble());
          await MouseService.clickAt(clickPoint);

          // 通知进度
          onProgress?.call(i + 1, repeatCount);

          // 如果不是最后一次点击，等待间隔时间
          if (i < repeatCount - 1) {
            // 添加少量随机延迟，模拟真实点击
            final variation = random.nextInt(20) - 10;
            await Future.delayed(
              Duration(milliseconds: intervalMs + variation),
            );
          }
        } on ClickException catch (e) {
          onError?.call('点击失败: ${e.message}');
          break;
        }
      }

      if (_isRunning) {
        onComplete?.call();
      }
    } finally {
      _isRunning = false;
    }
  }

  /// 取消当前任务
  void cancelTask() {
    _isRunning = false;
  }
}
