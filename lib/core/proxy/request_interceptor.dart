import 'dart:io';
import '../models/request_detail.dart';

/// 请求拦截器接口
abstract class RequestInterceptor {
  /// 拦截并处理请求
  /// 返回 true 表示继续处理，false 表示已处理完毕
  Future<bool> intercept(HttpRequest request, RequestDetail requestDetail);

  /// 在请求发送前修改请求
  Future<RequestDetail?> modifyRequest(RequestDetail requestDetail);
}

/// 默认请求拦截器实现
class DefaultRequestInterceptor implements RequestInterceptor {
  final List<RequestInterceptor> _interceptors = [];

  /// 注册拦截器
  void addInterceptor(RequestInterceptor interceptor) {
    _interceptors.add(interceptor);
  }

  /// 移除拦截器
  void removeInterceptor(RequestInterceptor interceptor) {
    _interceptors.remove(interceptor);
  }

  @override
  Future<bool> intercept(HttpRequest request, RequestDetail requestDetail) async {
    // 执行所有注册的拦截器
    for (final interceptor in _interceptors) {
      final shouldContinue = await interceptor.intercept(request, requestDetail);
      if (!shouldContinue) {
        return false;
      }
    }
    return true;
  }

  @override
  Future<RequestDetail?> modifyRequest(RequestDetail requestDetail) async {
    RequestDetail? modified = requestDetail;
    for (final interceptor in _interceptors) {
      final result = await interceptor.modifyRequest(modified!);
      if (result != null) {
        modified = result;
      }
    }
    return modified;
  }
}

/// 日志请求拦截器
class LoggingRequestInterceptor implements RequestInterceptor {
  @override
  Future<bool> intercept(HttpRequest request, RequestDetail requestDetail) async {
    print('[Request] ${requestDetail.method} ${requestDetail.uri}');
    print('[Headers] ${requestDetail.headers}');
    return true;
  }

  @override
  Future<RequestDetail?> modifyRequest(RequestDetail requestDetail) {
    return Future.value(requestDetail);
  }
}

/// 请求过滤拦截器
class FilteringRequestInterceptor implements RequestInterceptor {
  final List<RegExp> _includePatterns = [];
  final List<RegExp> _excludePatterns = [];

  /// 添加包含模式
  void addIncludePattern(String pattern) {
    _includePatterns.add(RegExp(pattern, caseSensitive: false));
  }

  /// 添加排除模式
  void addExcludePattern(String pattern) {
    _excludePatterns.add(RegExp(pattern, caseSensitive: false));
  }

  bool _shouldIntercept(Uri uri) {
    final urlString = uri.toString();
    
    // 检查排除模式
    for (final pattern in _excludePatterns) {
      if (pattern.hasMatch(urlString)) {
        return false;
      }
    }

    // 如果没有包含模式，默认拦截所有
    if (_includePatterns.isEmpty) {
      return true;
    }

    // 检查包含模式
    for (final pattern in _includePatterns) {
      if (pattern.hasMatch(urlString)) {
        return true;
      }
    }

    return false;
  }

  @override
  Future<bool> intercept(HttpRequest request, RequestDetail requestDetail) async {
    return _shouldIntercept(requestDetail.uri);
  }

  @override
  Future<RequestDetail?> modifyRequest(RequestDetail requestDetail) {
    return Future.value(requestDetail);
  }
}
