import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';

class NewIncidentScreen extends StatefulWidget {
  const NewIncidentScreen({required this.api, super.key});
  final ApiClient api;

  @override
  State<NewIncidentScreen> createState() => _NewIncidentScreenState();
}

class _NewIncidentScreenState extends State<NewIncidentScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _repro = TextEditingController();
  final _systemInfo = TextEditingController();
  final _tags = TextEditingController();
  final _area = TextEditingController(text: 'Harness');
  final _iteration = TextEditingController(text: 'Harness\\Current');

  String _type = 'Bug';
  String _severity = '3 - Medium';
  int _priority = 2;
  bool _autorun = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _title,
      _description,
      _repro,
      _systemInfo,
      _tags,
      _area,
      _iteration,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await widget.api.createWorkItem(
        type: _type,
        title: _title.text.trim(),
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        reproSteps:
            _repro.text.trim().isEmpty ? null : _repro.text.trim(),
        systemInfo: _systemInfo.text.trim().isEmpty
            ? null
            : _systemInfo.text.trim(),
        severity: _severity,
        priority: _priority,
        areaPath: _area.text.trim(),
        iterationPath: _iteration.text.trim(),
        tags: _tags.text.trim().isEmpty ? null : _tags.text.trim(),
        autorun: _autorun,
      );
      if (!mounted) return;
      GoRouter.of(context).go('/work-items/${result.workItem.id}');
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _form,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('New incident',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Mirrors the Azure DevOps bug form. On submit the agent '
                'will plan and start work automatically.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                    ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _type,
                              decoration:
                                  const InputDecoration(labelText: 'Type'),
                              items: const [
                                DropdownMenuItem(
                                    value: 'Bug', child: Text('Bug')),
                                DropdownMenuItem(
                                    value: 'Incident',
                                    child: Text('Incident')),
                                DropdownMenuItem(
                                    value: 'Task', child: Text('Task')),
                                DropdownMenuItem(
                                    value: 'UserStory',
                                    child: Text('User Story')),
                              ],
                              onChanged: (v) =>
                                  setState(() => _type = v ?? 'Bug'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _severity,
                              decoration: const InputDecoration(
                                  labelText: 'Severity'),
                              items: const [
                                DropdownMenuItem(
                                    value: '1 - Critical',
                                    child: Text('1 - Critical')),
                                DropdownMenuItem(
                                    value: '2 - High',
                                    child: Text('2 - High')),
                                DropdownMenuItem(
                                    value: '3 - Medium',
                                    child: Text('3 - Medium')),
                                DropdownMenuItem(
                                    value: '4 - Low',
                                    child: Text('4 - Low')),
                              ],
                              onChanged: (v) => setState(
                                  () => _severity = v ?? '3 - Medium'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _priority,
                              decoration: const InputDecoration(
                                  labelText: 'Priority'),
                              items: const [
                                DropdownMenuItem(value: 1, child: Text('1')),
                                DropdownMenuItem(value: 2, child: Text('2')),
                                DropdownMenuItem(value: 3, child: Text('3')),
                                DropdownMenuItem(value: 4, child: Text('4')),
                              ],
                              onChanged: (v) =>
                                  setState(() => _priority = v ?? 2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _title,
                        decoration:
                            const InputDecoration(labelText: 'Title'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Title is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _description,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _repro,
                        minLines: 3,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: 'Repro steps',
                          alignLabelWithHint: true,
                          hintText: '1. ...\n2. ...\nExpected: ...\nActual: ...',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _systemInfo,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'System info',
                          alignLabelWithHint: true,
                          hintText: 'OS, browser/runtime version, region, ...',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _area,
                              decoration: const InputDecoration(
                                  labelText: 'Area path'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _iteration,
                              decoration: const InputDecoration(
                                  labelText: 'Iteration path'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _tags,
                        decoration: const InputDecoration(
                          labelText: 'Tags',
                          hintText: 'semicolon;separated;list',
                        ),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        value: _autorun,
                        onChanged: (v) => setState(() => _autorun = v),
                        title: const Text(
                            'Kick off the agent immediately on submit'),
                        subtitle: const Text(
                            'Disable to file the work item without planning.'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!,
                            style: TextStyle(
                                color:
                                    Theme.of(context).colorScheme.error)),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _submitting
                                ? null
                                : () =>
                                    GoRouter.of(context).go('/work-items'),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: _submitting ? null : _submit,
                            icon: _submitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white),
                                  )
                                : const Icon(Icons.send),
                            label: Text(
                                _submitting ? 'Submitting...' : 'Submit'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
