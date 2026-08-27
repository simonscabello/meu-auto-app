import 'package:flutter_test/flutter_test.dart';

/// A required contract field that is missing must not parse as a silent
/// default. The runtime type error is the failure mode we have today, and it
/// is the one a test can pin down without inventing a second parser.
final Matcher throwsMissingRequired = throwsA(
  anyOf(isA<TypeError>(), isA<ArgumentError>(), isA<FormatException>()),
);
