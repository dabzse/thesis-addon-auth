import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'authenticator_provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => AuthenticatorProvider(),
      child: const EduAuthApp(),
    ),
  );
}

class EduAuthApp extends StatelessWidget {
  const EduAuthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Edu_AUTH',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edu_AUTH'),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Consumer<AuthenticatorProvider>(
        builder: (context, auth, child) {
          if (auth.entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No accounts added yet.', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 16,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showAddDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Manually'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showScanner(context, auth),
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Scan QR'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              LinearProgressIndicator(
                value: auth.secondsRemaining / 20,
                backgroundColor: Colors.transparent,
                minHeight: 4,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Refresh in ${auth.secondsRemaining}s',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: auth.secondsRemaining <= 5 ? Colors.red : Colors.grey,
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: auth.entries.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final entry = auth.entries[index];
                    final code = auth.getCode(entry.secret);
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(entry.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${code.substring(0, 3)} ${code.substring(3)}',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Code copied to clipboard'), duration: Duration(seconds: 1)),
                          );
                        },
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.qr_code),
                              onPressed: () => _showShareDialog(context, auth, entry),
                              tooltip: 'Share via QR',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () => _confirmDelete(context, auth, entry),
                              tooltip: 'Delete account',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            onPressed: () => _showScanner(context, Provider.of<AuthenticatorProvider>(context, listen: false)),
            heroTag: 'scan',
            tooltip: 'Scan QR Code',
            child: const Icon(Icons.qr_code_scanner),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            onPressed: () => _showAddDialog(context),
            heroTag: 'add',
            tooltip: 'Add account manually',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  void _showShareDialog(BuildContext context, AuthenticatorProvider auth, AuthEntry entry) {
    final uri = auth.generateUri(entry);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Share ${entry.name}'),
        content: SizedBox(
          width: 250,
          height: 250,
          child: Center(
            child: QrImageView(
              data: uri,
              version: QrVersions.auto,
              size: 200.0,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showScanner(BuildContext context, AuthenticatorProvider auth) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Scan QR Code')),
          body: MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  auth.addFromUri(barcode.rawValue!);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Account added successfully')),
                  );
                  break;
                }
              }
            },
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AuthenticatorProvider auth, AuthEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Account'),
        content: Text('Are you sure you want to remove ${entry.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              auth.removeEntry(entry.id);
              Navigator.pop(context);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final nameController = TextEditingController();
    final secretController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Account Name',
                hintText: 'e.g. GitHub: username',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: secretController,
              decoration: const InputDecoration(
                labelText: 'Secret Key',
                hintText: 'Base32 secret from service',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && secretController.text.isNotEmpty) {
                Provider.of<AuthenticatorProvider>(context, listen: false)
                    .addEntry(nameController.text.trim(), secretController.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Consumer<AuthenticatorProvider>(
        builder: (context, auth, child) {
          return ListView(
            children: [
              SwitchListTile(
                title: const Text('Allow Screenshots'),
                subtitle: const Text('Enable or disable screen capture/recording'),
                value: auth.allowScreenshots,
                onChanged: (value) => auth.toggleScreenshot(value),
              ),
              const Divider(),
              const AboutListTile(
                applicationName: 'Edu_AUTH by @dabzse (ZKLSTP)',
                applicationVersion: '0.0.7, prototype/MVP',
                icon: Icon(Icons.info_outline),
                aboutBoxChildren: [
                  SizedBox(height: 8),
                  Text('Thesis addon authenticator app.'),
                  Text('Supports 6-digit TOTP codes with 20-second validity.'),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
