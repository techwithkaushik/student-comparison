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
  List<Map<String, dynamic>> get _profiles => context.read<HomeBloc>().state.profiles;
  bool get _loading => context.read<HomeBloc>().state.status == HomeStatus.loading || context.read<HomeBloc>().state.status == HomeStatus.initial;
  String? get _error => context.read<HomeBloc>().state.error;

  Future<void> _loadProfiles() => context.read<HomeBloc>().load();

  Future<void> _importDatabase() async {
    final appRepository = context.read<AppRepository>();
    final homeBloc = context.read<HomeBloc>();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db', 'sqlite', 'sqlite3'],
        withData: true,
      );
      if (result == null) return;

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

      ScaffoldMessenger.of(context).showSnackBar(
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
    try {
      final bytes = await appRepository.exportDatabase();
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Backup Student Comparison database',
        fileName: 'student_comparison_backup.db',
        bytes: Uint8List.fromList(bytes),
      );
      if (path != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 42),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _loadProfiles,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _profiles.isEmpty
                  ? _emptyState(scheme)
                  : RefreshIndicator(
                      onRefresh: _loadProfiles,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  scheme.primaryContainer,
                                  scheme.secondaryContainer,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: scheme.surface.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    Icons.account_balance_rounded,
                                    color: scheme.primary,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Your schools',
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_profiles.length} school profile${_profiles.length == 1 ? '' : 's'} · Choose a school to compare its data',
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          ..._profiles.map((profile) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _profileCard(profile, scheme),
                              )),
                        ],
                      ),
                    ),
    );
      },
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
