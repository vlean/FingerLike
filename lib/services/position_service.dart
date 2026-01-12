import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/position.dart';

class PositionService {
  static const String _fileName = 'positions.json';
  File? _file;

  Future<File> _getFile() async {
    if (_file != null) return _file!;

    final directory = await getApplicationDocumentsDirectory();
    _file = File('${directory.path}/$_fileName');

    // 如果文件不存在，创建一个空数组
    if (!await _file!.exists()) {
      await _file!.writeAsString('[]');
    }

    return _file!;
  }

  Future<List<Position>> loadPositions() async {
    try {
      final file = await _getFile();
      final String contents = await file.readAsString();

      if (contents.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = jsonDecode(contents);
      return jsonList
          .map((item) => Position.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // 如果出错，返回空列表
      return [];
    }
  }

  Future<void> savePositions(List<Position> positions) async {
    try {
      final file = await _getFile();
      final String json = jsonEncode(
        positions.map((p) => p.toJson()).toList(),
      );
      await file.writeAsString(json);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addPosition(Position position) async {
    final positions = await loadPositions();
    positions.add(position);
    await savePositions(positions);
  }

  Future<void> updatePosition(Position position) async {
    final positions = await loadPositions();
    final index = positions.indexWhere((p) => p.id == position.id);
    if (index != -1) {
      positions[index] = position;
      await savePositions(positions);
    }
  }

  Future<void> deletePosition(String id) async {
    final positions = await loadPositions();
    positions.removeWhere((p) => p.id == id);
    await savePositions(positions);
  }

  Future<bool> aliasExists(String alias, {String? excludeId}) async {
    final positions = await loadPositions();
    return positions.any((p) =>
        p.alias == alias && (excludeId == null || p.id != excludeId));
  }

  Future<Position?> getPositionByAlias(String alias) async {
    final positions = await loadPositions();
    try {
      return positions.firstWhere((p) => p.alias == alias);
    } catch (e) {
      return null;
    }
  }
}
