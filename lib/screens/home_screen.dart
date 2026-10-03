import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/home_cubit.dart';

import 'comparison_screen.dart';

/// Main landing page: one independent comparison workspace per school.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
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
  }

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
