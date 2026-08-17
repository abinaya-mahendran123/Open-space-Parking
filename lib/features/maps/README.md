# Google Maps Module

Reusable maps feature with location services, marker selection, saved coordinates, nearby parking, directions, and navigation.

## Architecture

```
maps/
├── domain/
│   ├── entities/          MapCoordinate, SavedCoordinate, MapMarkerData, ...
│   └── repositories/        MapsRepository (abstract)
├── data/
│   ├── services/
│   │   ├── location_service.dart              Geolocator wrapper
│   │   ├── google_maps_navigation_service.dart  Directions & navigation URLs
│   │   └── saved_coordinates_storage_service.dart Secure storage persistence
│   └── repositories/
│       └── maps_repository_impl.dart
└── presentation/
    ├── providers/maps_providers.dart   Riverpod state + helpers
    ├── pages/
    │   ├── map_picker_page.dart        Marker selection + save coordinates
    │   ├── nearby_parking_map_page.dart Full-screen nearby parking map
    │   └── saved_coordinates_page.dart Saved locations list
    └── widgets/
        ├── google_map_view.dart        Core GoogleMap Flutter widget
        ├── location_permission_banner.dart
        ├── directions_bar.dart       Directions + Navigate buttons
        └── selected_coordinate_card.dart
```

## Features

| Feature | Implementation |
|---------|----------------|
| **Current Location** | `LocationService` + `currentLocationProvider` |
| **Location Permission** | `LocationPermissionBanner`, request/check via repository |
| **Marker Selection** | Tap map in `GoogleMapView` → `MapSelectionNotifier` |
| **Save Coordinates** | `SavedCoordinatesStorageService` (secure storage) |
| **Nearby Parking** | `nearbyParkingMarkersProvider` + vehicle owner listings |
| **Directions** | Google Maps directions URL via `DirectionsBar` |
| **Navigation** | Turn-by-turn navigation URL launch |
| **Google Maps Flutter** | `google_maps_flutter` in `GoogleMapView` |

## Routes

| Path | Page |
|------|------|
| `/maps/picker` | Map picker (returns `MapCoordinate`) |
| `/maps/nearby-parking` | Full nearby parking map |
| `/maps/saved-coordinates` | Saved coordinates list |

## Usage

### Pick location (returns coordinate)
```dart
final result = await context.push<MapCoordinate>(RoutePaths.mapPicker);
if (result != null) {
  // use result.latitude, result.longitude
}
```

### Embedded map
```dart
GoogleMapView(
  height: 240,
  enableSelection: true,
  showCurrentLocation: true,
  markers: myMarkers,
  onMarkerTap: (marker) => ...,
)
```

### Directions
```dart
DirectionsBar(
  destination: MapCoordinate(latitude: 12.97, longitude: 77.59),
  destinationLabel: 'Parking Spot',
)
```

## DI Registration

Registered in `service_locator.dart`:
- `LocationService`
- `GoogleMapsNavigationService`
- `SavedCoordinatesStorageService`
- `MapsRepository`

## Google Maps API Key

Required for embedded maps. See Vehicle Owner README for Android/iOS setup.

Without a key, external "Open in Google Maps" links still work via `url_launcher`.

## Integration

- **Vehicle Owner** — search page, parking detail use `GoogleMapView` + `DirectionsBar`
- **Land Owner** — land details form opens map picker for GPS coordinates
