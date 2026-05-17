import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {this.tone = ChipTone.neutral, super.key});

  final String label;
  final ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      ChipTone.neutral => (const Color(0xFFE5E7EB), const Color(0xFF1F2937)),
      ChipTone.info => (const Color(0xFFDBEAFE), const Color(0xFF1E3A8A)),
      ChipTone.warn => (const Color(0xFFFEF3C7), const Color(0xFF92400E)),
      ChipTone.danger => (const Color(0xFFFEE2E2), const Color(0xFF991B1B)),
      ChipTone.success => (const Color(0xFFDCFCE7), const Color(0xFF166534)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

enum ChipTone { neutral, info, warn, danger, success }

ChipTone toneForState(String state) {
  switch (state.toLowerCase()) {
    case 'new':
      return ChipTone.info;
    case 'active':
    case 'running':
      return ChipTone.warn;
    case 'resolved':
    case 'done':
      return ChipTone.success;
    case 'failed':
    case 'blocked':
      return ChipTone.danger;
    default:
      return ChipTone.neutral;
  }
}

ChipTone toneForSeverity(String severity) {
  if (severity.startsWith('1')) return ChipTone.danger;
  if (severity.startsWith('2')) return ChipTone.warn;
  return ChipTone.info;
}
