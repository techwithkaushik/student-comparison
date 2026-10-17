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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
    final scheme = Theme.of(context).colorScheme;
    final query = _searchQuery.trim().toLowerCase();
    final filteredProfiles = state.profiles.where((profile) {
      if (query.isEmpty) return true;
      return [
        profile['schoolName'],
        profile['pspCode'],
        profile['udiseCode'],
      ].any((value) => value?.toString().toLowerCase().contains(query) ?? false);
    }).toList();
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
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (value) => setState(() => _searchQuery = value),
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                hintText: 'Search school name or code',
                                prefixIcon: const Icon(Icons.search_rounded),
                                suffixIcon: _searchQuery.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Clear search',
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                        icon: const Icon(Icons.close_rounded),
                                      ),
                                filled: true,
                                fillColor: scheme.surfaceContainerLow,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
                            child: Row(
                              children: [
                                Text(
                                  query.isEmpty
                                      ? 'SCHOOL WORKSPACES'
                                      : 'SEARCH RESULTS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    letterSpacing: 1.1,
                                    fontWeight: FontWeight.w800,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${filteredProfiles.length} of ${state.profiles.length}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (filteredProfiles.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Column(
                                children: [
                                  Icon(Icons.search_off_rounded,
                                      size: 42, color: scheme.onSurfaceVariant),
                                  const SizedBox(height: 12),
                                  const Text('No schools match your search',
                                      style: TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text('Try a school name, PSP code or UDISE code.',
                                      style: TextStyle(color: scheme.onSurfaceVariant),
                                      textAlign: TextAlign.center),
                                ],
                              ),
                            )
                          else
                            ...filteredProfiles.map((profile) => Padding(
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


  int _classSortOrder(String rawName) {
    final name = rawName.trim().toLowerCase();
    const wordRanks = <String, int>{
      'pre-primary': 0, 'nursery': 0, 'lkg': 0, 'ukg': 0, 'kindergarten': 0,
      'first': 1, '1st': 1, 'i': 1,
      'second': 2, '2nd': 2, 'ii': 2,
      'third': 3, '3rd': 3, 'iii': 3,
      'fourth': 4, '4th': 4, 'iv': 4,
      'fifth': 5, '5th': 5, 'v': 5,
      'sixth': 6, '6th': 6, 'vi': 6,
      'seventh': 7, '7th': 7, 'vii': 7,
      'eighth': 8, '8th': 8, 'viii': 8,
      'ninth': 9, '9th': 9, 'ix': 9,
      'tenth': 10, '10th': 10, 'x': 10,
      'eleventh': 11, '11th': 11, 'xi': 11,
      'twelfth': 12, '12th': 12, 'xii': 12,
    };
    if (wordRanks.containsKey(name)) return wordRanks[name]!;
    final numeric = RegExp(r'\d+').firstMatch(name);
    if (numeric != null) return int.parse(numeric.group(0)!);
    return 1000;
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
          ..sort((a, b) =>
              _classSortOrder(a['name'].toString()).compareTo(
                _classSortOrder(b['name'].toString()),
              ));
        final total = psp + udise;
        final countGap = (psp - udise).abs();
        final classesWithDifferentCounts = classes.where((row) =>
          (row['psp'] as int) != (row['udise'] as int),
        ).length;
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
              LayoutBuilder(
                builder: (context, constraints) {
                  final metricWidth = (constraints.maxWidth - 16) / 3;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: metricWidth,
                        child: _metricTile(
                          label: 'PSP STUDENTS', value: psp,
                          icon: Icons.groups_2_rounded,
                          color: const Color(0xFF3977F6),
                        ),
                      ),
                      SizedBox(
                        width: metricWidth,
                        child: _metricTile(
                          label: 'UDISE STUDENTS', value: udise,
                          icon: Icons.school_rounded,
                          color: const Color(0xFF9B59D0),
                        ),
                      ),
                      SizedBox(
                        width: metricWidth,
                        child: _metricTile(
                          label: 'CLASSES', value: classes.length,
                          icon: Icons.stacked_bar_chart_rounded,
                          color: const Color(0xFF0F9D83),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.65)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.fact_check_outlined, size: 16, color: scheme.primary),
                        const SizedBox(width: 7),
                        const Expanded(child: Text('DATA QUALITY CHECK',
                          style: TextStyle(fontSize: 9, letterSpacing: 0.7,
                            fontWeight: FontWeight.w900))),
                        Text('$classesWithDifferentCounts class labels differ',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                            color: classesWithDifferentCounts == 0
                                ? Colors.green.shade800 : scheme.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _qualityChip('PSP', psp > 0 ? 'Imported' : 'Missing', psp > 0),
                        _qualityChip('UDISE', udise > 0 ? 'Imported' : 'Missing', udise > 0),
                        _qualityChip('Count gap', countGap.toString(), countGap == 0),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
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
                                  const Text('source entries', style: TextStyle(fontSize: 8)),
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
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 10,
                                runSpacing: 4,
                                children: [
                                  _legendDot(const Color(0xFF3977F6), 'PSP', psp),
                                  _legendDot(const Color(0xFF9B59D0), 'UDISE', udise),
                                ],
                              ),
                              const SizedBox(height: 4),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: (classes.length * 58.0).clamp(174.0, 1100.0).toDouble(),
                                  height: 132,
                                  child: CustomPaint(
                                    painter: _SchoolClassBarPainter(classes: classes),
                                  ),
                                ),
                              ),
                            ],
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

  Widget _qualityChip(String label, String value, bool healthy) {
    final scheme = Theme.of(context).colorScheme;
    final color = healthy ? Colors.green.shade800 : scheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text('$label: $value', style: TextStyle(
        fontSize: 10, fontWeight: FontWeight.w700, color: color,
      )),
    );
  }

  Widget _metricTile({
    required String label,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 8, letterSpacing: 0.45,
                        fontWeight: FontWeight.w800, color: scheme.onSurfaceVariant)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value.toString(), maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 20, height: 1.05,
                  fontWeight: FontWeight.w900, color: scheme.onSurface)),
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
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: InkWell(
        onTap: () => _openProfile(profile),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
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
    const bottom = 24.0;
    const top = 18.0;
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
      for (final item in <({double x, double height, int value, Color color})>[
        (x: center - barWidth - 1, height: pspHeight, value: psp, color: const Color(0xFF3977F6)),
        (x: center + 1, height: udiseHeight, value: udise, color: const Color(0xFF9B59D0)),
      ]) {
        if (item.value == 0) continue;
        final valuePainter = TextPainter(
          text: TextSpan(text: item.value.toString(), style: TextStyle(
            fontSize: 8, fontWeight: FontWeight.w800, color: item.color,
          )),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: slot / 2);
        valuePainter.paint(canvas, Offset(
          item.x + barWidth / 2 - valuePainter.width / 2,
          (top + chartHeight - item.height - 11).clamp(0.0, size.height - bottom),
        ));
      }
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
