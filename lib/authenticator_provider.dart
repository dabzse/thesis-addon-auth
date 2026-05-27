import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:otp/otp.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:screen_protector/screen_protector.dart';
import 'dart:io';

class AuthEntry {
  final String id;
  final String name;
  final String secret;

  AuthEntry({required this.id, required this.name, required this.secret});
}

class AuthenticatorProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  List<AuthEntry> _entries = [];
  bool _allowScreenshots = false;
  int _secondsRemaining = 20;
  Timer? _timer;

  List<AuthEntry> get entries => _entries;
  bool get allowScreenshots => _allowScreenshots;
  int get secondsRemaining => _secondsRemaining;

  AuthenticatorProvider() {
    _loadSettings();
    _loadEntries();
    _startTimer();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _allowScreenshots = prefs.getBool('allowScreenshots') ?? false;
    _applyScreenshotSetting();
    notifyListeners();
  }

  Future<void> toggleScreenshot(bool value) async {
    _allowScreenshots = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('allowScreenshots', value);
    _applyScreenshotSetting();
    notifyListeners();
  }

  Future<void> _applyScreenshotSetting() async {
    if (kIsWeb) return;
    
    if (Platform.isAndroid) {
      if (_allowScreenshots) {
        await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
      } else {
        await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
      }
    } else if (Platform.isIOS) {
      if (_allowScreenshots) {
        await ScreenProtector.preventScreenshotOff();
      } else {
        await ScreenProtector.preventScreenshotOn();
      }
    }
    // Desktop screenshot prevention is not easily supported by these plugins
  }

  Future<void> _loadEntries() async {
    // For now, let's load a dummy if empty, or real from secure storage
    final keys = await _storage.readAll();
    _entries = keys.entries
        .where((e) => e.key.startsWith('secret_'))
        .map((e) => AuthEntry(
              id: e.key,
              name: e.key.replaceFirst('secret_', ''),
              secret: e.value,
            ))
        .toList();
    
    // Add a demo entry if empty for testing
    if (_entries.isEmpty) {
      await addEntry('Demo Account', 'JBSWY3DPEHPK3PXP'); // Standard RFC4226 test secret
    }
    notifyListeners();
  }

  Future<void> addEntry(String name, String secret) async {
    final id = 'secret_$name';
    await _storage.write(key: id, value: secret);
    _entries.add(AuthEntry(id: id, name: name, secret: secret));
    notifyListeners();
  }

  Future<void> removeEntry(String id) async {
    await _storage.delete(key: id);
    _entries.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now().millisecondsSinceEpoch;
      _secondsRemaining = 20 - ((now ~/ 1000) % 20);
      if (_secondsRemaining == 20) {
        notifyListeners(); // Refresh codes
      } else {
        notifyListeners(); // Update progress bar
      }
    });
  }

  String getCode(String secret) {
    try {
      final normalizedSecret = secret.replaceAll(' ', '').toUpperCase();
      return OTP.generateTOTPCodeString(
        normalizedSecret,
        DateTime.now().millisecondsSinceEpoch,
        interval: 20,
        length: 6,
        algorithm: Algorithm.SHA1,
        isGoogle: true,
      );
    } catch (e) {
      debugPrint('Error generating OTP: $e');
      return '000000';
    }
  }

  String generateUri(AuthEntry entry) {
    // Format: otpauth://totp/Issuer:Account?secret=SECRET&issuer=Issuer&digits=6&period=20
    final issuer = Uri.encodeComponent('Edu Auth');
    final account = Uri.encodeComponent(entry.name);
    final secret = Uri.encodeComponent(entry.secret.replaceAll(' ', '').toUpperCase());
    return 'otpauth://totp/$issuer:$account?secret=$secret&issuer=$issuer&digits=6&period=20';
  }

  Future<void> addFromUri(String uriString) async {
    try {
      final uri = Uri.parse(uriString);
      if (uri.scheme != 'otpauth') return;
      
      final secret = uri.queryParameters['secret'];
      final issuer = uri.queryParameters['issuer'] ?? 'Unknown';
      var label = uri.path.split('/').last;
      if (label.contains(':')) {
        label = label.split(':').last;
      }
      
      if (secret != null) {
        await addEntry(label, secret);
      }
    } catch (e) {
      debugPrint('Error adding from URI: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
