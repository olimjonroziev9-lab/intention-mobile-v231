import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';
import 'common.dart';
import 'config.dart';
import 'session.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _busy = false;

  Future<void> _linkTelegram() async {
    final session = SessionScope.of(context);
    setState(() => _busy = true);
    try {
      final data = Map<String, dynamic>.from(await session.api.post('telegram/link') as Map);
      final url = Uri.tryParse('${data['url'] ?? ''}');
      if (url == null) throw ApiException('Telegram ҳаволаси олинмади.');
      final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!ok && mounted) showMessage(context, 'Telegram очилмади.', error: true);
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final u = session.user;
    final telegram = asText(u['telegram_id']);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const CircleAvatar(radius: 28, child: Icon(Icons.person, size: 30)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(asText(u['full_name'], 'Фойдаланувчи'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(roleLabel(session.role)),
                ])),
              ]),
              const Divider(height: 30),
              _line('Логин', asText(u['login'], '—')),
              _line('Телефон', asText(u['phone'], '—')),
              _line('Telegram ID', telegram.isEmpty ? 'Боғланмаган' : telegram),
            ]),
          ),
        ),
        ...[
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _busy ? null : _linkTelegram,
            icon: const Icon(Icons.telegram),
            label: const Text('Telegram’ни боғлаш'),
          ),
          if (session.role == 'student' && telegram.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Telegram боғланиши ўқувчи томонидан узилмайди. Алмаштириш учун админга мурожаат қилинг.'),
            ),
        ],
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => launchUrl(Uri.parse(AppConfig.website), mode: LaunchMode.externalApplication),
          icon: const Icon(Icons.language),
          label: const Text('Веб-сайтни очиш'),
        ),
        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          onPressed: session.busy ? null : session.logout,
          icon: const Icon(Icons.logout),
          label: const Text('Чиқиш'),
        ),
      ],
    );
  }

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value)),
        ]),
      );
}
