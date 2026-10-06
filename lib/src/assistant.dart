import 'package:flutter/material.dart';
import 'common.dart';
import 'session.dart';

class AssistantSummaryScreen extends StatefulWidget {
  const AssistantSummaryScreen({super.key});
  @override
  State<AssistantSummaryScreen> createState() => _AssistantSummaryScreenState();
}

class AssistantGradesJournalScreen extends StatefulWidget {
  const AssistantGradesJournalScreen({super.key});
  @override
  State<AssistantGradesJournalScreen> createState() =>
      _AssistantGradesJournalScreenState();
}

class _AssistantGradesJournalScreenState
    extends State<AssistantGradesJournalScreen> {
  Future<Map<String, dynamic>>? _options;
  Future<Map<String, dynamic>>? _report;
  int _classId = 0, _subjectId = 0;
  String _period = 'monthly';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _options ??= _loadOptions();
  }

  Future<Map<String, dynamic>> _loadOptions() async =>
      Map<String, dynamic>.from(
        await SessionScope.of(context).api.get('grades-journal/options') as Map,
      );

  Future<void> _open() async {
    if (_classId < 1) {
      showMessage(context, 'Синфни танланг.', error: true);
      return;
    }
    setState(() => _report = _loadReport());
  }

  Future<Map<String, dynamic>> _loadReport() async => Map<String, dynamic>.from(
    await SessionScope.of(context).api.get(
          'admin/grades-journal',
          query: {
            'class_id': _classId,
            'subject_id': _subjectId,
            'period': _period,
            'date': ymd(DateTime.now()),
          },
        )
        as Map,
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _options,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done)
        return const LoadingView();
      if (snap.hasError)
        return ErrorView(
          message: '${snap.error}',
          onRetry: () => setState(() => _options = _loadOptions()),
        );
      final data = snap.data!;
      final classes = (data['classes'] as List? ?? const [])
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList();
      final subjects = (data['subjects'] as List? ?? const [])
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList();
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text(
            'Баҳолар журнали',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _classId == 0 ? null : _classId,
            decoration: const InputDecoration(labelText: 'Синф'),
            items: classes
                .map(
                  (x) => DropdownMenuItem(
                    value: asInt(x['id']),
                    child: Text(asText(x['name'])),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _classId = v ?? 0),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _subjectId,
            decoration: const InputDecoration(labelText: 'Фан'),
            items: [
              const DropdownMenuItem(value: 0, child: Text('Барча фанлар')),
              ...subjects.map(
                (x) => DropdownMenuItem(
                  value: asInt(x['id']),
                  child: Text(asText(x['name'])),
                ),
              ),
            ],
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
          FilledButton(onPressed: _open, child: const Text('Журнални кўриш')),
          if (_report != null)
            FutureBuilder<Map<String, dynamic>>(
              future: _report,
              builder: (context, result) {
                if (result.connectionState != ConnectionState.done)
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                if (result.hasError)
                  return ErrorView(message: '${result.error}', onRetry: _open);
                final rows = (result.data!['rows'] as List? ?? const [])
                    .map((x) => Map<String, dynamic>.from(x as Map))
                    .toList();
                if (rows.isEmpty)
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Бу даврда баҳолар йўқ.'),
                  );
                return Column(
                  children: rows
                      .map(
                        (row) => Card(
                          child: ListTile(
                            title: Text(asText(row['full_name'])),
                            subtitle: Text(
                              '${asText(row['journal_date'])} · ${asInt(row['period_no'])}-дарс · ${asText(row['subject_name'])}\nДавомат: ${asText(row['attendance_status'])} · Ўқитувчи: ${asText(row['teacher_name'])}',
                            ),
                            isThreeLine: true,
                            trailing: Text(
                              asText(row['grade']),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
        ],
      );
    },
  );
}

class _AssistantSummaryScreenState extends State<AssistantSummaryScreen> {
  DateTime _date = DateTime.now();
  Future<Map<String, dynamic>>? _future;
  bool _sending = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<Map<String, dynamic>> _load() async => Map<String, dynamic>.from(
    await SessionScope.of(
          context,
        ).api.get('attendance/summary', query: {'date': ymd(_date)})
        as Map,
  );

  void _reload() => setState(() => _future = _load());

  Future<void> _send(String target) async {
    setState(() => _sending = true);
    try {
      final data = Map<String, dynamic>.from(
        await SessionScope.of(context).api.post(
              'attendance/send',
              body: {'date': ymd(_date), 'target': target},
            )
            as Map,
      );
      if (mounted)
        showMessage(
          context,
          data['sent'] == true
              ? 'Telegram юборилди: ${asInt(data['sent_count'])}. Ўтказиб юборилди: ${asInt(data['skipped_count'])}.'
              : 'Юборилмади.',
        );
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _changeDate() async {
    final picked = await pickDate(context, _date);
    if (picked != null) {
      setState(() {
        _date = picked;
        _future = _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _future,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done)
        return const LoadingView();
      if (snap.hasError)
        return ErrorView(message: '${snap.error}', onRetry: _reload);
      final d = snap.data!;
      final totals = Map<String, dynamic>.from(d['totals'] as Map? ?? const {});
      final classes = (d['classes'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      return RefreshIndicator(
        onRefresh: () async {
          _reload();
          await _future;
        },
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_month),
                title: const Text('Давомат санаси'),
                subtitle: Text(humanDate(_date)),
                trailing: const Icon(Icons.edit_calendar),
                onTap: _changeDate,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Telegram’га юбориш'),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _sending ? null : () => _send('admins'),
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      label: const Text('Давоматни жўнатиш'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _sending ? null : () => _send('parents'),
                      icon: const Icon(Icons.family_restroom_outlined),
                      label: const Text('Ота-онага жўнатиш'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 165,
                  child: StatCard(
                    title: 'Ўқувчилар',
                    value: '${asInt(totals['students'])}',
                    icon: Icons.groups_outlined,
                  ),
                ),
                SizedBox(
                  width: 165,
                  child: StatCard(
                    title: 'Келган',
                    value: '${asInt(totals['present'])}',
                    icon: Icons.check_circle_outline,
                  ),
                ),
                SizedBox(
                  width: 165,
                  child: StatCard(
                    title: 'Келмаган',
                    value: '${asInt(totals['absent'])}',
                    icon: Icons.cancel_outlined,
                  ),
                ),
                SizedBox(
                  width: 165,
                  child: StatCard(
                    title: 'Кечиккан',
                    value: '${asInt(totals['late'])}',
                    icon: Icons.schedule,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Синфлар',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            if (classes.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Сизга синф бириктирилмаган.'),
                ),
              ),
            ...classes.map(
              (c) => Card(
                child: ListTile(
                  title: Text(
                    asText(c['class_name']),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Жами ${asInt(c['students'])} · Келди ${asInt(c['present'])} · Келмади ${asInt(c['absent'])} · Кечикди ${asInt(c['late'])}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AttendanceEditorScreen(
                          classId: asInt(c['class_id']),
                          className: asText(c['class_name']),
                          date: _date,
                        ),
                      ),
                    );
                    _reload();
                  },
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class AttendanceEditorScreen extends StatefulWidget {
  const AttendanceEditorScreen({
    super.key,
    required this.classId,
    required this.className,
    required this.date,
  });
  final int classId;
  final String className;
  final DateTime date;
  @override
  State<AttendanceEditorScreen> createState() => _AttendanceEditorScreenState();
}

class _AttendanceEditorScreenState extends State<AttendanceEditorScreen> {
  late Future<Map<String, dynamic>> _future;
  final Map<int, String> _statuses = {};
  final Map<int, TextEditingController> _notes = {};
  List<Map<String, dynamic>> _students = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final data = Map<String, dynamic>.from(
      await SessionScope.of(context).api.get(
            'attendance',
            query: {'class_id': widget.classId, 'date': ymd(widget.date)},
          )
          as Map,
    );
    _students = (data['students'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    for (final s in _students) {
      final id = asInt(s['id']);
      _statuses[id] = asText(s['status']).isEmpty
          ? 'present'
          : asText(s['status']);
      _notes[id] ??= TextEditingController(text: asText(s['note']));
    }
    return data;
  }

  @override
  void dispose() {
    for (final c in _notes.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<bool> _save({bool showSaved = true}) async {
    setState(() => _busy = true);
    try {
      final items = _students.map((s) {
        final id = asInt(s['id']);
        return {
          'student_id': id,
          'status': _statuses[id] ?? 'present',
          'note': _notes[id]?.text.trim() ?? '',
        };
      }).toList();
      await SessionScope.of(context).api.post(
        'attendance/save',
        body: {
          'class_id': widget.classId,
          'date': ymd(widget.date),
          'items': items,
        },
      );
      if (mounted && showSaved) showMessage(context, 'Давомат сақланди.');
      return true;
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.className)),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done)
          return const LoadingView();
        if (snap.hasError)
          return ErrorView(
            message: '${snap.error}',
            onRetry: () => setState(() => _future = _load()),
          );
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Text(
                '${humanDate(widget.date)} · ${_students.length} нафар ўқувчи',
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: _students.length,
                itemBuilder: (context, i) {
                  final s = _students[i];
                  final id = asInt(s['id']);
                  final status = _statuses[id] ?? 'present';
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${i + 1}. ${asText(s['full_name'])}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'present',
                                label: Text('Келди'),
                                icon: Icon(Icons.check),
                              ),
                              ButtonSegment(
                                value: 'absent',
                                label: Text('Келмади'),
                                icon: Icon(Icons.close),
                              ),
                              ButtonSegment(
                                value: 'late',
                                label: Text('Кечикди'),
                                icon: Icon(Icons.schedule),
                              ),
                            ],
                            selected: {status},
                            onSelectionChanged: _busy
                                ? null
                                : (v) =>
                                      setState(() => _statuses[id] = v.first),
                            showSelectedIcon: false,
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _notes[id],
                            enabled: !_busy,
                            decoration: const InputDecoration(
                              labelText: 'Изоҳ (ихтиёрий)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _save,
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text('Давоматни сақлаш'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
