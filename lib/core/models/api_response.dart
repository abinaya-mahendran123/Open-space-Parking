class ApiResponse<T> {
  const ApiResponse({
    required this.data,
    this.message,
    this.isSuccess = true,
  });

  final T data;
  final String? message;
  final bool isSuccess;
}
