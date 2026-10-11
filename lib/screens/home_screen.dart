import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/home_bloc.dart';
import '../data/repositories/app_repository.dart';
import '../bloc/comparison_bloc.dart';
import '../data/repositories/comparison_repository.dart';
import '../data/repositories/school_repository.dart';
import 'comparison_screen.dart';

/// Main landing page: one independent comparison workspace per school.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Map<String, Future<Map<String, dynamic>>> _profileDashboardFutures = {};

  Future<void> _loadProfiles() async {
    _profileDashboardFutures.clear();
    await context.read<HomeBloc>().load();
    if (mounted) setState(() {});
  }

  void _refreshDashboardStats() {
    _profileDashboardFutures.clear();
    if (mounted) setState(() {});
  }

  Future<Map<String, dynamic>> _profileDashboardFuture(
    Map<String, dynamic> profile,
  ) {
    final id = profile['id']?.toString() ?? '';
    return _profileDashboardFutures.putIfAbsent(
      id,
      () => context.read<SchoolRepository>().getProfileDashboardStats(id),
    );
  }

  Future<void> _importDatabase() async {
    final appRepository = context.read<AppRepository>();
    final homeBloc = context.read<HomeBloc>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db', 'sqlite', 'sqlite3'],
        withData: true,
      );
      if (result == null) return;
      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Restore database?'),
          content: const Text(
            'This will replace all current school profiles, PSP/UDISE data and remarks with the selected backup. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Restore'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      final bytes = result.files.single.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Unable to read the selected database backup.');
      }

      await appRepository.restoreDatabase(bytes);
      if (!mounted) return;
      await homeBloc.load();
      if (!mounted) return;
      _refreshDashboardStats();

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Database restored successfully. School profiles and data are ready.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Database restore failed: $e')),
      );
    }
  }

  Future<void> _exportDatabase() async {
    final appRepository = context.read<AppRepository>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await appRepository.exportDatabase();
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Backup Student Comparison database',
        fileName: 'student_comparison_backup.db',
        bytes: bytes,
      );
      if (path != null && mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Database backup exported successfully.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Database export failed: $e')),
      );
    }
  }

  Future<void> _openProfile(Map<String, dynamic> profile) async {
    try {
      await context.read<HomeBloc>().selectProfile(profile['id'].toString());
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BlocProvider(
            create: (context) => ComparisonBloc(
              repository: context.read<ComparisonRepository>(),
              schoolRepository: context.read<SchoolRepository>(),
            ),
            child: ComparisonDashboardScreen(
              schoolName: profile['schoolName']?.toString() ?? 'School Comparison',
            ),
          ),
        ),
      );
      if (mounted) _loadProfiles();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open school profile: $e')),
      );
    }
  }

  Future<void> _deleteProfile(Map<String, dynamic> profile) async {
    final homeBloc = context.read<HomeBloc>();
    final name = profile['schoolName']?.toString() ?? 'this school';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete school profile?'),
        content: Text(
          'Delete "$name" and all PSP/UDISE data, mappings and remarks stored for this school?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await homeBloc.deleteProfile(profile['id'].toString());
      if (!mounted) return;
      _refreshDashboardStats();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('School profile deleted successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete profile: $e')),
      );
    }
  }

  Future<void> _showProfileForm({Map<String, dynamic>? profile}) async {
    final homeBloc = context.read<HomeBloc>();
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(
      text: profile?['schoolName']?.toString() ?? '',
    );
    final pspController = TextEditingController(
      text: profile?['pspCode']?.toString() ?? '',
    );
    final udiseController = TextEditingController(
      text: profile?['udiseCode']?.toString() ?? '',
    );
    try {
      final values = await showDialog<Map<String, String>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(profile == null ? 'Add School Profile' : 'Edit School Profile'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'School name',
                      hintText: 'Enter full school name',
                      prefixIcon: Icon(Icons.school_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'School name is required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: pspController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'PSP code',
                      prefixIcon: Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'PSP code is required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: udiseController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'UDISE code',
                      prefixIcon: Icon(Icons.confirmation_number_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'UDISE code is required'
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                Navigator.pop(dialogContext, {
                  'schoolName': nameController.text.trim(),
                  'pspCode': pspController.text.trim(),
                  'udiseCode': udiseController.text.trim(),
                });
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save profile'),
            ),
          ],
        ),
      );
      if (values == null) return;
      await homeBloc.saveProfile(
        id: profile?['id']?.toString(),
        schoolName: values['schoolName']!,
        pspCode: values['pspCode']!,
        udiseCode: values['udiseCode']!,
      );
      if (!mounted) return;
      _refreshDashboardStats();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(profile == null
              ? 'School profile created successfully.'
              : 'School profile updated successfully.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save profile: $e')),
      );
    } finally {
      nameController.dispose();
      pspController.dispose();
      udiseController.dispose();
    }
  }

  @override
  void initState() {
    super.initState();
    context.read<HomeBloc>().add(const HomeLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'School Profiles',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Database backup',
            onSelected: (value) {
              if (value == 'import_database') {
                _importDatabase();
              } else if (value == 'export_database') {
                _exportDatabase();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'import_database',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.restore_rounded),
                  title: Text('Import database'),
                  subtitle: Text('Restore schools and all data'),
                ),
              ),
              PopupMenuItem(
                value: 'export_database',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.backup_rounded),
                  title: Text('Export database'),
                  subtitle: Text('Backup all schools and data'),
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Add school',
            onPressed: () => _showProfileForm(),
            icon: const Icon(Icons.add_business_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProfileForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add School'),
      ),
      body: (state.status == HomeStatus.loading ||
              state.status == HomeStatus.initial)
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 42),
                        const SizedBox(height: 12),
                        Text(state.error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _loadProfiles,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : state.profiles.isEmpty
                  ? _emptyState(scheme)
                  : RefreshIndicator(
                      onRefresh: _loadProfiles,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        children: [
                          ...state.profiles.map((profile) => Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _profileCard(profile, scheme),
                              )),
                        ],
                      ),
                    ),
    );
      },
    );
  }


  Widget _schoolDashboard(Map<String, dynamic> profile) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<Map<String, dynamic>>(
      future: _profileDashboardFuture(profile),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snapshot.hasError) {
          return Text(
            'Could not load school analytics',
            style: TextStyle(color: scheme.error, fontSize: 12),
          );
        }
        final stats = snapshot.data ?? const <String, dynamic>{};
        final psp = stats['pspStudents'] as int? ?? 0;
        final udise = stats['udiseStudents'] as int? ?? 0;
        final rawClasses = stats['classes'] as List<dynamic>? ?? const [];
        final classes = rawClasses
            .whereType<Map>()
            .map((row) => <String, dynamic>{
                  'name': row['name']?.toString() ?? '—',
                  'psp': row['psp'] as int? ?? 0,
                  'udise': row['udise'] as int? ?? 0,
                })
            .toList()
          ..sort((a, b) => (int.tryParse(a['name'].toString()) ?? 999)
              .compareTo(int.tryParse(b['name'].toString()) ?? 999));
        final total = psp + udise;
        final gap = (psp - udise).abs();
        final dataState = psp > 0 && udise > 0
            ? 'Both datasets available'
            : psp > 0
                ? 'UDISE data pending'
                : udise > 0
                    ? 'PSP data pending'
                    : 'No student data imported';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                scheme.primaryContainer.withValues(alpha: 0.38),
                scheme.tertiaryContainer.withValues(alpha: 0.28),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.65)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.insights_rounded, color: scheme.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('School analytics',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(dataState,
                            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: psp > 0 && udise > 0
                          ? Colors.green.withValues(alpha: 0.13)
                          : Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      psp > 0 && udise > 0 ? 'READY' : 'INCOMPLETE',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w900,
                        color: psp > 0 && udise > 0 ? Colors.green.shade800 : Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _metricTile('PSP students', psp, const Color(0xFF3977F6), Icons.people_alt_rounded)),
                  const SizedBox(width: 8),
                  Expanded(child: _metricTile('UDISE students', udise, const Color(0xFF9B59D0), Icons.groups_rounded)),
                  const SizedBox(width: 8),
                  Expanded(child: _metricTile('Count gap', gap, const Color(0xFFFF9F43), Icons.compare_arrows_rounded)),
                ],
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 350;
                  final pie = _chartPanel(
                    title: 'DATA SHARE',
                    child: Row(
                      children: [
                        SizedBox(
                          width: 94,
                          height: 94,
                          child: CustomPaint(
                            painter: _SchoolDonutPainter(psp: psp, udise: udise),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('$total', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                                  const Text('records', style: TextStyle(fontSize: 9)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _legendDot(const Color(0xFF3977F6), 'PSP', psp),
                              const SizedBox(height: 9),
                              _legendDot(const Color(0xFF9B59D0), 'UDISE', udise),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                  final bars = _chartPanel(
                    title: 'CLASS-WISE STUDENTS',
                    child: classes.isEmpty
                        ? const SizedBox(
                            height: 94,
                            child: Center(child: Text('Import data to view class chart', style: TextStyle(fontSize: 11))),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: (classes.length * 48.0).clamp(160.0, 900.0).toDouble(),
                              height: 112,
                              child: CustomPaint(
                                painter: _SchoolClassBarPainter(classes: classes),
                              ),
                            ),
                          ),
                  );
                  if (stacked) {
                    return Column(children: [pie, const SizedBox(height: 10), bars]);
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: pie),
                      const SizedBox(width: 10),
                      Expanded(flex: 6, child: bars),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _metricTile(String label, int value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(height: 7),
          Text(value.toString(),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: color)),
          const SizedBox(height: 2),
          Text(label, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _chartPanel({required String title, required Widget child}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(
            fontSize: 9, letterSpacing: 0.8, fontWeight: FontWeight.w900,
            color: scheme.onSurfaceVariant,
          )),
          const SizedBox(height: 9),
          child,
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label, int value) {
    return Row(
      children: [
        Container(width: 9, height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
        Text(value.toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _profileCard(Map<String, dynamic> profile, ColorScheme scheme) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: InkWell(
        onTap: () => _openProfile(profile),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.school_rounded, color: scheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      profile['schoolName']?.toString() ?? 'Unnamed school',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'School profile actions',
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showProfileForm(profile: profile);
                      } else if (value == 'delete') {
                        _deleteProfile(profile);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit profile'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete profile'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _codeLine(Icons.badge_outlined, 'PSP Code', profile['pspCode']?.toString() ?? ''),
              const SizedBox(height: 8),
              _codeLine(Icons.confirmation_number_outlined, 'UDISE Code', profile['udiseCode']?.toString() ?? ''),
              const SizedBox(height: 14),
              _schoolDashboard(profile),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: () => _openProfile(profile),
                  icon: const Icon(Icons.compare_arrows_rounded, size: 18),
                  label: const Text('Open comparison'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _codeLine(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 17, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value.isEmpty ? 'Not set' : value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _emptyState(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.domain_add_rounded, size: 64, color: scheme.primary),
            const SizedBox(height: 16),
            const Text(
              'Add your first school',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a profile with the school name, PSP code and UDISE code. Each school will have its own PSP/UDISE data and comparison.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => _showProfileForm(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create school profile'),
            ),
          ],
        ),
      ),
    );
  }
}


class _SchoolDonutPainter extends CustomPainter {
  final int psp;
  final int udise;

  const _SchoolDonutPainter({required this.psp, required this.udise});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..color = const Color(0xFFE4E8F0);
    canvas.drawArc(rect.deflate(8), 0, 6.28318, false, base);
    final total = psp + udise;
    if (total == 0) return;
    final pspPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = 13
      ..color = const Color(0xFF3977F6);
    final udisePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = 13
      ..color = const Color(0xFF9B59D0);
    final start = -1.570796;
    final pspSweep = 6.28318 * psp / total;
    canvas.drawArc(rect.deflate(8), start, pspSweep, false, pspPaint);
    canvas.drawArc(rect.deflate(8), start + pspSweep, 6.28318 - pspSweep, false, udisePaint);
  }

  @override
  bool shouldRepaint(covariant _SchoolDonutPainter oldDelegate) =>
      oldDelegate.psp != psp || oldDelegate.udise != udise;
}

class _SchoolClassBarPainter extends CustomPainter {
  final List<Map<String, dynamic>> classes;

  const _SchoolClassBarPainter({required this.classes});

  @override
  void paint(Canvas canvas, Size size) {
    const left = 4.0;
    const bottom = 22.0;
    const top = 8.0;
    final chartHeight = size.height - bottom - top;
    final maxValue = classes.fold<int>(1, (max, row) {
      final psp = row['psp'] as int? ?? 0;
      final udise = row['udise'] as int? ?? 0;
      return [max, psp, udise].reduce((a, b) => a > b ? a : b);
    });
    final textStyle = const TextStyle(fontSize: 9, color: Color(0xFF667085));
    final gridPaint = Paint()
      ..color = const Color(0xFFE8ECF3)
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = top + chartHeight * i / 2;
      canvas.drawLine(Offset(left, y), Offset(size.width, y), gridPaint);
    }
    final slot = (size.width - left) / classes.length;
    for (var i = 0; i < classes.length; i++) {
      final row = classes[i];
      final psp = row['psp'] as int? ?? 0;
      final udise = row['udise'] as int? ?? 0;
      final barWidth = (slot * 0.25).clamp(4.0, 13.0).toDouble();
      final center = left + slot * i + slot / 2;
      final pspHeight = chartHeight * psp / maxValue;
      final udiseHeight = chartHeight * udise / maxValue;
      final pspRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(center - barWidth - 1, top + chartHeight - pspHeight, barWidth, pspHeight),
        const Radius.circular(3),
      );
      final udiseRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(center + 1, top + chartHeight - udiseHeight, barWidth, udiseHeight),
        const Radius.circular(3),
      );
      canvas.drawRRect(pspRect, Paint()..color = const Color(0xFF3977F6));
      canvas.drawRRect(udiseRect, Paint()..color = const Color(0xFF9B59D0));
      final tp = TextPainter(
        text: TextSpan(text: row['name']?.toString() ?? '', style: textStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: slot);
      tp.paint(canvas, Offset(center - tp.width / 2, size.height - 15));
    }
  }

  @override
  bool shouldRepaint(covariant _SchoolClassBarPainter oldDelegate) =>
      oldDelegate.classes != classes;
}
