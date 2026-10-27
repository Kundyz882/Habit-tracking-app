import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/habit_store.dart';
import '../theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.auth, required this.store});

  final AuthService auth;
  final HabitStore store;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  String? _loadedUserId;
  bool _saving = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final user = widget.auth.user;
    if (user == null) return;
    if (_firstName.text.trim().isEmpty || _email.text.trim().isEmpty) {
      _showMessage('Enter your first name and email.');
      return;
    }

    String? password;
    final emailChanged =
        _email.text.trim().toLowerCase() != user.email.toLowerCase();
    if (emailChanged) {
      final controller = TextEditingController();
      password = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm email change'),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Current password'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text),
                child: const Text('Continue')),
          ],
        ),
      );
      controller.dispose();
      if (password == null || !mounted) return;
    }

    setState(() => _saving = true);
    try {
      await widget.auth.updateProfile(
        firstName: _firstName.text,
        lastName: _lastName.text,
        email: _email.text,
        currentPassword: password,
      );
      if (emailChanged && mounted) {
        _showMessage('Check your new email to confirm the change.');
      } else if (mounted) {
        _showMessage('Profile saved.');
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
            'Could not save profile. Check the details and try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
            'Your daily habits and history stay saved in your account.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Log out')),
        ],
      ),
    );
    if (ok == true) await widget.auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.user;
    if (user == null) return const SizedBox.shrink();
    final primary = Theme.of(context).colorScheme.primary;
    if (_loadedUserId != user.id) {
      _loadedUserId = user.id;
      _firstName.text = user.firstName;
      _lastName.text = user.lastName;
      _email.text = user.email;
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text('Profile',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: tint(primary, 0.15),
                    child: Icon(Icons.person_rounded, color: primary, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Personal information',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 20),
                _profileField('First name', _firstName, Icons.badge_outlined),
                const SizedBox(height: 12),
                _profileField('Last name', _lastName, Icons.badge_outlined),
                const SizedBox(height: 12),
                _profileField('Email', _email, Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _saveProfile,
                    icon: _saving
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving…' : 'Save changes'),
                  ),
                ),
              ],
            ),
          ),
          if (widget.auth.profileSyncError != null)
            ListTile(
              title: Text(widget.auth.profileSyncError!),
              trailing: TextButton(
                  onPressed: widget.auth.syncProfile,
                  child: const Text('Retry')),
            ),
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: widget.store,
            builder: (context, _) => Container(
              padding: const EdgeInsets.all(16),
              decoration: cardDecoration(),
              child: Row(children: [
                Icon(Icons.checklist_rounded, color: primary),
                const SizedBox(width: 12),
                Text('${widget.store.habits.length} habits tracked'),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Log out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: lapseColor,
                side: const BorderSide(color: lapseColor),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileField(
      String label, TextEditingController controller, IconData icon,
      {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: keyboardType == TextInputType.emailAddress
          ? TextCapitalization.none
          : TextCapitalization.words,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }
}
