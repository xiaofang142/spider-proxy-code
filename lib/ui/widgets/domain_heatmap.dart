import 'package:flutter/material.dart';

/// 域名/IP 热力图组件
///
/// 以条形图形式展示域名或 IP 的请求分布
/// 支持点击展开查看详情
class DomainHeatmap extends StatefulWidget {
  /// 域名统计 Map<域名，请求数>
  final Map<String, int> domainStats;

  /// IP 段统计 Map<IP 段，请求数>
  final Map<String, int> ipStats;

  /// 显示类型
  final HeatmapType type;

  /// 最大显示条数
  final int maxItems;

  /// 是否可点击展开详情
  final bool expandable;

  /// 点击回调
  final Function(String domain)? onDomainTap;

  const DomainHeatmap({
    super.key,
    required this.domainStats,
    this.ipStats = const {},
    this.type = HeatmapType.domain,
    this.maxItems = 10,
    this.expandable = true,
    this.onDomainTap,
  });

  @override
  State<DomainHeatmap> createState() => _DomainHeatmapState();
}

class _DomainHeatmapState extends State<DomainHeatmap>
    with SingleTickerProviderStateMixin {
  late AnimationController _expandController;
  String? _expandedDomain;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = widget.type == HeatmapType.domain
        ? widget.domainStats
        : widget.ipStats;

    if (stats.isEmpty) {
      return _buildEmptyState();
    }

    // 排序并取前 N 项
    final sortedEntries = stats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEntries = sortedEntries.take(widget.maxItems).toList();
    final maxValue = topEntries.isNotEmpty ? topEntries.first.value : 0;
    final totalRequests = stats.values.fold<int>(0, (a, b) => a + b);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Icon(
                  widget.type == HeatmapType.domain
                      ? Icons.dns
                      : Icons.public,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.type == HeatmapType.domain
                      ? '域名分布'
                      : 'IP 段分布',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '共${stats.length}个${widget.type == HeatmapType.domain ? '域名' : 'IP 段'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 热力图列表
            ...topEntries.map((entry) {
              final index = topEntries.indexOf(entry);
              final percentage = maxValue > 0 ? entry.value / maxValue : 0;
              final totalPercentage = totalRequests > 0
                  ? (entry.value / totalRequests * 100)
                  : 0.0;

              return _buildHeatmapItem(
                domain: entry.key,
                count: entry.value,
                percentage: percentage,
                totalPercentage: totalPercentage,
                rank: index + 1,
              );
            }),
            // 展开更多
            if (sortedEntries.length > widget.maxItems)
              _buildExpandMoreButton(
                sortedEntries.skip(widget.maxItems).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.show_chart,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无数据',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmapItem({
    required String domain,
    required int count,
    required double percentage,
    required double totalPercentage,
    required int rank,
  }) {
    final isExpanded = _expandedDomain == domain;

    return InkWell(
      onTap: widget.expandable
          ? () {
              setState(() {
                if (_expandedDomain == domain) {
                  _expandedDomain = null;
                  _expandController.reverse();
                } else {
                  _expandedDomain = domain;
                  _expandController.forward();
                }
              });
              widget.onDomainTap?.call(domain);
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            // 主行
            Row(
              children: [
                // 排名
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: rank <= 3
                        ? _getRankColor(rank).withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: rank <= 3
                          ? _getRankColor(rank)
                          : Colors.grey.shade400,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 域名
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        domain,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // 进度条背景
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: Container(
                          height: 6,
                          width: double.infinity,
                          color: Colors.grey.shade200,
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: percentage,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _getRankColor(rank),
                                    _getRankColor(rank).withOpacity(0.6),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // 统计数字
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${totalPercentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                if (widget.expandable) ...[
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      size: 20,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ],
            ),
            // 展开的详情
            if (widget.expandable)
              SizeTransition(
                sizeFactor: _expandController,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, left: 32),
                  child: _buildDomainDetails(domain),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDomainDetails(String domain) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '域名详情',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          _buildDetailRow('主机名', domain),
          _buildDetailRow('类型', domain.contains('api') ? 'API' : '其他'),
          Row(
            children: [
              Text(
                '操作',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.filter_list, size: 16),
                    label: const Text(
                      '过滤',
                      style: TextStyle(fontSize: 11),
                    ),
                    onPressed: () {
                      widget.onDomainTap?.call(domain);
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.search, size: 16),
                    label: const Text(
                      '搜索',
                      style: TextStyle(fontSize: 11),
                    ),
                    onPressed: () {
                      widget.onDomainTap?.call(domain);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandMoreButton(List<MapEntry<String, int>> moreEntries) {
    return InkWell(
      onTap: () {
        // 显示更多域名弹窗
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('更多域名'),
            content: SizedBox(
              width: const double.maxFinite,
              child: ListView.builder(
                itemCount: moreEntries.length,
                itemBuilder: (context, index) {
                  final entry = moreEntries[index];
                  final totalRequests = widget.domainStats.values
                      .fold<int>(0, (a, b) => a + b);
                  final percentage = totalRequests > 0
                      ? (entry.value / totalRequests * 100)
                      : 0.0;

                  return ListTile(
                    dense: true,
                    leading: Text(
                      '#${widget.maxItems + index + 1}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    title: Text(
                      entry.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${entry.value}'),
                        Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onDomainTap?.call(entry.key);
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ],
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '展开更多${moreEntries.length}个域名',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Color _getRankColor(int rank) {
    if (rank == 1) return Colors.amber;
    if (rank == 2) return Colors.blueGrey;
    if (rank == 3) return Colors.brown;
    return Theme.of(context).colorScheme.primary;
  }
}

enum HeatmapType {
  /// 域名分布
  domain,

  /// IP 段分布
  ip,
}
