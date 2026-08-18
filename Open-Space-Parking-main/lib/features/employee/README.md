# Employee Module

Isolated employee portal for field/construction staff.

## Access

- Login only at `/employee/login` (not shown in normal app navigation)
- Credentials are created by Admin when adding an employee
- Authenticated employees are confined to `/employee/*` routes

## Features

- Dashboard KPIs
- Assigned Projects
- Ticket detail with Owner Details
- GPS Navigation
- Quotation submission
- Construction progress updates
- Completed Projects
- Notifications

## Architecture

- Domain: Quotation, ConstructionProgressEntry, EmployeeNotification, EmployeeRepository
- Data: MongoEmployeeRepository
- Presentation: Riverpod providers + Material 3 shell UI
