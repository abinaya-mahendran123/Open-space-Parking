import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:open_space_parking/core/domain/domain_extensions.dart';
import 'package:open_space_parking/core/cloudinary/presentation/widgets/cloudinary_asset_preview.dart';
import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';
import 'package:open_space_parking/core/widgets/dialogs/app_dialogs.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/features/admin/domain/entities/employee.dart';
import 'package:open_space_parking/features/admin/presentation/providers/admin_providers.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_details.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_request.dart';

class AdminTicketDetailPage extends ConsumerWidget {
  const AdminTicketDetailPage({
    super.key,
    required this.ticketId,
    this.readOnly = false,
  });

  static final _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

  final String ticketId;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketAsync = ref.watch(adminTicketDetailProvider(ticketId));
    final isLoading = ref.watch(adminLoadingProvider);

    return Scaffold(
      appBar: AppBar(title: Text(ticketId)),
      body: ticketAsync.when(
        loading: () => const AppLoadingWidget(),
        error: (_, __) => AppErrorWidget(
          message: 'Failed to load ticket',
          onRetry: () => ref.invalidate(adminTicketDetailProvider(ticketId)),
        ),
        data: (ticket) {
          if (ticket == null) {
            return const Center(child: Text('Ticket not found.'));
          }

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SectionCard(
                    title: 'Ticket Summary',
                    children: [
                      _InfoRow('Status', ticket.status.label),
                      _InfoRow('Type', ticket.requestType.label),
                      _InfoRow(
                        'Submitted',
                        _dateFormat.format(ticket.submittedAt.toLocal()),
                      ),
                      _InfoRow(
                        'Assigned',
                        ticket.assignedEmployeeName ?? 'Unassigned',
                      ),
                      _InfoRow(
                        'Documents',
                        ticket.documentsVerified ? 'Verified' : 'Pending',
                      ),
                      if (ticket.adminNotes != null && ticket.adminNotes!.isNotEmpty)
                        _InfoRow('Admin Notes', ticket.adminNotes!),
                    ],
                  ),
                  _SectionCard(
                    title: 'Owner Details',
                    children: [
                      _InfoRow('Name', ticket.ownerDetails.fullName),
                      _InfoRow('Email', ticket.ownerDetails.email),
                      _InfoRow('Phone', ticket.ownerDetails.phone),
                      _InfoRow('Address', ticket.ownerDetails.address),
                    ],
                  ),
                  _LandLocationCard(landDetails: ticket.landDetails),
                  _SectionCard(
                    title: 'Land Details',
                    children: [
                      _InfoRow('Area', '${ticket.landDetails.areaSqFt} sq ft'),
                      _InfoRow('Road Access', ticket.landDetails.roadAccess ? 'Yes' : 'No'),
                      _InfoRow('Drainage', ticket.landDetails.drainage ? 'Yes' : 'No'),
                      _InfoRow('Flood Risk', ticket.landDetails.flood ? 'Yes' : 'No'),
                      _InfoRow('Boundary', ticket.landDetails.boundary ? 'Yes' : 'No'),
                      _InfoRow('CCTV', ticket.landDetails.cctv ? 'Yes' : 'No'),
                    ],
                  ),
                  if (ticket.parkingPreferences != null)
                    _SectionCard(
                      title: 'Parking Preferences',
                      children: [
                        _InfoRow(
                          'Priority',
                          ticket.parkingPreferences!.priority.label,
                        ),
                        _InfoRow(
                          'Type',
                          ticket.parkingPreferences!.parkingType.label,
                        ),
                        _InfoRow(
                          'Cars',
                          '${ticket.parkingPreferences!.numberOfCars}',
                        ),
                        if (ticket.parkingPreferences!.hourlyRate != null)
                          _InfoRow(
                            'Hourly Amount',
                            '₹${ticket.parkingPreferences!.hourlyRate!.toStringAsFixed(0)}/hr',
                          ),
                      ],
                    ),
                  _SectionCard(
                    title: 'Verify Documents',
                    children: [
                      // DigiLocker verified banner
                      if (ticket.documents.digilockerVerified) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.verified, color: Colors.green, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'DigiLocker Verified',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          color: Colors.green.shade800,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Government Certified',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: Colors.green.shade800,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (ticket.documents.digilockerDocumentType?.isNotEmpty == true)
                                _InfoRow('Doc Type', ticket.documents.digilockerDocumentType!),
                              if (ticket.documents.digilockerOwnerName?.isNotEmpty == true)
                                _InfoRow('Owner Name', ticket.documents.digilockerOwnerName!),
                              if (ticket.documents.digilockerSurveyNumber?.isNotEmpty == true)
                                _InfoRow('Survey No.', ticket.documents.digilockerSurveyNumber!),
                              if (ticket.documents.digilockerLandArea?.isNotEmpty == true)
                                _InfoRow('Land Area', ticket.documents.digilockerLandArea!),
                              if (ticket.documents.digilockerDistrict?.isNotEmpty == true)
                                _InfoRow('District', ticket.documents.digilockerDistrict!),
                              if (ticket.documents.digilockerIssuedBy?.isNotEmpty == true)
                                _InfoRow('Issued By', ticket.documents.digilockerIssuedBy!),
                              if (ticket.documents.digilockerVerificationUrl?.isNotEmpty == true) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Verification URL:',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                SelectableText(
                                  ticket.documents.digilockerVerificationUrl!,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ] else ...[
                        // Manual documents
                        _DocRow('Government ID', ticket.documents.governmentIdPath),
                        _DocRow('Property Document', ticket.documents.propertyDocumentPath),
                        _DocRow('Patta', ticket.documents.pattaPath),
                        _DocRow('Property Tax', ticket.documents.propertyTaxPath),
                        const SizedBox(height: 4),
                        Text(
                          'Employee site visit required to verify manually uploaded documents.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (!ticket.documentsVerified && !readOnly)
                        PrimaryButton(
                          label: ticket.documents.digilockerVerified
                              ? 'Confirm DigiLocker Verification'
                              : 'Mark Documents Verified',
                          isLoading: isLoading,
                          onPressed: () => _verify(context, ref, ticket),
                        )
                      else if (ticket.documentsVerified)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.verified, color: Colors.green),
                          title: const Text('Documents verified'),
                          subtitle: ticket.documents.digilockerVerified
                              ? const Text('via DigiLocker (Government certified)')
                              : const Text('via manual employee review'),
                        ),
                    ],
                  ),
                  if (!readOnly) ...[
                    const SizedBox(height: 8),
                    Text('Ticket Actions', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ticket.assignedEmployeeId != null
                            ? FilledButton.tonalIcon(
                                onPressed: isLoading
                                    ? null
                                    : () => _assignEmployee(context, ref, ticket),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.green.shade50,
                                  foregroundColor: Colors.green.shade700,
                                ),
                                icon: const Icon(Icons.person_pin, size: 18),
                                label: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Employee Assigned',
                                      style: TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    Text(
                                      ticket.assignedEmployeeName ?? '',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              )
                            : FilledButton.tonalIcon(
                                onPressed: isLoading
                                    ? null
                                    : () => _assignEmployee(context, ref, ticket),
                                icon: const Icon(Icons.person_add),
                                label: const Text('Assign Employee'),
                              ),
                        FilledButton.icon(
                          onPressed: isLoading ||
                                  ticket.status == RequestStatus.approved ||
                                  ticket.status == RequestStatus.rejected
                              ? null
                              : () => _approve(context, ref, ticket),
                          icon: const Icon(Icons.check),
                          label: const Text('Approve'),
                        ),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.error,
                          ),
                          onPressed: isLoading ||
                                  ticket.status == RequestStatus.approved ||
                                  ticket.status == RequestStatus.rejected
                              ? null
                              : () => _reject(context, ref, ticket),
                          icon: const Icon(Icons.close),
                          label: const Text('Reject'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
              if (isLoading)
                const ColoredBox(
                  color: Color(0x33000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _verify(
    BuildContext context,
    WidgetRef ref,
    LandOwnerRequest ticket,
  ) async {
    final confirmed = await AppDialogs.showConfirmation(
      context,
      title: 'Verify Documents',
      message: 'Confirm all uploaded documents for ${ticket.ticketId} are valid?',
      confirmText: 'Verify',
    );
    if (confirmed != true) return;

    final adminId = ref.read(authStateProvider).session?.userId ?? '';
    final loading = ref.read(adminLoadingProvider.notifier);
    loading.state = true;
    try {
      await ref.read(adminRepositoryProvider).verifyDocuments(
            requestId: ticket.id,
            verified: true,
            adminId: adminId,
          );
      _refresh(ref, ticket.ticketId);
      ref.read(snackbarServiceProvider).showSuccess('Documents verified.');
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    } catch (_) {
      ref.read(snackbarServiceProvider).showError('Verification failed.');
    } finally {
      loading.state = false;
    }
  }

  Future<void> _approve(
    BuildContext context,
    WidgetRef ref,
    LandOwnerRequest ticket,
  ) async {
    final confirmed = await AppDialogs.showConfirmation(
      context,
      title: 'Approve Ticket',
      message: 'Approve ${ticket.ticketId} and notify the land owner?',
      confirmText: 'Approve',
    );
    if (confirmed != true) return;

    final adminId = ref.read(authStateProvider).session?.userId ?? '';
    final loading = ref.read(adminLoadingProvider.notifier);
    loading.state = true;
    try {
      await ref.read(adminRepositoryProvider).approveTicket(
            requestId: ticket.id,
            adminId: adminId,
          );
      _refresh(ref, ticket.ticketId);
      ref.read(snackbarServiceProvider).showSuccess('Ticket approved.');
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    } catch (_) {
      ref.read(snackbarServiceProvider).showError('Approval failed.');
    } finally {
      loading.state = false;
    }
  }

  Future<void> _reject(
    BuildContext context,
    WidgetRef ref,
    LandOwnerRequest ticket,
  ) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => const _RejectDialog(),
    );

    if (reason == null || reason.trim().isEmpty) return;

    final adminId = ref.read(authStateProvider).session?.userId ?? '';
    final loading = ref.read(adminLoadingProvider.notifier);
    loading.state = true;
    try {
      await ref.read(adminRepositoryProvider).rejectTicket(
            requestId: ticket.id,
            adminId: adminId,
            reason: reason,
          );
      _refresh(ref, ticket.ticketId);
      ref.read(snackbarServiceProvider).showSuccess('Ticket rejected.');
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    } catch (_) {
      ref.read(snackbarServiceProvider).showError('Rejection failed.');
    } finally {
      loading.state = false;
    }
  }

  Future<void> _assignEmployee(
    BuildContext context,
    WidgetRef ref,
    LandOwnerRequest ticket,
  ) async {
    // Guard against double-tap: if already loading, do nothing.
    if (ref.read(adminLoadingProvider)) return;

    final loading = ref.read(adminLoadingProvider.notifier);
    loading.state = true;

    List<Employee> employees;
    try {
      employees = await ref.read(activeEmployeesProvider.future);
    } on Exception catch (e) {
      if (context.mounted) {
        ref.read(snackbarServiceProvider).showError(
              e is AppException ? e.message : 'Could not load employees.',
            );
      }
      loading.state = false;
      return;
    } finally {
      if (!context.mounted) {
        loading.state = false;
        return;
      }
    }

    loading.state = false;

    if (!context.mounted) return;

    if (employees.isEmpty) {
      ref.read(snackbarServiceProvider).showError('No active employees available.');
      return;
    }

    final selected = await showModalBottomSheet<Employee>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return ListView.builder(
          shrinkWrap: true,
          itemCount: employees.length,
          itemBuilder: (context, index) {
            final employee = employees[index];
            return ListTile(
              leading: const Icon(Icons.badge),
              title: Text(employee.fullName),
              subtitle: Text('${employee.phone} • ${employee.roleTitle}'),
              onTap: () => Navigator.pop(context, employee),
            );
          },
        );
      },
    );

    if (selected == null) return;

    final adminId = ref.read(authStateProvider).session?.userId ?? '';
    final assignLoading = ref.read(adminLoadingProvider.notifier);
    assignLoading.state = true;
    try {
      final deliverySummary = await ref.read(adminRepositoryProvider).assignEmployee(
            requestId: ticket.id,
            employeeId: selected.id,
            employeeName: selected.fullName,
            adminId: adminId,
          );
      _refresh(ref, ticket.ticketId);
      ref.read(snackbarServiceProvider).showSuccess(
            'Assigned ${selected.fullName}. $deliverySummary',
          );
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    } catch (_) {
      ref.read(snackbarServiceProvider).showError('Assignment failed.');
    } finally {
      assignLoading.state = false;
    }
  }

  void _refresh(WidgetRef ref, String ticketId) {
    ref.invalidate(adminTicketDetailProvider(ticketId));
    ref.invalidate(adminTicketsProvider);
    ref.invalidate(adminStatisticsProvider);
    ref.invalidate(adminEmployeesProvider);
    ref.invalidate(activeEmployeesProvider);
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

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

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

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
            width: 120,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject Ticket'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Rejection reason',
          border: OutlineInputBorder(),
        ),
        maxLines: 3,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}

class _LandLocationCard extends StatelessWidget {
  const _LandLocationCard({required this.landDetails});

  final LandDetails landDetails;

  Future<void> _openMaps(BuildContext context) async {
    final lat = landDetails.gpsLatitude;
    final lng = landDetails.gpsLongitude;
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
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
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontFamily: 'monospace',
                          ),
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
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openMaps(context),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open in Google Maps'),
                ),
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

class _DocRow extends StatelessWidget {
  const _DocRow(this.label, this.url);

  final String label;
  final String? url;

  bool get _hasUrl =>
      url != null &&
      url!.isNotEmpty &&
      (url!.startsWith('http://') || url!.startsWith('https://'));

  @override
  Widget build(BuildContext context) {
    if (_hasUrl) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            CloudinaryAssetPreview(url: url!, height: 100),
          ],
        ),
      );
    }

    final fileName = url?.split(RegExp(r'[\\/]')).last;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        url != null ? Icons.check_circle : Icons.cancel,
        color: url != null ? Colors.green : Colors.red,
      ),
      title: Text(label),
      subtitle: Text(fileName ?? 'Missing'),
    );
  }
}
