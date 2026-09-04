const test = require('node:test');
const assert = require('node:assert/strict');

const {
  canAutoTransferToLandOwner,
  bankFingerprint,
} = require('./razorpay_route');

test('canAutoTransferToLandOwner requires activated acc_', () => {
  assert.equal(
    canAutoTransferToLandOwner({
      razorpayLinkedAccountId: 'acc_test123',
      razorpayActivationStatus: 'activated',
    }),
    true,
  );
  assert.equal(
    canAutoTransferToLandOwner({
      razorpayLinkedAccountId: 'acc_test123',
      razorpayActivationStatus: 'pending',
    }),
    false,
  );
  assert.equal(
    canAutoTransferToLandOwner({
      razorpayLinkedAccountId: '',
      razorpayActivationStatus: 'activated',
    }),
    false,
  );
});

test('bankFingerprint is stable for same bank details', () => {
  const a = bankFingerprint({
    accountHolderName: 'Rajesh Kumar',
    bankAccountNumber: '1234567890',
    ifscCode: 'sbin0001234',
  });
  const b = bankFingerprint({
    accountHolderName: ' rajesh kumar ',
    bankAccountNumber: '1234567890',
    ifscCode: 'SBIN0001234',
  });
  assert.equal(a, b);
});
