# Cloudinary Integration

Upload images, PDFs, and documents to Cloudinary. **Only URLs** (and metadata) are stored in MongoDB — never file bytes.

## Features

- Upload images, PDFs, and generic documents
- File validation (type + size limits)
- Upload progress indicator
- Preview (images inline, PDFs/documents with open-in-browser)
- Delete from Cloudinary + soft-delete MongoDB record
- MongoDB `documents` collection via `DocumentMongoRepository`

## Configuration

Pass at build/run time:

```bash
flutter run \
  --dart-define=CLOUDINARY_CLOUD_NAME=your_cloud \
  --dart-define=CLOUDINARY_UPLOAD_PRESET=your_unsigned_preset \
  --dart-define=CLOUDINARY_API_KEY=your_api_key \
  --dart-define=CLOUDINARY_API_SECRET=your_api_secret
```

| Variable | Required | Purpose |
|----------|----------|---------|
| `CLOUDINARY_CLOUD_NAME` | Yes (upload) | Cloud name |
| `CLOUDINARY_UPLOAD_PRESET` | Yes (upload) | Unsigned upload preset |
| `CLOUDINARY_API_KEY` | Delete only | Signed destroy API |
| `CLOUDINARY_API_SECRET` | Delete only | Signed destroy API |

Create an **unsigned upload preset** in the Cloudinary dashboard with folder/authentication settings as needed.

## Size limits

| Category | Max size | Extensions |
|----------|----------|------------|
| Image | 10 MB | jpg, jpeg, png, webp, gif |
| PDF | 20 MB | pdf |
| Document | 15 MB | pdf, doc, docx, txt, jpg, jpeg, png |

## MongoDB schema (`documents`)

```json
{
  "ownerId": "...",
  "ownerType": "land_owner",
  "fileName": "patta.pdf",
  "fileType": "application/pdf",
  "url": "https://res.cloudinary.com/.../file.pdf",
  "publicId": "open_space_parking/abc123",
  "resourceType": "raw",
  "referenceId": "optional-context-id"
}
```

Land owner request documents store Cloudinary URLs in existing `governmentIdPath`, `propertyDocumentPath`, etc. fields.

## Usage

```dart
CloudinaryUploadTile(
  label: 'Government ID',
  fileUrl: documents.governmentIdPath,
  category: CloudinaryFileCategory.document,
  ownerId: userId,
  ownerType: 'land_owner',
  onUrlChanged: (url) => updateDocuments(url),
)
```
