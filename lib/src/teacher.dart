import 'package:flutter/material.dart';
import 'common.dart';
import 'session.dart';

class TeacherAssignmentsScreen extends StatefulWidget {
  const TeacherAssignmentsScreen({super.key});
  @override
  State<TeacherAssignmentsScreen> createState() => _TeacherAssignmentsScreenState();
}

class _TeacherAssignmentsScreenState extends State<TeacherAssignmentsScreen> {
  Future<List<Map<String, dynamic>>>? _future;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final d = Map<String, dynamic>.from(await SessionScope.of(context).api.get('journal/assignments') as Map);
    return (d['assignments'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) return ErrorView(message: '${snap.error}', onRetry: _reload);
          final rows = snap.data ?? const [];
          return RefreshIndicator(
            onRefresh: () async { _reload(); await _future; },
            child: rows.isEmpty
                ? ListView(children: const [SizedBox(height: 160), Center(child: Text('Синф ва фан бириктирилмаган.'))])
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: rows.length,
                    itemBuilder: (context, i) {
                      final a = rows[i];
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.menu_book_outlined)),
                          title: Text(asText(a['class_name']), style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(asText(a['subject_name'])),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => JournalEditorScreen(
                            classId: asInt(a['class_id']),
                            subjectId: asInt(a['subject_id']),
                            className: asText(a['class_name']),
                            subjectName: asText(a['subject_name']),
                          ))),
                        ),
                      );
                    },
                  ),
          );
        },
      );
}

class JournalEditorScreen extends StatefulWidget {
  const JournalEditorScreen({
    super.key,
    required this.classId,
    required this.subjectId,
    required this.className,
    required this.subjectName,
  });
  final int classId;
  final int subjectId;
  final String className;
  final String subjectName;

  @override
  State<JournalEditorScreen> createState() => _JournalEditorScreenState();
}

class _JournalEditorScreenState extends State<JournalEditorScreen> {
  DateTime _date = DateTime.now();
  int _period = 1;
  final _homework = TextEditingController();
  final _manualTopic = TextEditingController();
  List<Map<String, dynamic>> _workPlans = [];
  int _workPlanId = 0;
  final Map<int, String> _teacherStatus = {};
  final Map<int, String> _grade = {};
  final Map<int, TextEditingController> _notes = {};
  List<Map<String, dynamic>> _students = [];
  Future<Map<String, dynamic>>? _future;
  bool _busy = false;
  String _gradingMode = 'five';
  bool _assistantDispatchReady = false;
  String _assistantDispatchHash = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final d = Map<String, dynamic>.from(await SessionScope.of(context).api.get('journal', query: {
      'class_id': widget.classId,
      'subject_id': widget.subjectId,
      'date': ymd(_date),
      'period_no': _period,
    }) as Map);
    _students = (d['students'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final lesson = d['lesson'] is Map ? Map<String, dynamic>.from(d['lesson'] as Map) : <String, dynamic>{};
    _workPlans = (d['work_plans'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    _workPlanId = asInt(lesson['work_plan_id']);
    _manualTopic.text = _workPlanId > 0 ? '' : asText(lesson['topic']);
    final homework = d['homework'] is Map ? Map<String, dynamic>.from(d['homework'] as Map) : <String, dynamic>{};
    _homework.text = asText(homework['text']);
    _gradingMode = asText(lesson['grading_mode'], 'five') == 'hundred' ? 'hundred' : 'five';
    for (final s in _students) {
      final id = asInt(s['id']);
      final suggested = asText(s['suggested_teacher_status'], 'present');
      _teacherStatus[id] = asText(s['teacher_status']).isEmpty ? suggested : asText(s['teacher_status']);
      _grade[id] = s['grade'] == null ? '' : asText(s['grade']);
      _notes[id]?.dispose();
      _notes[id] = TextEditingController(text: asText(s['teacher_note']));
    }
    _assistantDispatchReady = false;
    _assistantDispatchHash = '';
    return d;
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _changeDate() async {
    final d = await pickDate(context, _date);
    if (d != null) setState(() { _date = d; _assistantDispatchReady=false;_assistantDispatchHash='';_future = _load(); });
  }

  List<Map<String, dynamic>> _items() => _students.map((s) {
        final id = asInt(s['id']);
        final status = _teacherStatus[id] ?? 'present';
        return {
          'student_id': id,
          'attendance_status': status,
          'grade': status == 'absent' || (_grade[id] ?? '').trim().isEmpty
              ? null
              : num.tryParse((_grade[id] ?? '').trim().replaceAll(',', '.')),
          'note': _notes[id]?.text.trim() ?? '',
        };
      }).toList();

  Future<void> _sendAttendanceToAssistants() async {
    setState(() => _busy = true);
    try {
      final data=Map<String,dynamic>.from(await SessionScope.of(context).api.post('journal/send-attendance-to-assistants',body:{
        'class_id':widget.classId,'subject_id':widget.subjectId,'date':ymd(_date),'period_no':_period,'items':_items(),
      }) as Map);
      if(!mounted)return;
      setState(() {_assistantDispatchReady=true;_assistantDispatchHash=asText(data['dispatch_hash']);});
      showMessage(context,asText(data['message'],'Давомат ассистентга юборилди.'));
    } catch(e) {
      if(mounted)showMessage(context,'$e',error:true);
    } finally {
      if(mounted)setState(() => _busy=false);
    }
  }

  String? _validateGrades() {
    for (final s in _students) {
      final id = asInt(s['id']);
      if ((_teacherStatus[id] ?? 'present') == 'absent') continue;
      final raw = (_grade[id] ?? '').trim();
      if (raw.isEmpty) continue;
      final value = num.tryParse(raw.replaceAll(',', '.'));
      final name = asText(s['full_name']);
      if (value == null) return '$name: баҳо рақам бўлиши керак.';
      if (_gradingMode == 'five') {
        if (value != value.roundToDouble() || value < 2 || value > 5) {
          return '$name: 5 баллик баҳолашда фақат 2, 3, 4 ёки 5 танланади.';
        }
      } else if (value < 0 || value > 100) {
        return '$name: 100 баллик баҳолашда балл 0 дан 100 гача бўлиши керак.';
      }
    }
    return null;
  }

  Future<void> _save() async {
    if(_workPlanId < 1 && _manualTopic.text.trim().isEmpty){showMessage(context,'Иш режадан мавзуни танланг ёки мавзуни ҳозир киритинг.',error:true);return;}
    final gradeError = _validateGrades();
    if (gradeError != null) { showMessage(context, gradeError, error:true); return; }
    if(!_assistantDispatchReady){showMessage(context,'Аввал «Давоматни ассистентга жўнатиш» тугмасини босинг.',error:true);return;}
    setState(() => _busy = true);
    try {
      await SessionScope.of(context).api.post('journal/save', body: {
        'class_id': widget.classId,
        'subject_id': widget.subjectId,
        'date': ymd(_date),
        'period_no': _period,
        'work_plan_id': _workPlanId,
        'manual_topic': _manualTopic.text.trim(),
        'homework_text': _homework.text.trim(),
        'grading_mode': _gradingMode,
        'items': _items(),
        'assistant_dispatch_hash': _assistantDispatchHash,
      });
      if (mounted) showMessage(context, 'Журнал сақланди.');
      _reload();
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _homework.dispose();
    _manualTopic.dispose();
    for (final c in _notes.values) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('${widget.className} · ${widget.subjectName}')),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const LoadingView();
            if (snap.hasError) return ErrorView(message: '${snap.error}', onRetry: _reload);
            return Column(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _changeDate,
                        icon: const Icon(Icons.calendar_month),
                        label: Text(humanDate(_date)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<int>(
                        value: _period,
                        decoration: const InputDecoration(labelText: 'Дарс', border: OutlineInputBorder(), isDense: true),
                        items: [for (var i = 1; i <= 12; i++) DropdownMenuItem(value: i, child: Text('$i-дарс'))],
                        onChanged: _busy ? null : (v) { if (v != null) setState(() { _period = v; _assistantDispatchReady=false;_assistantDispatchHash='';_future = _load(); }); },
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: _workPlanId > 0 && _workPlans.any((p) => asInt(p['id']) == _workPlanId) ? _workPlanId : 0,
                    decoration: const InputDecoration(labelText: 'Мавзуни танланг ёки ҳозир киритинг', border: OutlineInputBorder(), isDense: true),
                    items: [
                      const DropdownMenuItem<int>(value: 0, child: Text('✍ Мавзуни ҳозир киритиш')),
                      ..._workPlans.map((p) => DropdownMenuItem<int>(
                        value: asInt(p['id']),
                        child: Text('${asText(p['topic'])} · режада ${asText(p['lesson_date'])}'),
                      )),
                    ],
                    onChanged: _busy ? null : (v) => setState(() => _workPlanId = v ?? 0),
                  ),
                  if (_workPlanId == 0) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _manualTopic,
                      maxLength: 255,
                      decoration: const InputDecoration(labelText: 'Дарс мавзусини ҳозир киритинг', border: OutlineInputBorder(), isDense: true),
                    ),
                  ],
                  if (_workPlans.isEmpty) const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Align(alignment: Alignment.centerLeft, child: Text('Тасдиқланган иш режа йўқ — мавзуни ҳозир киритиш мумкин.', style: TextStyle(color: Colors.deepOrange))),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _homework,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Уй вазифаси', border: OutlineInputBorder(), isDense: true),
                  ),
                  const SizedBox(height: 10),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Баҳолаш варианти',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text('5 баллик'),
                          value: _gradingMode == 'five',
                          onChanged: _busy ? null : (_) => setState(() {
                            _gradingMode = 'five';
                            for (final id in _grade.keys.toList()) {
                              final raw = (_grade[id] ?? '').trim();
                              final n = num.tryParse(raw.replaceAll(',', '.'));
                              if (n != null && (n < 2 || n > 5 || n != n.roundToDouble())) _grade[id] = '';
                            }
                          }),
                        ),
                      ),
                      Expanded(
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text('100 баллик'),
                          value: _gradingMode == 'hundred',
                          onChanged: _busy ? null : (_) => setState(() => _gradingMode = 'hundred'),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  itemCount: _students.length,
                  itemBuilder: (context, i) {
                    final s = _students[i];
                    final id = asInt(s['id']);
                    final assistant = asText(s['assistant_status']);
                    final teacher = _teacherStatus[id] ?? 'present';
                    final diff = assistant.isNotEmpty && assistant != teacher;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${i + 1}. ${asText(s['full_name'])}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                if (diff) const Text('⚠ Давоматда фарқ бор', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w700)),
                              ]),
                            ),
                            if (diff) const Tooltip(message: 'Ассистент ва устоз давомати фарқ қилади', child: Icon(Icons.warning_amber_rounded, color: Colors.deepOrange)),
                          ]),
                          const SizedBox(height: 6),
                          Row(children: [
                            const Text('Ассистент: ', style: TextStyle(fontWeight: FontWeight.w600)),
                            Icon(attendanceIcon(assistant), size: 18),
                            const SizedBox(width: 4),
                            Text(attendanceLabel(assistant)),
                          ]),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: teacher,
                            decoration: const InputDecoration(labelText: 'Устоз давомати', border: OutlineInputBorder(), isDense: true),
                            items: const [
                              DropdownMenuItem(value: 'present', child: Text('Келди')),
                              DropdownMenuItem(value: 'absent', child: Text('Келмади')),
                              DropdownMenuItem(value: 'late', child: Text('Кечикди')),
                            ],
                            onChanged: _busy ? null : (v) => setState(() {
                              if (v != null) {
                                _teacherStatus[id] = v;
                                if (v == 'absent') _grade[id] = '';
                                _assistantDispatchReady = false;
                                _assistantDispatchHash = '';
                              }
                            }),
                          ),
                          const SizedBox(height: 10),
                          Row(children: [
                            SizedBox(
                              width: 125,
                              child: _gradingMode == 'five'
                                ? DropdownButtonFormField<String>(
                                    value: (_grade[id] ?? '').isEmpty ? null : _grade[id],
                                    decoration: const InputDecoration(labelText: 'Баҳо', border: OutlineInputBorder(), isDense: true),
                                    items: const [
                                      DropdownMenuItem(value: '2', child: Text('2')),
                                      DropdownMenuItem(value: '3', child: Text('3')),
                                      DropdownMenuItem(value: '4', child: Text('4')),
                                      DropdownMenuItem(value: '5', child: Text('5')),
                                    ],
                                    onChanged: _busy || teacher == 'absent' ? null : (v) => setState(() => _grade[id] = v ?? ''),
                                  )
                                : TextFormField(
                                    key: ValueKey('hundred-grade-${id}'),
                                    initialValue: _grade[id] ?? '',
                                    enabled: !_busy && teacher != 'absent',
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(labelText: 'Балл (0–100)', border: OutlineInputBorder(), isDense: true),
                                    onChanged: (value) => _grade[id] = value,
                                  ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _notes[id],
                                enabled: !_busy,
                                decoration: const InputDecoration(labelText: 'Изоҳ', border: OutlineInputBorder(), isDense: true),
                              ),
                            ),
                          ]),
                        ]),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    SizedBox(width: double.infinity,child: OutlinedButton.icon(
                      onPressed: _busy ? null : _sendAttendanceToAssistants,
                      icon: const Icon(Icons.send_outlined),
                      label: Text(_assistantDispatchReady ? 'Ассистентга юборилди' : 'Давоматни ассистентга жўнатиш'),
                    )),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy || !_assistantDispatchReady ? null : _save,
                        icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
                        label: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Журнални сақлаш')),
                      ),
                    ),
                  ]),
                ),
              ),
            ]);
          },
        ),
      );
}

class TeacherMonthlyGradesScreen extends StatefulWidget { const TeacherMonthlyGradesScreen({super.key}); @override State<TeacherMonthlyGradesScreen> createState()=>_TeacherMonthlyGradesScreenState(); }
class _TeacherMonthlyGradesScreenState extends State<TeacherMonthlyGradesScreen>{
  Future<List<Map<String,dynamic>>>? _assignments; Future<List<Map<String,dynamic>>>? _rows; int _classId=0,_subjectId=0; DateTime _month=DateTime.now();
  @override void didChangeDependencies(){super.didChangeDependencies();_assignments??=_loadAssignments();}
  Future<List<Map<String,dynamic>>> _loadAssignments() async {final d=Map<String,dynamic>.from(await SessionScope.of(context).api.get('journal/assignments') as Map);return (d['assignments']as List? ??const[]).map((x)=>Map<String,dynamic>.from(x as Map)).toList();}
  Future<List<Map<String,dynamic>>> _loadRows() async {final d=Map<String,dynamic>.from(await SessionScope.of(context).api.get('journal/monthly-grades',query:{'class_id':_classId,'subject_id':_subjectId,'month':'${_month.year.toString().padLeft(4,'0')}-${_month.month.toString().padLeft(2,'0')}'}) as Map);return (d['rows']as List? ??const[]).map((x)=>Map<String,dynamic>.from(x as Map)).toList();}
  @override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,dynamic>>>(future:_assignments,builder:(context,snap){if(snap.connectionState!=ConnectionState.done)return const LoadingView();if(snap.hasError)return ErrorView(message:'${snap.error}',onRetry:()=>setState(()=>_assignments=_loadAssignments()));final a=snap.data??const[];return ListView(padding:const EdgeInsets.all(12),children:[DropdownButtonFormField<int>(value:_classId==0?null:_classId,decoration:const InputDecoration(labelText:'Синф'),items:a.map((x)=>DropdownMenuItem(value:asInt(x['class_id']),child:Text(asText(x['class_name'])))).toList(),onChanged:(v)=>setState(()=>_classId=v??0)),const SizedBox(height:8),DropdownButtonFormField<int>(value:_subjectId==0?null:_subjectId,decoration:const InputDecoration(labelText:'Фан'),items:a.where((x)=>_classId==0||asInt(x['class_id'])==_classId).map((x)=>DropdownMenuItem(value:asInt(x['subject_id']),child:Text(asText(x['subject_name'])))).toList(),onChanged:(v)=>setState(()=>_subjectId=v??0)),const SizedBox(height:8),OutlinedButton.icon(icon:const Icon(Icons.calendar_month),label:Text('${_month.year}-${_month.month.toString().padLeft(2,'0')}'),onPressed:()async{final d=await showDatePicker(context:context,initialDate:_month,firstDate:DateTime(2020),lastDate:DateTime.now());if(d!=null)setState(()=>_month=d);}),FilledButton(onPressed:_classId<1||_subjectId<1?null:()=>setState(()=>_rows=_loadRows()),child:const Text('Ойлик баҳоларни кўриш')),if(_rows!=null)FutureBuilder<List<Map<String,dynamic>>>(future:_rows,builder:(context,r){if(r.connectionState!=ConnectionState.done)return const Padding(padding:EdgeInsets.all(24),child:Center(child:CircularProgressIndicator()));if(r.hasError)return ErrorView(message:'${r.error}',onRetry:()=>setState(()=>_rows=_loadRows()));return Column(children:(r.data??const[]).map((x)=>ListTile(title:Text(asText(x['full_name'])),subtitle:Text('${asText(x['journal_date'],'—')} · ${asInt(x['period_no'])}-дарс · ${asText(x['attendance_status'],'—')}'),trailing:Text(asText(x['grade'],'—')))).toList());})]);});
}

class TeacherHistoryScreen extends StatefulWidget {
  const TeacherHistoryScreen({super.key});
  @override
  State<TeacherHistoryScreen> createState() => _TeacherHistoryScreenState();
}

class _TeacherHistoryScreenState extends State<TeacherHistoryScreen> {
  Future<List<Map<String, dynamic>>>? _future;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final d = Map<String, dynamic>.from(await SessionScope.of(context).api.get('journal/history', query: {'limit': 100}) as Map);
    return (d['rows'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) return ErrorView(message: '${snap.error}', onRetry: _reload);
          final rows = snap.data ?? const [];
          return RefreshIndicator(
            onRefresh: () async { _reload(); await _future; },
            child: rows.isEmpty
                ? ListView(children: const [SizedBox(height: 160), Center(child: Text('Журнал тарихи йўқ.'))])
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: rows.length,
                    itemBuilder: (context, i) {
                      final r = rows[i];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${asText(r['class_name'])} · ${asText(r['subject_name'])}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('${asText(r['lesson_date'])} · ${asText(r['period_no'])}-дарс · ${asText(r['topic'], 'Мавзу киритилмаган')}'),
                            const Divider(),
                            Text('Ўқувчилар: ${asInt(r['students'])}'),
                            Text('Ассистент: келмади ${asInt(r['assistant_absent'])}, кечикди ${asInt(r['assistant_late'])}'),
                            Text('Устоз: келмади ${asInt(r['teacher_absent'])}, кечикди ${asInt(r['teacher_late'])}'),
                            Text('Давомат фарқи: ${asInt(r['attendance_diff'])}'),
                            Text('Ўртача баҳо: ${asText(r['avg_grade'], '—')}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      );
                    },
                  ),
          );
        },
      );
}
