/**
 * Razorpay Route linked-account onboarding for land owners.
 *
 * Flow (when Route is enabled on the merchant account):
 *  1. Create linked account (acc_...)
 *  2. Create stakeholder
 *  3. Request Route product configuration
 *  4. Submit bank settlements → penny test → activation_status
 *
 * E Star merchant keeps 10% on the main account (no company transfer needed).
 * Land owner 90% transfers only when activationStatus === 'activated'.
 */

const https = require('https');

function razorpayConfigured() {
  return Boolean(
    (process.env.RAZORPAY_KEY_ID || '').trim() &&
      (process.env.RAZORPAY_KEY_SECRET || '').trim(),
  );
}

function authHeader() {
  const id = (process.env.RAZORPAY_KEY_ID || '').trim();
  const secret = (process.env.RAZORPAY_KEY_SECRET || '').trim();
  return Buffer.from(`${id}:${secret}`).toString('base64');
}

function razorpayRequest(method, apiPath, body) {
  return new Promise((resolve, reject) => {
    const payload = body == null ? null : JSON.stringify(body);
    const req = https.request(
      {
        hostname: 'api.razorpay.com',
        path: apiPath,
        method,
        headers: {
          Authorization: `Basic ${authHeader()}`,
          ...(payload
            ? {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(payload),
              }
            : {}),
        },
      },
      (res) => {
        let raw = '';
        res.on('data', (chunk) => {
          raw += chunk;
        });
        res.on('end', () => {
          let data = {};
          try {
            data = raw ? JSON.parse(raw) : {};
          } catch {
            data = { raw };
          }
          resolve({ status: res.statusCode || 0, data });
        });
      },
    );
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

function digitsOnly(value) {
  return String(value || '').replace(/\D/g, '');
}

function normalizePhone(value) {
  const digits = digitsOnly(value).slice(-10);
  if (digits.length !== 10) return null;
  return digits;
}

function normalizeEmail(value, ownerId) {
  const email = String(value || '').trim().toLowerCase();
  if (email.includes('@')) return email;
  const safe = String(ownerId || 'owner')
    .replace(/[^a-zA-Z0-9]/g, '')
    .slice(0, 24);
  return `owner_${safe || 'user'}@openspace.local`;
}

function normalizePan(value) {
  return String(value || '')
    .trim()
    .toUpperCase();
}

function isValidPan(pan) {
  return /^[A-Z]{5}[0-9]{4}[A-Z]$/.test(pan);
}

function isValidIfsc(ifsc) {
  return /^[A-Z]{4}0[A-Z0-9]{6}$/.test(String(ifsc || '').toUpperCase());
}

function parseAddressParts(payout, ownerDetails) {
  const city = String(payout.city || '').trim();
  const state = String(payout.state || '').trim().toUpperCase();
  const postal = digitsOnly(payout.postalCode || payout.pinCode).slice(0, 6);
  const street =
    String(payout.street || ownerDetails?.address || '').trim() ||
    'Registered address';

  // Prefer explicit fields; fall back to parsing a free-form address.
  let resolvedCity = city;
  let resolvedState = state;
  let resolvedPostal = postal.length === 6 ? postal : '';

  if (!resolvedPostal) {
    const match = street.match(/\b(\d{6})\b/);
    if (match) resolvedPostal = match[1];
  }
  if (!resolvedCity) {
    const parts = street.split(',').map((p) => p.trim()).filter(Boolean);
    if (parts.length >= 2) resolvedCity = parts[parts.length - 2];
  }
  if (!resolvedState) resolvedState = 'TN';
  if (!resolvedCity) resolvedCity = 'Chennai';
  if (!resolvedPostal) resolvedPostal = '600001';

  return {
    street1: street.slice(0, 100),
    street2: 'India',
    city: resolvedCity.slice(0, 100),
    state: resolvedState.slice(0, 32),
    postal_code: resolvedPostal,
    country: 'IN',
  };
}

function bankFingerprint(payout) {
  return [
    String(payout.bankAccountNumber || '').trim(),
    String(payout.ifscCode || '').trim().toUpperCase(),
    String(payout.accountHolderName || '').trim().toLowerCase(),
  ].join('|');
}

function mapActivationStatus(status) {
  const value = String(status || '').toLowerCase();
  if (value === 'activated') return 'activated';
  if (value === 'under_review' || value === 'requested') return 'pending';
  if (value === 'needs_clarification') return 'needs_clarification';
  if (value === 'suspended') return 'failed';
  if (value === 'verification_failed') return 'failed';
  return value || 'pending';
}

async function createLinkedAccount({ ownerId, ownerDetails, payout }) {
  const name = String(
    payout.accountHolderName || ownerDetails?.fullName || '',
  ).trim();
  const email = normalizeEmail(ownerDetails?.email || payout.email, ownerId);
  const phone = normalizePhone(ownerDetails?.phone || payout.phone);
  const pan = normalizePan(payout.pan);
  const address = parseAddressParts(payout, ownerDetails);

  if (!name || name.length < 4) {
    throw Object.assign(new Error('Account holder name is required (min 4 characters).'), {
      statusCode: 400,
    });
  }
  if (!phone) {
    throw Object.assign(new Error('A valid 10-digit mobile number is required on the land owner profile.'), {
      statusCode: 400,
    });
  }
  if (!isValidPan(pan)) {
    throw Object.assign(new Error('Enter a valid PAN (e.g. ABCDE1234F) to create a Razorpay payout account.'), {
      statusCode: 400,
    });
  }

  const accountBody = {
    email,
    phone,
    type: 'route',
    reference_id: String(ownerId).slice(0, 40),
    legal_business_name: name.slice(0, 200),
    business_type: 'individual',
    contact_name: name.slice(0, 255),
    profile: {
      category: 'ecommerce',
      subcategory: 'marketplace',
      addresses: {
        registered: address,
      },
    },
    legal_info: {
      pan,
    },
  };

  const created = await razorpayRequest('POST', '/v2/accounts', accountBody);
  if (created.status >= 400 || !created.data?.id) {
    const description =
      created.data?.error?.description ||
      created.data?.description ||
      'Could not create Razorpay linked account.';
    throw Object.assign(new Error(description), {
      statusCode: created.status >= 400 ? created.status : 502,
      razorpay: created.data,
    });
  }
  return created.data;
}

async function createStakeholder(accountId, { ownerDetails, payout }) {
  const name = String(
    payout.accountHolderName || ownerDetails?.fullName || '',
  ).trim();
  const email = normalizeEmail(ownerDetails?.email || payout.email, accountId);
  const phone = normalizePhone(ownerDetails?.phone || payout.phone);
  const address = parseAddressParts(payout, ownerDetails);

  const body = {
    name,
    email,
    percentage_ownership: 100,
    relationship: {
      director: true,
      executive: true,
    },
    phone: {
      primary: phone,
    },
    addresses: {
      residential: {
        street: address.street1,
        city: address.city,
        state: address.state,
        postal_code: address.postal_code,
        country: 'IN',
      },
    },
  };

  const result = await razorpayRequest(
    'POST',
    `/v2/accounts/${encodeURIComponent(accountId)}/stakeholders`,
    body,
  );
  // Some accounts already have a stakeholder — treat as non-fatal.
  if (result.status >= 400) {
    const reason = String(result.data?.error?.reason || '');
    const description = String(result.data?.error?.description || '');
    if (
      reason.includes('stakeholder') ||
      description.toLowerCase().includes('already') ||
      description.toLowerCase().includes('more than one')
    ) {
      return result.data;
    }
    throw Object.assign(
      new Error(description || 'Could not create Razorpay stakeholder.'),
      { statusCode: result.status, razorpay: result.data },
    );
  }
  return result.data;
}

async function requestProduct(accountId) {
  const result = await razorpayRequest(
    'POST',
    `/v2/accounts/${encodeURIComponent(accountId)}/products`,
    { product_name: 'route', tnc_accepted: true },
  );
  if (result.status >= 400 || !result.data?.id) {
    throw Object.assign(
      new Error(
        result.data?.error?.description ||
          'Could not request Razorpay Route product. Ensure Route is enabled on the E Star merchant account.',
      ),
      { statusCode: result.status >= 400 ? result.status : 502, razorpay: result.data },
    );
  }
  return result.data;
}

async function updateProductBank(accountId, productId, payout) {
  const accountNumber = String(payout.bankAccountNumber || '').trim();
  const ifsc = String(payout.ifscCode || '').trim().toUpperCase();
  const beneficiary = String(payout.accountHolderName || '').trim();

  if (accountNumber.length < 5 || accountNumber.length > 35) {
    throw Object.assign(new Error('Enter a valid bank account number.'), {
      statusCode: 400,
    });
  }
  if (!isValidIfsc(ifsc)) {
    throw Object.assign(new Error('Enter a valid IFSC code (e.g. SBIN0001234).'), {
      statusCode: 400,
    });
  }
  if (!beneficiary) {
    throw Object.assign(new Error('Account holder name is required.'), {
      statusCode: 400,
    });
  }

  const result = await razorpayRequest(
    'PATCH',
    `/v2/accounts/${encodeURIComponent(accountId)}/products/${encodeURIComponent(productId)}/`,
    {
      settlements: {
        account_number: accountNumber,
        ifsc_code: ifsc,
        beneficiary_name: beneficiary,
      },
      tnc_accepted: true,
    },
  );
  if (result.status >= 400) {
    throw Object.assign(
      new Error(
        result.data?.error?.description ||
          'Could not submit bank details to Razorpay.',
      ),
      { statusCode: result.status, razorpay: result.data },
    );
  }
  return result.data;
}

async function fetchProduct(accountId, productId) {
  const result = await razorpayRequest(
    'GET',
    `/v2/accounts/${encodeURIComponent(accountId)}/products/${encodeURIComponent(productId)}/`,
  );
  if (result.status >= 400) {
    throw Object.assign(
      new Error(
        result.data?.error?.description || 'Could not fetch Razorpay product status.',
      ),
      { statusCode: result.status, razorpay: result.data },
    );
  }
  return result.data;
}

/**
 * Create or refresh a land-owner Route linked account and return payout fields to persist.
 */
async function onboardLandOwnerLinkedAccount({
  ownerId,
  ownerDetails,
  payout,
  existingPayout,
}) {
  if (!razorpayConfigured()) {
    return {
      ...payout,
      razorpayLinkedAccountId: existingPayout?.razorpayLinkedAccountId || null,
      razorpayProductId: existingPayout?.razorpayProductId || null,
      razorpayActivationStatus: 'not_configured',
      razorpayStatusMessage:
        'Razorpay keys are not configured on the server yet. Bank details were saved; linked account will be created after keys + Route are enabled.',
      razorpayBankFingerprint: bankFingerprint(payout),
      razorpayOnboardedAt: new Date().toISOString(),
    };
  }

  const accountNumber = String(payout.bankAccountNumber || '').trim();
  const ifsc = String(payout.ifscCode || '').trim().toUpperCase();
  if (!accountNumber || !ifsc) {
    throw Object.assign(
      new Error('Bank account number and IFSC are required for automatic payout setup.'),
      { statusCode: 400 },
    );
  }

  const fingerprint = bankFingerprint({
    ...payout,
    bankAccountNumber: accountNumber,
    ifscCode: ifsc,
  });

  let accountId = String(existingPayout?.razorpayLinkedAccountId || '').trim();
  let productId = String(existingPayout?.razorpayProductId || '').trim();
  const sameBank =
    existingPayout?.razorpayBankFingerprint &&
    existingPayout.razorpayBankFingerprint === fingerprint;

  try {
    if (!accountId) {
      const account = await createLinkedAccount({
        ownerId,
        ownerDetails,
        payout: { ...payout, bankAccountNumber: accountNumber, ifscCode: ifsc },
      });
      accountId = account.id;
      await createStakeholder(accountId, {
        ownerDetails,
        payout: { ...payout, bankAccountNumber: accountNumber, ifscCode: ifsc },
      });
      const product = await requestProduct(accountId);
      productId = product.id;
      const updated = await updateProductBank(accountId, productId, {
        ...payout,
        bankAccountNumber: accountNumber,
        ifscCode: ifsc,
      });
      return {
        ...payout,
        bankAccountNumber: accountNumber,
        ifscCode: ifsc,
        razorpayLinkedAccountId: accountId,
        razorpayProductId: productId,
        razorpayActivationStatus: mapActivationStatus(updated.activation_status),
        razorpayStatusMessage:
          updated.activation_status === 'activated'
            ? 'Payout account is active. 90% will transfer automatically on payment.'
            : 'Linked account created. Razorpay is verifying bank details (usually ~1 minute).',
        razorpayBankFingerprint: fingerprint,
        razorpayOnboardedAt: new Date().toISOString(),
        razorpayRequirements: updated.requirements || [],
      };
    }

    // Existing linked account — refresh / update bank if needed.
    if (!productId) {
      const product = await requestProduct(accountId);
      productId = product.id;
    }

    let productData;
    if (!sameBank) {
      productData = await updateProductBank(accountId, productId, {
        ...payout,
        bankAccountNumber: accountNumber,
        ifscCode: ifsc,
      });
    } else {
      productData = await fetchProduct(accountId, productId);
    }

    return {
      ...payout,
      bankAccountNumber: accountNumber,
      ifscCode: ifsc,
      razorpayLinkedAccountId: accountId,
      razorpayProductId: productId,
      razorpayActivationStatus: mapActivationStatus(productData.activation_status),
      razorpayStatusMessage:
        productData.activation_status === 'activated'
          ? 'Payout account is active. 90% will transfer automatically on payment.'
          : 'Razorpay is still verifying this payout account.',
      razorpayBankFingerprint: fingerprint,
      razorpayOnboardedAt:
        existingPayout?.razorpayOnboardedAt || new Date().toISOString(),
      razorpayUpdatedAt: new Date().toISOString(),
      razorpayRequirements: productData.requirements || [],
    };
  } catch (error) {
    const message =
      error.message ||
      'Could not create Razorpay linked account. Check Route is enabled and details are correct.';
    return {
      ...payout,
      bankAccountNumber: accountNumber,
      ifscCode: ifsc,
      razorpayLinkedAccountId: accountId || existingPayout?.razorpayLinkedAccountId || null,
      razorpayProductId: productId || existingPayout?.razorpayProductId || null,
      razorpayActivationStatus: 'failed',
      razorpayStatusMessage: message,
      razorpayBankFingerprint: fingerprint,
      razorpayOnboardedAt: new Date().toISOString(),
      razorpayLastError: message,
    };
  }
}

async function refreshLandOwnerLinkedAccountStatus(existingPayout) {
  const accountId = String(existingPayout?.razorpayLinkedAccountId || '').trim();
  const productId = String(existingPayout?.razorpayProductId || '').trim();
  if (!razorpayConfigured() || !accountId || !productId) {
    return existingPayout || null;
  }
  try {
    const productData = await fetchProduct(accountId, productId);
    return {
      ...existingPayout,
      razorpayActivationStatus: mapActivationStatus(productData.activation_status),
      razorpayStatusMessage:
        productData.activation_status === 'activated'
          ? 'Payout account is active. 90% will transfer automatically on payment.'
          : 'Razorpay is still verifying this payout account.',
      razorpayUpdatedAt: new Date().toISOString(),
      razorpayRequirements: productData.requirements || [],
    };
  } catch (error) {
    return {
      ...existingPayout,
      razorpayStatusMessage: error.message,
      razorpayUpdatedAt: new Date().toISOString(),
    };
  }
}

function canAutoTransferToLandOwner(payout) {
  const id = String(payout?.razorpayLinkedAccountId || '').trim();
  const status = String(payout?.razorpayActivationStatus || '').toLowerCase();
  return id.startsWith('acc_') && status === 'activated';
}

module.exports = {
  onboardLandOwnerLinkedAccount,
  refreshLandOwnerLinkedAccountStatus,
  canAutoTransferToLandOwner,
  razorpayConfigured,
  bankFingerprint,
};
