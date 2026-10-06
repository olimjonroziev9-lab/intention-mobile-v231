import 'package:flutter/material.dart';
import 'common.dart';
import 'session.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  Future<Map<String, dynamic>>? _options;
  Future<Map<String, dynamic>>? _report;
  int _classId = 0;
  int _subjectId = 0;
  String _period = 'monthly';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _options ??= _loadOptions();
  }

  Future<Map<String, dynamic>> _loadOptions() async {
    final api = SessionScope.of(context).api;
    final c = Map<String, dynamic>.from(await api.get('classes') as Map);
    final s = Map<String, dynamic>.from(await api.get('subjects') as Map);
    return {
      'classes': c['classes'],
      'subjects': s['subjects'],
    };
  }

  Future<void> _open() async {
    if (_classId < 1 || _subjectId < 1) {
      showMessage(context, 'Синф ва фанни танланг.', error: true);
      return;
    }
    setState(() {
      _report = _loadReport();
    });
  }

  Future<Map<String, dynamic>> _loadReport() async {
    final api = SessionScope.of(context).api;
    final q = {
      'class_id': _classId,
      'subject_id': _subjectId,
      'period': _period,
      'date': DateTime.now().toIso8601String().substring(0, 10),
    };
    final g = Map<String, dynamic>.from(
      await api.get('admin/grades-journal', query: q) as Map,
    );
    final a = Map<String, dynamic>.from(
      await api.get('admin/attendance', query: q) as Map,
    );
    return {
      'grades': g['rows'],
      'attendance': a['rows'],
      'from': g['from'],
      'to': g['to'],
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _options,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const LoadingView();
        }
        if (snap.hasError) {
          return ErrorView(
            message: '${snap.error}',
            onRetry: () => setState(() => _options = _loadOptions()),
          );
        }

        final d = snap.data!;
        final classes = (d['classes'] as List? ?? const [])
            .map((x) => Map<String, dynamic>.from(x as Map))
            .toList();
        final subjects = (d['subjects'] as List? ?? const [])
            .map((x) => Map<String, dynamic>.from(x as Map))
            .toList();

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            DropdownButtonFormField<int>(
              value: _classId == 0 ? null : _classId,
              decoration: const InputDecoration(labelText: 'Синф'),
              items: classes
                  .map(
                    (x) => DropdownMenuItem<int>(
                      value: asInt(x['id']),
                      child: Text(asText(x['name'])),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _classId = v ?? 0),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _subjectId == 0 ? null : _subjectId,
              decoration: const InputDecoration(labelText: 'Фан'),
              items: subjects
                  .map(
                    (x) => DropdownMenuItem<int>(
                      value: asInt(x['id']),
                      child: Text(asText(x['name'])),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _subjectId = v ?? 0),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _period,
              decoration: const InputDecoration(labelText: 'Давр'),
              items: const [
                DropdownMenuItem(value: 'daily', child: Text('Кунлик')),
                DropdownMenuItem(value: 'weekly', child: Text('Ҳафталик')),
                DropdownMenuItem(value: 'monthly', child: Text('Ойлик')),
              ],
              onChanged: (v) => setState(() => _period = v ?? 'monthly'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _open,
              child: const Text('Ҳисоботни кўриш'),
            ),
            if (_report != null)
              FutureBuilder<Map<String, dynamic>>(
                future: _report,
                builder: (context, r) {
                  if (r.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (r.hasError) {
                    return ErrorView(
                      message: '${r.error}',
                      onRetry: _open,
                    );
                  }

                  final x = r.data!;
                  final grades = (x['grades'] as List? ?? const [])
                      .map((e) => Map<String, dynamic>.from(e as Map))
                      .toList();
                  final attendance = (x['attendance'] as List? ?? const [])
                      .map((e) => Map<String, dynamic>.from(e as Map))
                      .toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        'Баҳолар',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      ...grades.map(
                        (g) => ListTile(
                          title: Text(asText(g['full_name'])),
                          subtitle: Text(
                            '${asText(g['journal_date'])} · ${asInt(g['period_no'])}-дарс · ${asText(g['subject_name'])}',
                          ),
                          trailing: Text(asText(g['grade'])),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Давомат',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      ...attendance.map(
                        (a) => ListTile(
                          title: Text(asText(a['full_name'])),
                          subtitle: Text(
                            'Қолдирган соат: ${asText(a['absent_hours'])} · кечикди: ${asText(a['late_count'])}',
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class AdminGradingScreen extends StatefulWidget {
  const AdminGradingScreen({super.key});
  @override
  State<AdminGradingScreen> createState() => _AdminGradingScreenState();
}

class _AdminGradingScreenState extends State<AdminGradingScreen> {
  List<Map<String, dynamic>> _rows = [];
  Future<void>? _future;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<void> _load() async {
    final data = Map<String, dynamic>.from(
      await SessionScope.of(context).api.get('grading-scale') as Map,
    );
    _rows = (data['scale'] as List? ?? const [])
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final data = Map<String, dynamic>.from(
        await SessionScope.of(context).api.post(
          'grading-scale',
          body: {
            'min_percent': _rows.map((row) => asText(row['min'])).toList(),
            'max_percent': _rows.map((row) => asText(row['max'])).toList(),
            'grade': _rows.map((row) => asText(row['grade'])).toList(),
          },
        ) as Map,
      );
      if (!mounted) return;
      setState(
        () => _rows = (data['scale'] as List? ?? const [])
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(),
      );
      showMessage(context, 'Баҳолаш мезони сақланди.');
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return ErrorView(
              message: '${snapshot.error}',
              onRetry: () => setState(() => _future = _load()),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Text(
                'Баҳолаш мезони',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'Диапазонлар 0% дан 100% гача узлуксиз бўлиши керак. Масалан: 64–84 → 4, шунинг учун 78% = 4.',
              ),
              const SizedBox(height: 12),
              ...List.generate(_rows.length, (index) {
                final row = _rows[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: ValueKey('min-$index-${row['min']}'),
                            initialValue: asText(row['min']),
                            enabled: !_saving,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Мин. %'),
                            onChanged: (value) => row['min'] = value,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            key: ValueKey('max-$index-${row['max']}'),
                            initialValue: asText(row['max']),
                            enabled: !_saving,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Макс. %'),
                            onChanged: (value) => row['max'] = value,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 70,
                          child: TextFormField(
                            key: ValueKey('grade-$index-${row['grade']}'),
                            initialValue: asText(row['grade']),
                            enabled: !_saving,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Баҳо'),
                            onChanged: (value) => row['grade'] = value,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () => setState(
                          () => _rows.add({'min': '', 'max': '', 'grade': ''}),
                        ),
                icon: const Icon(Icons.add),
                label: const Text('Диапазон қўшиш'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Сақланмоқда…' : 'Мезонни сақлаш'),
              ),
            ],
          );
        },
      );
}
