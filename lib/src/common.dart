import 'package:flutter/material.dart';

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String humanDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

String epochDateTime(dynamic value) {
  final n = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  if (n <= 0) return '—';
  final d = DateTime.fromMillisecondsSinceEpoch(n * 1000).toLocal();
  return '${humanDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

num asNum(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;
int asInt(dynamic v) => asNum(v).toInt();
String asText(dynamic v, [String fallback = '']) => v == null ? fallback : '$v';

String roleLabel(String role) {
  switch (role) {
    case 'student':
      return 'Ўқувчи';
    case 'teacher':
      return 'Ўқитувчи';
    case 'assistant':
      return 'Ассистент';
    case 'admin':
      return 'Админ';
    case 'methodologist':
      return 'Методист';
    default:
      return role;
  }
}

String attendanceLabel(String status) {
  switch (status) {
    case 'present':
      return 'Келди';
    case 'absent':
      return 'Келмади';
    case 'late':
      return 'Кечикди';
    default:
      return 'Белгиланмаган';
  }
}

IconData attendanceIcon(String status) {
  switch (status) {
    case 'present':
      return Icons.check_circle_outline;
    case 'absent':
      return Icons.cancel_outlined;
    case 'late':
      return Icons.schedule;
    default:
      return Icons.help_outline;
  }
}

void showMessage(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ),
  );
}

Future<DateTime?> pickDate(BuildContext context, DateTime current) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: current.isAfter(now) ? now : current,
    firstDate: DateTime(now.year - 5),
    lastDate: now,
  );
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.text = 'Юкланмоқда...'});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 14),
            Text(text),
          ],
        ),
      );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Қайта уриниш')),
            ],
          ),
        ),
      );
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.title, required this.value, required this.icon});
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(child: Icon(icon)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                Text(title, style: Theme.of(context).textTheme.bodySmall),
              ])),
            ],
          ),
        ),
      );
}
