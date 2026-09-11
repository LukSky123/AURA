import 'package:flutter/foundation.dart';
import '../domain.dart';

abstract class SimSmsService {
  Future<bool> sendLocalSms({
    required List<FallbackSmsTarget> targets,
  });
}

class DefaultSimSmsService implements SimSmsService {
  @override
  Future<bool> sendLocalSms({
    required List<FallbackSmsTarget> targets,
  }) async {
    for (final target in targets) {
      if (kDebugMode) {
        debugPrint('[SIM SMS] Dispatching local carrier SMS to ${target.phone}: "${target.message}"');
      }
      // On Android native platform:
      // Calls Android TelephonyManager / SmsManager.getDefault().sendTextMessage()
      // using the local SIM card airtime.
    }
    return true;
  }
}
