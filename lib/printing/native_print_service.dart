import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PrintSettings {
  final String paper;
  final String orientation;
  final int margin;
  final double fontSize;
  final bool autoFit;
  final bool repeatHeader;
  final bool pageNumber;

  const PrintSettings({
    this.paper = 'A4',
    this.orientation = 'auto',
    this.margin = 5,
    this.fontSize = 10,
    this.autoFit = true,
    this.repeatHeader = true,
    this.pageNumber = true,
  });

  PrintSettings copyWith({
    String? paper,
    String? orientation,
    int? margin,
    double? fontSize,
    bool? autoFit,
    bool? repeatHeader,
    bool? pageNumber,
  }) => PrintSettings(
    paper: paper ?? this.paper,
    orientation: orientation ?? this.orientation,
    margin: margin ?? this.margin,
    fontSize: fontSize ?? this.fontSize,
    autoFit: autoFit ?? this.autoFit,
    repeatHeader: repeatHeader ?? this.repeatHeader,
    pageNumber: pageNumber ?? this.pageNumber,
  );

  Map<String, dynamic> toMap() => {
    'paper': paper,
    'orientation': orientation,
    'margin': margin,
    'fontSize': fontSize,
    'autoFit': autoFit,
    'repeatHeader': repeatHeader,
    'pageNumber': pageNumber,
  };

  static PrintSettings fromMap(Map<dynamic, dynamic>? m) {
    if (m == null) return const PrintSettings();
    return PrintSettings(
      paper: m['paper']?.toString() ?? 'A4',
      orientation: m['orientation']?.toString() ?? 'auto',
      margin: (m['margin'] as num?)?.toInt() ?? 5,
      fontSize: (m['fontSize'] as num?)?.toDouble() ?? 10,
      autoFit: m['autoFit'] != false,
      repeatHeader: m['repeatHeader'] != false,
      pageNumber: m['pageNumber'] != false,
    );
  }
}

class NativePrintService {
  static const _channel = MethodChannel('student_comparison/native_print');

  static Future<PrintSettings> loadSettings() async {
    if (kIsWeb) return const PrintSettings();
    final value = await _channel.invokeMethod<dynamic>('getPrintSettings');
    if (value is Map) return PrintSettings.fromMap(value);
    return const PrintSettings();
  }

  static Future<void> saveSettings(PrintSettings settings) async {
    if (kIsWeb) return;
    await _channel.invokeMethod('savePrintSettings', settings.toMap());
  }

  static Future<Map<String, dynamic>?> loadColumnPreferences({
    required String source,
  }) async {
    if (kIsWeb) return null;
    final value = await _channel.invokeMethod<dynamic>(
      'getPrintColumnPreferences',
      {'source': source},
    );
    if (value is! Map) return null;
    final fields = value['fields'];
    final headers = value['headers'];
    return {
      'fields': fields is List
          ? fields.map((e) => e.toString()).toList()
          : <String>[],
      'headers': headers is Map
          ? headers.map((key, value) => MapEntry(
              key.toString(),
              value.toString(),
            ))
          : <String, String>{},
    };
  }

  static Future<void> saveColumnPreferences({
    required String source,
    required List<String> fields,
    required Map<String, String> headers,
  }) async {
    if (kIsWeb) return;
    await _channel.invokeMethod('savePrintColumnPreferences', {
      'source': source,
      'fields': fields,
      'headers': headers,
    });
  }

  static Future<void> printTable({
    required String title,
    required String subtitle,
    required List<String> columns,
    required List<List<String>> rows,
    required PrintSettings settings,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Native Android printing is available on Android only.');
    }
    await _channel.invokeMethod('printTable', {
      'title': title,
      'subtitle': subtitle,
      'columns': columns,
      'rows': rows,
      'settings': settings.toMap(),
    });
  }
}
