import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  late final TextEditingController _nameCtrl;
  bool _nameEditing = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await AuthService.getProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
          _nameCtrl.text = profile?['display_name'] as String? ?? '';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  Future<void> _saveName() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await AuthService.updateDisplayName(name);
      if (mounted) {
        setState(() {
          _profile = {...?_profile, 'display_name': name};
          _nameEditing = false;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Name updated'),
              behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> _pickAndUploadAvatar() async {
    ImageSource? source;

    if (_isMobile) {
      source = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    } else {
      // Desktop / web: file picker only, no camera
      source = ImageSource.gallery;
    }

    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _saving = true);
    try {
      final url = await AuthService.uploadAvatar(File(picked.path));
      if (mounted) {
        setState(() {
          _profile = {...?_profile, 'avatar_url': url};
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Photo updated'),
              behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Upload failed: $e'),
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<AuthProvider>().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final user = AuthService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Text(_error!, style: TextStyle(color: cs.error)))
                : ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      // Avatar
                      Center(
                        child: Stack(
                          children: [
                            _buildAvatar(cs),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _saving ? null : _pickAndUploadAvatar,
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: cs.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: cs.surface,
                                      width: 2,
                                    ),
                                  ),
                                  child: _saving
                                      ? Padding(
                                          padding: const EdgeInsets.all(6),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: cs.onPrimary,
                                          ),
                                        )
                                      : Icon(Icons.camera_alt,
                                          size: 16, color: cs.onPrimary),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Display name (editable)
                      ListTile(
                        leading: const Icon(Icons.person_outlined),
                        title: Text('Display name',
                            style: theme.textTheme.labelSmall),
                        subtitle: _nameEditing
                            ? Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _nameCtrl,
                                        autofocus: true,
                                        style: theme.textTheme.bodyLarge,
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding:
                                              EdgeInsets.symmetric(vertical: 8),
                                          border: UnderlineInputBorder(),
                                        ),
                                        onSubmitted: (_) => _saveName(),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.check),
                                      tooltip: 'Save',
                                      onPressed: _saving ? null : _saveName,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close),
                                      tooltip: 'Cancel',
                                      onPressed: () => setState(() {
                                        _nameEditing = false;
                                        _nameCtrl.text =
                                            _profile?['display_name']
                                                    as String? ??
                                                '';
                                      }),
                                    ),
                                  ],
                                ),
                              )
                            : Text(
                                _profile?['display_name'] as String? ?? '—',
                                style: theme.textTheme.bodyLarge,
                              ),
                        trailing: _nameEditing
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: 'Edit name',
                                onPressed: () =>
                                    setState(() => _nameEditing = true),
                              ),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const Divider(),

                      ListTile(
                        leading: const Icon(Icons.email_outlined),
                        title: Text('Email', style: theme.textTheme.labelSmall),
                        subtitle: Text(user?.email ?? '—',
                            style: theme.textTheme.bodyLarge),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const Divider(),

                      ListTile(
                        leading: const Icon(Icons.badge_outlined),
                        title: Text('Role', style: theme.textTheme.labelSmall),
                        subtitle: Text(() {
                          final r = _profile?['role'] as String? ?? '';
                          if (r.isEmpty) return '—';
                          return '${r[0].toUpperCase()}${r.substring(1)}';
                        }(), style: theme.textTheme.bodyLarge),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 40),

                      OutlinedButton.icon(
                        onPressed: _signOut,
                        icon: const Icon(Icons.logout),
                        label: const Text('Log out'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.error,
                          side: BorderSide(color: cs.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildAvatar(ColorScheme cs) {
    final avatarUrl = _profile?['avatar_url'] as String?;
    final displayName = _profile?['display_name'] as String? ?? '';
    final initials =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return CircleAvatar(
      radius: 52,
      backgroundColor: cs.primaryContainer,
      backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
          ? NetworkImage(avatarUrl)
          : null,
      child: avatarUrl == null || avatarUrl.isEmpty
          ? Text(
              initials,
              style: TextStyle(
                fontSize: 38,
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }
}
