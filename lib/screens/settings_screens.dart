import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  static const String routeName = '/settings';

  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _saveChatsLocally = true;
  bool _enableImageInput = true;
  bool _showDebugInfo = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'App Preferences',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Save chats locally'),
                  subtitle: const Text(
                    'Keep conversations on device for future viewing.',
                  ),
                  value: _saveChatsLocally,
                  onChanged: (value) {
                    setState(() {
                      _saveChatsLocally = value;
                    });
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable image input'),
                  subtitle: const Text(
                    'Allow camera and gallery image attachments in chat.',
                  ),
                  value: _enableImageInput,
                  onChanged: (value) {
                    setState(() {
                      _enableImageInput = value;
                    });
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show debug info'),
                  subtitle: const Text(
                    'Helpful later when integrating the local model.',
                  ),
                  value: _showDebugInfo,
                  onChanged: (value) {
                    setState(() {
                      _showDebugInfo = value;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Model',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          const _SettingsCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Local model status'),
              subtitle: Text('Not connected yet'),
              trailing: Icon(Icons.memory_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;

  const _SettingsCard({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: child,
    );
  }
}
