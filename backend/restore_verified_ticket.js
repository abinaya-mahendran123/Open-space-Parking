const now = new Date().toISOString();
const submittedAt = new Date('2026-08-10T06:57:00.000Z').toISOString(); // 12:27 PM IST

db.land_owner_requests.deleteMany({ ticketId: 'OSP-20260810-9430' });

db.land_owner_requests.insertOne({
  ticketId: 'OSP-20260810-9430',
  ownerId: 'land-owner-yasin',
  requestType: 'build_parking',
  status: 'approved',
  documentsVerified: true,
  assignedEmployeeId: null,
  assignedEmployeeName: null,
  ownerDetails: {
    fullName: 'Yasin',
    email: 'aasin12@gmail.com',
    phone: '2345667567',
    address: 'madurai',
  },
  documents: {
    governmentIdPath: 'verified',
    propertyDocumentPath: 'verified',
    pattaPath: 'verified',
    propertyTaxPath: 'verified',
  },
  landDetails: {
    gpsLatitude: 13.052078844064647,
    gpsLongitude: 80.22914082796493,
    areaSqFt: 246,
    roadAccess: true,
    drainage: true,
    flood: false,
    boundary: true,
    cctv: false,
    landAddress: 'madurai',
  },
  parkingPreferences: {
    priority: 'medium',
    parkingType: 'tower_parking',
    numberOfCars: 6,
  },
  submittedAt,
  reviewedAt: now,
  createdAt: submittedAt,
  updatedAt: now,
});

print('Restored ticket OSP-20260810-9430');
print('Total: ' + db.land_owner_requests.countDocuments());
printjson(
  db.land_owner_requests.findOne(
    { ticketId: 'OSP-20260810-9430' },
    {
      ticketId: 1,
      status: 1,
      documentsVerified: 1,
      'landDetails.gpsLatitude': 1,
      'landDetails.gpsLongitude': 1,
      'landDetails.landAddress': 1,
      'landDetails.areaSqFt': 1,
    },
  ),
);
