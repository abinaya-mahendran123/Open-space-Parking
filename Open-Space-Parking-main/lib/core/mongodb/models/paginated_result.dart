import 'package:equatable/equatable.dart';

class PaginatedResult<T> extends Equatable {
  const PaginatedResult({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalItems,
  });

  final List<T> items;
  final int page;
  final int pageSize;
  final int totalItems;

  int get totalPages =>
      pageSize > 0 ? (totalItems / pageSize).ceil() : 0;

  bool get hasNext => page < totalPages;
  bool get hasPrevious => page > 1;

  @override
  List<Object?> get props => [items, page, pageSize, totalItems];
}
