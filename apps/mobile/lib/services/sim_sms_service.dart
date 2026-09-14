import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../domain.dart';

abstract class SimSmsService {
  Future<bool> sendLocalSms({
    required List<FallbackSmsTarget> targets,
  });
}

class DefaultSimSmsService implements SimSmsService {
  static const MethodChannel _nativeChannel =
      MethodChannel('com.aura.safety/native_controls');

  @override
  Future<bool> sendLocalSms({
    required List<FallbackSmsTarget> targets,
  }) async {
    if (targets.isEmpty) return true;

    // Verify / request runtime SMS dispatch permission on Android
    final smsStatus = await Permission.sms.status;
    if (!smsStatus.isGranted) {
      final requested = await Permission.sms.request();
      if (!requested.isGranted) {
        if (kDebugMode) {
          debugPrint('[SIM SMS] SEND_SMS permission denied by user. Cannot dispatch offline local carrier SMS.');
        }
        return false;
      }
    }

    bool allSuccess = true;
    for (final target in targets) {
      if (kDebugMode) {
        debugPrint('[SIM SMS] Dispatching local carrier SMS to ${target.phone}: "${target.message}"');
      }
      try {
        final bool? success = await _nativeChannel.invokeMethod<bool>(
          'sendDirectSms',
          {
            'phoneNumber': target.phone,
            'message': target.message,
          },
        );
        if (success != true) {
          allSuccess = false;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[SIM SMS] Failed to dispatch SMS to ${target.phone}: $e');
        }
        allSuccess = false;
      }
    }
    return allSuccess;
  }
}
