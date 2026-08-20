import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:open_space_parking/core/domain/domain_extensions.dart';
import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';
import 'package:open_space_parking/core/widgets/dialogs/app_dialogs.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/core/widgets/textfields/app_text_field.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/employee/presentation/providers/employee_providers.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_details.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_request.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/request_status.dart';

class EmployeeTicketDetailPage extends ConsumerStatefulWidget {
  const EmployeeTicketDetailPage({super.key, required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<EmployeeTicketDetailPage> createState() =>
      _EmployeeTicketDetailPageState();
}

class _EmployeeTicketDetailPageState
    extends ConsumerState<EmployeeTicketDetailPage> {
  static final _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
  final _navNotesController = TextEditingController();
  final _quoteAmountController = TextEditingController();
  final _materialsController = TextEditingController();
  final _laborController = TextEditingController();
  final _timelineController = TextEditingController();
  final _quoteDescController = TextEditingController();
  final _progressController = TextEditingController();
  final _progressNotesController = TextEditingController();

  @override
  void dispose() {
    _navNotesController.dispose();
    _quoteAmountController.dispose();
    _materialsController.dispose();
    _laborController.dispose();
    _timelineController.dispose();
    _quoteDescController.dispose();
    _progressController.dispose();
    _progressNotesController.dispose();
    super.dispose();
  }

  void _syncControllers(LandOwnerRequest ticket) {
    if (_navNotesController.text.isEmpty && ticket.navigationNotes != null) {
      _navNotesController.text = ticket.navigationNotes!;
    }
    if (_progressController.text.isEmpty) {
      _progressController.text = '${ticket.constructionProgress}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final employeeId = ref.watch(authStateProvider).session?.userId ?? '';
    final ticketAsync = ref.watch(
      employeeTicketProvider((ticketId: widget.ticketId, employeeId: employeeId)),
    );
    final quotationAsync = ref.watch(ticketQuotationProvider(widget.ticketId));
    final progressAsync = ref.watch(progressHistoryProvider(widget.ticketId));
    final isLoading = ref.watch(employeeLoadingProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.ticketId)),
      body: ticketAsync.when(
        loading: () => const AppLoadingWidget(),
        error: (_, __) => AppErrorWidget(
          message: 'Failed to load ticket',
          onRetry: () => ref.invalidate(
            employeeTicketProvider(
              (ticketId: widget.ticketId, employeeId: employeeId),
            ),
          ),
        ),
        data: (ticket) {
          if (ticket == null) {
            return const Center(child: Text('Ticket not found or not assigned to you.'));
          }
          _syncControllers(ticket);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Section(
                title: 'Ticket Summary',
                children: [
                  _Row('Status', ticket.status.label),
                  _Row('Type', ticket.requestType.label),
                  _Row('Progress', '${ticket.constructionProgress}%'),
                  _Row(
                    'Submitted',
                    _dateFormat.format(ticket.submittedAt.toLocal()),
                  ),
                ],
              ),
              _Section(
                title: 'Owner Details',
                children: [
                  _Row('Name', ticket.ownerDetails.fullName),
                  _Row('Email', ticket.ownerDetails.email),
                  _Row('Phone', ticket.ownerDetails.phone),
                  _Row('Address', ticket.ownerDetails.address),
                ],
              ),
              _LandLocationCard(landDetails: ticket.landDetails),
              _Section(
                title: 'Land Details',
                children: [
                  _Row('Area', '${ticket.landDetails.areaSqFt} sq ft'),
                  _Row('Road Access', ticket.landDetails.roadAccess ? 'Yes' : 'No'),
                  _Row('Drainage', ticket.landDetails.drainage ? 'Yes' : 'No'),
                  _Row('Flood Risk', ticket.landDetails.flood ? 'Yes' : 'No'),
                  _Row('Boundary', ticket.landDetails.boundary ? 'Yes' : 'No'),
                  _Row('CCTV', ticket.landDetails.cctv ? 'Yes' : 'No'),
                ],
              ),
              _Section(
                title: 'Document verification',
                children: [
                  _Row(
                    'Status',
                    ticket.documentsVerified ? 'Verified' : 'Pending',
                  ),
                  const SizedBox(height: 8),
                  if (!ticket.documentsVerified)
                    PrimaryButton(
                      label: 'Verify documents & list nearby',
                      isLoading: isLoading,
                      onPressed: () => _verifyDocuments(ticket),
                    )
                  else
                    const Text(
                      'Verified. This parking can appear in nearby search.',
                    ),
                ],
              ),
              _Section(
                title: 'Navigation Notes',
                children: [
                  AppTextField(
                    controller: _navNotesController,
                    label: 'Site access / navigation notes',
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: 'Save Navigation Notes',
                    isLoading: isLoading,
                    onPressed: () => _saveNavigation(ticket),
                  ),
                ],
              ),
              quotationAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (quotation) {
                  if (quotation != null) {
                    return _Section(
                      title: 'Quotation',
                      children: [
                        _Row('Total', '₹${quotation.amount.toStringAsFixed(2)}'),
                        _Row(
                          'Materials',
                          '₹${quotation.materialsCost.toStringAsFixed(2)}',
                        ),
                        _Row(
                          'Labor',
                          '₹${quotation.laborCost.toStringAsFixed(2)}',
                        ),
                        _Row('Timeline', '${quotation.timelineDays} days'),
                        _Row('Notes', quotation.description),
                      ],
                    );
                  }

                  return _Section(
                    title: 'Submit Quotation',
                    children: [
                      AppTextField(
                        controller: _quoteAmountController,
                        label: 'Total Amount',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _materialsController,
                        label: 'Materials Cost',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _laborController,
                        label: 'Labor Cost',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _timelineController,
                        label: 'Timeline (days)',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _quoteDescController,
                        label: 'Description',
                      ),
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: 'Submit Quotation',
                        isLoading: isLoading,
                        onPressed: () => _submitQuotation(ticket),
                      ),
                    ],
                  );
                },
              ),
              _Section(
                title: 'Construction Progress',
                children: [
                  LinearProgressIndicator(
                    value: ticket.constructionProgress / 100,
                  ),
                  const SizedBox(height: 8),
                  Text('Current: ${ticket.constructionProgress}%'),
                  const SizedBox(height: 12),
                  if (ticket.status != RequestStatus.completed) ...[
                    AppTextField(
                      controller: _progressController,
                      label: 'Progress % (0-100)',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _progressNotesController,
                      label: 'Progress notes',
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: 'Update Progress',
                      isLoading: isLoading,
                      onPressed: () => _updateProgress(ticket),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: isLoading
                          ? null
                          : () => _markCompleted(ticket),
                      icon: const Icon(Icons.task_alt),
                      label: const Text('Mark Project Completed'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text('Progress History', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  progressAsync.when(
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) => const Text('Could not load history'),
                    data: (entries) {
                      if (entries.isEmpty) {
                        return const Text('No progress updates yet.');
                      }
                      return Column(
                        children: entries
                            .map(
                              (e) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(child: Text('${e.progressPercent}')),
                                title: Text(e.notes),
                                subtitle: Text(
                                  _dateFormat.format(e.createdAt.toLocal()),
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveNavigation(LandOwnerRequest ticket) async {
    final employeeId = ref.read(authStateProvider).session?.userId ?? '';
    final loading = ref.read(employeeLoadingProvider.notifier);
    loading.state = true;
    try {
      await ref.read(employeeRepositoryProvider).updateNavigationNotes(
            requestId: ticket.id,
            employeeId: employeeId,
            notes: _navNotesController.text,
          );
      _refresh(employeeId);
      ref.read(snackbarServiceProvider).showSuccess('Navigation notes saved.');
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    } catch (_) {
      ref.read(snackbarServiceProvider).showError('Could not save notes.');
    } finally {
      loading.state = false;
    }
  }

  Future<void> _submitQuotation(LandOwnerRequest ticket) async {
    final amount = double.tryParse(_quoteAmountController.text);
    final materials = double.tryParse(_materialsController.text) ?? 0;
    final labor = double.tryParse(_laborController.text) ?? 0;
    final days = int.tryParse(_timelineController.text) ?? 0;

    if (amount == null || amount <= 0) {
      ref.read(snackbarServiceProvider).showError('Enter a valid quotation amount.');
      return;
    }

    final employeeId = ref.read(authStateProvider).session?.userId ?? '';
    final loading = ref.read(employeeLoadingProvider.notifier);
    loading.state = true;
    try {
      await ref.read(employeeRepositoryProvider).submitQuotation(
            employeeId: employeeId,
            requestId: ticket.id,
            ticketId: ticket.ticketId,
            amount: amount,
            materialsCost: materials,
            laborCost: labor,
            timelineDays: days,
            description: _quoteDescController.text,
          );
      _refresh(employeeId);
      ref.read(snackbarServiceProvider).showSuccess('Quotation submitted.');
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    } catch (_) {
      ref.read(snackbarServiceProvider).showError('Quotation failed.');
    } finally {
      loading.state = false;
    }
  }

  Future<void> _updateProgress(LandOwnerRequest ticket) async {
    final progress = int.tryParse(_progressController.text);
    if (progress == null || progress < 0 || progress > 100) {
      ref.read(snackbarServiceProvider).showError('Enter progress between 0 and 100.');
      return;
    }

    final employeeId = ref.read(authStateProvider).session?.userId ?? '';
    final loading = ref.read(employeeLoadingProvider.notifier);
    loading.state = true;
    try {
      await ref.read(employeeRepositoryProvider).updateConstructionProgress(
            employeeId: employeeId,
            requestId: ticket.id,
            ticketId: ticket.ticketId,
            progressPercent: progress,
            notes: _progressNotesController.text.isEmpty
                ? 'Progress updated to $progress%'
                : _progressNotesController.text,
          );
      _progressNotesController.clear();
      _refresh(employeeId);
      ref.read(snackbarServiceProvider).showSuccess('Progress updated.');
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    } catch (_) {
      ref.read(snackbarServiceProvider).showError('Progress update failed.');
    } finally {
      loading.state = false;
    }
  }

  Future<void> _markCompleted(LandOwnerRequest ticket) async {
    final confirmed = await AppDialogs.showConfirmation(
      context,
      title: 'Mark Completed',
      message: 'Mark ${ticket.ticketId} as completed?',
      confirmText: 'Complete',
    );
    if (confirmed != true) return;

    final employeeId = ref.read(authStateProvider).session?.userId ?? '';
    final loading = ref.read(employeeLoadingProvider.notifier);
    loading.state = true;
    try {
      await ref.read(employeeRepositoryProvider).markProjectCompleted(
            requestId: ticket.id,
            employeeId: employeeId,
          );
      _refresh(employeeId);
      ref.read(snackbarServiceProvider).showSuccess('Project marked completed.');
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    } catch (_) {
      ref.read(snackbarServiceProvider).showError('Could not complete project.');
    } finally {
      loading.state = false;
    }
  }

  Future<void> _verifyDocuments(LandOwnerRequest ticket) async {
    final employeeId = ref.read(authStateProvider).session?.userId ?? '';
    final loading = ref.read(employeeLoadingProvider.notifier);
    loading.state = true;
    try {
      await ref.read(employeeRepositoryProvider).verifyDocuments(
            requestId: ticket.id,
            employeeId: employeeId,
          );
      _refresh(employeeId);
      ref.read(snackbarServiceProvider).showSuccess(
            'Documents verified. This parking will show in nearby search.',
          );
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    } catch (_) {
      ref.read(snackbarServiceProvider).showError('Could not verify documents.');
    } finally {
      loading.state = false;
    }
  }

  void _refresh(String employeeId) {
    ref.invalidate(
      employeeTicketProvider((ticketId: widget.ticketId, employeeId: employeeId)),
    );
    ref.invalidate(ticketQuotationProvider(widget.ticketId));
    ref.invalidate(progressHistoryProvider(widget.ticketId));
    ref.invalidate(assignedProjectsProvider(employeeId));
    ref.invalidate(completedProjectsProvider(employeeId));
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _LandLocationCard extends StatelessWidget {
  const _LandLocationCard({required this.landDetails});

  final LandDetails landDetails;

  Future<void> _openMaps(BuildContext context) async {
    final lat = landDetails.gpsLatitude;
    final lng = landDetails.gpsLongitude;
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps.')),
        );
      }
    }
  }

  void _copyCoords(BuildContext context) {
    final lat = landDetails.gpsLatitude;
    final lng = landDetails.gpsLongitude;
    Clipboard.setData(ClipboardData(text: '$lat, $lng'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coordinates copied to clipboard.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lat = landDetails.gpsLatitude;
    final lng = landDetails.gpsLongitude;
    final hasLocation = lat != 0 || lng != 0;
    final locationName = landDetails.landAddress;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Land Location',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (locationName != null && locationName.isNotEmpty) ...[
              Text(
                'Area / Address',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                locationName,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
            ],
            if (hasLocation) ...[
              Text(
                'GPS Coordinates',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontFamily: 'monospace'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: 'Copy coordinates',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _copyCoords(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openMaps(context),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Open in Google Maps'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _openMaps(context),
                      icon: const Icon(Icons.navigation, size: 16),
                      label: const Text('Navigate'),
                    ),
                  ),
                ],
              ),
            ] else
              Text(
                'Location not set',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }
}
