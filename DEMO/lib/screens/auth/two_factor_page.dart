import 'package:flutter/material.dart';
import 'package:school_manager/services/auth_service.dart';

class TwoFactorPage extends StatefulWidget {
  final String username;
  final VoidCallback onSuccess;
  const TwoFactorPage({super.key, required this.username, required this.onSuccess});

  @override
  State<TwoFactorPage> createState() => _TwoFactorPageState();
}

class _TwoFactorPageState extends State<TwoFactorPage> {
  final _codeController = TextEditingController();
  bool _isVerifying = false;
  String? _error;

  Future<void> _verify() async {
    setState(() { _isVerifying = true; _error = null; });
    final ok = await AuthService.instance.verifyTotpCode(widget.username, _codeController.text.trim());
    setState(() { _isVerifying = false; });
    if (!mounted) return;
    if (ok) {
      widget.onSuccess();
    } else {
      setState(() { _error = 'Code invalide'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_user_outlined, size: 48),
                  const SizedBox(height: 16),
                  const Text('Vérification 2FA', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _codeController,
                    decoration: const InputDecoration(labelText: 'Code TOTP (6 chiffres)'),
                    keyboardType: TextInputType.number,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isVerifying ? null : _verify,
                      icon: const Icon(Icons.check_circle_outline),
                      label: _isVerifying ? const Text('Vérification...') : const Text('Vérifier'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
