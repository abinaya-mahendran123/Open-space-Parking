import 'package:flutter/material.dart';

import 'package:open_space_parking/features/admin/domain/entities/document_verification_report.dart';

class DocumentVerificationChecklist extends StatelessWidget {
  const DocumentVerificationChecklist({
    super.key,
    required this.report,
    this.isLoading = false,
    this.error,
    this.onRetry,
  });

  final DocumentVerificationReport? report;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Running document cross-check (OCR)… this can take 1–3 minutes.',
              ),
            ),
          ],
        ),
      );
    }

    if (error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            error!,
            style: TextStyle(color: colorScheme.error, fontSize: 13),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry cross-check'),
            ),
          ],
        ],
      );
    }

    if (report == null) return const SizedBox.shrink();

    final scorePct = (report!.overallScore * 100).round();
    final docs = report!.documents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: report!.readyForQuickApproval
                ? colorScheme.secondaryContainer
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: report!.readyForQuickApproval
                  ? colorScheme.secondary.withValues(alpha: 0.45)
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    report!.readyForQuickApproval
                        ? Icons.task_alt
                        : Icons.fact_check_outlined,
                    color: report!.readyForQuickApproval
                        ? colorScheme.secondary
                        : colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      report!.readyForQuickApproval
                          ? 'Quick approval recommended'
                          : 'Manual review recommended',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Text(
                    '$scorePct%',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                docs.isNotEmpty
                    ? '${docs.where((d) => d.pass).length}/${docs.length} documents verified'
                    : '${report!.passCount}/${report!.totalChecks} checks passed',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (report!.extractedSurveyNumber?.isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Text(
                  'OCR: Survey ${report!.extractedSurveyNumber}'
                  '${report!.extractedDistrict?.isNotEmpty == true ? ' · ${report!.extractedDistrict}' : ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ),
        ),
        if (docs.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Per-document result',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          for (final doc in docs) ...[
            _DocumentResultCard(item: doc),
            const SizedBox(height: 8),
          ],
        ],
        const SizedBox(height: 4),
        Text(
          'Field checks',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        for (final check in report!.checks) _CheckRow(check: check),
      ],
    );
  }
}

class _DocumentResultCard extends StatelessWidget {
  const _DocumentResultCard({required this.item});

  final DocumentVerificationItem item;

  Color _statusColor(ColorScheme scheme) {
    if (!item.present) return scheme.error;
    if (item.pass) return scheme.secondary;
    return scheme.tertiary;
  }

  String get _statusLabel {
    if (!item.present) return 'Missing';
    if (item.pass) return 'Verified';
    return 'Mismatch';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = _statusColor(colorScheme);
    final pct = item.matchPercent.clamp(0, 100);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
        color: colorScheme.surface,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            !item.present
                ? Icons.cancel
                : item.pass
                    ? Icons.verified
                    : Icons.warning_amber_rounded,
            color: statusColor,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$_statusLabel · $pct%',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 6,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    color: statusColor,
                  ),
                ),
                if ((item.message ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.message!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check});

  final DocumentVerificationCheck check;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final icon = check.pass ? Icons.check_circle : Icons.warning_amber_rounded;
    final color = check.pass
        ? colorScheme.secondary
        : colorScheme.tertiary;
    final scorePct = check.score == null ? null : (check.score! * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        check.label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: check.severity == 'critical'
                                  ? FontWeight.w600
                                  : null,
                            ),
                      ),
                    ),
                    if (scorePct != null)
                      Text(
                        '$scorePct%',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                  ],
                ),
                if (check.found?.isNotEmpty == true)
                  Text(
                    'Found: ${check.found}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                if (check.expected?.isNotEmpty == true && !check.pass)
                  Text(
                    'Expected: ${check.expected}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                if (check.note?.isNotEmpty == true)
                  Text(
                    check.note!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
