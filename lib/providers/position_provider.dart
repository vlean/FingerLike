import 'package:flutter/material.dart';
import '../models/position.dart';
import '../services/position_service.dart';

class PositionProvider with ChangeNotifier {
  final PositionService _positionService = PositionService();

  List<Position> _positions = [];
  Position? _selectedPosition;
  bool _isLoading = false;
  String? _error;

  List<Position> get positions => List.unmodifiable(_positions);
  Position? get selectedPosition => _selectedPosition;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // 加载所有位置
  Future<void> loadPositions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _positions = await _positionService.loadPositions();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // 添加位置
  Future<bool> addPosition(Position position) async {
    // 检查别名是否已存在
    final exists = await _positionService.aliasExists(position.alias);
    if (exists) {
      _error = '别名 "${position.alias}" 已存在';
      notifyListeners();
      return false;
    }

    try {
      await _positionService.addPosition(position);
      _positions.add(position);
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // 更新位置
  Future<bool> updatePosition(Position position) async {
    // 检查别名是否与其他位置冲突
    final exists = await _positionService.aliasExists(
      position.alias,
      excludeId: position.id,
    );
    if (exists) {
      _error = '别名 "${position.alias}" 已存在';
      notifyListeners();
      return false;
    }

    try {
      await _positionService.updatePosition(position);
      final index = _positions.indexWhere((p) => p.id == position.id);
      if (index != -1) {
        _positions[index] = position;
      }
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // 删除位置
  Future<void> deletePosition(String id) async {
    try {
      await _positionService.deletePosition(id);
      _positions.removeWhere((p) => p.id == id);
      if (_selectedPosition?.id == id) {
        _selectedPosition = null;
      }
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // 选择位置
  void selectPosition(Position? position) {
    _selectedPosition = position;
    notifyListeners();
  }

  // 通过别名获取位置
  Future<Position?> getPositionByAlias(String alias) async {
    return await _positionService.getPositionByAlias(alias);
  }

  // 清除错误
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // 生成唯一ID
  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  // 获取下一个可用别名建议
  String getSuggestedAlias(String name) {
    // 将中文名称转换为拼音或简单的字母别名
    final baseAlias = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (baseAlias.isEmpty) return 'pos${_positions.length + 1}';

    // 检查是否已存在
    var suffix = 1;
    var suggestedAlias = baseAlias;
    while (_positions.any((p) => p.alias == suggestedAlias)) {
      suffix++;
      suggestedAlias = '${baseAlias}_$suffix';
    }
    return suggestedAlias;
  }
}
