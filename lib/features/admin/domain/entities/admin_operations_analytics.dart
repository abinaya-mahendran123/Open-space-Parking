class AdminParkingPlace {
  const AdminParkingPlace({
    required this.id,
    required this.name,
    this.ticketId,
    this.capacity,
  });

  final String id;
  final String name;
  final String? ticketId;
  final int? capacity;

  factory AdminParkingPlace.fromJson(Map<String, dynamic> json) {
    return AdminParkingPlace(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? 'Parking'}',
      ticketId: json['ticketId']?.toString(),
      capacity: json['capacity'] is num ? (json['capacity'] as num).toInt() : null,
    );
  }
}

class AdminDailyOccupancy {
  const AdminDailyOccupancy({
    required this.day,
    required this.checkIns,
    required this.peakOccupancy,
  });

  final String day;
  final int checkIns;
  final int peakOccupancy;

  factory AdminDailyOccupancy.fromJson(Map<String, dynamic> json) {
    return AdminDailyOccupancy(
      day: '${json['day'] ?? ''}',
      checkIns: (json['checkIns'] as num?)?.toInt() ?? 0,
      peakOccupancy: (json['peakOccupancy'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminOccupancyReport {
  const AdminOccupancyReport({
    required this.from,
    required this.to,
    required this.daily,
    required this.totalCheckIns,
    required this.maxPeakOccupancy,
    this.listingId,
  });

  final String from;
  final String to;
  final String? listingId;
  final List<AdminDailyOccupancy> daily;
  final int totalCheckIns;
  final int maxPeakOccupancy;

  factory AdminOccupancyReport.fromJson(Map<String, dynamic> json) {
    final totals = json['totals'] is Map
        ? Map<String, dynamic>.from(json['totals'] as Map)
        : <String, dynamic>{};
    final dailyRaw = json['daily'];
    final daily = dailyRaw is List
        ? dailyRaw
            .whereType<Map>()
            .map((e) => AdminDailyOccupancy.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <AdminDailyOccupancy>[];
    return AdminOccupancyReport(
      from: '${json['from'] ?? ''}',
      to: '${json['to'] ?? ''}',
      listingId: json['listingId']?.toString(),
      daily: daily,
      totalCheckIns: (totals['checkIns'] as num?)?.toInt() ?? 0,
      maxPeakOccupancy: (totals['peakOccupancy'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminPaymentItem {
  const AdminPaymentItem({
    required this.id,
    required this.kind,
    required this.amount,
    this.bookingId,
    this.bookingRef,
    this.parkingListingId,
    this.parkingName,
    this.vehicleNumber,
    this.platformCommission = 0,
    this.landOwnerPayout = 0,
    this.razorpayPaymentId,
    this.method,
    this.at,
  });

  final String id;
  final String kind; // paid | unpaid
  final double amount;
  final String? bookingId;
  final String? bookingRef;
  final String? parkingListingId;
  final String? parkingName;
  final String? vehicleNumber;
  final double platformCommission;
  final double landOwnerPayout;
  final String? razorpayPaymentId;
  final String? method;
  final String? at;

  bool get isPaid => kind == 'paid';

  factory AdminPaymentItem.fromJson(Map<String, dynamic> json) {
    return AdminPaymentItem(
      id: '${json['id'] ?? ''}',
      kind: '${json['kind'] ?? 'unpaid'}',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      bookingId: json['bookingId']?.toString(),
      bookingRef: json['bookingRef']?.toString(),
      parkingListingId: json['parkingListingId']?.toString(),
      parkingName: json['parkingName']?.toString(),
      vehicleNumber: json['vehicleNumber']?.toString(),
      platformCommission:
          (json['platformCommission'] as num?)?.toDouble() ?? 0,
      landOwnerPayout: (json['landOwnerPayout'] as num?)?.toDouble() ?? 0,
      razorpayPaymentId: json['razorpayPaymentId']?.toString(),
      method: json['method']?.toString(),
      at: json['at']?.toString(),
    );
  }
}

class AdminPaymentsReport {
  const AdminPaymentsReport({
    required this.from,
    required this.to,
    required this.paid,
    required this.unpaid,
    required this.paidCount,
    required this.unpaidCount,
    required this.paidAmount,
    required this.unpaidAmount,
    required this.platformCommission,
    required this.landOwnerPayout,
    this.listingId,
  });

  final String from;
  final String to;
  final String? listingId;
  final List<AdminPaymentItem> paid;
  final List<AdminPaymentItem> unpaid;
  final int paidCount;
  final int unpaidCount;
  final double paidAmount;
  final double unpaidAmount;
  final double platformCommission;
  final double landOwnerPayout;

  factory AdminPaymentsReport.fromJson(Map<String, dynamic> json) {
    final totals = json['totals'] is Map
        ? Map<String, dynamic>.from(json['totals'] as Map)
        : <String, dynamic>{};
    List<AdminPaymentItem> parseList(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => AdminPaymentItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return AdminPaymentsReport(
      from: '${json['from'] ?? ''}',
      to: '${json['to'] ?? ''}',
      listingId: json['listingId']?.toString(),
      paid: parseList(json['paid']),
      unpaid: parseList(json['unpaid']),
      paidCount: (totals['paidCount'] as num?)?.toInt() ?? 0,
      unpaidCount: (totals['unpaidCount'] as num?)?.toInt() ?? 0,
      paidAmount: (totals['paidAmount'] as num?)?.toDouble() ?? 0,
      unpaidAmount: (totals['unpaidAmount'] as num?)?.toDouble() ?? 0,
      platformCommission:
          (totals['platformCommission'] as num?)?.toDouble() ?? 0,
      landOwnerPayout: (totals['landOwnerPayout'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AdminOperationsAnalytics {
  const AdminOperationsAnalytics({
    required this.places,
    required this.occupancy,
    required this.payments,
  });

  final List<AdminParkingPlace> places;
  final AdminOccupancyReport occupancy;
  final AdminPaymentsReport payments;

  factory AdminOperationsAnalytics.fromJson(Map<String, dynamic> json) {
    final placesRaw = json['places'];
    final places = placesRaw is List
        ? placesRaw
            .whereType<Map>()
            .map((e) => AdminParkingPlace.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <AdminParkingPlace>[];
    return AdminOperationsAnalytics(
      places: places,
      occupancy: AdminOccupancyReport.fromJson(
        Map<String, dynamic>.from(json['occupancy'] as Map? ?? {}),
      ),
      payments: AdminPaymentsReport.fromJson(
        Map<String, dynamic>.from(json['payments'] as Map? ?? {}),
      ),
    );
  }
}
