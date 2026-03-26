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
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        decoration: InputDecoration(
          hintText: '搜索 URL、主机、路径...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) => setState(() => _filterText = value),
      ),
    );
  }

  List<CaptureItem> _applyFilters(List<CaptureItem> captures) {
    return captures.where((capture) {
      // 文本搜索
      if (_filterText.isNotEmpty) {
        final searchText = _filterText.toLowerCase();
        if (!capture.url.toLowerCase().contains(searchText) &&
            !capture.method.toLowerCase().contains(searchText)) {
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

      return true;
    }).toList();
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('过滤条件'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
              onChanged: (value) => setState(() => _filterMethod = value),
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
              onChanged: (value) => setState(() => _filterStatusCode = value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _filterText = '';
                _filterMethod = null;
                _filterStatusCode = null;
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
