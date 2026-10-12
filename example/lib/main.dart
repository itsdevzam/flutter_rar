import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rar/flutter_rar.dart';

import 'rar_check.dart';
import 'rar_checks.dart';

void main() {
  runApp(const RarExampleApp());
}

class RarExampleApp extends StatelessWidget {
  const RarExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_rar',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F6FED)),
        useMaterial3: true,
      ),
      home: const RarCheckPage(),
    );
  }
}

class RarCheckPage extends StatefulWidget {
  const RarCheckPage({super.key});

  @override
  State<RarCheckPage> createState() => _RarCheckPageState();
}

class _RarCheckPageState extends State<RarCheckPage> {
  List<RarCheck>? _results;
  Object? _error;
  var _running = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _error = null;
      _results = null;
    });
    try {
      final results = await runRarChecks();
      if (!mounted) return;
      setState(() {
        _results = results;
        _running = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _running = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final passed = results?.where((item) => item.passed).length ?? 0;
    final platform = kIsWeb ? 'web' : Theme.of(context).platform.name;
    return Scaffold(
      appBar: AppBar(
        title: const Text('flutter_rar'),
        actions: [
          IconButton(
            onPressed: _running ? null : _run,
            icon: const Icon(Icons.refresh),
            tooltip: 'Run checks again',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Platform: $platform',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            FlutterRar.canExtractToDirectory
                ? 'Native extract to a folder is available.'
                : 'This platform lists archives and reads entry bytes.',
          ),
          const SizedBox(height: 16),
          if (_running) const LinearProgressIndicator(),
          if (_error != null)
            Text(
              '$_error',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (results != null) ...[
            Text(
              '$passed of ${results.length} checks passed',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            for (final check in results)
              Card(
                child: ListTile(
                  leading: Icon(
                    check.passed ? Icons.check_circle : Icons.cancel,
                    color: check.passed
                        ? const Color(0xFF1B7F3A)
                        : Theme.of(context).colorScheme.error,
                  ),
                  title: Text(check.name),
                  subtitle: Text(check.detail),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
