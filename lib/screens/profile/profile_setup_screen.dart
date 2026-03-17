import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  String _selectedGender = 'Male';
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _emergencyContactController = TextEditingController();
  final TextEditingController _houseNoController = TextEditingController();
  final TextEditingController _streetNameController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _zipCodeController = TextEditingController();

  void _saveAndContinue() async {
    final Map<String, dynamic> profileData = {
      'full_name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'gender': _selectedGender.toLowerCase(),
      'dob': _dobController.text.trim(),
      'emergency_contact': _emergencyContactController.text.trim(),
      'house_no': _houseNoController.text.trim(),
      'street': _streetNameController.text.trim(),
      'city': _cityController.text.trim(),
      'zip_code': _zipCodeController.text.trim(),
    };

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.updateProfile(profileData);

    if (success) {
      if (mounted) context.go('/home');
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authProvider.error ?? 'Failed to update profile', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildTextField(String label, String placeholder, {IconData? leadingIcon, TextInputType keyboardType = TextInputType.text, TextEditingController? controller}) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colorScheme.onSurface.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 6),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: placeholder,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: leadingIcon != null ? 0 : 16, vertical: 16),
              prefixIcon: leadingIcon != null ? Icon(leadingIcon, color: colorScheme.primary) : null,
              hintStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.4), fontWeight: FontWeight.normal),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          // Background Glow Effect
          Positioned(
            top: -100,
            left: MediaQuery.of(context).size.width / 2 - 200,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary.withValues(alpha: 0.05),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.surfaceContainerHighest,
                          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.5), width: 2),
                          image: const DecorationImage(
                            image: NetworkImage('https://via.placeholder.com/150'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: colorScheme.surface, width: 2),
                          ),
                          child: Icon(Icons.edit, color: colorScheme.onPrimary, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                _buildTextField('Full Name', 'Enter your full name', controller: _nameController),
                const SizedBox(height: 16),
                _buildTextField('Email Address', 'alex@example.com', keyboardType: TextInputType.emailAddress, controller: _emailController),
                const SizedBox(height: 16),
                
                // Gender Segmented Control
                Text(
                  'Gender',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colorScheme.onSurface.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 56,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: ['Male', 'Female', 'Other'].map((gender) {
                      final isSelected = _selectedGender == gender;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedGender = gender;
                            });
                          },
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? colorScheme.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              gender,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                
                const SizedBox(height: 16),
                _buildTextField('Date of Birth', 'YYYY-MM-DD', keyboardType: TextInputType.datetime, controller: _dobController),
                
                const SizedBox(height: 32),
                Row(
                  children: [
                    Icon(Icons.shield, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Safety First', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.primary)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField('Emergency Contact', '(555) 019-2834', leadingIcon: Icons.call, keyboardType: TextInputType.phone, controller: _emergencyContactController),
                Text(
                  'Used only in case of emergencies during your ride.',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
                
                const SizedBox(height: 32),
                Row(
                  children: [
                    Icon(Icons.home, color: colorScheme.onSurface.withValues(alpha: 0.4)),
                    const SizedBox(width: 8),
                    const Text('Residential Address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(flex: 1, child: _buildTextField('House / Apt', '12A', controller: _houseNoController)),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: _buildTextField('Street Name', 'Park Avenue', controller: _streetNameController)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(flex: 2, child: _buildTextField('City', 'New York', controller: _cityController)),
                          const SizedBox(width: 16),
                          Expanded(flex: 1, child: _buildTextField('Zip Code', '10001', controller: _zipCodeController)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.9),
                border: Border(top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.1))),
              ),
              child: SizedBox(
                height: 56,
                child: Consumer<AuthProvider>(
                  builder: (context, auth, child) {
                    return ElevatedButton(
                      onPressed: auth.isLoading ? null : _saveAndContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: auth.isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Save & Continue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward),
                            ],
                          ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
