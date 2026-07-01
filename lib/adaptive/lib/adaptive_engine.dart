/// Adaptive Engine — Dart Client
///
/// V2.5: No local BKT computation. Client sends raw submission to server.
/// Server is authoritative for correctness, state mutation.
/// Client only: locks UI, shows "Checking...", returns result from server.
library adaptive_engine;

export 'src/adaptive_service.dart';
export 'src/adaptive_types.dart';
export 'src/adaptive_fixtures.dart';
