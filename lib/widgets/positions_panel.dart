import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/position_provider.dart';
import '../models/position.dart';
import '../services/mouse_service.dart';
import '../l10n/app_localizations.dart';

class PositionsPanel extends StatefulWidget {
  const PositionsPanel({super.key});

  @override
  State<PositionsPanel> createState() => _PositionsPanelState();
}

class _PositionsPanelState extends State<PositionsPanel> {
  @override
  void initState() {
    super.initState();
    // 初始化时加载位置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PositionProvider>(context, listen: false).loadPositions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PositionProvider>(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        // 工具栏
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.get('positionManagement'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showAddPositionDialog(context),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.get('addPosition')),
                  ),
                ],
              ),
            ],
          ),
        ),
        // 错误提示
        if (provider.error != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline,
                    color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    provider.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => provider.clearError(),
                ),
              ],
            ),
          ),
        // 位置列表
        Expanded(
          child: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : provider.positions.isEmpty
                  ? Center(
                      child: Text(l10n.get('noPositions')),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      itemCount: provider.positions.length,
                      itemBuilder: (context, index) {
                        final position = provider.positions[index];
                        return _PositionCard(
                          position: position,
                          onTap: () => _showPositionPreview(context, position),
                          onEdit: () => _showEditPositionDialog(context, position),
                          onDelete: () => _confirmDelete(context, position),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  void _showAddPositionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const PositionEditDialog(),
    );
  }

  void _showEditPositionDialog(BuildContext context, Position position) {
    showDialog(
      context: context,
      builder: (context) => PositionEditDialog(position: position),
    );
  }

  void _showPositionPreview(BuildContext context, Position position) {
    showDialog(
      context: context,
      builder: (context) => PositionPreviewDialog(position: position),
    );
  }

  void _confirmDelete(BuildContext context, Position position) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.get('confirmDelete')),
        content: Text(
          "${l10n.get('deletePositionConfirm')} \"${position.name}\" 吗？",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.get('cancel')),
          ),
          TextButton(
            onPressed: () {
              Provider.of<PositionProvider>(context, listen: false)
                  .deletePosition(position.id);
              Navigator.pop(context);
            },
            child: Text(
              l10n.get('delete'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

// 位置卡片组件
class _PositionCard extends StatelessWidget {
  final Position position;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PositionCard({
    required this.position,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          position.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '别名: ${position.alias}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility, size: 20),
                        onPressed: onTap,
                        tooltip: '查看',
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: onEdit,
                        tooltip: '编辑',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        onPressed: onDelete,
                        tooltip: '删除',
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on,
                      size: 16, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 4),
                  Text(
                    'X: ${position.x}, Y: ${position.y}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 位置编辑对话框
class PositionEditDialog extends StatefulWidget {
  final Position? position;

  const PositionEditDialog({super.key, this.position});

  @override
  State<PositionEditDialog> createState() => _PositionEditDialogState();
}

class _PositionEditDialogState extends State<PositionEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _aliasController;
  late final TextEditingController _xController;
  late final TextEditingController _yController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.position?.name ?? '');
    _aliasController = TextEditingController(text: widget.position?.alias ?? '');
    _xController = TextEditingController(
      text: widget.position?.x.toString() ?? '',
    );
    _yController = TextEditingController(
      text: widget.position?.y.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aliasController.dispose();
    _xController.dispose();
    _yController.dispose();
    super.dispose();
  }

  Future<void> _pickCurrentPosition() async {
    try {
      final currentPos = await MouseService.getCurrentPosition();
      _xController.text = currentPos.x.toInt().toString();
      _yController.text = currentPos.y.toInt().toString();
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取当前位置失败: $e')),
        );
      }
    }
  }

  Future<void> _savePosition() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final provider = Provider.of<PositionProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context);

    final x = int.tryParse(_xController.text);
    final y = int.tryParse(_yController.text);

    if (x == null || y == null) {
      setState(() => _isLoading = false);
      return;
    }

    final position = Position(
      id: widget.position?.id ?? PositionProvider.generateId(),
      name: _nameController.text,
      alias: _aliasController.text,
      x: x,
      y: y,
    );

    final success = widget.position == null
        ? await provider.addPosition(position)
        : await provider.updatePosition(position);

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.position == null
                ? l10n.get('positionAdded')
                : l10n.get('positionUpdated'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(
        widget.position == null
            ? l10n.get('addPosition')
            : l10n.get('editPosition'),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.get('positionName'),
                  hintText: '例如：登录按钮',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.get('enterPositionName');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _aliasController,
                decoration: InputDecoration(
                  labelText: l10n.get('positionAlias'),
                  hintText: '例如：login',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.get('enterPositionAlias');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _xController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'X',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty ||
                            int.tryParse(value) == null) {
                          return '请输入有效的 X 坐标';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _yController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Y',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty ||
                            int.tryParse(value) == null) {
                          return '请输入有效的 Y 坐标';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (Platform.isMacOS || Platform.isWindows)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Tooltip(
                        message: l10n.get('getCurrentPosition'),
                        child: IconButton(
                          icon: const Icon(Icons.my_location),
                          onPressed: _pickCurrentPosition,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text(l10n.get('cancel')),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _savePosition,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.get('save')),
        ),
      ],
    );
  }
}

// 位置预览对话框
class PositionPreviewDialog extends StatefulWidget {
  final Position position;

  const PositionPreviewDialog({super.key, required this.position});

  @override
  State<PositionPreviewDialog> createState() => _PositionPreviewDialogState();
}

class _PositionPreviewDialogState extends State<PositionPreviewDialog> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Dialog(
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.position.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),
            _PositionVisualization(position: widget.position),
            const SizedBox(height: 16),
            Text(
              '别名: ${widget.position.alias}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '坐标: (${widget.position.x}, ${widget.position.y})',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    // 返回编辑对话框
                    showDialog(
                      context: context,
                      builder: (context) => PositionEditDialog(
                        position: widget.position,
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: Text(l10n.get('editPosition')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// 位置可视化组件
class _PositionVisualization extends StatelessWidget {
  final Position position;

  const _PositionVisualization({required this.position});

  @override
  Widget build(BuildContext context) {
    const boxSize = 200.0;
    const targetSize = 40.0;

    return Container(
      width: boxSize,
      height: boxSize,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomPaint(
        painter: _PositionPainter(
          x: position.x.toDouble(),
          y: position.y.toDouble(),
          targetSize: targetSize,
          primaryColor: Theme.of(context).primaryColor,
        ),
        child: Center(
          child: Text(
            '${position.x}, ${position.y}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ),
    );
  }
}

// 绘制位置的画笔
class _PositionPainter extends CustomPainter {
  final double x;
  final double y;
  final double targetSize;
  final Color primaryColor;

  _PositionPainter({
    required this.x,
    required this.y,
    required this.targetSize,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 绘制中心点
    final centerPointPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, centerPointPaint);

    // 绘制方框（目标区域）
    final rectPaint = Paint()
      ..color = primaryColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = Rect.fromCenter(
      center: center,
      width: targetSize,
      height: targetSize,
    );
    canvas.drawRect(rect, rectPaint);

    // 绘制十字线
    final linePaint = Paint()
      ..color = primaryColor.withOpacity(0.5)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx - targetSize / 2 - 10, center.dy),
      Offset(center.dx + targetSize / 2 + 10, center.dy),
      linePaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - targetSize / 2 - 10),
      Offset(center.dx, center.dy + targetSize / 2 + 10),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
