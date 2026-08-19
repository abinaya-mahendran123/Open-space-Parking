# Employee Module

Isolated employee portal for field/construction staff.

## Access

- On the main sign-in screen, tap **Sign in with phone number**
- Enter the employee mobile number; the app detects employee accounts automatically
- Sign in with the **password** issued by Admin when the employee was created
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
