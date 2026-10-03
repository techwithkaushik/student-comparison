import '../../printing/native_print_service.dart';

class PrintRepository {
  Future<PrintSettings> loadSettings() =>
      NativePrintService.loadSettings();

  Future<void> saveSettings(PrintSettings settings) =>
      NativePrintService.saveSettings(settings);

  Future<Map<String, dynamic>?> loadColumnPreferences({
    required String source,
  }) =>
      NativePrintService.loadColumnPreferences(source: source);

  Future<void> saveColumnPreferences({
    required String source,
    required List<String> fields,
    required Map<String, String> headers,
  }) =>
      NativePrintService.saveColumnPreferences(
        source: source,
        fields: fields,
        headers: headers,
      );

  Future<void> printTable({
    required String title,
    required List<String> columns,
    required List<List<String>> rows,
    required PrintSettings settings,
  }) =>
      NativePrintService.printTable(
        title: title,
        columns: columns,
        rows: rows,
        settings: settings,
      );
}
