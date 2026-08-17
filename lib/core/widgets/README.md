# Design System

Shared Material 3 UI components for Open Space Parking.

## Theme

- **Light / Dark** — system-aware via `ThemeMode.system` with animated transitions
- **Colors** — `app_colors.dart`, seed-based `ColorScheme`
- **Typography** — weighted hierarchy in `app_typography.dart`
- **Spacing / Radius** — `app_spacing.dart`

## Components

| Widget | Path | Use |
|--------|------|-----|
| `AppCard` | `widgets/cards/app_card.dart` | Base surface card |
| `AppActionCard` | `widgets/cards/app_action_card.dart` | Dashboard quick actions |
| `AppStatCard` | `widgets/cards/app_stat_card.dart` | KPI / stat tiles |
| `AppPageHeader` | `widgets/layout/app_page_header.dart` | Page title + subtitle |
| `ResponsivePage` | `widgets/layout/responsive_page.dart` | Max-width + padding |
| `AppFadeSlide` | `widgets/animations/app_fade_slide.dart` | Entrance animation |
| `AppStaggeredList` | `widgets/animations/app_fade_slide.dart` | Staggered list items |
| `AppShimmer` | `widgets/loading/app_shimmer.dart` | Shimmer wrapper |
| `AppSkeleton` | `widgets/loading/app_skeleton.dart` | Skeleton placeholders |
| `AppLoadingWidget` | `widgets/loading/app_loading_widget.dart` | Spinner or skeleton |
| `AppErrorWidget` | `widgets/errors/app_error_widget.dart` | Error + retry |
| `AppEmptyState` | `widgets/errors/app_error_widget.dart` | Empty lists |
| `AppDialogs` | `widgets/dialogs/app_dialogs.dart` | Animated dialogs |
| `PrimaryButton` | `widgets/buttons/primary_button.dart` | CTA buttons |
| `AppTextField` | `widgets/textfields/app_text_field.dart` | Form inputs |

## Loading pattern

```dart
AppLoadingWidget(
  message: 'Loading...',
  useSkeleton: true,
  skeleton: AppSkeleton.statGrid(context),
)
```

## Responsive

```dart
ResponsivePage(
  maxWidth: 900,
  scrollable: true,
  child: ...,
)
```

Grid columns adapt via `responsiveGridCount(context)`.
