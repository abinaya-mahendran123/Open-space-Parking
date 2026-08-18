# Admin Portal (Isolated)

Completely isolated from the normal application.

## Access rules

- Admin login is only available at `/admin/login` (never linked from app UI).
- Authenticated admins are confined to `/admin/*` routes.
- Land owners and vehicle owners are redirected away from all admin routes.
- Unauthenticated users hitting `/admin/portal` are sent to `/admin/login`.

## Features

- Dashboard with operational KPIs
- Construction / ticket management
- Document verification
- Approve / Reject workflows
- Employee management + assignment
- Search and filter
- Statistics with pie/bar charts (`fl_chart`)

## Architecture

- Domain: `Employee`, `AdminStatistics`, `AdminRepository`
- Data: `MongoAdminRepository`
- Presentation: Riverpod providers + Material 3 shell UI
