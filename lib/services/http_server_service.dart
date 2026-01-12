import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import '../models/position.dart';
import '../services/click_executor_service.dart';
import '../providers/position_provider.dart';

/// HTTP API 服务
/// 提供远程调用点击功能的 REST API
class HttpServerService {
  HttpServer? _server;
  int? _port;
  final ClickExecutorService _clickExecutor = ClickExecutorService();

  bool get isRunning => _server != null;
  int? get port => _port;

  /// 启动 HTTP 服务器
  Future<bool> startServer({
    required int port,
    required PositionProvider positionProvider,
  }) async {
    if (_server != null) {
      return false;
    }

    try {
      final router = Router();

      // 获取健康状态
      router.get('/health', (Request request) {
        return Response.ok(
          jsonEncode({'status': 'ok', 'service': 'FingerLike HTTP API'}),
          headers: {'Content-Type': 'application/json'},
        );
      });

      // 获取所有位置
      router.get('/api/positions', (Request request) {
        final positions = positionProvider.positions;
        final data = positions.map((p) => p.toJson()).toList();
        return Response.ok(
          jsonEncode({'success': true, 'data': data}),
          headers: {'Content-Type': 'application/json'},
        );
      });

      // 根据别名获取位置
      router.get('/api/positions/<alias>', (Request request) {
        final alias = request.params['alias'];
        final position = positionProvider.positions
            .where((p) => p.alias == alias)
            .firstOrNull;

        if (position == null) {
          return Response.notFound(
            jsonEncode({'success': false, 'message': '位置不存在'}),
            headers: {'Content-Type': 'application/json'},
          );
        }

        return Response.ok(
          jsonEncode({'success': true, 'data': position.toJson()}),
          headers: {'Content-Type': 'application/json'},
        );
      });

      // 执行点击任务（通过别名）
      router.post('/api/click/by-alias', (Request request) async {
        try {
          final body = await request.readAsString();
          final data = jsonDecode(body);

          final alias = data['alias'] as String?;
          final repeatCount = data['repeatCount'] as int? ?? 1;
          final intervalMs = data['intervalMs'] as int? ?? 100;

          if (alias == null || alias.isEmpty) {
            return Response.badRequest(
              body: jsonEncode({'success': false, 'message': '别名不能为空'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          final position = positionProvider.positions
              .where((p) => p.alias == alias)
              .firstOrNull;

          if (position == null) {
            return Response.notFound(
              jsonEncode({'success': false, 'message': '位置不存在: $alias'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          // 异步执行点击任务
          _executeClick(
            position: position,
            repeatCount: repeatCount,
            intervalMs: intervalMs,
          );

          return Response.ok(
            jsonEncode({
              'success': true,
              'message': '点击任务已开始',
              'data': {
                'position': position.name,
                'alias': position.alias,
                'x': position.x,
                'y': position.y,
                'repeatCount': repeatCount,
                'intervalMs': intervalMs,
              },
            }),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e) {
          return Response.badRequest(
            body: jsonEncode({'success': false, 'message': '请求格式错误: $e'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      });

      // 执行点击任务（通过坐标）
      router.post('/api/click/by-coords', (Request request) async {
        try {
          final body = await request.readAsString();
          final data = jsonDecode(body);

          final x = data['x'] as int?;
          final y = data['y'] as int?;
          final repeatCount = data['repeatCount'] as int? ?? 1;
          final intervalMs = data['intervalMs'] as int? ?? 100;

          if (x == null || y == null) {
            return Response.badRequest(
              body: jsonEncode({'success': false, 'message': '坐标不能为空'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          // 异步执行点击任务
          _executeClick(
            x: x,
            y: y,
            repeatCount: repeatCount,
            intervalMs: intervalMs,
          );

          return Response.ok(
            jsonEncode({
              'success': true,
              'message': '点击任务已开始',
              'data': {
                'x': x,
                'y': y,
                'repeatCount': repeatCount,
                'intervalMs': intervalMs,
              },
            }),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e) {
          return Response.badRequest(
            body: jsonEncode({'success': false, 'message': '请求格式错误: $e'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      });

      // 执行点击任务（通用接口，支持别名或坐标）
      router.post('/api/click', (Request request) async {
        try {
          final body = await request.readAsString();
          final data = jsonDecode(body);

          final alias = data['alias'] as String?;
          final x = data['x'] as int?;
          final y = data['y'] as int?;
          final name = data['name'] as String?;
          final repeatCount = data['repeatCount'] as int? ?? 1;
          final intervalMs = data['intervalMs'] as int? ?? 100;

          Position? position;
          int? targetX;
          int? targetY;

          // 优先使用别名查找位置
          if (alias != null && alias.isNotEmpty) {
            position = positionProvider.positions
                .where((p) => p.alias == alias)
                .firstOrNull;

            if (position == null) {
              return Response.notFound(
                jsonEncode({'success': false, 'message': '位置不存在: $alias'}),
                headers: {'Content-Type': 'application/json'},
              );
            }

            targetX = position.x;
            targetY = position.y;
          } else if (x != null && y != null) {
            targetX = x;
            targetY = y;
          } else {
            return Response.badRequest(
              body: jsonEncode({
                'success': false,
                'message': '必须指定别名(alias)或坐标(x,y)',
              }),
              headers: {'Content-Type': 'application/json'},
            );
          }

          // 异步执行点击任务
          _executeClick(
            position: position,
            x: targetX,
            y: targetY,
            repeatCount: repeatCount,
            intervalMs: intervalMs,
            taskName: name ?? position?.name ?? '自定义位置',
          );

          return Response.ok(
            jsonEncode({
              'success': true,
              'message': '点击任务已开始',
              'data': {
                'name': name ?? position?.name ?? '自定义位置',
                'alias': position?.alias,
                'x': targetX,
                'y': targetY,
                'repeatCount': repeatCount,
                'intervalMs': intervalMs,
              },
            }),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e) {
          return Response.badRequest(
            body: jsonEncode({'success': false, 'message': '请求格式错误: $e'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      });

      // 获取当前点击状态
      router.get('/api/status', (Request request) {
        return Response.ok(
          jsonEncode({
            'success': true,
            'data': {
              'isRunning': _clickExecutor.isRunning,
              'serverPort': _port,
            },
          }),
          headers: {'Content-Type': 'application/json'},
        );
      });

      // 创建处理器
      final handler = const Pipeline().addHandler(router.call);

      // 启动服务器
      _server = await serve(handler, InternetAddress.anyIPv4, port);
      _port = port;

      return true;
    } catch (e) {
      return false;
    }
  }

  /// 异步执行点击任务
  void _executeClick({
    Position? position,
    int? x,
    int? y,
    int repeatCount = 1,
    int intervalMs = 100,
    String? taskName,
  }) {
    _clickExecutor.executeClickTask(
      position: position,
      x: x,
      y: y,
      repeatCount: repeatCount,
      intervalMs: intervalMs,
      onProgress: (current, total) {
        // 可以在这里添加日志或通知
        print('[HTTP API] 点击进度: $current/$total');
      },
      onComplete: () {
        print('[HTTP API] 任务完成: $taskName');
      },
      onError: (error) {
        print('[HTTP API] 任务错误: $error');
      },
    );
  }

  /// 停止服务器
  Future<void> stopServer() async {
    _clickExecutor.cancelTask();
    if (_server != null) {
      await _server!.close();
      _server = null;
      _port = null;
    }
  }
}
