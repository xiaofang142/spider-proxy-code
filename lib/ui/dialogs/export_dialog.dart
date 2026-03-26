import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import '../../main.dart';

/// 导出格式枚举
enum ExportFormat {
  har,
  pcap,
}

/// 导出对话框
class ExportDialog extends StatefulWidget {
  const ExportDialog({super.key});

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  ExportFormat _selectedFormat = ExportFormat.har;
  DateTimeRange? _timeRange;
  bool _selectAll = true;

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, List<CaptureItem>>(
      converter: (store) => store.state.captures,
      builder: (context, captures) {
        final filteredCaptures = _applyTimeFilter(captures);

        return AlertDialog(
          title: const Text('导出抓包数据'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 格式选择
                _buildFormatSelector(),
                const SizedBox(height: 24),
                // 时间范围选择
                _buildTimeRangeSelector(),
                const SizedBox(height: 24),
                // 数据预览
                _buildDataPreview(filteredCaptures.length),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton.icon(
              onPressed: filteredCaptures.isEmpty
                  ? null
                  : () => _export(context, filteredCaptures),
              icon: const Icon(Icons.download),
              label: const Text('导出'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFormatSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '选择格式',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          children: [
            _buildFormatOption(
              ExportFormat.har,
              'HAR',
              'HTTP 存档格式',
              Icons.http,
            ),
            _buildFormatOption(
              ExportFormat.pcap,
              'PCAP',
              '网络抓包格式',
              Icons.folder_shared,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFormatOption(ExportFormat format, String title, String subtitle, IconData icon) {
    final isSelected = _selectedFormat == format;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedFormat = format;
        });
      },
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '时间范围',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    initialDate: _timeRange?.start ?? DateTime.now(),
                  );
                  if (range != null) {
                    setState(() {
                      _timeRange = DateTimeRange(
                        start: range,
                        end: range.add(const Duration(hours: 23, minutes: 59)),
                      );
                    });
                  }
                },
                icon: const Icon(Icons.calendar_today),
                label: Text(_timeRange == null
                    ? '选择日期'
                    : '${_timeRange!.start.month}/${_timeRange!.start.day}'),
              ),
            ),
            if (_timeRange != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  setState(() {
                    _timeRange = null;
                  });
                },
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Checkbox(
              value: _selectAll,
              onChanged: (value) {
                setState(() {
                  _selectAll = value ?? false;
                  if (_selectAll) {
                    _timeRange = null;
                  }
                });
              },
            ),
            const Text('导出全部数据'),
          ],
        ),
      ],
    );
  }

  Widget _buildDataPreview(int count) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              const Text(
                '导出预览',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('将导出 $count 条记录'),
          const SizedBox(height: 4),
          Text(
            '格式：${_selectedFormat == ExportFormat.har ? 'HAR' : 'PCAP'}',
            style: const TextStyle(fontSize: 12),
          ),
          if (_timeRange != null) ...[
            const SizedBox(height: 4),
            Text(
              '时间：${_timeRange!.start.month}/${_timeRange!.start.day} - ${_timeRange!.end.month}/${_timeRange!.end.day}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  List<CaptureItem> _applyTimeFilter(List<CaptureItem> captures) {
    if (_selectAll || _timeRange == null) {
      return captures;
    }

    return captures.where((capture) {
      final timestamp = capture.timestamp;
      return timestamp.isAfter(_timeRange!.start) &&
          timestamp.isBefore(_timeRange!.end);
    }).toList();
  }

  void _export(BuildContext context, List<CaptureItem> captures) {
    Navigator.pop(context, {
      'format': _selectedFormat,
      'captures': captures,
    });
  }
}
