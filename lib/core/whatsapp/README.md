# WhatsApp Integration

Send WhatsApp messages via **Meta WhatsApp Business API** or **Twilio**, with reusable templates and assignment notifications.

## Features

| Feature | Implementation |
|---------|----------------|
| **WhatsApp Service** | `WhatsAppService` — provider routing + template rendering |
| **Meta placeholder** | `MetaWhatsAppClient` — Graph API v21.0 |
| **Twilio placeholder** | `TwilioWhatsAppClient` — Messages API |
| **Employee assignment** | `sendEmployeeAssignment()` |
| **Owner assignment** | `sendOwnerAssignment()` |
| **Reusable templates** | `WhatsAppTemplates` with `{{variable}}` placeholders |
| **Riverpod** | `whatsapp_providers.dart` |

## Configuration

```bash
flutter run \
  --dart-define=WHATSAPP_PROVIDER=meta \
  --dart-define=META_WHATSAPP_PHONE_NUMBER_ID=your_phone_number_id \
  --dart-define=META_WHATSAPP_ACCESS_TOKEN=your_access_token
```

Twilio:

```bash
flutter run \
  --dart-define=WHATSAPP_PROVIDER=twilio \
  --dart-define=TWILIO_ACCOUNT_SID=your_sid \
  --dart-define=TWILIO_AUTH_TOKEN=your_token \
  --dart-define=TWILIO_WHATSAPP_FROM=whatsapp:+14155238886
```

| Variable | Provider | Purpose |
|----------|----------|---------|
| `WHATSAPP_PROVIDER` | All | `none`, `meta`, or `twilio` |
| `META_WHATSAPP_PHONE_NUMBER_ID` | Meta | Business phone number ID |
| `META_WHATSAPP_ACCESS_TOKEN` | Meta | Permanent access token |
| `TWILIO_ACCOUNT_SID` | Twilio | Account SID |
| `TWILIO_AUTH_TOKEN` | Twilio | Auth token |
| `TWILIO_WHATSAPP_FROM` | Twilio | Sender e.g. `whatsapp:+14155238886` |

When credentials are missing, messages are **simulated** (logged, no API call).

## Templates

| ID | Use case |
|----|----------|
| `employeeAssignment` | Notify employee of new ticket |
| `ownerAssignment` | Notify land owner that employee was assigned |
| `bookingConfirmation` | Vehicle owner booking confirmed |
| `requestStatusUpdate` | Generic status change |

```dart
await whatsAppService.sendTemplate(
  templateId: WhatsAppTemplateId.bookingConfirmation,
  toPhone: '+919876543210',
  variables: {
    'customerName': 'Alex',
    'bookingRef': 'OSP-001',
    'startTime': '10:00 AM',
    'endTime': '2:00 PM',
    'amount': '₹200',
  },
);
```

## Integration

Employee assignment in `MongoAdminRepository.assignEmployee()` automatically sends:
1. Employee assignment WhatsApp to the employee phone
2. Owner assignment WhatsApp to the land owner phone

Failures are logged and do not block the assignment.

## Architecture

```
lib/core/whatsapp/
├── data/
│   ├── providers/
│   │   ├── meta_whatsapp_client.dart
│   │   └── twilio_whatsapp_client.dart
│   ├── services/whatsapp_service.dart
│   └── templates/whatsapp_templates.dart
├── domain/entities/
└── presentation/providers/whatsapp_providers.dart
```
