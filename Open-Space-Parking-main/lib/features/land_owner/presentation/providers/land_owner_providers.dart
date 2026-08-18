import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/core/di/service_locator.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_details.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_documents.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_notification.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_request.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/owner_details.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/parking_type.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/request_priority.dart';
import 'package:open_space_parking/features/land_owner/domain/repositories/land_owner_repository.dart';
import 'package:open_space_parking/features/land_owner/data/repositories/mongo_land_owner_repository.dart';
import 'package:open_space_parking/features/notification/domain/entities/notification_recipient_type.dart';
import 'package:open_space_parking/features/notification/presentation/providers/notification_providers.dart';

final landOwnerRepositoryProvider = Provider<LandOwnerRepository>(
  (ref) => sl<LandOwnerRepository>(),
);

final landOwnerNotificationRepositoryProvider =
    Provider<LandOwnerNotificationRepository>(
  (ref) => sl<LandOwnerNotificationRepository>(),
);

final requestHistoryProvider =
    FutureProvider.family<List<LandOwnerRequest>, String>((ref, ownerId) async {
  return ref.read(landOwnerRepositoryProvider).getRequestHistory(ownerId);
});

final landOwnerProfileProvider =
    FutureProvider.family<OwnerDetails?, String>((ref, ownerId) async {
  return ref.read(landOwnerRepositoryProvider).getOwnerProfile(ownerId);
});

final landOwnerNotificationsProvider =
    FutureProvider.family<List<LandOwnerNotification>, String>((ref, ownerId) async {
  return ref.read(landOwnerNotificationRepositoryProvider).getNotifications(ownerId);
});

final unreadNotificationCountProvider =
    FutureProvider.family<int, String>((ref, ownerId) async {
  return ref.read(notificationRepositoryProvider).getUnreadCount(
        recipientId: ownerId,
        recipientType: NotificationRecipientType.landOwner,
      );
});

final landOwnerLoadingProvider = StateProvider<bool>((ref) => false);

class BuildParkingFormState {
  const BuildParkingFormState({
    this.currentStep = 0,
    this.ownerDetails,
    this.documents = const LandOwnerDocuments(),
    this.landDetails,
    this.priority = RequestPriority.notImmediate,
    this.parkingType = ParkingType.towerParking,
    this.numberOfCars = 1,
    this.generatedTicketId,
  });

  final int currentStep;
  final OwnerDetails? ownerDetails;
  final LandOwnerDocuments documents;
  final LandDetails? landDetails;
  final RequestPriority priority;
  final ParkingType parkingType;
  final int numberOfCars;
  final String? generatedTicketId;

  static const int totalSteps = 5;

  BuildParkingFormState copyWith({
    int? currentStep,
    OwnerDetails? ownerDetails,
    LandOwnerDocuments? documents,
    LandDetails? landDetails,
    RequestPriority? priority,
    ParkingType? parkingType,
    int? numberOfCars,
    String? generatedTicketId,
  }) {
    return BuildParkingFormState(
      currentStep: currentStep ?? this.currentStep,
      ownerDetails: ownerDetails ?? this.ownerDetails,
      documents: documents ?? this.documents,
      landDetails: landDetails ?? this.landDetails,
      priority: priority ?? this.priority,
      parkingType: parkingType ?? this.parkingType,
      numberOfCars: numberOfCars ?? this.numberOfCars,
      generatedTicketId: generatedTicketId ?? this.generatedTicketId,
    );
  }
}

class BuildParkingFormNotifier extends StateNotifier<BuildParkingFormState> {
  BuildParkingFormNotifier() : super(const BuildParkingFormState());

  void nextStep() {
    if (state.currentStep < BuildParkingFormState.totalSteps - 1) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  void goToStep(int step) {
    if (step >= 0 && step < BuildParkingFormState.totalSteps) {
      state = state.copyWith(currentStep: step);
    }
  }

  void setOwnerDetails(OwnerDetails details) {
    state = state.copyWith(ownerDetails: details);
  }

  void setDocuments(LandOwnerDocuments documents) {
    state = state.copyWith(documents: documents);
  }

  void setLandDetails(LandDetails details) {
    state = state.copyWith(landDetails: details);
  }

  void setPriority(RequestPriority priority) {
    state = state.copyWith(priority: priority);
  }

  void setParkingType(ParkingType type) {
    state = state.copyWith(parkingType: type);
  }

  void setNumberOfCars(int count) {
    state = state.copyWith(numberOfCars: count);
  }

  void setGeneratedTicketId(String ticketId) {
    state = state.copyWith(generatedTicketId: ticketId);
  }

  void reset() {
    state = const BuildParkingFormState();
  }
}

final buildParkingFormProvider =
    StateNotifierProvider<BuildParkingFormNotifier, BuildParkingFormState>(
  (ref) => BuildParkingFormNotifier(),
);

class ExistingParkingFormState {
  const ExistingParkingFormState({
    this.currentStep = 0,
    this.ownerDetails,
    this.documents = const LandOwnerDocuments(),
    this.landDetails,
  });

  final int currentStep;
  final OwnerDetails? ownerDetails;
  final LandOwnerDocuments documents;
  final LandDetails? landDetails;

  static const int totalSteps = 3;

  ExistingParkingFormState copyWith({
    int? currentStep,
    OwnerDetails? ownerDetails,
    LandOwnerDocuments? documents,
    LandDetails? landDetails,
  }) {
    return ExistingParkingFormState(
      currentStep: currentStep ?? this.currentStep,
      ownerDetails: ownerDetails ?? this.ownerDetails,
      documents: documents ?? this.documents,
      landDetails: landDetails ?? this.landDetails,
    );
  }
}

class ExistingParkingFormNotifier extends StateNotifier<ExistingParkingFormState> {
  ExistingParkingFormNotifier() : super(const ExistingParkingFormState());

  void nextStep() {
    if (state.currentStep < ExistingParkingFormState.totalSteps - 1) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  void setOwnerDetails(OwnerDetails details) {
    state = state.copyWith(ownerDetails: details);
  }

  void setDocuments(LandOwnerDocuments documents) {
    state = state.copyWith(documents: documents);
  }

  void setLandDetails(LandDetails details) {
    state = state.copyWith(landDetails: details);
  }

  void reset() {
    state = const ExistingParkingFormState();
  }
}

final existingParkingFormProvider =
    StateNotifierProvider<ExistingParkingFormNotifier, ExistingParkingFormState>(
  (ref) => ExistingParkingFormNotifier(),
);
