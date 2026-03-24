import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import '../../main.dart';

class CaptureListPage extends StatelessWidget {
  const CaptureListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('抓包列表'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: 实现过滤功能
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              // TODO: 实现清空功能
            },
          ),
        ],
      ),
      body: StoreConnector<AppState, List<CaptureItem>>(
        converter: (store) => store.state.captures,
        builder: (context, captures) {
          if (captures.isEmpty) {
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
            itemCount: captures.length,
            itemBuilder: (context, index) {
              final capture = captures[captures.length - 1 - index];
              return _CaptureListItem(capture: capture);
            },
          );
        },
      ),
    );
  }
}

class _CaptureListItem extends StatelessWidget {
  final CaptureItem capture;

  const _CaptureListItem({required this.capture});

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
        onTap: () {
          // TODO: 跳转到详情页
        },
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
