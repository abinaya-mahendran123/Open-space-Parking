/// Current land-owner payout terms version.
/// Bump this when legal text changes so users must re-accept.
class LandOwnerPayoutTerms {
  LandOwnerPayoutTerms._();

  static const String version = '1.3';

  static const String title = 'Payout terms';

  static const String subtitle =
      'Accept these to upload documents and list parking.';

  /// Short title + one simple sentence.
  static const List<({String title, String body})> points = [
    (
      title: 'Your share — 90%',
      body: 'When a driver pays, 90% goes to you.',
    ),
    (
      title: 'When money reaches your bank',
      body: 'Your share usually arrives in about 2 working days.',
    ),
    (
      title: 'Platform fee — 10%',
      body: 'E Star keeps 10% as the platform fee.',
    ),
    (
      title: 'Payment charges',
      body: 'Razorpay may take a small fee and GST on that fee.',
    ),
    (
      title: 'Your bank details',
      body: 'Add correct bank and PAN details for automatic payouts.',
    ),
  ];

  static const String checkboxLabel = 'I agree to these payout terms';
}
