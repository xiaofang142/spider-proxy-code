/// AI 分析器 - 用于智能分析网络请求
class AiAnalyzer {
  bool _isEnabled = false;

  bool get isEnabled => _isEnabled;

  /// 启用 AI 分析
  void enable() {
    _isEnabled = true;
  }

  /// 禁用 AI 分析
  void disable() {
    _isEnabled = false;
  }

  /// 分析请求
  Future<AnalysisResult> analyzeRequest({
    required String url,
    required String method,
    Map<String, String>? headers,
    String? body,
  }) async {
    if (!_isEnabled) {
      return AnalysisResult(
        category: 'unknown',
        riskLevel: RiskLevel.low,
        suggestions: [],
      );
    }

    // TODO: 实现 AI 分析逻辑
    // 1. 分析请求类型
    // 2. 检测潜在风险
    // 3. 提供优化建议

    return AnalysisResult(
      category: _categorizeUrl(url),
      riskLevel: RiskLevel.low,
      suggestions: [],
    );
  }

  String _categorizeUrl(String url) {
    if (url.contains('/api/')) return 'api';
    if (url.contains('/static/') || url.contains('/assets/')) return 'static';
    if (url.contains('.jpg') || url.contains('.png') || url.contains('.gif')) return 'image';
    if (url.contains('.js') || url.contains('.css')) return 'resource';
    return 'other';
  }
}

class AnalysisResult {
  final String category;
  final RiskLevel riskLevel;
  final List<String> suggestions;

  AnalysisResult({
    required this.category,
    required this.riskLevel,
    required this.suggestions,
  });
}

enum RiskLevel { low, medium, high, critical }
