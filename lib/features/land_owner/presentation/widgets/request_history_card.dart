import 'package:flutter/material.dart';

import 'package:open_space_parking/core/domain/domain_extensions.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_request.dart';
import 'package:intl/intl.dart';

class RequestHistoryCard extends StatelessWidget {
  const RequestHistoryCard({super.key, required this.request});

  static final _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

  final LandOwnerRequest request;

  Color _statusColor(RequestStatus status) {
    switch (status) {
      case RequestStatus.submitted:
        return Colors.blue;
      case RequestStatus.underReview:
        return Colors.orange;
      case RequestStatus.approved:
        return Colors.green;
      case RequestStatus.rejected:
        return Colors.red;
      case RequestStatus.inProgress:
        return Colors.indigo;
      case RequestStatus.completed:
        return Colors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.ticketId,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  label: Text(request.status.label),
                  backgroundColor: _statusColor(request.status).withValues(alpha: 0.15),
                  labelStyle: TextStyle(color: _statusColor(request.status)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(request.requestType.label),
            if (request.parkingPreferences != null) ...[
              const SizedBox(height: 4),
              Text(
                '${request.parkingPreferences!.parkingType.label} • ${request.parkingPreferences!.numberOfCars} cars'
                '${request.parkingPreferences!.hourlyRate != null ? ' • ₹${request.parkingPreferences!.hourlyRate!.toStringAsFixed(0)}/hr' : ''}',
              ),
            ],
            const SizedBox(height: 8),
            Text(
              _dateFormat.format(request.submittedAt.toLocal()),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
