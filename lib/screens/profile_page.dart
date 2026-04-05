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
  String _username = "Loading...";
  
  // Profile Controllers (Read-only) [cite: 3936, 3937]
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();

  // BMI Calculator [cite: 3938]
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  String _bmiResult = "--";
  String _bmiCategory = ""; // NEW: Category display
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

  void _calculateBMI() {
    final double? heightCm = double.tryParse(_heightController.text);
    final double? weightKg = double.tryParse(_weightController.text);

    if (heightCm == null || weightKg == null || heightCm <= 0 || weightKg <= 0) {
      setState(() {
        _bmiResult = "Invalid";
        _bmiCategory = "";
        _bmiColor = neonRed;
      });
      return;
    }

    final double heightM = heightCm / 100;
    final double bmi = weightKg / (heightM * heightM);

    setState(() {
      _bmiResult = bmi.toStringAsFixed(1);
      // Logic for BMI categories 
      if (bmi < 18.5) {
        _bmiColor = Colors.blueAccent;
        _bmiCategory = "UNDERWEIGHT";
      } else if (bmi >= 18.5 && bmi < 24.9) {
        _bmiColor = mintGreen;
        _bmiCategory = "NORMAL";
      } else if (bmi >= 25 && bmi < 29.9) {
        _bmiColor = Colors.orange;
        _bmiCategory = "OVERWEIGHT";
      } else if (bmi >= 30 && bmi < 34.9) {
        _bmiColor = neonRed;
        _bmiCategory = "OBESITY CLASS I";
      } else if (bmi >= 35 && bmi < 39.9) {
        _bmiColor = neonRed;
        _bmiCategory = "OBESITY CLASS II";
      } else {
        _bmiColor = neonRed;
        _bmiCategory = "OBESITY CLASS III";
      }
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
      await prefs.clear();
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
    }
  }

  // Refactored helper to support Read-only mode
  Widget _buildTextField(String label, TextEditingController controller, {bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        readOnly: readOnly, // Blocks user input
        style: TextStyle(color: readOnly ? Colors.white70 : Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey),
          filled: true,
          fillColor: Colors.black.withOpacity(0.2),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), 
            borderSide: BorderSide(color: readOnly ? Colors.white10 : Colors.transparent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), 
            borderSide: BorderSide(color: readOnly ? Colors.white10 : mintGreen),
          ),
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
          // IDENTITY HEADER [cite: 3964, 3965]
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

          // VOLATILE BMI CALCULATOR [cite: 3966]
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
                if (_bmiResult != "--") ...[
                  const SizedBox(height: 16),
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Your BMI: ", style: TextStyle(color: Colors.grey, fontSize: 16)),
                          Text(_bmiResult, style: TextStyle(color: _bmiColor, fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(_bmiCategory, style: TextStyle(color: _bmiColor, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),

          // READ-ONLY ACCOUNT DETAILS [cite: 3971]
          const Text("ACCOUNT DETAILS", style: TextStyle(color: mintGreen, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: darkSlate, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
            child: Column(
              children: [
                _buildTextField("Email", _emailController, readOnly: true),
                _buildTextField("First Name", _firstNameController, readOnly: true),
                _buildTextField("Last Name", _lastNameController, readOnly: true),
                _buildTextField("Birthday (YYYY-MM-DD)", _birthdayController, readOnly: true),
                // SAVE CHANGES button removed 
              ],
            ),
          ),
          const SizedBox(height: 32),

          // LOGOUT [cite: 3976]
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