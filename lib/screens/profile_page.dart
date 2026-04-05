import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import 'login_page.dart';
import '../services/api_services.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = true;
  bool _isSaving = false;
  String _username = "Loading...";
  
  // Profile Form Controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();

  // BMI Calculator Controllers (Volatile)
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  String _bmiResult = "--";
  Color _bmiColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthdayController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    final token = prefs.getString('auth_token');
    
    setState(() => _username = prefs.getString('username') ?? "User");

    if (userId != null && token != null) {
      final response = await ApiService.getProfile(userId, token);
      if (response != null && response['status'] == 'success') {
        final data = response['data'];
        setState(() {
          _emailController.text = data['email'] ?? '';
          _firstNameController.text = data['first_name'] ?? '';
          _lastNameController.text = data['last_name'] ?? '';
          _birthdayController.text = data['birthday'] ?? '';
        });
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveProfileData() async {
    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    final token = prefs.getString('auth_token');

    if (userId != null && token != null) {
      final response = await ApiService.updateProfile(
        userId: userId,
        token: token,
        email: _emailController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        birthday: _birthdayController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message'] ?? 'Action completed.'),
          backgroundColor: response['status'] == 'success' ? mintGreen : neonRed,
          duration: const Duration(seconds: 2),
        ),
      );
    }
    setState(() => _isSaving = false);
  }

  void _calculateBMI() {
    final double? heightCm = double.tryParse(_heightController.text);
    final double? weightKg = double.tryParse(_weightController.text);

    if (heightCm == null || weightKg == null || heightCm <= 0 || weightKg <= 0) {
      setState(() {
        _bmiResult = "Invalid";
        _bmiColor = neonRed;
      });
      return;
    }

    final double heightM = heightCm / 100;
    final double bmi = weightKg / (heightM * heightM);

    setState(() {
      _bmiResult = bmi.toStringAsFixed(1);
      if (bmi < 18.5) _bmiColor = Colors.blueAccent;
      else if (bmi >= 18.5 && bmi < 24.9) _bmiColor = mintGreen;
      else if (bmi >= 25 && bmi < 29.9) _bmiColor = Colors.orange;
      else _bmiColor = neonRed;
    });
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: darkSlate,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Confirm Logout', style: TextStyle(color: Colors.white)),
          content: const Text('Are you sure you want to end your session?', style: TextStyle(color: Colors.grey)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('CANCEL', style: TextStyle(color: mintGreen)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: neonRed, foregroundColor: Colors.white),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('LOGOUT'),
            ),
          ],
        );
      },
    );

    if (confirm == true && context.mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // NUKE EVERYTHING. Zero ghost data left behind.

      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
    }
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey),
          filled: true,
          fillColor: Colors.black.withOpacity(0.2),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.transparent)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: mintGreen)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: navyBlue, body: Center(child: CircularProgressIndicator(color: mintGreen)));
    }

    return Scaffold(
      backgroundColor: navyBlue,
      appBar: AppBar(
        backgroundColor: navyBlue,
        elevation: 0,
        centerTitle: true,
        title: const Text('USER PROFILE', style: TextStyle(color: mintGreen, fontWeight: FontWeight.bold, letterSpacing: 2.0, fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // IDENTITY HEADER
          Center(
            child: Column(
              children: [
                const CircleAvatar(radius: 40, backgroundColor: darkSlate, child: Icon(Icons.person, size: 40, color: mintGreen)),
                const SizedBox(height: 12),
                Text(_username, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // VOLATILE BMI CALCULATOR
          const Text("BMI CALCULATOR", style: TextStyle(color: mintGreen, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: darkSlate, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildTextField("Height (cm)", _heightController)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTextField("Weight (kg)", _weightController)),
                  ],
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: mintGreen, foregroundColor: navyBlue, minimumSize: const Size(double.infinity, 48)),
                  onPressed: _calculateBMI,
                  child: const Text("CALCULATE", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Your BMI: ", style: TextStyle(color: Colors.grey, fontSize: 16)),
                    Text(_bmiResult, style: TextStyle(color: _bmiColor, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 32),

          // EDIT DETAILS FORM
          const Text("ACCOUNT DETAILS", style: TextStyle(color: mintGreen, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: darkSlate, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
            child: Column(
              children: [
                _buildTextField("Email", _emailController),
                _buildTextField("First Name", _firstNameController),
                _buildTextField("Last Name", _lastNameController),
                _buildTextField("Birthday (YYYY-MM-DD)", _birthdayController),
                const SizedBox(height: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: mintGreen, foregroundColor: navyBlue, minimumSize: const Size(double.infinity, 56)),
                  onPressed: _isSaving ? null : _saveProfileData,
                  child: _isSaving 
                    ? const CircularProgressIndicator(color: navyBlue) 
                    : const Text("SAVE CHANGES", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // LOGOUT
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: neonRed.withOpacity(0.1), foregroundColor: neonRed,
              side: const BorderSide(color: neonRed), padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.logout),
            label: const Text('LOGOUT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            onPressed: () => _confirmLogout(context),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}