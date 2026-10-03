import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/home_cubit.dart';

import 'comparison_screen.dart';

/// Main landing page: one independent comparison workspace per school.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeCubit _cubit;

  List<Map<String, dynamic>> get _profiles => _cubit.state.profiles;
  bool get _loading =>
      _cubit.state.status == HomeStatus.loading ||
      _cubit.state.status == HomeStatus.initial;
  String? get _error => _cubit.state.error;

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _cubit = HomeCubit()..load();
  }

  Future<void> _loadProfiles() => _cubit.load();

  Future<void> _openProfile(Map<String, dynamic> profile) async {
    try {
      await _cubit.selectProfile(profile['id'].toString());
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ComparisonDashboardScreen(
            schoolName: profile['schoolName']?.toString() ?? 'School Comparison',
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
      await _cubit.deleteProfile(profile['id'].toString());
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
      await _cubit.saveProfile(
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
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'School Profiles',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
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
      ),
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
