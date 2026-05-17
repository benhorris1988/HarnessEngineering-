import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../api/models/work_item.dart';
import '../widgets/status_chip.dart';

class WorkItemsScreen extends StatefulWidget {
  const WorkItemsScreen({required this.api, super.key});
  final ApiClient api;

  @override
  State<WorkItemsScreen> createState() => _WorkItemsScreenState();
}

class _WorkItemsScreenState extends State<WorkItemsScreen> {
  String? _stateFilter;
  late Future<List<WorkItem>> _future = _load();

  Future<List<WorkItem>> _load() => widget.api.listWorkItems(state: _stateFilter);

  void _setFilter(String? state) {
    setState(() {
      _stateFilter = state;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Work items',
                  style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => GoRouter.of(context).go('/work-items/new'),
                icon: const Icon(Icons.add),
                label: const Text('New incident'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final s in const ['All', 'New', 'Active', 'Resolved', 'Closed'])
                ChoiceChip(
                  label: Text(s),
                  selected: (_stateFilter ?? 'All') == s,
                  onSelected: (_) => _setFilter(s == 'All' ? null : s),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<WorkItem>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final items = snap.data ?? const <WorkItem>[];
                if (items.isEmpty) {
                  return const Center(child: Text('No work items.'));
                }
                final fmt = DateFormat.yMMMd().add_jm();
                return Card(
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final w = items[i];
                      return ListTile(
                        onTap: () =>
                            GoRouter.of(context).go('/work-items/${w.id}'),
                        title: Text(w.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              StatusChip(w.type),
                              StatusChip(w.state, tone: toneForState(w.state)),
                              StatusChip(w.severity,
                                  tone: toneForSeverity(w.severity)),
                              Text(
                                'P${w.priority} • ${fmt.format(w.createdAt.toLocal())}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
