import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/app_bloc.dart';
import 'bloc/home_bloc.dart';
import 'data/repositories/app_repository.dart';
import 'data/repositories/school_repository.dart';
import 'data/repositories/comparison_repository.dart';
import 'data/repositories/print_repository.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StudentComparisonApp());
}

class StudentComparisonApp extends StatelessWidget {
  const StudentComparisonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => AppRepository()),
        RepositoryProvider(create: (_) => SchoolRepository()),
        RepositoryProvider(create: (_) => ComparisonRepository()),
        RepositoryProvider(create: (_) => PrintRepository()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AppBloc(repository: context.read<AppRepository>())..add(const AppStarted()),
          ),
          BlocProvider(
            create: (context) => HomeBloc(repository: context.read<SchoolRepository>()),
          ),
        ],
        child: MaterialApp(
        title: 'PSP vs UDISE',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          visualDensity: VisualDensity.compact,
        ),
        home: BlocBuilder<AppBloc, AppState>(
          builder: (context, state) {
            switch (state.status) {
              case AppStatus.ready:
                return const HomeScreen();
              case AppStatus.failure:
                return _StartupFailure(error: state.error);
              case AppStatus.initializing:
                return const _StartupLoading();
            }
          },
        ),
        ),
      ),
    );
  }
}

class _StartupLoading extends StatelessWidget {
  const _StartupLoading();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Preparing student database...'),
        ],
      ),
    ),
  );
}

class _StartupFailure extends StatelessWidget {
  final String? error;
  const _StartupFailure({this.error});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Unable to start the application',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.read<AppBloc>().add(const AppRetryRequested()),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    ),
  );
}
