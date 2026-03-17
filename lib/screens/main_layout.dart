import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

// We import the colors from main.dart
import '../main.dart'; 

class MainLayout extends StatefulWidget {
  final List<CameraDescription> cameras;
  const MainLayout({super.key, required this.cameras});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  // Start on the Dashboard (Index 1) instead of Settings (Index 0)
  int _currentIndex = 1;

  // Placeholder screens until we build the real ones
  final List<Widget> _pages = [
    const Center(child: Text('Frame 5: Settings', style: TextStyle(color: Colors.white, fontSize: 20))),
    const Center(child: Text('Frame 3: Dashboard', style: TextStyle(color: Colors.white, fontSize: 20))),
    const Center(child: Text('Frame 4: Notifications', style: TextStyle(color: Colors.white, fontSize: 20))),
    const Center(child: Text('Frame 6: Profile', style: TextStyle(color: Colors.white, fontSize: 20))),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _pages[_currentIndex],
      ),
      // --- The Camera Button (Frame 7 Trigger) ---
      floatingActionButton: FloatingActionButton(
        backgroundColor: mintGreen,
        onPressed: () {
          // TODO: Push to Frame 7 (Session Setup)
          debugPrint("FAB Tapped: Opening Session Setup");
        },
        shape: const CircleBorder(),
        child: const Icon(Icons.camera_alt, color: navyBlue, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      
      // --- The Bottom Navigation Bar ---
      bottomNavigationBar: BottomAppBar(
        color: darkSlate,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: SizedBox(
          height: 65,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTabItem(icon: Icons.settings, index: 0, label: 'Settings'),
              _buildTabItem(icon: Icons.dashboard, index: 1, label: 'Stats'),
              const SizedBox(width: 48), // Empty space for the docked FAB
              _buildTabItem(icon: Icons.notifications, index: 2, label: 'Alerts'),
              _buildTabItem(icon: Icons.person, index: 3, label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem({required IconData icon, required int index, required String label}) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? mintGreen : Colors.grey.shade600;

    return InkWell(
      onTap: () => _onTabTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
          ),
        ],
      ),
    );
  }
}