import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../api/models/agent_run.dart';
import '../api/models/work_item.dart';
import '../api/models/work_item_comment.dart';
import '../widgets/status_chip.dart';

class WorkItemDetailScreen extends StatefulWidget {
  const WorkItemDetailScreen({
    required this.api,
    required this.workItemId,
    super.key,
  });

  final ApiClient api;
  final String workItemId;

  @override
  State<WorkItemDetailScreen> createState() => _WorkItemDetailScreenState();
}

class _WorkItemDetailScreenState extends State<WorkItemDetailScreen> {
  late Future<_Bundle> _future = _load();

  Future<_Bundle> _load() async {
    final results = await Future.wait([
      widget.api.getWorkItem(widget.workItemId),
      widget.api.listComments(widget.workItemId),
      widget.api.listRunsForWorkItem(widget.workItemId),
    ]);
    return _Bundle(
      item: results[0] as WorkItem,
      comments: results[1] as List<WorkItemComment>,
      runs: results[2] as List<AgentRun>,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _kickoff() async {
    final runId = await widget.api.kickoffRun(widget.workItemId);
    if (!mounted) return;
    GoRouter.of(context).go('/runs/$runId');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Bundle>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final b = snap.data!;
        final fmt = DateFormat.yMMMd().add_jm();
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => GoRouter.of(context).go('/work-items'),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      b.item.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _kickoff,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Run agent'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  StatusChip(b.item.type),
                  StatusChip(b.item.state, tone: toneForState(b.item.state)),
                  StatusChip(b.item.severity,
                      tone: toneForSeverity(b.item.severity)),
                  StatusChip('P${b.item.priority}'),
                  StatusChip(b.item.areaPath),
                ],
              ),
              const SizedBox(height: 24),
              if (b.item.description != null)
                _Section('Description', child: Text(b.item.description!)),
              if (b.item.reproSteps != null)
                _Section(
                  'Repro steps',
                  child: _Mono(text: b.item.reproSteps!),
                ),
              if (b.item.systemInfo != null)
                _Section(
                  'System info',
                  child: _Mono(text: b.item.systemInfo!),
                ),
              _Section(
                'Agent runs',
                child: b.runs.isEmpty
                    ? const Text('No runs yet.')
                    : Column(
                        children: [
                          for (final r in b.runs)
                            ListTile(
                              onTap: () =>
                                  GoRouter.of(context).go('/runs/${r.id}'),
                              dense: true,
                              leading: Icon(_statusIcon(r.status)),
                              title: Text('Run ${r.id.substring(0, 8)} '
                                  'on ${r.model}'),
                              subtitle: Text(
                                'Started ${fmt.format(r.startedAt.toLocal())}'
                                '${r.finishedAt == null ? '' : ' · finished ${fmt.format(r.finishedAt!.toLocal())}'}',
                              ),
                              trailing: StatusChip(r.status,
                                  tone: toneForState(r.status)),
                            ),
                        ],
                      ),
              ),
              _Section(
                'Comments',
                child: b.comments.isEmpty
                    ? const Text('No comments yet.')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final c in b.comments) _CommentTile(comment: c),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _statusIcon(String s) => switch (s) {
        'done' => Icons.check_circle_outline,
        'failed' => Icons.error_outline,
        'blocked' => Icons.pause_circle_outline,
        'running' => Icons.autorenew,
        _ => Icons.hourglass_empty,
      };
}

class _Bundle {
  _Bundle({required this.item, required this.comments, required this.runs});
  final WorkItem item;
  final List<WorkItemComment> comments;
  final List<AgentRun> runs;
}

class _Section extends StatelessWidget {
  const _Section(this.title, {required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _Mono extends StatelessWidget {
  const _Mono({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      width: double.infinity,
      child: SelectableText(
        text,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});
  final WorkItemComment comment;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMd().add_jm();
    final isAgent = comment.author == 'agent';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAgent ? const Color(0xFFEFF6FF) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isAgent
              ? const Color(0xFFBFDBFE)
              : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor:
                    isAgent ? const Color(0xFF1E3A8A) : Colors.black54,
                child: Icon(
                  isAgent ? Icons.smart_toy_outlined : Icons.person_outline,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(comment.author,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(fmt.format(comment.createdAt.toLocal()),
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(comment.body),
        ],
      ),
    );
  }
}
