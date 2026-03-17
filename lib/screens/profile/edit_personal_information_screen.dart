import 'package:flutter/material.dart';

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';

class EditPersonalInformationScreen extends StatefulWidget {
  const EditPersonalInformationScreen({super.key});

  @override
  State<EditPersonalInformationScreen> createState() =>
      _EditPersonalInformationScreenState();
}

class _EditPersonalInformationScreenState
    extends State<EditPersonalInformationScreen> {
  static const Color _screenBackground = Color(0xFF1A1814);
  static const Color _fieldBackground = Color(0xFF24211C);
  static const Color _borderColor = Color(0x4D8B6508);
  static const Color _primaryColor = Color(0xFFEEBD2B);
  static const String _fallbackFullName = 'John Doe';
  static const String _fallbackEmail = 'johndoe@example.com';
  static const String _fallbackCountryCode = '+91';
  static const String _fallbackPhoneNumber = '9876543210';
  static const String _fallbackGender = 'Male';
  static const String _fallbackAvatarUrl =
      'https://via.placeholder.com/150';
  static const List<String> _genderOptions = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _emergencyContactController = TextEditingController();
  final TextEditingController _houseNoController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _zipCodeController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  String _selectedGender = _fallbackGender;
  String _countryCode = _fallbackCountryCode;
  String _phoneNumber = _fallbackPhoneNumber;
  String? _localAvatarPath;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _loadInitialData(auth);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
       await auth.fetchProfile();
       if (mounted) _loadInitialData(auth);
    });
  }

  void _loadInitialData(AuthProvider auth) {
    _fullNameController.text = _normalized(auth.fullName) ?? _fallbackFullName;
    _emailController.text = _normalized(auth.email) ?? _fallbackEmail;
    _selectedGender = _resolvedGender(auth.gender);
    _countryCode = _normalized(auth.countryCode) ?? _fallbackCountryCode;
    _phoneNumber = _normalized(auth.phoneNumber) ?? _fallbackPhoneNumber;
    _localAvatarPath = _normalized(auth.localAvatarPath);
    _dobController.text = _normalized(auth.dob) ?? '';
    _emergencyContactController.text = _normalized(auth.emergencyContact) ?? '';
    _houseNoController.text = _normalized(auth.houseNo) ?? '';
    _streetController.text = _normalized(auth.street) ?? '';
    _cityController.text = _normalized(auth.city) ?? '';
    _zipCodeController.text = _normalized(auth.zipCode) ?? '';
    setState(() {});
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _emergencyContactController.dispose();
    _houseNoController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _zipCodeController.dispose();
    super.dispose();
  }

  String? _normalized(String? value) {
    final text = value?.trim();
    return (text == null || text.isEmpty) ? null : text;
  }

  String _resolvedGender(String? value) {
    final normalized = _normalized(value)?.toLowerCase();
    if (normalized == null) return _fallbackGender;
    final matched = _genderOptions.firstWhere(
      (option) => option.toLowerCase() == normalized,
      orElse: () => _fallbackGender,
    );
    return matched;
  }

  ImageProvider _profileImage(String remoteAvatarUrl) {
    if (_localAvatarPath != null) {
      return FileImage(File(_localAvatarPath!));
    }
    return NetworkImage(remoteAvatarUrl);
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), backgroundColor: const Color(0xFF2B2722)),
      );
  }

  Future<void> _pickAvatar() async {
    try {
      final pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
      );

      if (pickedImage == null || !mounted) return;

      setState(() {
        _localAvatarPath = pickedImage.path;
      });
      await context.read<AuthProvider>().setLocalAvatarPath(pickedImage.path);
    } catch (_) {
      _showMessage('Unable to pick image right now.');
    }
  }

  void _openHomeTab(int tabIndex) {
    FocusScope.of(context).unfocus();
    context.go('/home?tab=$tabIndex');
  }

  void _handleBack() {
    FocusScope.of(context).unfocus();
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      context.pop();
      return;
    }
    _openHomeTab(3);
  }

  Future<void> _saveChanges() async {
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final gender = _selectedGender.trim();
    final dob = _dobController.text.trim();
    final emergencyContact = _emergencyContactController.text.trim();
    final houseNo = _houseNoController.text.trim();
    final street = _streetController.text.trim();
    final city = _cityController.text.trim();
    final zipCode = _zipCodeController.text.trim();

    if (fullName.isEmpty || email.isEmpty || gender.isEmpty) {
      _showMessage('Full name, email, and gender are required.');
      return;
    }

    setState(() => _isSubmitting = true);
    final auth = context.read<AuthProvider>();
    final success = await auth.updateProfile({
      'full_name': fullName,
      'email': email,
      'gender': gender.toLowerCase(),
      'dob': dob,
      'emergency_contact': emergencyContact,
      'house_no': houseNo,
      'street': street,
      'city': city,
      'zip_code': zipCode,
    });

    if (success) {
      await auth.savePersonalInformation(
        fullName: fullName,
        email: email,
        gender: gender,
        dob: dob,
        emergencyContact: emergencyContact,
        houseNo: houseNo,
        street: street,
        city: city,
        zipCode: zipCode,
        localAvatarPath: _localAvatarPath,
      );
      if (mounted) {
        _showMessage('Profile updated successfully!');
        _openHomeTab(3);
      }
    } else {
      _showMessage(auth.error ?? 'Failed to update profile.');
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
          color: const Color(0xFF94A3B8),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.3,
        ),
      ),
    );
  }

  Widget _fieldContainer({required Widget child, double height = 72}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: _fieldBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final remoteAvatarUrl = _normalized(auth.avatarUrl) ?? _fallbackAvatarUrl;
    final displayCountryCode = _normalized(auth.countryCode) ?? _countryCode;
    final displayPhoneNumber = _normalized(auth.phoneNumber) ?? _phoneNumber;

    return Scaffold(
      backgroundColor: _screenBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: Row(
                children: [
                  InkWell(
                    onTap: _handleBack,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0x1AFFFFFF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Color(0xFFE2E8F0),
                        size: 20,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Personal Information',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 114,
                            height: 114,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _primaryColor.withOpacity(0.5),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x66EEBD2B),
                                  blurRadius: 18,
                                  spreadRadius: 0.5,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image(
                                image: _profileImage(remoteAvatarUrl),
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) {
                                  return Container(
                                    color: _fieldBackground,
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.person,
                                      color: Color(0xFFCBD5E1),
                                      size: 52,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: InkWell(
                              onTap: _pickAvatar,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: _fieldBackground,
                                  borderRadius: BorderRadius.circular(17),
                                  border: Border.all(color: _borderColor),
                                ),
                                child: const Icon(
                                  Icons.photo_camera_rounded,
                                  color: _primaryColor,
                                  size: 17,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 34),
                    _label('Full Name'),
                    _fieldContainer(
                      child: TextField(
                        controller: _fullNameController,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFF8FAFC),
                          fontSize: 19,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          hintText: _fallbackFullName,
                          hintStyle: GoogleFonts.inter(
                            color: const Color(0xFF64748B),
                            fontSize: 19,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _label('Email Address'),
                    _fieldContainer(
                      child: TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFF8FAFC),
                          fontSize: 19,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          hintText: _fallbackEmail,
                          hintStyle: GoogleFonts.inter(
                            color: const Color(0xFF64748B),
                            fontSize: 19,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _label('Phone Number'),
                    _fieldContainer(
                      child: Row(
                        children: [
                          Container(
                            width: 74,
                            height: double.infinity,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2A2620),
                              border: Border(
                                right: BorderSide(color: _borderColor),
                              ),
                              borderRadius: BorderRadius.horizontal(
                                left: Radius.circular(20),
                              ),
                            ),
                            child: Text(
                              displayCountryCode,
                              style: GoogleFonts.inter(
                                color: const Color(0xFFF8FAFC),
                                fontSize: 19,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              child: Text(
                                displayPhoneNumber,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFF8FAFC).withOpacity(0.5),
                                  fontSize: 19,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _label('Gender'),
                    _fieldContainer(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedGender,
                          dropdownColor: _fieldBackground,
                          borderRadius: BorderRadius.circular(16),
                          icon: const Padding(
                            padding: EdgeInsets.only(right: 12),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFF64748B),
                              size: 30,
                            ),
                          ),
                          isExpanded: true,
                          style: GoogleFonts.inter(
                            color: const Color(0xFFF8FAFC),
                            fontSize: 19,
                            fontWeight: FontWeight.w500,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          items: _genderOptions.map((option) {
                            return DropdownMenuItem<String>(
                              value: option,
                              child: Text(option),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _selectedGender = value);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _label('Date of Birth'),
                    _fieldContainer(
                      child: TextField(
                        controller: _dobController,
                        onTap: () async {
                           final date = await showDatePicker(
                             context: context,
                             initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
                             firstDate: DateTime(1900),
                             lastDate: DateTime.now(),
                           );
                           if (date != null) {
                             _dobController.text = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
                           }
                        },
                        readOnly: true,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFF8FAFC),
                          fontSize: 19,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          hintText: 'YYYY-MM-DD',
                          hintStyle: GoogleFonts.inter(
                            color: const Color(0xFF64748B),
                            fontSize: 19,
                          ),
                          suffixIcon: const Icon(Icons.calendar_today, color: _primaryColor, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _label('Emergency Contact'),
                    _fieldContainer(
                      child: TextField(
                        controller: _emergencyContactController,
                        keyboardType: TextInputType.phone,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFF8FAFC),
                          fontSize: 19,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          hintText: 'Emergency phone number',
                          hintStyle: GoogleFonts.inter(
                            color: const Color(0xFF64748B),
                            fontSize: 19,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        const Icon(Icons.home, color: _primaryColor, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'RESIDENTIAL ADDRESS',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('House / Apt'),
                              _fieldContainer(
                                child: TextField(
                                  controller: _houseNoController,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFFF8FAFC),
                                    fontSize: 16,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    hintText: '12A',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Street Name'),
                              _fieldContainer(
                                child: TextField(
                                  controller: _streetController,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFFF8FAFC),
                                    fontSize: 16,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    hintText: 'Park Avenue',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('City'),
                              _fieldContainer(
                                child: TextField(
                                  controller: _cityController,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFFF8FAFC),
                                    fontSize: 16,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    hintText: 'New York',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Zip Code'),
                              _fieldContainer(
                                child: TextField(
                                  controller: _zipCodeController,
                                  keyboardType: TextInputType.number,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFFF8FAFC),
                                    fontSize: 16,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    hintText: '10001',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _screenBackground,
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
