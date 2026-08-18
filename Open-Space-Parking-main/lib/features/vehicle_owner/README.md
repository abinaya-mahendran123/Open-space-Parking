# Vehicle Owner Module

Full-featured parking discovery and booking for vehicle owners.

## Features

| Feature | Description |
|---------|-------------|
| **Register / Login** | Shared auth flow with `UserRole.vehicleOwner` |
| **Dashboard** | Welcome, quick actions, nearby parking preview |
| **Nearby Parking** | Search bar, GPS "Near Me", filters, list + Google Map |
| **Parking Details** | Image gallery, map, amenities, availability, ratings |
| **Parking Images** | Swipeable gallery with parking type images |
| **Parking Availability** | Real-time slot check against overlapping bookings |
| **Booking** | 3-step flow with availability validation |
| **History** | All bookings with status and pricing |
| **Favorites** | Save/remove parking spaces |
| **Reviews & Ratings** | 1–5 stars, comments, average on listings |
| **Profile** | Personal info + default vehicle |
| **Notifications** | Booking confirmations, cancellations |
| **Google Maps** | Embedded map on detail/search + external navigation |

## Navigation (Material 3)

Bottom `NavigationBar` with 5 tabs:
1. Home (Dashboard)
2. Nearby (Search + Map)
3. Favorites
4. History (Bookings)
5. Profile

Notifications accessible via app bar bell icon.

## MongoDB Collections

| Collection | Purpose |
|------------|---------|
| `land_owner_requests` | Parking inventory source |
| `bookings` | Reservations |
| `vehicle_owner_favorites` | Saved parking |
| `parking_reviews` | Reviews & ratings |
| `vehicle_owner_profiles` | User profile |
| `vehicle_owner_notifications` | Alerts |

## Google Maps Setup

Add your API key after running `flutter create .`:

**Android** — `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data android:name="com.google.android.geo.API_KEY"
           android:value="YOUR_API_KEY"/>
```

**iOS** — `ios/Runner/AppDelegate.swift`:
```swift
GMSServices.provideAPIKey("YOUR_API_KEY")
```

Without an API key, the map falls back to an "Open in Google Maps" card.

## Routes

| Path | Screen |
|------|--------|
| `/vehicle-owner/dashboard` | Home tab |
| `/vehicle-owner/search` | Nearby tab |
| `/vehicle-owner/favorites` | Favorites tab |
| `/vehicle-owner/bookings` | History tab |
| `/vehicle-owner/profile` | Profile tab |
| `/vehicle-owner/notifications` | Notifications (pushed) |
| `/vehicle-owner/parking/:id` | Parking detail |
| `/vehicle-owner/parking/:id/book` | Booking flow |
| `/vehicle-owner/bookings/:id` | Booking detail |
