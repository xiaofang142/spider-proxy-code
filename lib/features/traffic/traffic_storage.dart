import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../../core/models/traffic_record.dart';
import '../../core/models/request_detail.dart';
import '../../core/models/response_detail.dart';

/// 流量数据存储 - 使用 SQLite
class TrafficStorage {
  static const String _dbName = 'spider_proxy.db';
  static const int _dbVersion = 1;

  Database? _database;
  bool _isInitialized = false;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 初始化数据库
  Future<void> initialize() async {
    if (_isInitialized) return;

    final documentsDir = await getApplicationDocumentsDirectory();
    final dbPath = path.join(documentsDir.path, _dbName);

    _database = await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    _isInitialized = true;
    print('[TrafficStorage] Initialized at $dbPath');
  }

  /// 创建数据库表
  Future<void> _onCreate(Database db, int version) async {
    // 流量记录表
    await db.execute('''
      CREATE TABLE traffic_records (
        id TEXT PRIMARY KEY,
        timestamp TEXT NOT NULL,
        method TEXT NOT NULL,
        url TEXT NOT NULL,
        host TEXT NOT NULL,
        path TEXT NOT NULL,
        statusCode INTEGER DEFAULT 0,
        requestSize INTEGER DEFAULT 0,
        responseSize INTEGER DEFAULT 0,
        durationMs INTEGER DEFAULT 0,
        requestType TEXT,
        responseType TEXT,
        isHttps INTEGER DEFAULT 0,
        clientIp TEXT,
        port INTEGER
      )
    ''');

    // 请求详情表
    await db.execute('''
      CREATE TABLE request_details (
        id TEXT PRIMARY KEY,
        traffic_record_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        method TEXT NOT NULL,
        uri TEXT NOT NULL,
        headers TEXT,
        cookies TEXT,
        body TEXT,
        contentLength INTEGER DEFAULT 0,
        contentType TEXT,
        userAgent TEXT,
        referer TEXT,
        origin TEXT,
        query_params TEXT,
        clientIp TEXT,
        clientPort INTEGER,
        FOREIGN KEY (traffic_record_id) REFERENCES traffic_records(id)
      )
    ''');

    // 响应详情表
    await db.execute('''
      CREATE TABLE response_details (
        id TEXT PRIMARY KEY,
        traffic_record_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        statusCode INTEGER NOT NULL,
        statusMessage TEXT,
        headers TEXT,
        cookies TEXT,
        body TEXT,
        contentLength INTEGER DEFAULT 0,
        contentType TEXT,
        server TEXT,
        date TEXT,
        last_modified TEXT,
        etag TEXT,
        cache_control TEXT,
        response_time INTEGER,
        is_redirect INTEGER DEFAULT 0,
        redirect_location TEXT,
        FOREIGN KEY (traffic_record_id) REFERENCES traffic_records(id)
      )
    ''');

    // 创建索引
    await db.execute('CREATE INDEX idx_traffic_timestamp ON traffic_records(timestamp)');
    await db.execute('CREATE INDEX idx_traffic_host ON traffic_records(host)');
    await db.execute('CREATE INDEX idx_traffic_method ON traffic_records(method)');
    await db.execute('CREATE INDEX idx_request_traffic_id ON request_details(traffic_record_id)');
    await db.execute('CREATE INDEX idx_response_traffic_id ON response_details(traffic_record_id)');

    print('[TrafficStorage] Database tables created');
  }

  /// 数据库升级
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // TODO: 实现数据库迁移
    print('[TrafficStorage] Upgrading from $oldVersion to $newVersion');
  }

  /// 保存流量记录
  Future<void> saveTrafficRecord(TrafficRecord record) async {
    if (!_isInitialized || _database == null) {
      throw StateError('TrafficStorage not initialized');
    }

    await _database!.insert(
      'traffic_records',
      record.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 保存请求详情
  Future<void> saveRequestDetail(RequestDetail detail) async {
    if (!_isInitialized || _database == null) {
      throw StateError('TrafficStorage not initialized');
    }

    await _database!.insert(
      'request_details',
      {
        ...detail.toJson(),
        'headers': detail.headers.toString(),
        'cookies': detail.cookies.toString(),
        'query_params': detail.queryParams.toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 保存响应详情
  Future<void> saveResponseDetail(ResponseDetail detail) async {
    if (!_isInitialized || _database == null) {
      throw StateError('TrafficStorage not initialized');
    }

    await _database!.insert(
      'response_details',
      {
        ...detail.toJson(),
        'headers': detail.headers.toString(),
        'cookies': detail.cookies.toString(),
        'date': detail.date?.toIso8601String(),
        'last_modified': detail.lastModified?.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 保存完整的流量记录（包括请求和响应详情）
  Future<void> saveCompleteTraffic(
    TrafficRecord record,
    RequestDetail? requestDetail,
    ResponseDetail? responseDetail,
  ) async {
    final batch = _database!.batch();

    batch.insert('traffic_records', record.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace);

    if (requestDetail != null) {
      batch.insert('request_details', {
        ...requestDetail.toJson(),
        'headers': requestDetail.headers.toString(),
        'cookies': requestDetail.cookies.toString(),
        'query_params': requestDetail.queryParams.toString(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    if (responseDetail != null) {
      batch.insert('response_details', {
        ...responseDetail.toJson(),
        'headers': responseDetail.headers.toString(),
        'cookies': responseDetail.cookies.toString(),
        'date': responseDetail.date?.toIso8601String(),
        'last_modified': responseDetail.lastModified?.toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  /// 获取流量记录列表
  Future<List<TrafficRecord>> getTrafficRecords({
    int? limit,
    int? offset,
    String? host,
    String? method,
    DateTime? startTime,
    DateTime? endTime,
    bool? isHttps,
  }) async {
    if (!_isInitialized || _database == null) {
      throw StateError('TrafficStorage not initialized');
    }

    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (host != null) {
      whereClauses.add('host = ?');
      whereArgs.add(host);
    }

    if (method != null) {
      whereClauses.add('method = ?');
      whereArgs.add(method);
    }

    if (startTime != null) {
      whereClauses.add('timestamp >= ?');
      whereArgs.add(startTime.toIso8601String());
    }

    if (endTime != null) {
      whereClauses.add('timestamp <= ?');
      whereArgs.add(endTime.toIso8601String());
    }

    if (isHttps != null) {
      whereClauses.add('isHttps = ?');
      whereArgs.add(isHttps ? 1 : 0);
    }

    final where = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final List<Map<String, dynamic>> maps = await _database!.query(
      'traffic_records',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((map) => TrafficRecord.fromJson(map)).toList();
  }

  /// 获取单个流量记录
  Future<TrafficRecord?> getTrafficRecord(String id) async {
    if (!_isInitialized || _database == null) {
      throw StateError('TrafficStorage not initialized');
    }

    final List<Map<String, dynamic>> maps = await _database!.query(
      'traffic_records',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return TrafficRecord.fromJson(maps.first);
    }
    return null;
  }

  /// 获取请求详情
  Future<RequestDetail?> getRequestDetail(String trafficRecordId) async {
    if (!_isInitialized || _database == null) {
      throw StateError('TrafficStorage not initialized');
    }

    final List<Map<String, dynamic>> maps = await _database!.query(
      'request_details',
      where: 'traffic_record_id = ?',
      whereArgs: [trafficRecordId],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return RequestDetail.fromJson(maps.first);
    }
    return null;
  }

  /// 获取响应详情
  Future<ResponseDetail?> getResponseDetail(String trafficRecordId) async {
    if (!_isInitialized || _database == null) {
      throw StateError('TrafficStorage not initialized');
    }

    final List<Map<String, dynamic>> maps = await _database!.query(
      'response_details',
      where: 'traffic_record_id = ?',
      whereArgs: [trafficRecordId],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return ResponseDetail.fromJson(maps.first);
    }
    return null;
  }

  /// 删除流量记录
  Future<int> deleteTrafficRecord(String id) async {
    if (!_isInitialized || _database == null) {
      throw StateError('TrafficStorage not initialized');
    }

    final batch = _database!.batch();
    batch.delete('traffic_records', where: 'id = ?', whereArgs: [id]);
    batch.delete('request_details', where: 'traffic_record_id = ?', whereArgs: [id]);
    batch.delete('response_details', where: 'traffic_record_id = ?', whereArgs: [id]);

    final results = await batch.commit();
    return results.first as int? ?? 0;
  }

  /// 清空所有数据
  Future<void> clearAll() async {
    if (!_isInitialized || _database == null) {
      throw StateError('TrafficStorage not initialized');
    }

    await _database!.delete('traffic_records');
    await _database!.delete('request_details');
    await _database!.delete('response_details');
    
    print('[TrafficStorage] All data cleared');
  }

  /// 获取统计信息
  Future<TrafficStats> getStats() async {
    if (!_isInitialized || _database == null) {
      throw StateError('TrafficStorage not initialized');
    }

    // 总记录数
    final totalResult = await _database!.rawQuery('SELECT COUNT(*) as count FROM traffic_records');
    final totalCount = totalResult.first['count'] as int? ?? 0;

    // 今日记录数
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayResult = await _database!.rawQuery(
      'SELECT COUNT(*) as count FROM traffic_records WHERE timestamp >= ?',
      [todayStart.toIso8601String()],
    );
    final todayCount = todayResult.first['count'] as int? ?? 0;

    // 按状态码统计
    final statusResult = await _database!.rawQuery('''
      SELECT 
        CASE 
          WHEN statusCode >= 200 AND statusCode < 300 THEN '2xx'
          WHEN statusCode >= 300 AND statusCode < 400 THEN '3xx'
          WHEN statusCode >= 400 AND statusCode < 500 THEN '4xx'
          WHEN statusCode >= 500 THEN '5xx'
          ELSE 'other'
        END as status_group,
        COUNT(*) as count
      FROM traffic_records
      GROUP BY status_group
    ''');

    // 按方法统计
    final methodResult = await _database!.rawQuery('''
      SELECT method, COUNT(*) as count
      FROM traffic_records
      GROUP BY method
    ''');

    return TrafficStats(
      totalRecords: totalCount,
      todayRecords: todayCount,
      statusCodes: Map<String, int>.fromEntries(
        statusResult.map((e) => MapEntry(e['status_group'] as String, e['count'] as int)),
      ),
      methods: Map<String, int>.fromEntries(
        methodResult.map((e) => MapEntry(e['method'] as String, e['count'] as int)),
      ),
    );
  }

  /// 关闭数据库
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _isInitialized = false;
      print('[TrafficStorage] Database closed');
    }
  }
}

/// 流量统计信息
class TrafficStats {
  final int totalRecords;
  final int todayRecords;
  final Map<String, int> statusCodes;
  final Map<String, int> methods;

  TrafficStats({
    required this.totalRecords,
    required this.todayRecords,
    required this.statusCodes,
    required this.methods,
  });

  Map<String, dynamic> toJson() {
    return {
      'totalRecords': totalRecords,
      'todayRecords': todayRecords,
      'statusCodes': statusCodes,
      'methods': methods,
    };
  }
}
