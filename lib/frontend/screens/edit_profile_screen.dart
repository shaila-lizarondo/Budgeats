import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../backend/local_database.dart';
import '../widgets/primary_button.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const EditProfileScreen(),
      ),
    );
  }

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final formKey = GlobalKey<FormState>();

  late TextEditingController nameController;
  late TextEditingController emailController;
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  String? photoBase64;
  bool isGoogleAccount = false;
  bool isSaving = false;
  bool hidePasswords = true;

  @override
  void initState() {
    super.initState();
    final db = context.read<LocalDatabase>();
    final user = db.currentUser;

    nameController = TextEditingController(text: user?.name ?? '');
    emailController = TextEditingController(text: user?.email ?? '');
    photoBase64 = user?.photoBase64;
    isGoogleAccount = user?.provider == 'google';
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 70,
      );
      if (image != null) {
        final Uint8List bytes = await image.readAsBytes();
        setState(() {
          photoBase64 = base64Encode(bytes);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _removePhoto() {
    setState(() {
      photoBase64 = null;
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (isSaving) return;
    if (!formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    final db = context.read<LocalDatabase>();
    final currentUser = db.currentUser;
    final newName = nameController.text.trim();
    final newEmail = emailController.text.trim();
    final currentPassword = currentPasswordController.text;
    final newPassword = newPasswordController.text;

    // 1. Update Photo & Name
    await db.updateProfilePhoto(photoBase64);
    final nameErr = await db.updateName(newName);
    if (nameErr != null) {
      setState(() => isSaving = false);
      _showSnackBar(nameErr, isError: true);
      return;
    }

    // 2. Email / Password updates (for non-Google accounts)
    if (!isGoogleAccount) {
      final emailChanged = newEmail != currentUser?.email;
      final passwordChanged = newPassword.isNotEmpty;

      if (emailChanged || passwordChanged) {
        if (currentPassword.isEmpty) {
          setState(() => isSaving = false);
          _showSnackBar(
            'Enter your current password to save email/password changes.',
            isError: true,
          );
          return;
        }

        // Email update
        if (emailChanged) {
          final emailErr = await db.updateEmailAndAuth(
            currentPassword: currentPassword,
            newEmail: newEmail,
          );
          if (emailErr != null) {
            setState(() => isSaving = false);
            _showSnackBar(emailErr, isError: true);
            return;
          }
          _showSnackBar(
            'Verification email sent to $newEmail. Please check your inbox to confirm.',
          );
        }

        // Password update
        if (passwordChanged) {
          if (newPassword != confirmPasswordController.text) {
            setState(() => isSaving = false);
            _showSnackBar('New passwords do not match.', isError: true);
            return;
          }

          final pwdErr = await db.updatePasswordAuth(
            currentPassword: currentPassword,
            newPassword: newPassword,
          );
          if (pwdErr != null) {
            setState(() => isSaving = false);
            _showSnackBar(pwdErr, isError: true);
            return;
          }
        }
      }
    }

    if (!mounted) return;
    setState(() => isSaving = false);
    _showSnackBar('Profile updated successfully!');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<LocalDatabase>().currentUser;

    ImageProvider? avatarImage;
    if (photoBase64 != null && photoBase64!.isNotEmpty) {
      try {
        avatarImage = MemoryImage(base64Decode(photoBase64!));
      } catch (_) {}
    } else if (user?.photoUrl != null && user!.photoUrl!.isNotEmpty) {
      avatarImage = NetworkImage(user.photoUrl!);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Edit Profile',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Profile Avatar Picker
            GestureDetector(
              onTap: isSaving ? null : _pickPhoto,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor:
                        theme.colorScheme.primary.withValues(alpha: 0.15),
                    backgroundImage: avatarImage,
                    child: avatarImage == null
                        ? Icon(
                            Icons.person_rounded,
                            size: 50,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: isSaving ? null : _pickPhoto,
              child: const Text('Change Photo'),
            ),
            if (photoBase64 != null || (user?.photoUrl != null && user!.photoUrl!.isNotEmpty))
              TextButton(
                onPressed: isSaving ? null : _removePhoto,
                child: Text(
                  'Remove Photo',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),

            // Name Field
            TextFormField(
              controller: nameController,
              enabled: !isSaving,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter your full name' : null,
            ),
            const SizedBox(height: 16),

            // Google Account Note or Email/Password Fields
            if (isGoogleAccount) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your email and password are managed by Google.',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              TextFormField(
                controller: emailController,
                enabled: !isSaving,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: LocalDatabase.validateEmail,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: currentPasswordController,
                enabled: !isSaving,
                obscureText: hidePasswords,
                decoration: InputDecoration(
                  labelText: 'Current password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      hidePasswords
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => hidePasswords = !hidePasswords),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: newPasswordController,
                enabled: !isSaving,
                obscureText: hidePasswords,
                decoration: const InputDecoration(
                  labelText: 'New password (optional)',
                  prefixIcon: Icon(Icons.lock_reset_outlined),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  return LocalDatabase.validatePassword(v);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmPasswordController,
                enabled: !isSaving,
                obscureText: hidePasswords,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                  prefixIcon: Icon(Icons.lock_clock_outlined),
                ),
                validator: (v) {
                  if (newPasswordController.text.isNotEmpty &&
                      v != newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],

            const SizedBox(height: 28),
            if (isSaving)
              const CircularProgressIndicator()
            else
              PrimaryButton(
                label: 'Save Changes',
                onPressed: isSaving ? null : _saveProfile,
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
