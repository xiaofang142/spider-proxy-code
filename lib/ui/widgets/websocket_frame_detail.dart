import 'package:flutter/material.dart';
import 'websocket_proxy.dart';

/// WebSocket 帧详情组件
///
/// 分级视图展示 WebSocket 帧结构信息
class WebSocketFrameDetailPanel extends StatefulWidget {
  final WebSocketMessage message;

  const WebSocketFrameDetailPanel({
    super.key,
    required this.message,
  });

  @override
  State<WebSocketFrameDetailPanel> createState() => _WebSocketFrameDetailPanelState();
}

class _WebSocketFrameDetailPanelState extends State<WebSocketFrameDetailPanel> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final frame = widget.message.frame;

    if (frame == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 可展开的头部
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.chevron_right,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '帧详情',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 展开的内容
          if (_isExpanded) ..._buildFrameDetails(frame),
        ],
      ),
    );
  }

  List<Widget> _buildFrameDetails(WebSocketFrame frame) {
    return [
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
              'FIN',
              frame.fin ? '1 (最后一片帧)' : '0 (还有后续)',
              Icons.check_circle_outline,
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              'RSV',
              'RSV1=${frame.rsv1} RSV2=${frame.rsv2} RSV3=${frame.rsv3}',
              Icons.settings_outlined,
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              'Opcode',
              '${frame.opcodeText} (0x${frame.opcode.toRadixString(16)})',
              Icons.code,
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              'MASK',
              frame.masked ? '1 (已掩码)' : '0 (未掩码)',
              Icons.security,
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              'Payload Length',
              '${frame.actualPayloadLength} B',
              Icons.data_usage,
            ),
            const SizedBox(height: 8),
            if (frame.isCompressed)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.compress,
                      size: 16,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '已压缩 (RSV1=1)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 8),
    ];
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade900,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}

/// 消息详情对话框（增强版 - 包含帧详情）
void showWebSocketMessageDetail({
  required BuildContext context,
  required WebSocketMessage message,
}) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            Row(
              children: [
                Text(
                  '消息详情',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),

            // 基本信息
            Text(
              '基本信息',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('类型', message.typeText),
                  const SizedBox(height: 4),
                  _buildInfoRow('方向', message.directionText),
                  const SizedBox(height: 4),
                  _buildInfoRow('大小', message.sizeString),
                  const SizedBox(height: 4),
                  _buildInfoRow(
                    '压缩',
                    (message.frame?.isCompressed ?? false) ? '是 ✓' : '否',
                    valueColor: (message.frame?.isCompressed ?? false)
                        ? Colors.green
                        : null,
                  ),
                  const SizedBox(height: 4),
                  _buildInfoRow(
                    '时间',
                    '${message.timestamp.hour.toString().padLeft(2, '0')}:'
                    '${message.timestamp.minute.toString().padLeft(2, '0')}:'
                    '${message.timestamp.second.toString().padLeft(2, '0')}.'
                    '${message.timestamp.millisecond.toString().padLeft(3, '0')}',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 帧详情（如果有）
            if (message.frame != null) ...[
              Text(
                '帧详情',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: WebSocketFrameDetailPanel(message: message),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 消息内容
            Text(
              '消息内容',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    message.payloadString,
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 60,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
      ),
      SizedBox(
        width: 100,
        child: Text(
          ':',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade400,
          ),
        ),
      ),
      Expanded(
        child: Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: valueColor ?? Colors.grey.shade900,
            fontWeight: valueColor != null ? FontWeight.w500 : null,
          ),
        ),
      ),
    ],
  );
}
