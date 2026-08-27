import 'package:uuid/uuid.dart';

/// The id the app sends with a POST so a retry is not a second row.
///
/// The contract asks for UUIDv7 specifically, not any UUID: it sorts by
/// creation time, which is what lets the server treat a repeated `id` as the
/// same write instead of a new one. Three repositories needed exactly this
/// line, so it lives here rather than three times over.
///
/// Repositories still take a `newId` parameter — the value has to be
/// injectable for a test to assert on it — and default to this.
String newClientId() => const Uuid().v7();
