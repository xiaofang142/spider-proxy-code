import 'dart:io';
import '../models/response_detail.dart';

/// 响应拦截器接口
abstract class ResponseInterceptor {
  /// 拦截并处理响应
  /// 返回 true 表示继续处理，false 表示已处理完毕
  Future<bool> intercept(HttpResponse response, ResponseDetail responseDetail);

  /// 在响应发送给客户端前修改响应
  Future<ResponseDetail?> modifyResponse(ResponseDetail responseDetail);
}

/// 默认响应拦截器实现
class DefaultResponseInterceptor implements ResponseInterceptor {
  final List<ResponseInterceptor> _interceptors = [];

  /// 注册拦截器
  void addInterceptor(ResponseInterceptor interceptor) {
    _interceptors.add(interceptor);
  }

  /// 移除拦截器
  void removeInterceptor(ResponseInterceptor interceptor) {
    _interceptors.remove(interceptor);
  }

  @override
  Future<bool> intercept(HttpResponse response, ResponseDetail responseDetail) async {
    // 执行所有注册的拦截器
    for (final interceptor in _interceptors) {
      final shouldContinue = await interceptor.intercept(response, responseDetail);
      if (!shouldContinue) {
        return false;
      }
    }
    return true;
  }

  @override
  Future<ResponseDetail?> modifyResponse(ResponseDetail responseDetail) async {
    ResponseDetail? modified = responseDetail;
    for (final interceptor in _interceptors) {
      final result = await interceptor.modifyResponse(modified!);
      if (result != null) {
        modified = result;
      }
    }
    return modified;
  }
}

/// 日志响应拦截器
class LoggingResponseInterceptor implements ResponseInterceptor {
  @override
  Future<bool> intercept(HttpResponse response, ResponseDetail responseDetail) async {
    print('[Response] ${responseDetail.statusCode} ${responseDetail.statusMessage}');
    print('[Headers] ${responseDetail.headers}');
    return true;
  }

  @override
  Future<ResponseDetail?> modifyResponse(ResponseDetail responseDetail) {
    return Future.value(responseDetail);
  }
}

/// 响应修改拦截器
class ModifyingResponseInterceptor implements ResponseInterceptor {
  final Map<String, String> _headerOverrides = {};
  final Function(ResponseDetail)? _bodyModifier;

  ModifyingResponseInterceptor({
    Map<String, String> headerOverrides = const {},
    this._bodyModifier,
  }) : _headerOverrides = Map.unmodifiable(headerOverrides);

  /// 添加响应头覆盖
  void addHeaderOverride(String name, String value) {
    // 注意：这会在运行时修改，使用时需注意线程安全
    _headerOverrides[name] = value;
  }

  @override
  Future<bool> intercept(HttpResponse response, ResponseDetail responseDetail) async {
    return true;
  }

  @override
  Future<ResponseDetail?> modifyResponse(ResponseDetail responseDetail) async {
    final modified = responseDetail.copyWith(
      headers: {
        ...responseDetail.headers,
        ..._headerOverrides,
      },
    );

    if (_bodyModifier != null) {
      _bodyModifier!(modified);
    }

    return modified;
  }
}

/// 响应缓存拦截器
class CachingResponseInterceptor implements ResponseInterceptor {
  final Map<String, _CacheEntry> _cache = {};
  final Duration _defaultTtl;

  CachingResponseInterceptor({Duration defaultTtl = const Duration(minutes: 5)})
      : _defaultTtl = defaultTtl;

  @override
  Future<bool> intercept(HttpResponse response, ResponseDetail responseDetail) async {
    final cacheKey = responseDetail.headers['cache-key'];
    if (cacheKey != null) {
      _cache[cacheKey] = _CacheEntry(
        responseDetail: responseDetail,
        expires: DateTime.now().add(_defaultTtl),
      );
    }
    return true;
  }

  @override
  Future<ResponseDetail?> modifyResponse(ResponseDetail responseDetail) async {
    return responseDetail;
  }

  /// 获取缓存的响应
  ResponseDetail? getCachedResponse(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expires)) {
      _cache.remove(key);
      return null;
    }
    return entry.responseDetail;
  }

  /// 清除缓存
  void clearCache() {
    _cache.clear();
  }

  /// 清理过期缓存
  void pruneExpired() {
    final now = DateTime.now();
    _cache.removeWhere((key, entry) => now.isAfter(entry.expires));
  }
}

class _CacheEntry {
  final ResponseDetail responseDetail;
  final DateTime expires;

  _CacheEntry({
    required this.responseDetail,
    required this.expires,
  });
}
