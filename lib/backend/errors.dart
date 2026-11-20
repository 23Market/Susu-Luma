import '../chat_media.dart';

/// Turns server error codes (raised by the SQL functions) into messages a business user can act on.
String friendlyError(Object e) {
  if (e is MediaException) return e.message;
  final raw = e.toString();
  const map = {
    'not_authenticated': 'Please sign in again.',
    'not_permitted':
        'Your account is not allowed to do that for this business.',
    'quote_expired':
        'This quotation has expired. Ask the supplier for a new one.',
    'quote_not_acceptable': 'This quotation can no longer be accepted.',
    'rfq_not_open': 'This request is no longer open for quotes.',
    'not_a_recipient': 'This request was not sent to your business.',
    'invalid_state': 'That is not possible at this stage of the order.',
    'every_item_must_be_priced_once': 'Every item must be priced.',
    'quantity_invalid': 'Enter a quantity above zero.',
    'listing_unavailable': 'That product is no longer available.',
    'no_valid_recipients': 'No supplier could be found for this request.',
    'organization_not_active_buyer':
        'Your business is not an active buyer account.',
    'organization_not_active_supplier':
        'Your business is not an active supplier account.',
    'description_required': 'Please describe the problem.',
    'validity_in_past': 'The quote validity date must be in the future.',
    'multi_item_unsupported':
        'This request has several items. Multi-item quotes are not supported in the app yet.',
    'media_invalid':
        'That file cannot be sent. Photos can be up to 5 MB and voice notes up to 60 seconds.',
    'media_not_uploaded': 'The file did not finish uploading. Please try again.',
    'Invalid login credentials': 'Email or password is incorrect.',
    'User already registered': 'An account with this email already exists.',
  };
  for (final entry in map.entries) {
    if (raw.contains(entry.key)) return entry.value;
  }
  if (raw.contains('SocketException') || raw.contains('ClientException')) {
    return 'No connection. Check your network and try again.';
  }
  return 'Something went wrong. Please try again.';
}
