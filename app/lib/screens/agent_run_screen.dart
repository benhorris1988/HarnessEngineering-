import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../api/models/agent_message.dart';
import '../api/models/agent_run.dart';
import '../api/models/plan_step.dart';
import '../widgets/status_chip.dart';

class AgentRunScreen extends StatefulWidget {
  const AgentRunScreen({required this.api, required this.runId, super.key});
  final ApiClient api;
  final String runId;

  @override
  State<AgentRunScreen> createState() => _AgentRunScreenState();
}

class _AgentRunScreenState extends State<AgentRunScreen> {
  Timer? _poll;
  AgentRun? _run;
  List<PlanStep> _steps = const [];
  List<AgentMessage> _messages = const [];
  Object? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final results = await Future.wait([
        widget.api.getRun(widget.runId),
        widget.api.listSteps(widget.runId),
        widget.api.listMessages(widget.runId),
      ]);
      if (!mounted) return;
      setState(() {
        _run = results[0] as AgentRun;
        _steps = results[1] as List<PlanStep>;
        _messages = results[2] as List<AgentMessage>;
        _error = null;
        if (_run!.isTerminal) _poll?.cancel();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_run == null && _error != null) {
      return Center(child: Text('Error: $_error'));
    }
    if (_run == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final run = _run!;
    final fmt = DateFormat.yMMMd().add_jms();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () =>
                    GoRouter.of(context).go('/work-items/${run.workItemId}'),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 4),
              Text('Agent run',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(width: 12),
              StatusChip(run.status, tone: toneForState(run.status)),
              const Spacer(),
              if (!run.isTerminal)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              Text('Model ${run.model}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Started ${fmt.format(run.startedAt.toLocal())}'
            '${run.finishedAt == null ? '' : ' · finished ${fmt.format(run.finishedAt!.toLocal())}'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (run.summary != null && run.summary!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              color: const Color(0xFFECFDF5),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.flag_outlined, color: Color(0xFF166534)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(run.summary!)),
                  ],
                ),
              ),
            ),
          ],
          if (run.error != null) ...[
            const SizedBox(height: 12),
            Card(
              color: const Color(0xFFFEF2F2),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(run.error!,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Color(0xFF991B1B))),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                final plan = _PlanColumn(steps: _steps);
                final transcript = _TranscriptColumn(messages: _messages);
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 2, child: plan),
                      const SizedBox(width: 16),
                      Expanded(flex: 3, child: transcript),
                    ],
                  );
                }
                return Column(
                  children: [
                    SizedBox(height: 280, child: plan),
                    const SizedBox(height: 16),
                    Expanded(child: transcript),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanColumn extends StatelessWidget {
  const _PlanColumn({required this.steps});
  final List<PlanStep> steps;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('Plan',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
          const Divider(height: 1),
          Expanded(
            child: steps.isEmpty
                ? const Center(child: Text('Waiting for planner...'))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: steps.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final s = steps[i];
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: _bgForStatus(s.status),
                          child: Text('${s.ordinal + 1}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                        title: Text(s.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w500)),
                        subtitle: s.rationale == null
                            ? null
                            : Text(s.rationale!,
                                style: Theme.of(context).textTheme.bodySmall),
                        trailing: StatusChip(s.status,
                            tone: toneForState(s.status)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _bgForStatus(String status) => switch (status) {
        'done' => const Color(0xFF166534),
        'running' => const Color(0xFFB45309),
        'failed' => const Color(0xFF991B1B),
        _ => Colors.black54,
      };
}

class _TranscriptColumn extends StatelessWidget {
  const _TranscriptColumn({required this.messages});
  final List<AgentMessage> messages;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('Transcript',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
          const Divider(height: 1),
          Expanded(
            child: messages.isEmpty
                ? const Center(child: Text('No messages yet.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) =>
                        _MessageBubble(message: messages[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final AgentMessage message;

  @override
  Widget build(BuildContext context) {
    final (bg, icon, label) = switch (message.role) {
      'assistant' => (
        const Color(0xFFEFF6FF),
        Icons.smart_toy_outlined,
        'assistant',
      ),
      'tool' => (
        const Color(0xFFF1F5F9),
        Icons.build_outlined,
        message.toolName ?? 'tool',
      ),
      'system' => (
        const Color(0xFFFFFBEB),
        Icons.info_outline,
        'system',
      ),
      _ => (const Color(0xFFFAFAFA), Icons.person_outline, message.role),
    };
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.black54),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 12)),
              const Spacer(),
              Text(
                DateFormat.Hms().format(message.createdAt.toLocal()),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            message.content,
            style: TextStyle(
              fontFamily: message.role == 'tool' ? 'monospace' : null,
              fontSize: message.role == 'tool' ? 12 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
