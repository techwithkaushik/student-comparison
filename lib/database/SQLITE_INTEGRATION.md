
# SQLite Step 1 integration

## main.dart

Add:

```dart
import 'database/database.dart';
```

and change main to:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance.database;

  runApp(const StudentComparisonApp());
}
```

## home_screen.dart

Add:

```dart
import '../database/database.dart';
```

After the existing PSP JSON parser has produced the final
`List<Map<String, dynamic>> rows`, before converting them to
`PspStudent`, call:

```dart
await AppDatabase.instance.replacePspRows(rows);
```

For UDISE do the same:

```dart
await AppDatabase.instance.replaceUdiseRows(rows);
```

Keep the current matching engine and JSON parsing unchanged.

## Remarks

Use:

```dart
final remarkRepository = RemarkRepository();

await remarkRepository.save(
  pspNic: row.psp?.nicId,
  udisePen: row.udise?.studentCodeNat,
  remark: controller.text.trim(),
);
```

Load with:

```dart
final saved = await remarkRepository.get(
  pspNic: row.psp?.nicId,
  udisePen: row.udise?.studentCodeNat,
);

final remark = saved?['remark']?.toString() ?? '';
```

Delete with:

```dart
await remarkRepository.delete(
  pspNic: row.psp?.nicId,
  udisePen: row.udise?.studentCodeNat,
);
```

The remark table is never cleared by PSP/UDISE re-import.
