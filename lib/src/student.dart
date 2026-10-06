import 'dart:async';
import 'package:flutter/material.dart';
import 'api.dart';
import 'common.dart';
import 'session.dart';

class StudentTestsScreen extends StatefulWidget {
  const StudentTestsScreen({super.key});
  @override
  State<StudentTestsScreen> createState() => _StudentTestsScreenState();
}

class StudentGradesScreen extends StatefulWidget {
  const StudentGradesScreen({super.key});
  @override
  State<StudentGradesScreen> createState() => _StudentGradesScreenState();
}

class _StudentGradesScreenState extends State<StudentGradesScreen> {
  String _period = 'daily';
  DateTime _date = DateTime.now();
  Future<Map<String, dynamic>>? _future;

  @override
  void didChangeDependencies() { super.didChangeDependencies(); _future ??= _load(); }
  String get _dateText => '${_date.year.toString().padLeft(4,'0')}-${_date.month.toString().padLeft(2,'0')}-${_date.day.toString().padLeft(2,'0')}';
  Future<Map<String, dynamic>> _load() async => Map<String, dynamic>.from(await SessionScope.of(context).api.get('grades', query: {'period':_period,'date':_dateText}) as Map);
  void _reload() => setState(() => _future=_load());

  @override
  Widget build(BuildContext context) => Column(children:[
    Padding(padding: const EdgeInsets.fromLTRB(12,12,12,0), child: Row(children:[
      Expanded(child: DropdownButtonFormField<String>(value:_period, decoration: const InputDecoration(labelText:'Давр'), items: const [DropdownMenuItem(value:'daily',child:Text('Кунлик')),DropdownMenuItem(value:'weekly',child:Text('Ҳафталик')),DropdownMenuItem(value:'monthly',child:Text('Ойлик'))], onChanged:(v){if(v!=null)setState((){_period=v;_future=_load();});})),
      const SizedBox(width:8), IconButton(tooltip:'Санани танлаш',icon:const Icon(Icons.calendar_month),onPressed:() async {final d=await showDatePicker(context:context,initialDate:_date,firstDate:DateTime(2020),lastDate:DateTime.now());if(d!=null)setState((){_date=d;_future=_load();});}),
    ])),
    Expanded(child: FutureBuilder<Map<String,dynamic>>(future:_future,builder:(context,snap){
      if(snap.connectionState!=ConnectionState.done)return const LoadingView();
      if(snap.hasError)return ErrorView(message:'${snap.error}',onRetry:_reload);
      final d=snap.data!; final rows=(d['attendance'] as List? ?? const []).map((x)=>Map<String,dynamic>.from(x as Map)).toList();
      return RefreshIndicator(onRefresh:()async{_reload();await _future;},child:ListView(padding:const EdgeInsets.all(12),children:[
        Text('${asText(d['from'])} — ${asText(d['to'])}',style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:8),
        if(rows.isEmpty) const Card(child:Padding(padding:EdgeInsets.all(18),child:Text('Бу даврда баҳо ёки давомат йўқ.'))),
        ...rows.map((r)=>Card(child:ListTile(leading:CircleAvatar(child:Text(asText(r['grade_5'],'—'))),title:Text(asText(r['subject_name'])),subtitle:Text('${asText(r['journal_date'])} · ${asInt(r['period_no'])}-дарс · ${asText(r['attendance_status'])}\n${asText(r['grade_display'],'—')}${asText(r['parent_note']).isEmpty?'':'\n${asText(r['parent_note'])}'}'),isThreeLine:true))),
      ]));
    }))
  ]);
}

class _StudentTestsScreenState extends State<StudentTestsScreen> {
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final data = Map<String, dynamic>.from(await SessionScope.of(context).api.get('tests') as Map);
    final rows = data['tests'] as List? ?? const [];
    return rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) return ErrorView(message: '${snap.error}', onRetry: _reload);
          final tests = snap.data ?? const [];
          return RefreshIndicator(
            onRefresh: () async { _reload(); await _future; },
            child: tests.isEmpty
                ? ListView(children: const [SizedBox(height: 160), Center(child: Text('Тестлар йўқ.'))])
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: tests.length,
                    itemBuilder: (context, i) {
                      final t = tests[i];
                      final available = t['available_now'] == true || asInt(t['available_now']) == 1;
                      final status = asText(t['attempt_status']);
                      final percentage = t['percentage'];
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(14),
                          leading: CircleAvatar(child: Icon(status.isEmpty ? Icons.quiz_outlined : Icons.fact_check_outlined)),
                          title: Text(asText(t['title'], 'Тест'), style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const SizedBox(height: 6),
                            Text('${asText(t['subject_name'])} · ${asText(t['class_name'])}'),
                            Text('Вақт: ${epochDateTime(t['starts_at'])} — ${epochDateTime(t['ends_at'])}'),
                            if (percentage != null) Text('Натижа: $percentage% · Баҳо: ${asText(t['grade'], '—')}'),
                            if (available) const Text('Ҳозир топшириш мумкин', style: TextStyle(fontWeight: FontWeight.w600)),
                          ]),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TestDetailScreen(testId: asInt(t['id']))));
                            _reload();
                          },
                        ),
                      );
                    },
                  ),
          );
        },
      );
}

class TestDetailScreen extends StatefulWidget {
  const TestDetailScreen({super.key, required this.testId});
  final int testId;
  @override
  State<TestDetailScreen> createState() => _TestDetailScreenState();
}

class _TestDetailScreenState extends State<TestDetailScreen> {
  late Future<Map<String, dynamic>> _future;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async => Map<String, dynamic>.from(
        await SessionScope.of(context).api.get('tests/${widget.testId}') as Map,
      );

  Future<void> _start(Map<String, dynamic> test) async {
    setState(() => _starting = true);
    try {
      final data = Map<String, dynamic>.from(await SessionScope.of(context).api.post('attempt/start', body: {'test_id': widget.testId}) as Map);
      final attempt = Map<String, dynamic>.from(data['attempt'] as Map);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => AttemptScreen(initialAttempt: attempt)));
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Тест маълумоти')),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const LoadingView();
            if (snap.hasError) return ErrorView(message: '${snap.error}', onRetry: () => setState(() => _future = _load()));
            final t = snap.data!;
            final attempt = t['attempt'] is Map ? Map<String, dynamic>.from(t['attempt'] as Map) : null;
            final available = t['available_now'] == true || asInt(t['available_now']) == 1;
            final active = attempt != null && asText(attempt['status']) == 'active';
            return ListView(padding: const EdgeInsets.all(16), children: [
              Text(asText(t['title']), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _info(Icons.menu_book_outlined, 'Фан', asText(t['subject_name'])),
              _info(Icons.groups_outlined, 'Синф', asText(t['class_name'])),
              _info(Icons.help_outline, 'Саволлар', '${asInt(t['question_count'])} та'),
              _info(Icons.timer_outlined, 'Давомийлик', '${asInt(t['duration_minutes'])} дақиқа'),
              _info(Icons.stars_outlined, 'Максимум бал', asText(t['max_score'], '0')),
              _info(Icons.schedule, 'Бошланиш', epochDateTime(t['starts_at'])),
              _info(Icons.event_busy, 'Тугаш', epochDateTime(t['ends_at'])),
              const SizedBox(height: 18),
              if (active)
                FilledButton.icon(
                  onPressed: () async {
                    try {
                      final a = Map<String, dynamic>.from(await SessionScope.of(context).api.get('attempt/${asInt(attempt['id'])}') as Map);
                      if (!context.mounted) return;
                      await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => AttemptScreen(initialAttempt: a)));
                    } catch (e) {
                      if (context.mounted) showMessage(context, '$e', error: true);
                    }
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Тестни давом эттириш'),
                )
              else if (available)
                FilledButton.icon(
                  onPressed: _starting ? null : () => _start(t),
                  icon: _starting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_arrow),
                  label: const Text('Тестни бошлаш'),
                )
              else if (attempt != null)
                Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('Бу тест топширилган. Ҳолат: ${asText(attempt['status'])}')))
              else
                const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Ҳозир тестни бошлаб бўлмайди.'))),
            ]);
          },
        ),
      );

  Widget _info(IconData icon, String label, String value) => ListTile(
        dense: true,
        leading: Icon(icon),
        title: Text(label),
        trailing: SizedBox(width: 180, child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w600))),
      );
}

class AttemptScreen extends StatefulWidget {
  const AttemptScreen({super.key, required this.initialAttempt});
  final Map<String, dynamic> initialAttempt;
  @override
  State<AttemptScreen> createState() => _AttemptScreenState();
}

class _AttemptScreenState extends State<AttemptScreen> {
  late Map<String, dynamic> _attempt;
  late List<Map<String, dynamic>> _questions;
  int _index = 0;
  Timer? _timer;
  int _remaining = 0;
  bool _busy = false;
  final Map<int, TextEditingController> _textControllers = {};

  @override
  void initState() {
    super.initState();
    _apply(widget.initialAttempt);
  }

  void _apply(Map<String, dynamic> data) {
    _attempt = data;
    _remaining = asInt(data['remaining_time']);
    final raw = data['questions'] as List? ?? const [];
    _questions = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    for (final q in _questions) {
      if (asText(q['question_type']) == 'short') {
        final id = asInt(q['id']);
        _textControllers[id] ??= TextEditingController(text: asText(q['text_answer']));
      }
    }
    _timer?.cancel();
    if (_remaining > 0 && asText(_attempt['status']) == 'active') {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (_remaining <= 1) {
          _timer?.cancel();
          setState(() => _remaining = 0);
          _finish(auto: true);
        } else {
          setState(() => _remaining--);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _textControllers.values) { c.dispose(); }
    super.dispose();
  }

  String get _clock => '${(_remaining ~/ 60).toString().padLeft(2, '0')}:${(_remaining % 60).toString().padLeft(2, '0')}';

  Future<void> _saveChoice(Map<String, dynamic> q, int optionId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await SessionScope.of(context).api.post('attempt/${asInt(_attempt['id'])}/answer', body: {
        'question_id': asInt(q['id']),
        'option_id': optionId,
      });
      setState(() => q['selected'] = optionId);
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveText(Map<String, dynamic> q) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final text = _textControllers[asInt(q['id'])]?.text ?? '';
      await SessionScope.of(context).api.post('attempt/${asInt(_attempt['id'])}/answer', body: {
        'question_id': asInt(q['id']),
        'text_answer': text,
      });
      q['text_answer'] = text;
      if (mounted) showMessage(context, 'Жавоб сақланди.');
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish({bool auto = false}) async {
    if (_busy) return;
    if (!auto) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Тестни якунлаш'),
          content: const Text('Жавобларни топшириб, тестни якунлайсизми?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Йўқ')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ҳа, якунлаш')),
          ],
        ),
      );
      if (yes != true) return;
    }
    setState(() => _busy = true);
    try {
      // Finish босилганда сақланмай қолган short-answer матнларини ҳам серверга ёзамиз.
      for (final q in _questions) {
        if (asText(q['question_type']) != 'short') continue;
        final id = asInt(q['id']);
        final text = _textControllers[id]?.text ?? '';
        if (text != asText(q['text_answer'])) {
          await SessionScope.of(context).api.post('attempt/${asInt(_attempt['id'])}/answer', body: {
            'question_id': id,
            'text_answer': text,
          });
          q['text_answer'] = text;
        }
      }
      final data = Map<String, dynamic>.from(await SessionScope.of(context).api.post('attempt/${asInt(_attempt['id'])}/finish') as Map);
      _timer?.cancel();
      if (!mounted) return;
      final result = data['result'] is Map ? Map<String, dynamic>.from(data['result'] as Map) : <String, dynamic>{};
      await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ResultSummaryScreen(result: result)));
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(appBar: AppBar(title: const Text('Тест')), body: const Center(child: Text('Саволлар йўқ.')));
    }
    final q = _questions[_index];
    final options = (q['options'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text('${_index + 1}/${_questions.length}'),
        actions: [
          Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(_clock, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)))),
        ],
      ),
      body: Column(children: [
        LinearProgressIndicator(value: (_index + 1) / _questions.length),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Text('${_index + 1}-савол · ${asText(q['points'])} балл', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 10),
            Text(asText(q['body']), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
            if (asText(q['image_url']).isNotEmpty) ...[
              const SizedBox(height: 14),
              ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(asText(q['image_url']), errorBuilder: (_, __, ___) => const SizedBox.shrink())),
            ],
            const SizedBox(height: 18),
            if (asText(q['question_type']) == 'short') ...[
              TextField(
                controller: _textControllers[asInt(q['id'])],
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Жавоб', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              FilledButton.tonal(onPressed: _busy ? null : () => _saveText(q), child: const Text('Жавобни сақлаш')),
            ] else
              ...options.map((o) => RadioListTile<int>(
                    value: asInt(o['id']),
                    groupValue: asInt(q['selected']) > 0 ? asInt(q['selected']) : null,
                    title: Text(asText(o['body'])),
                    onChanged: _busy ? null : (v) { if (v != null) _saveChoice(q, v); },
                  )),
          ]),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: _index > 0 ? () => setState(() => _index--) : null, icon: const Icon(Icons.chevron_left), label: const Text('Олдинги'))),
              const SizedBox(width: 10),
              if (_index < _questions.length - 1)
                Expanded(child: FilledButton.icon(onPressed: () => setState(() => _index++), icon: const Icon(Icons.chevron_right), label: const Text('Кейинги')))
              else
                Expanded(child: FilledButton.icon(onPressed: _busy ? null : () => _finish(), icon: const Icon(Icons.done_all), label: const Text('Якунлаш'))),
            ]),
          ),
        ),
      ]),
    );
  }
}

class ResultSummaryScreen extends StatelessWidget {
  const ResultSummaryScreen({super.key, required this.result});
  final Map<String, dynamic> result;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Натижа')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.emoji_events_outlined, size: 64),
                  const SizedBox(height: 12),
                  Text('${asText(result['percentage'], '0')}%', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text('Балл: ${asText(result['score'], '0')} / ${asText(result['max_score'], '0')}'),
                  Text('Баҳо: ${asText(result['grade'], '—')}', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 18),
                  FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Тайёр')),
                ]),
              ),
            ),
          ),
        ),
      );
}

class StudentResultsScreen extends StatefulWidget {
  const StudentResultsScreen({super.key});
  @override
  State<StudentResultsScreen> createState() => _StudentResultsScreenState();
}

class _StudentResultsScreenState extends State<StudentResultsScreen> {
  Future<Map<String, dynamic>>? _future;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }
  Future<Map<String, dynamic>> _load() async => Map<String, dynamic>.from(await SessionScope.of(context).api.get('results') as Map);
  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) return ErrorView(message: '${snap.error}', onRetry: _reload);
          final d = snap.data!;
          final summary = Map<String, dynamic>.from(d['summary'] as Map? ?? const {});
          final rows = (d['rows'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          return RefreshIndicator(
            onRefresh: () async { _reload(); await _future; },
            child: ListView(padding: const EdgeInsets.all(12), children: [
              Row(children: [
                Expanded(child: StatCard(title: 'Ўртача фоиз', value: '${asText(summary['average_percentage'], '0')}%', icon: Icons.percent)),
                const SizedBox(width: 8),
                Expanded(child: StatCard(title: 'Ўртача балл', value: asText(summary['average_score'], '0'), icon: Icons.stars_outlined)),
              ]),
              const SizedBox(height: 8),
              if (rows.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('Ҳозирча натижа йўқ.'))),
              ...rows.map((r) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(asText(r['title']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('${asText(r['subject_name'])} · ${asText(r['teacher_name'])}'),
                        const Divider(),
                        Text('Максимум бал: ${asText(r['max_score'])}'),
                        Text('Ўқувчи бали: ${asText(r['score'])}'),
                        Text('Фоиз: ${asText(r['percentage'])}%'),
                        Text('Баҳо: ${asText(r['grade'])}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Сана: ${epochDateTime(r['end_time'])}'),
                      ]),
                    ),
                  )),
            ]),
          );
        },
      );
}
