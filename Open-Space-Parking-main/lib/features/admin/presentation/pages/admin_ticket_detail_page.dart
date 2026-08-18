import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_request.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/request_status.dart';

class AdminTicketDetailPage extends ConsumerWidget {
  const AdminTicketDetailPage({super.key, required this.ticketId});

  final String ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketAsync = ref.watch(adminTicketDetailProvider(ticketId));
    final isLoading = ref.watch(adminLoadingProvider);
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

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
                        dateFormat.format(ticket.submittedAt.toLocal()),
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
                  _SectionCard(
                    title: 'Land Details',
                    children: [
                      _InfoRow(
                        'GPS',
                        '${ticket.landDetails.gpsLatitude}, ${ticket.landDetails.gpsLongitude}',
                      ),
                      _InfoRow('Area', '${ticket.landDetails.areaSqFt} sq ft'),
                      _InfoRow('Road Access', ticket.landDetails.roadAccess ? 'Y' : 'N'),
                      _InfoRow('Drainage', ticket.landDetails.drainage ? 'Y' : 'N'),
                      _InfoRow('Flood', ticket.landDetails.flood ? 'Y' : 'N'),
                      _InfoRow('Boundary', ticket.landDetails.boundary ? 'Y' : 'N'),
                      _InfoRow('CCTV', ticket.landDetails.cctv ? 'Y' : 'N'),
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
                      ],
                    ),
                  _SectionCard(
                    title: 'Verify Documents',
                    children: [
                      _DocRow('Government ID', ticket.documents.governmentIdPath),
                      _DocRow('Property Document', ticket.documents.propertyDocumentPath),
                      _DocRow('Patta', ticket.documents.pattaPath),
                      _DocRow('Property Tax', ticket.documents.propertyTaxPath),
                      const SizedBox(height: 12),
                      if (!ticket.documentsVerified)
                        PrimaryButton(
                          label: 'Mark Documents Verified',
                          isLoading: isLoading,
                          onPressed: () => _verify(context, ref, ticket),
                        )
                      else
                        const ListTile(
                          leading: Icon(Icons.verified, color: Colors.green),
                          title: Text('Documents verified'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Ticket Actions', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.tonalIcon(
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
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reject Ticket'),
          content: TextField(
            controller: reasonController,
            decoration: const InputDecoration(
              labelText: 'Rejection reason',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, reasonController.text),
              child: const Text('Reject'),
            ),
          ],
        );
      },
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
    final employees = await ref.read(activeEmployeesProvider.future);
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
    final loading = ref.read(adminLoadingProvider.notifier);
    loading.state = true;
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
      loading.state = false;
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
