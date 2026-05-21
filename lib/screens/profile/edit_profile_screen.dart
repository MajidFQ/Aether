import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/theme_helper.dart';

const Color _kPrimary = Color(0xFF5B4FFF);
const Color _kBorderBlack = Color(0xFF000000);

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _educationController = TextEditingController();
  final _hobbiesController = TextEditingController();
  final _bioController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      _nameController.text =
          FirebaseAuth.instance.currentUser?.displayName ?? '';
      if (doc.exists) {
        final data = doc.data() ?? {};
        _ageController.text = data['age']?.toString() ?? '';
        _educationController.text = data['education'] ?? '';
        _hobbiesController.text = data['hobbies'] ?? '';
        _bioController.text = data['bio'] ?? '';
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      // Update display name in Firebase Auth
      final name = _nameController.text.trim();
      if (name.isNotEmpty) {
        await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
      }

      // Save all profile data to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({
        'age': _ageController.text.trim().isNotEmpty
            ? int.tryParse(_ageController.text.trim())
            : null,
        'education': _educationController.text.trim(),
        'hobbies': _hobbiesController.text.trim(),
        'bio': _bioController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated! ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _educationController.dispose();
    _hobbiesController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = getBackgroundColor(context);
    final textColor = getTextColor(context);
    final cardColor = getCardColor(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          title: Text('Edit Profile',
              style: GoogleFonts.plusJakartaSans(
                  color: _kPrimary, fontWeight: FontWeight.w800)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Profile',
          style: GoogleFonts.plusJakartaSans(
            color: _kPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: _saveProfile,
                    child: Text(
                      'Save',
                      style: GoogleFonts.plusJakartaSans(
                        color: _kPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar preview ──────────────────────────────────────
              Center(
                child: Stack(
                  children: [
                    ValueListenableBuilder(
                      valueListenable: _nameController,
                      builder: (_, value, __) {
                        final text = _nameController.text;
                        final letter = text.isNotEmpty
                            ? text[0].toUpperCase()
                            : (FirebaseAuth.instance.currentUser?.email?[0]
                                    .toUpperCase() ??
                                'U');
                        return Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: _kPrimary,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: _kBorderBlack, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                  color: Colors.black,
                                  offset: Offset(3, 3),
                                  blurRadius: 0),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              letter,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 42,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _kPrimary,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: _kBorderBlack, width: 2),
                        ),
                        child: const Icon(Icons.edit,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Name ────────────────────────────────────────────────
              _buildLabel('Name', textColor),
              _buildField(
                controller: _nameController,
                hint: 'Enter your name',
                icon: Icons.person,
                cardColor: cardColor,
                textColor: textColor,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),

              // ── Age ─────────────────────────────────────────────────
              _buildLabel('Age (Optional)', textColor),
              _buildField(
                controller: _ageController,
                hint: 'e.g., 20',
                icon: Icons.cake,
                cardColor: cardColor,
                textColor: textColor,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // ── Education ───────────────────────────────────────────
              _buildLabel('Education (Optional)', textColor),
              _buildField(
                controller: _educationController,
                hint: 'e.g., Computer Science Student',
                icon: Icons.school,
                cardColor: cardColor,
                textColor: textColor,
              ),
              const SizedBox(height: 16),

              // ── Hobbies ─────────────────────────────────────────────
              _buildLabel('Hobbies (Optional)', textColor),
              _buildField(
                controller: _hobbiesController,
                hint: 'e.g., Reading, Gaming, Coding',
                icon: Icons.favorite,
                cardColor: cardColor,
                textColor: textColor,
              ),
              const SizedBox(height: 16),

              // ── Bio ─────────────────────────────────────────────────
              _buildLabel('Bio (Optional)', textColor),
              _buildField(
                controller: _bioController,
                hint: 'Tell us about yourself...',
                icon: Icons.description,
                cardColor: cardColor,
                textColor: textColor,
                maxLines: 4,
              ),
              const SizedBox(height: 24),

              // ── Info banner ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kPrimary.withValues(alpha: 0.08),
                  border: Border.all(color: _kPrimary, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: _kPrimary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'All fields except Name are optional. This info helps personalize your experience.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Save button ─────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: _kBorderBlack, width: 2),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Save Profile',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color cardColor,
    required Color textColor,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.plusJakartaSans(color: textColor),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey),
        prefixIcon: Icon(icon, color: _kPrimary),
        filled: true,
        fillColor: cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorderBlack, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorderBlack, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }
}
