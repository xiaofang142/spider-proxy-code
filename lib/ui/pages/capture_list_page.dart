import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import '../../main.dart';
import '../../core/proxy_service.dart';
import 'request_detail_page.dart';

class CaptureListPage extends StatefulWidget {
  final ProxyServiceManager proxyService;

  const CaptureListPage({super.key, required this.proxyService});

  @override
  State<CaptureListPage> createState() => _CaptureListPageState();
}

class _CaptureListPageState extends State<CaptureListPage> {
  String _filterText = '';
  String? _filterMethod;
  int? _filterStatusCode;
  String? _filterDomain;
  DateTimeRange? _filterTimeRange;
  bool _useRegex = false;
  List<String> _searchHistory = [];
  bool _showHistory = false;

  // 搜索历史管理
  static const String _historyKey = 'capture_search_history';
  static const int _maxHistoryItems = 10;

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
  }

  Future<void> _loadSearchHistory() async {
    // 简化实现：仅内存存储
    setState(() {});
  }

  void _addToHistory(String query) {
    if (query.isEmpty) return;
    setState(() {
      _searchHistory.remove(query);
      _searchHistory.insert(0, query);
      if (_searchHistory.length > _maxHistoryItems) {
        _searchHistory = _searchHistory.sublist(0, _maxHistoryItems);
      }
    });
  }

  void _clearHistory() {
    setState(() {
      _searchHistory.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('抓包列表'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmClearCaptures(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          _buildSearchBar(),
          // 抓包列表
          Expanded(
            child: StoreConnector<AppState, List<CaptureItem>>(
              converter: (store) => store.state.captures,
              builder: (context, captures) {
                // 应用过滤
                final filteredCaptures = _applyFilters(captures);

                if (filteredCaptures.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          '暂无抓包数据',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '启动代理后，网络请求将显示在此处',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filteredCaptures.length,
                  itemBuilder: (context, index) {
                    final capture = filteredCaptures[filteredCaptures.length - 1 - index];
                    return _CaptureListItem(
                      capture: capture,
                      onTap: () => _navigateToDetail(context, capture),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: '搜索 URL、主机、路径...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      _useRegex ? Icons.regex : Icons.text_fields,
                      size: 20,
                    ),
                    tooltip: _useRegex ? '正则表达式模式' : '普通搜索模式',
                    onPressed: () {
                      setState(() {
                        _useRegex = !_useRegex;
                      });
                    },
                  ),
                  if (_searchHistory.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.history, size: 20),
                      tooltip: '搜索历史',
                      onPressed: () {
                        setState(() {
                          _showHistory = !_showHistory;
                        });
                      },
                    ),
                ],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              setState(() => _filterText = value);
              if (value.isNotEmpty) {
                _addToHistory(value);
              }
            },
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                _addToHistory(value);
              }
              setState(() {
                _showHistory = false;
              });
            },
          ),
        ),
        // 搜索历史下拉
        if (_showHistory && _searchHistory.isNotEmpty) _buildSearchHistory(),
        // 活跃过滤条件显示
        _buildActiveFilters(),
      ],
    );
  }

  Widget _buildSearchHistory() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _searchHistory.map((item) {
          return Chip(
            label: Text(item, style: const TextStyle(fontSize: 12)),
            deleteIcon: const Icon(Icons.close, size: 16),
            onDeleted: () {
              setState(() {
                _searchHistory.remove(item);
              });
            },
            avatar: const Icon(Icons.history, size: 16),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActiveFilters() {
    final hasFilters = _filterMethod != null ||
        _filterStatusCode != null ||
        _filterDomain != null ||
        _filterTimeRange != null;

    if (!hasFilters) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          if (_filterMethod != null)
            Chip(
              label: Text('方法：$_filterMethod', style: const TextStyle(fontSize: 12)),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () => setState(() => _filterMethod = null),
            ),
          if (_filterStatusCode != null)
            Chip(
              label: Text('状态：$_filterStatusCode', style: const TextStyle(fontSize: 12)),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () => setState(() => _filterStatusCode = null),
            ),
          if (_filterDomain != null)
            Chip(
              label: Text('域名：$_filterDomain', style: const TextStyle(fontSize: 12)),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () => setState(() => _filterDomain = null),
            ),
          if (_filterTimeRange != null)
            Chip(
              label: Text(
                '时间：${_filterTimeRange!.start.month}/${_filterTimeRange!.start.day} - ${_filterTimeRange!.end.month}/${_filterTimeRange!.end.day}',
                style: const TextStyle(fontSize: 12),
              ),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () => setState(() => _filterTimeRange = null),
            ),
        ],
      ),
    );
  }

  List<CaptureItem> _applyFilters(List<CaptureItem> captures) {
    return captures.where((capture) {
      // 文本搜索（支持正则）
      if (_filterText.isNotEmpty) {
        bool matchesSearch = false;
        final searchText = _filterText.toLowerCase();
        final urlToSearch = capture.url.toLowerCase();
        final methodToSearch = capture.method.toLowerCase();

        try {
          if (_useRegex) {
            final regex = RegExp(_filterText, caseSensitive: false);
            matchesSearch = regex.hasMatch(urlToSearch) || regex.hasMatch(methodToSearch);
          } else {
            matchesSearch = urlToSearch.contains(searchText) || methodToSearch.contains(searchText);
          }
        } catch (e) {
          // 正则表达式无效，回退到普通搜索
          matchesSearch = urlToSearch.contains(searchText) || methodToSearch.contains(searchText);
        }

        if (!matchesSearch) {
          return false;
        }
      }

      // 域名过滤
      if (_filterDomain != null && _filterDomain!.isNotEmpty) {
        final domainToSearch = capture.url.toLowerCase();
        if (!domainToSearch.contains(_filterDomain!.toLowerCase())) {
          return false;
        }
      }

      // 方法过滤
      if (_filterMethod != null && capture.method != _filterMethod) {
        return false;
      }

      // 状态码过滤
      if (_filterStatusCode != null) {
        final statusGroup = (capture.statusCode ~/ 100);
        final filterGroup = (_filterStatusCode! ~/ 100);
        if (statusGroup != filterGroup) {
          return false;
        }
      }

      // 时间范围过滤
      if (_filterTimeRange != null) {
        final timestamp = capture.timestamp;
        final startTime = _filterTimeRange!.start;
        final endTime = _filterTimeRange!.end;

        // 将时间戳转换为 DateTime 进行比较
        final captureDate = DateTime.fromMillisecondsSinceEpoch(timestamp);

        // 检查是否在时间范围内
        if (captureDate.isBefore(startTime) || captureDate.isAfter(endTime)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('过滤条件'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 域名过滤
                TextFormField(
                  initialValue: _filterDomain ?? '',
                  decoration: const InputDecoration(
                    labelText: '域名过滤',
                    hintText: 'example.com',
                    helperText: '包含指定域名的请求',
                  ),
                  onChanged: (value) {
                    setDialogState(() {});
                  },
                  onFieldSubmitted: (value) {
                    setState(() => _filterDomain = value.isEmpty ? null : value);
                  },
                ),
                const SizedBox(height: 16),
                // 方法过滤
                DropdownButtonFormField<String>(
                  value: _filterMethod,
                  decoration: const InputDecoration(labelText: '请求方法'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('全部')),
                    const DropdownMenuItem(value: 'GET', child: Text('GET')),
                    const DropdownMenuItem(value: 'POST', child: Text('POST')),
                    const DropdownMenuItem(value: 'PUT', child: Text('PUT')),
                    const DropdownMenuItem(value: 'DELETE', child: Text('DELETE')),
                    const DropdownMenuItem(value: 'PATCH', child: Text('PATCH')),
                    const DropdownMenuItem(value: 'HEAD', child: Text('HEAD')),
                    const DropdownMenuItem(value: 'OPTIONS', child: Text('OPTIONS')),
                  ],
                  onChanged: (value) {
                    setDialogState(() => _filterMethod = value);
                  },
                ),
                const SizedBox(height: 16),
                // 状态码过滤
                DropdownButtonFormField<int>(
                  value: _filterStatusCode,
                  decoration: const InputDecoration(labelText: '状态码'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('全部')),
                    const DropdownMenuItem(value: 200, child: Text('2xx 成功')),
                    const DropdownMenuItem(value: 300, child: Text('3xx 重定向')),
                    const DropdownMenuItem(value: 400, child: Text('4xx 客户端错误')),
                    const DropdownMenuItem(value: 500, child: Text('5xx 服务器错误')),
                  ],
                  onChanged: (value) {
                    setDialogState(() => _filterStatusCode = value);
                  },
                ),
                const SizedBox(height: 16),
                // 时间范围过滤
                ElevatedButton.icon(
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      initialDate: _filterTimeRange?.start ?? DateTime.now(),
                    );
                    if (picked != null) {
                      final endPicked = await showDateRangePicker(
                        context: context,
                        firstDate: picked,
                        lastDate: DateTime(2030),
                        initialDate: _filterTimeRange?.end ?? DateTime.now(),
                      );
                      if (endPicked != null) {
                        setState(() {
                          _filterTimeRange = DateTimeRange(start: picked, end: endPicked);
                        });
                      }
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(_filterTimeRange == null
                      ? '选择时间范围'
                      : '已选择：${_filterTimeRange!.start.month}/${_filterTimeRange!.start.day} - ${_filterTimeRange!.end.month}/${_filterTimeRange!.end.day}'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _filterText = '';
                  _filterMethod = null;
                  _filterStatusCode = null;
                  _filterDomain = null;
                  _filterTimeRange = null;
                });
                Navigator.pop(context);
              },
              child: const Text('重置'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClearCaptures(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('确定要清空所有抓包记录吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              StoreProvider.of<AppState>(context).dispatch(ClearCapturesAction());
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已清空所有抓包记录')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }

  void _navigateToDetail(BuildContext context, CaptureItem capture) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RequestDetailPage(
          captureId: capture.id,
        ),
      ),
    );
  }
}

class _CaptureListItem extends StatelessWidget {
  final CaptureItem capture;
  final VoidCallback onTap;

  const _CaptureListItem({
    required this.capture,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: _getMethodIcon(capture.method),
        title: Text(
          capture.url,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          capture.timestamp.toString().substring(0, 19),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getStatusCodeColor(capture.statusCode).withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${capture.statusCode}',
            style: TextStyle(
              color: _getStatusCodeColor(capture.statusCode),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  Icon _getMethodIcon(String method) {
    IconData iconData;
    Color color;

    switch (method.toUpperCase()) {
      case 'GET':
        iconData = Icons.arrow_downward;
        color = Colors.blue;
        break;
      case 'POST':
        iconData = Icons.arrow_upward;
        color = Colors.green;
        break;
      case 'PUT':
        iconData = Icons.edit;
        color = Colors.orange;
        break;
      case 'DELETE':
        iconData = Icons.delete;
        color = Colors.red;
        break;
      default:
        iconData = Icons.http;
        color = Colors.grey;
    }

    return Icon(iconData, color: color);
  }

  Color _getStatusCodeColor(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) {
      return Colors.green;
    } else if (statusCode >= 300 && statusCode < 400) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}
