import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/http_server_service.dart';
import 'position_provider.dart';

/// HTTP 服务状态管理
class HttpServerProvider with ChangeNotifier {
  final HttpServerService _serverService = HttpServerService();

  bool _isServerRunning = false;
  int _port = 8080;
  String? _error;
  bool _isLoading = false;

  bool get isServerRunning => _isServerRunning;
  int get port => _port;
  String? get error => _error;
  bool get isLoading => _isLoading;

  // 默认端口
  static const int _defaultPort = 8080;
  static const String _prefPortKey = 'http_server_port';

  /// 初始化设置
  Future<void> initializeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _port = prefs.getInt(_prefPortKey) ?? _defaultPort;
    notifyListeners();
  }

  /// 设置端口
  void setPort(int port) {
    if (port < 1024 || port > 65535) {
      _error = '端口号必须在 1024-65535 之间';
      notifyListeners();
      return;
    }

    _port = port;
    _error = null;

    // 保存端口设置
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt(_prefPortKey, port);
    });

    notifyListeners();
  }

  /// 启动服务器
  Future<bool> startServer(PositionProvider positionProvider) async {
    if (_isServerRunning) {
      _error = '服务已在运行中';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    final success = await _serverService.startServer(
      port: _port,
      positionProvider: positionProvider,
    );

    _isLoading = false;

    if (success) {
      _isServerRunning = true;
      _error = null;
      notifyListeners();
      return true;
    } else {
      _error = '启动服务失败，端口 $_port 可能被占用';
      _isServerRunning = false;
      notifyListeners();
      return false;
    }
  }

  /// 停止服务器
  Future<void> stopServer() async {
    if (!_isServerRunning) return;

    _isLoading = true;
    notifyListeners();

    await _serverService.stopServer();

    _isServerRunning = false;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  /// 切换服务器状态
  Future<bool> toggleServer(PositionProvider positionProvider) async {
    if (_isServerRunning) {
      await stopServer();
      return false;
    } else {
      return await startServer(positionProvider);
    }
  }

  /// 清除错误
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// 获取服务器地址
  String getServerUrl() {
    return 'http://localhost:$_port';
  }

  /// 获取 API 文档
  String getApiDocumentation() {
    return '''
# FingerLike HTTP API

## 基础信息
- 服务器地址: ${getServerUrl()}

## API 端点

### 1. 健康检查
\`\`\`bash
GET /health
\`\`\`

### 2. 获取所有位置
\`\`\`bash
GET /api/positions
\`\`\`

### 3. 根据别名获取位置
\`\`\`bash
GET /api/positions/<alias>
\`\`\`

### 4. 执行点击任务（通用接口）
\`\`\`bash
POST /api/click
Content-Type: application/json

{
  "alias": "login",        # 位置别名（可选）
  "x": 1000,               # X 坐标（可选，与 alias 二选一）
  "y": 500,                # Y 坐标（可选，与 alias 二选一）
  "name": "点击登录",       # 任务名称（可选）
  "repeatCount": 10,       # 重复次数（默认1）
  "intervalMs": 100        # 重复间隔毫秒（默认100）
}
\`\`\`

### 5. 通过别名执行点击
\`\`\`bash
POST /api/click/by-alias
Content-Type: application/json

{
  "alias": "login",
  "repeatCount": 5,
  "intervalMs": 200
}
\`\`\`

### 6. 通过坐标执行点击
\`\`\`bash
POST /api/click/by-coords
Content-Type: application/json

{
  "x": 1000,
  "y": 500,
  "repeatCount": 3,
  "intervalMs": 150
}
\`\`\`

### 7. 获取当前状态
\`\`\`bash
GET /api/status
\`\`\`

## 示例

### 使用 curl 执行点击:
\`\`\`bash
# 通过别名
curl -X POST ${getServerUrl()}/api/click/by-alias \\
  -H "Content-Type: application/json" \\
  -d '{"alias": "login", "repeatCount": 5, "intervalMs": 200}'

# 通过坐标
curl -X POST ${getServerUrl()}/api/click/by-coords \\
  -H "Content-Type: application/json" \\
  -d '{"x": 1000, "y": 500, "repeatCount": 3}'

# 获取所有位置
curl ${getServerUrl()}/api/positions
\`\`\`
''';
  }

  @override
  void dispose() {
    stopServer();
    super.dispose();
  }
}
