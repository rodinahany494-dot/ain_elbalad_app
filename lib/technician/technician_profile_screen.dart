import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:ain_elbalad/app_config.dart';
import 'package:ain_elbalad/app_session.dart';
import 'package:ain_elbalad/technician/technician_screens.dart';

class ProfileSideMenu extends StatefulWidget {
  const ProfileSideMenu({super.key});

  @override
  State<ProfileSideMenu> createState() => _ProfileSideMenuState();
}

class _ProfileSideMenuState extends State<ProfileSideMenu> {
  String _displayName = 'Technician';
  String? _profilePhotoUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // =========================
  // LOAD PROFILE FROM API
  // =========================
  Future<void> _loadProfile() async {
    try {
      final cachedName = await AppSession.displayName();
      if (cachedName != null &&
          cachedName.trim().isNotEmpty &&
          mounted) {
        setState(() {
          _displayName = cachedName.trim();
        });
      }

      final token = await AppSession.token();

      if (token == null || token.isEmpty) {
        if (mounted) {
          setState(() {
            _loading = false;
          });
        }
        return;
      }

      final response = await http.get(
        Uri.parse(ApiConfig.technicianProfile),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];

        if (data != null) {
          final firstName = data['first_name'] ?? '';
          final lastName = data['last_name'] ?? '';
          final fullName = '$firstName $lastName'.trim();

          final image = data['image']?.toString();

          if (fullName.isNotEmpty) {
            await AppSession.saveDisplayName(fullName);
            if (mounted) {
              setState(() {
                _displayName = fullName;
              });
            }
          }

          if (image != null && image.isNotEmpty && mounted) {
            setState(() {
              _profilePhotoUrl = image;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Profile load error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // =========================
  // LOGOUT DIALOG
  // =========================
  Future<void> _showLogoutDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text("Logout"),
          content: const Text(
            "Are you sure you want to log out?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "Logout",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await AppSession.clear();

      if (!mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  // =========================
  // PICK IMAGE SHEET
  // =========================
  Future<void> _showAvatarSourceSheet() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (sheetContext) {
        return SizedBox(
          height: 180,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _AvatarSourceButton(
                icon: Icons.image,
                label: "Gallery",
                onTap: () => Navigator.pop(sheetContext, "gallery"),
              ),
              _AvatarSourceButton(
                icon: Icons.camera_alt,
                label: "Camera",
                onTap: () => Navigator.pop(sheetContext, "camera"),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || source == null) return;

    final picker = ImagePicker();

    final pickedFile = await picker.pickImage(
      source: source == "camera"
          ? ImageSource.camera
          : ImageSource.gallery,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    await _uploadImage(File(pickedFile.path));
    await _loadProfile();
  }

  // =========================
  // UPLOAD IMAGE
  // =========================
  Future<bool> _uploadImage(File file) async {
    final token = await AppSession.token();
    if (token == null || token.isEmpty) return false;

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(ApiConfig.technicianUpdateProfilePhoto),
    );

    request.headers.addAll({
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });

    request.files.add(
      await http.MultipartFile.fromPath('photo', file.path),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    return response.statusCode == 200 || response.statusCode == 201;
  }

  // =========================
  // UI BUILD (MODIFIED TO DRAWER)
  // =========================
  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 303,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Center(
                child: Text(
                  "My Profile",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0D4B97),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  GestureDetector(
                    onTap: _showAvatarSourceSheet,
                    child: CircleAvatar(
                      radius: 28,
                      backgroundImage: _profilePhotoUrl != null
                          ? NetworkImage(_profilePhotoUrl!)
                          : null,
                      child: _profilePhotoUrl == null
                          ? const Icon(Icons.person, size: 30, color: Color(0xFF5E6773))
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _loading ? "Loading..." : _displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _ProfileRow(
                icon: Icons.notifications,
                text: "Notifications",
                onTap: () {
                  Navigator.pop(context); // Close Drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NOTIFICATION_TECHScreen(),
                    ),
                  );
                },
              ),
              _ProfileRow(
                icon: Icons.help_outline,
                text: "Help & Support",
                onTap: () {
                  Navigator.pop(context); // Close Drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HelpSupportPage(),
                    ),
                  );
                },
              ),
              _ProfileRow(
                icon: Icons.privacy_tip_outlined,
                text: "Privacy Policy",
                onTap: () {
                  Navigator.pop(context); // Close Drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  "Log Out",
                  style: TextStyle(color: Colors.red),
                ),
                onTap: _showLogoutDialog,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================
// PROFILE ROW WIDGET
// =========================
class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _ProfileRow({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(text),
      onTap: onTap,
    );
  }
}

// =========================
// AVATAR SOURCE BUTTON
// =========================
class _AvatarSourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AvatarSourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 28,
            child: Icon(icon),
          ),
          const SizedBox(height: 8),
          Text(label),
        ],
      ),
    );
  }
}

// ====================================================================
// 6. Help & Support Screen
// ====================================================================
class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Help & Support",
          style: TextStyle(
            fontSize: 24,
            color: Color(0xFF004E98),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionHeader("Task Assistance"),
            descriptionText(
              "For help with assigned tasks or clarifications, contact your supervisor at: ",
                  "out to: ",
              "02-23456789",
            ),
            const Divider(height: 30),
            sectionHeader("Technical Issues"),
            descriptionText(
              "For app problems (task updates, photo upload, or ",
              "tasks not loading), contact technical support:, \n",
              "02-12345678",
            ),
            const Divider(height: 30),
            sectionHeader("System Problems"),
            descriptionText(
              "If task details or location are incorrect, report to ",
              "system support:",
              " 02-34567890",
            ),
            const Divider(height: 30),
            Row(
              children: [
                const Text("💡 ", style: TextStyle(fontSize: 20)),
                sectionHeader("Quick Tips"),
              ],
            ),
            const SizedBox(height: 8),
            bulletPoint("Check your internet connection"),
            bulletPoint("Keep the app updated"),
            bulletPoint("Enable camera and location access"),
            const Divider(height: 30),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WarningTriangle(size: 24),
                const SizedBox(width: 8),
                Expanded(child: sectionHeader("Emergencies")),
              ],
            ),
            const SizedBox(height: 4),
            descriptionText(
              "For dangerous situations (fire, gas leak, electrical ",
              "hazard), contact emergency authorities::\n",
              "02-45678901",
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// 7. Privacy Policy Screen
// ====================================================================
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            fontSize: 24,
            color: Color(0xFF004E98),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Center(
              child: Text(
                'The Ain El Balad app protects the privacy of  \n'
                'technicians using the system\n',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF5F5F5F),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            sectionTitle('1. Data We Collect'),
            bullet('Task details and updates'),
            bullet('Photos uploaded during tasks'),
            bullet('Device and location information'),
            const Divider(height: 30),
            sectionTitle('2. How We Use the Data'),
            bullet('Assign and manage tasks'),
            bullet('Track task progress'),
            bullet('Improve system performance'),
            const Divider(height: 30),
            sectionTitle('3. Data Sharing'),
            bullet('Data is shared only with authorized supervisors and system administrators.'),            const Divider(height: 30),
            sectionTitle('4. Data Security'),
            bullet('Data is encrypted and stored on secure servers'),
            const Divider(height: 30),
            sectionTitle('5. App Permissions'),
            bullet('Camera for task photos'),
            bullet('Location for task identification'),
            bullet('Notifications for task updates'),          
            ],
        ),
      ),
    );
  }
}

class WarningTriangle extends StatelessWidget {
  final double size;
  const WarningTriangle({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _TrianglePainter(),
          ),
          const Text(
            '!',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Widget sectionHeader(String title) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    ),
  );
}

Widget descriptionText(String text, String phoneLine, String phone) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF5F5F5F),
          height: 1.4,
        ),
      ),
      RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF5F5F5F),
          ),
          children: [
            TextSpan(text: phoneLine),
            TextSpan(
              text: phone,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget bulletPoint(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        color: Color(0xFF5F5F5F),
      ),
    ),
  );
}

Widget sectionTitle(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    ),
  );
}

Widget bullet(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '* ',
          style: TextStyle(fontSize: 12, color: Color(0xFF5F5F5F)),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Color(0xFF5F5F5F)),
          ),
        ),
      ],
    ),
  );
}









