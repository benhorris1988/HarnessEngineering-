import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../api/models/work_item.dart';
import '../widgets/status_chip.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({required this.api, super.key});
  final ApiClient api;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<WorkItem>> _future = widget.api.listWorkItems();

  Future<void> _refresh() async {
    setState(() {
      _future = widget.api.listWorkItems();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<WorkItem>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorState(error: snap.error!, onRetry: _refresh);
          }
          final items = snap.data ?? const <WorkItem>[];
          final byState = <String, int>{};
          for (final i in items) {
            byState[i.state] = (byState[i.state] ?? 0) + 1;
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Overview',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricCard(label: 'Total', value: '${items.length}'),
                  for (final entry in byState.entries)
                    _MetricCard(label: entry.key, value: '${entry.value}'),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Text('Recent work items',
                      style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () =>
                        GoRouter.of(context).go('/work-items/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('New incident'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final item in items.take(10))
                _WorkItemRow(item: item),
            ],
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.black54,
                    )),
            const SizedBox(height: 8),
            Text(value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
          ],
        ),
      ),
    );
  }
}

class _WorkItemRow extends StatelessWidget {
  const _WorkItemRow({required this.item});
  final WorkItem item;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMd().add_jm();
    return Card(
      child: ListTile(
        onTap: () => GoRouter.of(context).go('/work-items/${item.id}'),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEFF6FF),
          child: Icon(
            switch (item.type) {
              'Bug' => Icons.bug_report_outlined,
              'Incident' => Icons.report_problem_outlined,
              'Task' => Icons.check_circle_outline,
              _ => Icons.article_outlined,
            },
            color: const Color(0xFF1E3A8A),
          ),
        ),
        title: Text(item.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(item.state, tone: toneForState(item.state)),
              StatusChip(item.severity, tone: toneForSeverity(item.severity)),
              Text('${item.type} • ${fmt.format(item.createdAt.toLocal())}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48, color: Colors.black54),
          const SizedBox(height: 8),
          const Text('Could not reach the API server.'),
          const SizedBox(height: 4),
          Text('$error', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
