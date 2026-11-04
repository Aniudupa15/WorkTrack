import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:attendance_app/core/theme/app_spacing.dart';

/// Scans a company join QR and pops with its code.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  /// The join code in a scanned value: `punchin://join?code=ABC123`, any URL
  /// with a `code` parameter, or a bare code. Null if it isn't one.
  static String? codeFrom(String raw) {
    final value = raw.trim();
    final uri = Uri.tryParse(value);
    final fromUri = uri?.queryParameters['code'];
    final candidate = (fromUri ?? value).toUpperCase();
    return RegExp(r'^[A-Z0-9]{4,12}$').hasMatch(candidate) ? candidate : null;
  }

  /// The QR payload for [code].
  static String payloadFor(String code) => 'punchin://join?code=$code';

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool _done = false;

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final code = QrScanScreen.codeFrom(b.rawValue ?? '');
      if (code != null) {
        _done = true;
        Navigator.pop(context, code);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan company QR'),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  error.errorCode == MobileScannerErrorCode.permissionDenied
                      ? 'Allow camera access in Settings to scan, or type the '
                            'code instead.'
                      : 'The camera isn’t available. Type the code instead.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          const Positioned(
            bottom: 48,
            child: Text(
              'Point at the QR code from your admin',
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
