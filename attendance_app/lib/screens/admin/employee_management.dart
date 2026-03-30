import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/user_model.dart';
import '../../utils/user_provider.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';

class EmployeeManagement extends StatefulWidget {
  const EmployeeManagement({super.key});

  @override
  State<EmployeeManagement> createState() => _EmployeeManagementState();
}

class _EmployeeManagementState extends State<EmployeeManagement> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _radiusController = TextEditingController(text: '100');
  final _startTimeController = TextEditingController(text: '09:00');
  final _endTimeController = TextEditingController(text: '18:00');

  bool _isLoading = false;
  final _auth = AuthService();
  final _locationService = LocationService();

  void _addEmployee() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final employee = UserModel(
        id: '', // Will be set by Firebase Auth
        name: _nameController.text,
        email: _emailController.text,
        role: 'employee',
        assignedLocation: {
          'lat': double.parse(_latController.text),
          'lng': double.parse(_lngController.text),
        },
        radius: double.parse(_radiusController.text),
        shiftStart: _startTimeController.text,
        shiftEnd: _endTimeController.text,
      );

      final result = await _auth.registerEmployee(
        employee,
        _passwordController.text,
        Provider.of<UserProvider>(context, listen: false).user?.companyId ?? '',
      );
      if (result != null) {
        _showSuccessDialog(employee, _passwordController.text);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _getCurrentLocation() async {
    try {
      final pos = await _locationService.getCurrentLocation();
      if (pos != null) {
        _latController.text = pos.latitude.toString();
        _lngController.text = pos.longitude.toString();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    }
  }

  void _showSuccessDialog(UserModel employee, String password) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Column(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 64),
            SizedBox(height: 16),
            Text('Employee Created!', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'User account for ${employee.name} has been set up successfully.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Email', employee.email),
                  const SizedBox(height: 8),
                  _buildDetailRow('Password', password),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to dashboard
            },
            child: Text('DONE', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final message = '''
👋 Welcome to ${Provider.of<UserProvider>(context, listen: false).company?.name}!
            
Your attendance tracking account is ready:
📧 Email: ${employee.email}
🔑 Password: $password

Download the app to start checking in.
''';
              Share.share(message);
            },
            icon: const Icon(Icons.share_rounded),
            label: const Text('SHARE DETAILS'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              minimumSize: const Size(120, 44),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Add New Employee'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Personal Details'),
              const SizedBox(height: 16),
              _buildTextField(_nameController, 'Full Name', Icons.person_rounded),
              const SizedBox(height: 16),
              _buildTextField(_emailController, 'Email Address', Icons.email_rounded, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              _buildTextField(_passwordController, 'Temporary Password', Icons.lock_rounded, obscure: true),
              const SizedBox(height: 40),
              _buildSectionTitle('Work Location'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildTextField(_latController, 'Latitude', Icons.location_on_rounded, keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTextField(_lngController, 'Longitude', Icons.location_on_rounded, keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _getCurrentLocation,
                    icon: const Icon(Icons.my_location_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
                      foregroundColor: const Color(0xFF6366F1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(_radiusController, 'Allowed Radius (meters)', Icons.radar_rounded, keyboardType: TextInputType.number),
              const SizedBox(height: 40),
              _buildSectionTitle('Shift Schedule'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildTextField(_startTimeController, 'Start Time', Icons.login_rounded)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField(_endTimeController, 'End Time', Icons.logout_rounded)),
                ],
              ),
              const SizedBox(height: 48),
              _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                  : ElevatedButton(
                      onPressed: _addEmployee,
                      child: const Text('CREATE EMPLOYEE ACCOUNT'),
                    ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.grey[500],
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool obscure = false, TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
      ),
      validator: (v) => v!.isEmpty ? 'Required' : null,
    );
  }
}
