enum RequestPriority {
  immediate,
  notImmediate,
}

extension RequestPriorityX on RequestPriority {
  String get label {
    switch (this) {
      case RequestPriority.immediate:
        return 'Immediate';
      case RequestPriority.notImmediate:
        return 'Not Immediate';
    }
  }

  String get value {
    switch (this) {
      case RequestPriority.immediate:
        return 'immediate';
      case RequestPriority.notImmediate:
        return 'not_immediate';
    }
  }

  static RequestPriority fromValue(String value) {
    return RequestPriority.values.firstWhere(
      (priority) => priority.value == value,
      orElse: () => RequestPriority.notImmediate,
    );
  }
}
