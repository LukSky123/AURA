import '../domain.dart';

abstract class IncidentRepository {
  Future<void> dispatch(Incident incident);
  Future<void> cancel(String incidentId);
}

/// Network wiring deliberately lives behind this boundary. The production
/// implementation invokes authenticated Supabase Edge Functions; it never
/// sends Termii credentials or incident-link signing secrets to the device.
class DeferredIncidentRepository implements IncidentRepository {
  @override
  Future<void> cancel(String incidentId) async {}

  @override
  Future<void> dispatch(Incident incident) async {}
}
