import 'package:equatable/equatable.dart';

class SearchQuery extends Equatable {
  const SearchQuery({
    this.filters = const {},
    this.textQuery,
    this.searchFields = const [],
    this.page = 1,
    this.pageSize = 20,
    this.sortField = 'createdAt',
    this.sortDescending = true,
    this.includeDeleted = false,
  });

  final Map<String, dynamic> filters;
  final String? textQuery;
  final List<String> searchFields;
  final int page;
  final int pageSize;
  final String sortField;
  final bool sortDescending;
  final bool includeDeleted;

  int get skip => (page - 1) * pageSize;

  SearchQuery copyWith({
    Map<String, dynamic>? filters,
    String? textQuery,
    List<String>? searchFields,
    int? page,
    int? pageSize,
    String? sortField,
    bool? sortDescending,
    bool? includeDeleted,
    bool clearTextQuery = false,
  }) {
    return SearchQuery(
      filters: filters ?? this.filters,
      textQuery: clearTextQuery ? null : (textQuery ?? this.textQuery),
      searchFields: searchFields ?? this.searchFields,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      sortField: sortField ?? this.sortField,
      sortDescending: sortDescending ?? this.sortDescending,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  @override
  List<Object?> get props => [
        filters,
        textQuery,
        searchFields,
        page,
        pageSize,
        sortField,
        sortDescending,
        includeDeleted,
      ];
}
