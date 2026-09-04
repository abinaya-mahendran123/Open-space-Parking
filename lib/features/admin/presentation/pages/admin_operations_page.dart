import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:open_space_parking/core/theme/app_colors.dart';
import 'package:open_space_parking/core/utils/responsive.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/features/admin/domain/entities/admin_operations_analytics.dart';
import 'package:open_space_parking/features/admin/presentation/providers/admin_providers.dart';

enum _OccupancyMetric { checkIns, peak }

enum _PaymentList { none, paid, unpaid, platform, landOwner }

class AdminOperationsPage extends ConsumerStatefulWidget {
  const AdminOperationsPage({super.key});

  @override
  ConsumerState<AdminOperationsPage> createState() =>
      _AdminOperationsPageState();
}

class _AdminOperationsPageState extends ConsumerState<AdminOperationsPage> {
  _OccupancyMetric _metric = _OccupancyMetric.checkIns;
  _PaymentList _paymentList = _PaymentList.none;

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(adminOpsFilterProvider);
    final analyticsAsync = ref.watch(adminOperationsProvider);
    final currency =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

    return analyticsAsync.when(
      loading: () => const AppLoadingWidget(message: 'Loading operations...'),
      error: (error, _) => AppErrorWidget(
        message: error.toString().replaceFirst('Exception: ', ''),
        onRetry: () => ref.invalidate(adminOperationsProvider),
      ),
      data: (data) {
        final places = data.places;
        final occupancy = data.occupancy;
        final payments = data.payments;
        final chartTitle = _metric == _OccupancyMetric.checkIns
            ? 'Daily check-ins'
            : 'Daily peak occupancy';
        final chartColor = _metric == _OccupancyMetric.checkIns
            ? AppColors.primaryOf(context)
            : AppColors.success(Theme.of(context).brightness);

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminOperationsProvider),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: context.isDesktop ? 1100 : double.infinity,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Operations',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurfaceOf(context),
                          ),
                    ),
                    const SizedBox(height: 16),
                    _PlaceSelector(
                      listingId: filter.listingId,
                      places: places,
                      onChanged: (value) {
                        ref
                            .read(adminOpsFilterProvider.notifier)
                            .setListing(value);
                      },
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: constraints.maxWidth,
                            ),
                            child: SegmentedButton<AdminOpsRange>(
                              showSelectedIcon: false,
                              segments: const [
                                ButtonSegment(
                                  value: AdminOpsRange.days7,
                                  label: Text('7 days'),
                                ),
                                ButtonSegment(
                                  value: AdminOpsRange.days30,
                                  label: Text('30 days'),
                                ),
                                ButtonSegment(
                                  value: AdminOpsRange.custom,
                                  label: Text('Custom'),
                                ),
                              ],
                              selected: {filter.range},
                              onSelectionChanged: (s) async {
                                final next = s.first;
                                ref
                                    .read(adminOpsFilterProvider.notifier)
                                    .setPresetRange(next);
                                // Custom opens the picker; 7/30 use defaults
                                // and can be adjusted manually via Date range.
                                if (next == AdminOpsRange.custom &&
                                    context.mounted) {
                                  final current =
                                      ref.read(adminOpsFilterProvider);
                                  final picked =
                                      await showDialog<DateTimeRange>(
                                    context: context,
                                    builder: (context) =>
                                        _SmoothRangeCalendarDialog(
                                      initialRange: DateTimeRange(
                                        start: current.fromDate,
                                        end: current.toDate,
                                      ),
                                    ),
                                  );
                                  if (picked != null) {
                                    ref
                                        .read(adminOpsFilterProvider.notifier)
                                        .setDateRange(
                                          from: picked.start,
                                          to: picked.end,
                                          range: AdminOpsRange.custom,
                                        );
                                  }
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _DateRangeField(
                      from: filter.fromDate,
                      to: filter.toDate,
                      maxInclusiveDays:
                          maxInclusiveDaysForOpsRange(filter.range),
                      onPick: (range) {
                        // Keep 7 days / 30 days / Custom selected — only
                        // update the from/to the admin picked.
                        ref.read(adminOpsFilterProvider.notifier).setDateRange(
                              from: range.start,
                              to: range.end,
                            );
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Cars parked',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap a metric to show its graph.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.onSurfaceVariantOf(context),
                          ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricChip(
                            label: 'Check-ins',
                            value: '${occupancy.totalCheckIns}',
                            color: AppColors.primary,
                            selected: _metric == _OccupancyMetric.checkIns,
                            onTap: () => setState(
                              () => _metric = _OccupancyMetric.checkIns,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricChip(
                            label: 'Peak (max day)',
                            value: '${occupancy.maxPeakOccupancy}',
                            color: AppColors.success(Theme.of(context).brightness),
                            selected: _metric == _OccupancyMetric.peak,
                            onTap: () => setState(
                              () => _metric = _OccupancyMetric.peak,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.borderOf(context)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chartTitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 300,
                              child: occupancy.daily.isEmpty
                                  ? Center(
                                      child: Text(
                                        'No parking sessions in this range.',
                                        style: TextStyle(
                                          color: AppColors.onSurfaceVariantOf(context),
                                        ),
                                      ),
                                    )
                                  : _OccupancyChart(
                                      daily: occupancy.daily,
                                      metric: _metric,
                                      barColor: chartColor,
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Payments',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap a card to view its details.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.onSurfaceVariantOf(context),
                          ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _MetricChip(
                          label: 'Paid',
                          value: currency.format(payments.paidAmount),
                          color: AppColors.success(Theme.of(context).brightness),
                          selected: _paymentList == _PaymentList.paid,
                          onTap: () => setState(() {
                            _paymentList = _paymentList == _PaymentList.paid
                                ? _PaymentList.none
                                : _PaymentList.paid;
                          }),
                        ),
                        _MetricChip(
                          label: 'Unpaid due',
                          value: currency.format(payments.unpaidAmount),
                          color: AppColors.warningColor(Theme.of(context).brightness),
                          selected: _paymentList == _PaymentList.unpaid,
                          onTap: () => setState(() {
                            _paymentList = _paymentList == _PaymentList.unpaid
                                ? _PaymentList.none
                                : _PaymentList.unpaid;
                          }),
                        ),
                        _MetricChip(
                          label: 'Platform (10%)',
                          value: currency.format(payments.platformCommission),
                          color: AppColors.primaryOf(context),
                          selected: _paymentList == _PaymentList.platform,
                          onTap: () => setState(() {
                            _paymentList = _paymentList == _PaymentList.platform
                                ? _PaymentList.none
                                : _PaymentList.platform;
                          }),
                        ),
                        _MetricChip(
                          label: 'Land owners (90%)',
                          value: currency.format(payments.landOwnerPayout),
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          selected: _paymentList == _PaymentList.landOwner,
                          onTap: () => setState(() {
                            _paymentList =
                                _paymentList == _PaymentList.landOwner
                                    ? _PaymentList.none
                                    : _PaymentList.landOwner;
                          }),
                        ),
                      ],
                    ),
                    if (_paymentList == _PaymentList.paid) ...[
                      const SizedBox(height: 12),
                      _PaymentSection(
                        title: 'Paid (${payments.paidCount})',
                        items: payments.paid,
                        currency: currency,
                        emptyLabel: 'No paid sessions in this range.',
                        amountMode: _PaymentAmountMode.total,
                      ),
                    ],
                    if (_paymentList == _PaymentList.unpaid) ...[
                      const SizedBox(height: 12),
                      _PaymentSection(
                        title: 'Unpaid / due (${payments.unpaidCount})',
                        items: payments.unpaid,
                        currency: currency,
                        emptyLabel: 'No unpaid dues in this range.',
                        amountMode: _PaymentAmountMode.total,
                      ),
                    ],
                    if (_paymentList == _PaymentList.platform) ...[
                      const SizedBox(height: 12),
                      _PaymentSection(
                        title: 'Platform share (${payments.paidCount})',
                        items: payments.paid,
                        currency: currency,
                        emptyLabel: 'No platform commissions in this range.',
                        amountMode: _PaymentAmountMode.platform,
                      ),
                    ],
                    if (_paymentList == _PaymentList.landOwner) ...[
                      const SizedBox(height: 12),
                      _PaymentSection(
                        title: 'Land owner share (${payments.paidCount})',
                        items: payments.paid,
                        currency: currency,
                        emptyLabel: 'No land-owner payouts in this range.',
                        amountMode: _PaymentAmountMode.landOwner,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlaceSelector extends StatelessWidget {
  const _PlaceSelector({
    required this.listingId,
    required this.places,
    required this.onChanged,
  });

  final String? listingId;
  final List<AdminParkingPlace> places;
  final ValueChanged<String?> onChanged;

  String _label(AdminParkingPlace place, {bool truncate = false}) {
    final name = place.name.trim();
    final display = truncate && name.length > 56
        ? '${name.substring(0, 56)}…'
        : name;
    if (place.capacity != null) return '$display (${place.capacity} slots)';
    return display;
  }

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Parking place'),
          content: SizedBox(
            width: 480,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: places.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return ListTile(
                    selected: listingId == null,
                    title: const Text('All places'),
                    onTap: () => Navigator.pop(context, ''),
                  );
                }
                final place = places[index - 1];
                return ListTile(
                  selected: listingId == place.id,
                  title: Text(_label(place)),
                  onTap: () => Navigator.pop(context, place.id),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
    if (selected == null) return;
    onChanged(selected.isEmpty ? null : selected);
  }

  @override
  Widget build(BuildContext context) {
    final index = places.indexWhere((p) => p.id == listingId);
    final selectedPlace = index >= 0 ? places[index] : null;
    final display = selectedPlace == null
        ? 'All places'
        : _label(selectedPlace, truncate: true);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _openPicker(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Parking place',
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
          isDense: true,
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          display,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceOf(context),
              ),
        ),
      ),
    );
  }
}

class _DateRangeField extends StatelessWidget {
  const _DateRangeField({
    required this.from,
    required this.to,
    required this.onPick,
    this.maxInclusiveDays,
  });

  final DateTime from;
  final DateTime to;
  final ValueChanged<DateTimeRange> onPick;
  final int? maxInclusiveDays;

  Future<void> _open(BuildContext context) async {
    final picked = await showDialog<DateTimeRange>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _SmoothRangeCalendarDialog(
        initialRange: DateTimeRange(start: from, end: to),
        maxInclusiveDays: maxInclusiveDays,
      ),
    );
    if (picked != null) onPick(picked);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _open(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: maxInclusiveDays == null
              ? 'Date range'
              : 'Date range (max $maxInclusiveDays days)',
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
          isDense: true,
          suffixIcon: const Icon(Icons.calendar_month_outlined, size: 20),
        ),
        child: Text(
          '${formatOpsDay(from)}  →  ${formatOpsDay(to)}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceOf(context),
              ),
        ),
      ),
    );
  }
}

class _SmoothRangeCalendarDialog extends StatefulWidget {
  const _SmoothRangeCalendarDialog({
    required this.initialRange,
    this.maxInclusiveDays,
  });

  final DateTimeRange initialRange;
  /// When set (7 or 30), the selected range may not exceed this many days.
  final int? maxInclusiveDays;

  @override
  State<_SmoothRangeCalendarDialog> createState() =>
      _SmoothRangeCalendarDialogState();
}

class _SmoothRangeCalendarDialogState extends State<_SmoothRangeCalendarDialog> {
  static final DateTime _minMonth = DateTime(2020);
  static final DateTime _maxMonth = DateTime(
    DateTime.now().year + 1,
    DateTime.now().month,
  );

  static const _monthNames = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  late final TextEditingController _monthController;
  late final TextEditingController _yearController;
  late final FocusNode _monthFocus;
  late final FocusNode _yearFocus;
  late DateTime _visibleMonth;
  DateTime? _start;
  DateTime? _end;
  String? _jumpError;
  String? _rangeError;

  @override
  void initState() {
    super.initState();
    _start = opsDayOnly(widget.initialRange.start);
    _end = opsDayOnly(widget.initialRange.end);
    _visibleMonth = DateTime(_start!.year, _start!.month);
    _monthController = TextEditingController(
      text: _monthNames[_visibleMonth.month - 1],
    );
    _yearController = TextEditingController(
      text: '${_visibleMonth.year}',
    );
    _monthFocus = FocusNode();
    _yearFocus = FocusNode();
  }

  @override
  void dispose() {
    _monthController.dispose();
    _yearController.dispose();
    _monthFocus.dispose();
    _yearFocus.dispose();
    super.dispose();
  }

  bool get _canGoPrev {
    final prev = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
    return !prev.isBefore(_minMonth);
  }

  bool get _canGoNext {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
    return !next.isAfter(_maxMonth);
  }

  void _syncMonthYearFields(DateTime month) {
    final name = _monthNames[month.month - 1];
    if (_monthController.text != name) {
      _monthController.value = TextEditingValue(
        text: name,
        selection: TextSelection.collapsed(offset: name.length),
      );
    }
    final yearText = '${month.year}';
    if (_yearController.text != yearText) {
      _yearController.value = TextEditingValue(
        text: yearText,
        selection: TextSelection.collapsed(offset: yearText.length),
      );
    }
  }

  void _setVisibleMonth(DateTime month) {
    var target = DateTime(month.year, month.month);
    if (target.isBefore(_minMonth)) target = _minMonth;
    if (target.isAfter(_maxMonth)) target = _maxMonth;
    setState(() {
      _visibleMonth = target;
      _jumpError = null;
      _syncMonthYearFields(target);
    });
  }

  void _shiftMonth(int delta) {
    _setVisibleMonth(
      DateTime(_visibleMonth.year, _visibleMonth.month + delta),
    );
  }

  int? _parseMonth(String raw) {
    final text = raw.trim().toLowerCase();
    if (text.isEmpty) return null;
    final asNum = int.tryParse(text);
    if (asNum != null && asNum >= 1 && asNum <= 12) return asNum;
    for (var i = 0; i < _monthNames.length; i++) {
      final full = _monthNames[i].toLowerCase();
      final short = full.substring(0, 3);
      if (text == full || text == short || full.startsWith(text)) {
        return i + 1;
      }
    }
    return null;
  }

  void _jumpToTypedMonthYear() {
    final month = _parseMonth(_monthController.text);
    final year = int.tryParse(_yearController.text.trim());
    if (month == null || year == null) {
      setState(() => _jumpError = 'Enter a valid month and year');
      return;
    }
    final target = DateTime(year, month);
    if (target.isBefore(_minMonth) || target.isAfter(_maxMonth)) {
      setState(
        () => _jumpError =
            'Use ${_monthNames[_minMonth.month - 1]} ${_minMonth.year} – '
            '${_monthNames[_maxMonth.month - 1]} ${_maxMonth.year}',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    _setVisibleMonth(target);
  }

  bool _exceedsMax(DateTime start, DateTime end) {
    final max = widget.maxInclusiveDays;
    if (max == null) return false;
    return opsInclusiveDayCount(start, end) > max;
  }

  void _onDayTap(DateTime day) {
    final d = opsDayOnly(day);
    setState(() {
      if (_start == null || (_start != null && _end != null)) {
        _start = d;
        _end = null;
        _rangeError = null;
        return;
      }

      DateTime nextStart = _start!;
      DateTime nextEnd = d;
      if (d.isBefore(_start!)) {
        nextEnd = _start!;
        nextStart = d;
      }

      if (_exceedsMax(nextStart, nextEnd)) {
        _rangeError =
            'Range must be at most ${widget.maxInclusiveDays} days.';
        return;
      }

      _start = nextStart;
      _end = nextEnd;
      _rangeError = null;
    });
  }

  bool _inRange(DateTime day) {
    if (_start == null) return false;
    final d = opsDayOnly(day);
    if (_end == null) return d == _start;
    return !d.isBefore(_start!) && !d.isAfter(_end!);
  }

  bool _isEndpoint(DateTime day) {
    final d = opsDayOnly(day);
    return d == _start || d == _end;
  }

  @override
  Widget build(BuildContext context) {
    final canApply = _start != null && _end != null;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Select date range',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Previous month',
                    onPressed: _canGoPrev ? () => _shiftMonth(-1) : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _monthController,
                            focusNode: _monthFocus,
                            textAlign: TextAlign.center,
                            textInputAction: TextInputAction.next,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText: 'Month',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                            ),
                            onSubmitted: (_) {
                              _yearFocus.requestFocus();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _yearController,
                            focusNode: _yearFocus,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.go,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText: 'Year',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                            ),
                            onSubmitted: (_) => _jumpToTypedMonthYear(),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Go to month',
                          onPressed: _jumpToTypedMonthYear,
                          icon: const Icon(Icons.arrow_forward_rounded),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    onPressed: _canGoNext ? () => _shiftMonth(1) : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              if (_jumpError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _jumpError!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.full,
                      ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                _end == null
                    ? (widget.maxInclusiveDays == null
                        ? 'Type month & year, or use arrows. Then pick start and end days.'
                        : 'Pick a range of at most ${widget.maxInclusiveDays} days.')
                    : '${formatOpsDay(_start!)}  →  ${formatOpsDay(_end!)}'
                        '  (${opsInclusiveDayCount(_start!, _end!)} days)',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceVariantOf(context),
                    ),
              ),
              if (_rangeError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _rangeError!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.full,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                height: 300,
                child: _MonthGrid(
                  key: ValueKey(
                    '${_visibleMonth.year}-${_visibleMonth.month}',
                  ),
                  month: _visibleMonth,
                  inRange: _inRange,
                  isEndpoint: _isEndpoint,
                  onDayTap: _onDayTap,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: canApply
                        ? () {
                            if (_exceedsMax(_start!, _end!)) {
                              setState(() {
                                _rangeError =
                                    'Range must be at most ${widget.maxInclusiveDays} days.';
                              });
                              return;
                            }
                            Navigator.pop(
                              context,
                              DateTimeRange(start: _start!, end: _end!),
                            );
                          }
                        : null,
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    super.key,
    required this.month,
    required this.inRange,
    required this.isEndpoint,
    required this.onDayTap,
  });

  final DateTime month;
  final bool Function(DateTime day) inRange;
  final bool Function(DateTime day) isEndpoint;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday % 7; // Sunday-start grid
    final today = opsDayOnly(DateTime.now());
    const weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Column(
      children: [
        Row(
          children: [
            for (final day in weekdays)
              Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariantOf(context),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
            ),
            itemCount: leading + daysInMonth,
            itemBuilder: (context, index) {
              if (index < leading) return const SizedBox.shrink();
              final dayNum = index - leading + 1;
              final day = DateTime(month.year, month.month, dayNum);
              final selected = isEndpoint(day);
              final ranged = inRange(day);
              final isToday = day == today;

              return Padding(
                padding: const EdgeInsets.all(2),
                child: Material(
                  color: selected
                      ? AppColors.primary
                      : ranged
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => onDayTap(day),
                    child: Center(
                      child: Text(
                        '$dayNum',
                        style: TextStyle(
                          fontWeight:
                              selected || isToday ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? Colors.white
                              : isToday
                                  ? AppColors.primary
                                  : AppColors.onSurfaceOf(context),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}


class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    required this.color,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final String value;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = selected ? color : scheme.outlineVariant;
    final bg = selected
        ? color.withValues(alpha: 0.18)
        : scheme.surfaceContainerHigh;

    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
        borderRadius: BorderRadius.circular(10),
        color: bg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
          ),
        ],
      ),
    );

    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: child,
      ),
    );
  }
}

class _OccupancyChart extends StatelessWidget {
  const _OccupancyChart({
    required this.daily,
    required this.metric,
    required this.barColor,
  });

  final List<AdminDailyOccupancy> daily;
  final _OccupancyMetric metric;
  final Color barColor;

  int _valueFor(AdminDailyOccupancy day) {
    return metric == _OccupancyMetric.checkIns
        ? day.checkIns
        : day.peakOccupancy;
  }

  int _labelStep(int count, double width) {
    if (count <= 1) return 1;
    final maxLabels = (width / 52).floor().clamp(3, 8);
    return ((count - 1) / (maxLabels - 1)).ceil().clamp(1, count);
  }

  String _axisLabel(String day, int count) {
    if (day.length < 10) return day;
    final month = day.substring(5, 7);
    final d = day.substring(8, 10);
    if (count > 120) return '$month/$d';
    return '$month-$d';
  }

  Widget _bottomLabel(BuildContext context, int index, int step, int count) {
    if (index < 0 || index >= count) return const SizedBox.shrink();
    final isEdge = index == 0 || index == count - 1;
    if (!isEdge && index % step != 0) return const SizedBox.shrink();
    // Avoid crowding near the last label.
    if (!isEdge && index > count - 1 - (step ~/ 2) && index != count - 1) {
      return const SizedBox.shrink();
    }

    final short = _axisLabel(daily[index].day, count);
    final rotate = count > 10;
    final text = Text(
      short,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.onSurfaceVariantOf(context),
            fontSize: count > 60 ? 9 : 11,
          ),
    );

    if (!rotate) {
      return Padding(padding: const EdgeInsets.only(top: 6), child: text);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Transform.rotate(
        angle: -0.65,
        child: text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxY = daily.fold<double>(1, (m, d) {
      final local = _valueFor(d).toDouble();
      return local > m ? local : m;
    });
    final label =
        metric == _OccupancyMetric.checkIns ? 'Check-ins' : 'Peak';
    final useLine = daily.length > 21;

    return LayoutBuilder(
      builder: (context, constraints) {
        final step = _labelStep(daily.length, constraints.maxWidth);
        final bottomReserve = daily.length > 10 ? 44.0 : 28.0;

        if (useLine) {
          return LineChart(
            LineChartData(
              minX: 0,
              maxX: (daily.length - 1).toDouble(),
              minY: 0,
              maxY: maxY + 1,
              clipData: const FlClipData.all(),
              lineTouchData: LineTouchData(
                handleBuiltInTouches: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => Theme.of(context).colorScheme.inverseSurface,
                  getTooltipItems: (spots) {
                    return spots.map((spot) {
                      final i = spot.x.round().clamp(0, daily.length - 1);
                      return LineTooltipItem(
                        '${daily[i].day}\n$label: ${spot.y.toInt()}',
                        TextStyle(
                          color: Theme.of(context).colorScheme.onInverseSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, _) {
                      if (value % 1 != 0) return const SizedBox.shrink();
                      return Text(
                        value.toInt().toString(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.onSurfaceVariantOf(context),
                            ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: bottomReserve,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      return _bottomLabel(
                        context,
                        value.round(),
                        step,
                        daily.length,
                      );
                    },
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: AppColors.borderOf(context),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < daily.length; i++)
                      FlSpot(i.toDouble(), _valueFor(daily[i]).toDouble()),
                  ],
                  isCurved: daily.length <= 60,
                  curveSmoothness: 0.18,
                  color: barColor,
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: daily.length <= 45,
                    getDotPainter: (spot, percent, bar, index) {
                      return FlDotCirclePainter(
                        radius: 3,
                        color: barColor,
                        strokeWidth: 0,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: barColor.withValues(alpha: 0.10),
                  ),
                ),
              ],
            ),
          );
        }

        return BarChart(
          BarChartData(
            maxY: maxY + 1,
            alignment: BarChartAlignment.spaceAround,
            groupsSpace: daily.length > 14 ? 2 : 6,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => Theme.of(context).colorScheme.inverseSurface,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final day = daily[group.x.toInt()];
                  return BarTooltipItem(
                    '${day.day}\n$label: ${rod.toY.toInt()}',
                    TextStyle(color: Theme.of(context).colorScheme.onInverseSurface, fontSize: 12),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, _) {
                    if (value % 1 != 0) return const SizedBox.shrink();
                    return Text(
                      value.toInt().toString(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.onSurfaceVariantOf(context),
                          ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: bottomReserve,
                  getTitlesWidget: (value, meta) {
                    return _bottomLabel(
                      context,
                      value.toInt(),
                      step,
                      daily.length,
                    );
                  },
                ),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                  color: AppColors.borderOf(context),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: [
              for (var i = 0; i < daily.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: _valueFor(daily[i]).toDouble(),
                      width: daily.length > 14
                          ? (constraints.maxWidth / daily.length * 0.55)
                              .clamp(3.0, 10.0)
                          : 12,
                      color: barColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(3),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

enum _PaymentAmountMode { total, platform, landOwner }

class _PaymentSection extends StatelessWidget {
  const _PaymentSection({
    required this.title,
    required this.items,
    required this.currency,
    required this.emptyLabel,
    this.amountMode = _PaymentAmountMode.total,
  });

  final String title;
  final List<AdminPaymentItem> items;
  final NumberFormat currency;
  final String emptyLabel;
  final _PaymentAmountMode amountMode;

  double _displayAmount(AdminPaymentItem item) {
    switch (amountMode) {
      case _PaymentAmountMode.platform:
        return item.platformCommission;
      case _PaymentAmountMode.landOwner:
        return item.landOwnerPayout;
      case _PaymentAmountMode.total:
        return item.amount;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.borderOf(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  emptyLabel,
                  style: TextStyle(color: AppColors.onSurfaceVariantOf(context)),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final subtitle = [
                    if ((item.vehicleNumber ?? '').isNotEmpty) item.vehicleNumber!,
                    if ((item.bookingRef ?? '').isNotEmpty) item.bookingRef!,
                  ].join(' · ');
                  final amountLabel = switch (amountMode) {
                    _PaymentAmountMode.platform =>
                      'Platform ${currency.format(_displayAmount(item))}',
                    _PaymentAmountMode.landOwner =>
                      'Owner ${currency.format(_displayAmount(item))}',
                    _PaymentAmountMode.total => currency.format(item.amount),
                  };
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      amountLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurfaceOf(context),
                      ),
                    ),
                    subtitle: Text(
                      [
                        if (subtitle.isNotEmpty) subtitle,
                        if (amountMode == _PaymentAmountMode.total &&
                            item.isPaid &&
                            item.platformCommission > 0)
                          'Platform ${currency.format(item.platformCommission)} · '
                              'Owner ${currency.format(item.landOwnerPayout)}',
                        if ((item.at ?? '').isNotEmpty)
                          item.at!.split('T').first,
                      ].where((e) => e.isNotEmpty).join('\n'),
                      style: TextStyle(color: AppColors.onSurfaceVariantOf(context)),
                    ),
                    trailing: Icon(
                      item.isPaid ? Icons.check_circle : Icons.schedule,
                      color: item.isPaid
                          ? AppColors.available
                          : AppColors.limited,
                      size: 20,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
