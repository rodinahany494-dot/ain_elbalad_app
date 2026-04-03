import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'app_config.dart';
import 'app_session.dart';
import 'package:ain_elbalad/ticket_screens.dart';
import 'widgets/app_bottom_nav.dart';
const String homeBackgroundImagePath = 'assets/home_background.png';

// ====================================================================
// 1. Home Screen
// ====================================================================
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _showProfileMenu(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close profile menu',
      barrierColor: Colors.black.withValues(alpha: 0.2),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) {
        return Align(
          alignment: Alignment.centerLeft,
          child: _ProfileSideMenu(),
        );
      },
      transitionBuilder: (_, animation, __, child) {
        final offset = Tween<Offset>(
          begin: const Offset(-0.12, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
        return SlideTransition(position: offset, child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const bottomPanelHeight = 465.0;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            homeBackgroundImagePath,
            fit: BoxFit.cover,
          ),
          SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _TopIconButton(
                        icon: Icons.account_circle,
                        onTap: () {
                          _showProfileMenu(context);
                        },
                      ),
                      _TopIconButton(
                        icon: Icons.notifications,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    height: bottomPanelHeight,
                    width: double.infinity,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0x61004E98),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(50),
                          topRight: Radius.circular(50),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 42, 16, 16), // top=42, bottom=16 (requested)
                        child: Column(
                          children: [
                            _CreateTicketCard(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const CreateTicketScreen()),
                                );
                              },
                            ),
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                Expanded(
                                  child: _SmallActionCard(
                                    title: 'My Tickets',
                                    subtitle: 'View all Tickets you have submitted',
                                    icon: Icons.assignment_outlined,
                                    iconWidth: 55,
                                    iconHeight: 55,
                                    backgroundColor: const Color(0xFFF6CB74),
                                    iconColor: const Color(0xFFEF7F1A),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const MyTicketsScreen()),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _SmallActionCard(
                                    title: 'Track My Ticket',
                                    subtitle: 'Track your Ticket to see its current status',
                                    icon: Icons.local_shipping_outlined,
                                    iconWidth: 61,
                                    iconHeight: 55,
                                    backgroundColor: const Color(0xFFDCE7F2),
                                    iconColor: const Color(0xFFEF7F1A),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const TrackTicketScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 16,
                  child: Center(
                    child: AppBottomNav(
                      currentIndex: 1,
                      onLocationTap: () {
                        Navigator.pushNamed(
                          context,
                          '/map',
                        );
                      },
                      onHomeTap: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/home',
                          (route) => false,
                        );
                      },
                      onTrackTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TrackTicketScreen(),
                          ),
                        );
                      },
                      onCreateTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateTicketScreen(),
                          ),
                        );
                      },
                      locationLoading: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// 2. Profile Side Menu (Overlay)
// ====================================================================
class _ProfileSideMenu extends StatefulWidget {
  @override
  State<_ProfileSideMenu> createState() => _ProfileSideMenuState();
}

class _ProfileSideMenuState extends State<_ProfileSideMenu> {
  String _displayName = 'User';
  String? _profilePhotoUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final cached = await AppSession.displayName();
      if (cached != null && cached.trim().isNotEmpty && mounted) {
        setState(() => _displayName = cached.trim());
      }

      final token = await AppSession.token();
      if (token == null || token.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final res = await http.get(
        Uri.parse(ApiConfig.profile),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final name = _extractName(data);
        final photo = _extractPhotoUrl(data);
        if (name != null && name.isNotEmpty) {
          await AppSession.saveDisplayName(name);
          if (mounted) {
            setState(() {
              _displayName = name;
            });
          }
        }
        if (mounted && photo != null && photo.isNotEmpty) {
          setState(() => _profilePhotoUrl = photo);
        }
      }
    } catch (_) {
      // Keep cached/default name if profile call fails.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showEditNameDialog() async {
    final controller = TextEditingController(
      text: _displayName == 'User' ? '' : _displayName,
    );
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: const Text('Edit Name'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Enter your name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isEmpty) return;
                final updated = await _updateProfileNameOnServer(newName);
                if (!dialogContext.mounted) return;
                if (!updated) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to update profile name.')),
                  );
                  return;
                }
                await AppSession.saveDisplayName(newName);
                if (mounted) setState(() => _displayName = newName);
                if (Navigator.of(dialogContext).canPop()) {
                  Navigator.pop(dialogContext, newName);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (newName != null && newName.isNotEmpty) {
      await AppSession.saveDisplayName(newName);
      if (mounted) setState(() => _displayName = newName);
    }
  }

  Future<bool> _updateProfileNameOnServer(String newName) async {
    final token = await AppSession.token();
    if (token == null || token.isEmpty) return false;

    final res = await http.post(
      Uri.parse(ApiConfig.updateProfile),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': newName,
        'full_name': newName,
        'display_name': newName,
      }),
    );

    return res.statusCode == 200 || res.statusCode == 201;
  }

  String? _extractName(dynamic payload) {
    if (payload is! Map<String, dynamic>) return null;
    dynamic user = payload['user'];
    if (user == null && payload['data'] is Map<String, dynamic>) {
      user = payload['data']['user'] ?? payload['data'];
    }
    if (user is Map<String, dynamic>) {
      final fullName = user['full_name']?.toString().trim();
      if (fullName != null && fullName.isNotEmpty) return fullName;
      final first = user['first_name']?.toString().trim() ??
          user['firstName']?.toString().trim() ??
          user['firstname']?.toString().trim() ??
          '';
      final last = user['last_name']?.toString().trim() ??
          user['lastName']?.toString().trim() ??
          user['lastname']?.toString().trim() ??
          '';
      final full = '$first $last'.trim();
      if (full.isNotEmpty) return full;
      final name = user['name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
    }
    final directFirst = payload['first_name']?.toString().trim() ??
        payload['firstName']?.toString().trim() ??
        payload['firstname']?.toString().trim();
    final directLast = payload['last_name']?.toString().trim() ??
        payload['lastName']?.toString().trim() ??
        payload['lastname']?.toString().trim();
    if ((directFirst ?? '').isNotEmpty || (directLast ?? '').isNotEmpty) {
      return '${directFirst ?? ''} ${directLast ?? ''}'.trim();
    }
    final topFull = payload['full_name']?.toString().trim();
    if (topFull != null && topFull.isNotEmpty) return topFull;
    return null;
  }

  String? _extractPhotoUrl(dynamic payload) {
    if (payload is! Map<String, dynamic>) return null;
    dynamic data = payload['data'];
    if (data is! Map<String, dynamic>) return null;
    final rawPhoto = data['photo']?.toString().trim();
    if (rawPhoto == null || rawPhoto.isEmpty) return null;
    return _normalizeBackendUrl(rawPhoto);
  }

String _normalizeBackendUrl(String rawUrl) {
  final uri = Uri.tryParse(rawUrl);
  if (uri == null) return rawUrl;
  if (uri.host == '127.0.0.1' || uri.host == 'localhost') {
      final base = Uri.parse(ApiConfig.baseUrl);
      return uri.replace(
        scheme: base.scheme,
        host: base.host,
        port: base.hasPort ? base.port : 443,
      ).toString();
  }
  return rawUrl;
}

Future<bool> _uploadProfilePhotoToServer(File imageFile) async {
  final token = await AppSession.token();
  if (token == null || token.isEmpty) return false;

  final request = http.MultipartRequest(
    'POST',
    Uri.parse(ApiConfig.updateProfilePhoto),
  );
  request.headers.addAll({
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  });
  request.files.add(await http.MultipartFile.fromPath('photo', imageFile.path));

  final streamed = await request.send();
  final response = await http.Response.fromStream(streamed);
  return response.statusCode == 200 || response.statusCode == 201;
}

  Future<void> _showLogoutDialog() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          content: const Text(
            'Log out of your account?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600), // Logout dialog question
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('CANCEL', style: TextStyle(color: Colors.black87)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('LOG OUT', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await _logoutFromApi();
      await AppSession.clear();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _logoutFromApi() async {
    try {
      final token = await AppSession.token();
      if (token == null || token.isEmpty) return;
      await http.post(
        Uri.parse(ApiConfig.logout),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
    } catch (_) {
      // Ignore API logout failure and continue local logout.
    }
  }

  Future<void> _showAvatarSourceSheet() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(40),
        ),
      ),
      builder: (sheetContext) {
        return SizedBox(
          height: 220,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _AvatarSourceButton(
                icon: Icons.image_rounded,
                label: 'gallery',
                onTap: () => Navigator.pop(sheetContext, 'gallery'),
              ),
              _AvatarSourceButton(
                icon: Icons.camera_alt_rounded,
                label: 'camera',
                onTap: () => Navigator.pop(sheetContext, 'camera'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || source == null) return;

    final picker = ImagePicker();
    final imageSource = source == 'camera'
        ? ImageSource.camera
        : ImageSource.gallery;

    try {
      final pickedFile = await picker.pickImage(source: imageSource, imageQuality: 85);
      if (!mounted || pickedFile == null) return;

      final uploaded = await _uploadProfilePhotoToServer(File(pickedFile.path));
      if (!mounted) return;
      if (!uploaded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile photo.')),
        );
        return;
      }

      await _loadProfile();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not pick or upload the photo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF3F3F3),
      child: SizedBox(
        width: 303,
        height: MediaQuery.of(context).size.height,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 15),
                const Center(
                  child: Text(
                    'My Profile',
                    style: TextStyle(
                      color: Color(0xFF0D4B97),
                      fontSize: 32, // Side menu title
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _showAvatarSourceSheet,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: const Color(0xFFD9DDE2),
                            backgroundImage: _profilePhotoUrl != null
                                ? NetworkImage(_profilePhotoUrl!)
                                : null,
                            child: _profilePhotoUrl == null
                                ? const Icon(
                                    Icons.person,
                                    color: Color(0xFF5E6773),
                                    size: 30,
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _loading ? 'Loading...' : _displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18, // Side menu profile name
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _showEditNameDialog,
                      icon: const Icon(Icons.edit_outlined, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _ProfileRow(
                  icon: Icons.notifications,
                  text: 'Notifications',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    );
                  },
                ),
                _ProfileRow(
                  icon: Icons.help_outline,
                  text: 'Help & Support',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HelpSupportPage()),
                    );
                  },
                ),
                _ProfileRow(
                  icon: Icons.verified_user_outlined,
                  text: 'Privacy Policy',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                    );
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout, color: Colors.red, size: 20),
                  title: const Text(
                    'Log Out',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 14, // Side menu logout text
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: _showLogoutDialog,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarSourceButton extends StatelessWidget {
  const _AvatarSourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 110,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 42, color: const Color(0xFF0D4B97)),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF0D4B97),
                fontSize: 16, // Avatar source label (gallery/camera)
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// 3. Profile Screen
// ====================================================================
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _displayName = 'User';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final cached = await AppSession.displayName();
    if (cached != null && cached.trim().isNotEmpty) {
      _displayName = cached.trim();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _showEditNameDialog() async {
    final controller = TextEditingController(
      text: _displayName == 'User' ? '' : _displayName,
    );
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: const Text('Edit Name'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Enter your name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isEmpty) return;
                final updated = await _updateProfileNameOnServer(newName);
                if (!dialogContext.mounted) return;
                if (!updated) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to update profile name.')),
                  );
                  return;
                }
                await AppSession.saveDisplayName(newName);
                if (mounted) setState(() => _displayName = newName);
                if (Navigator.of(dialogContext).canPop()) {
                  Navigator.pop(dialogContext, newName);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (newName != null && newName.isNotEmpty) {
      await AppSession.saveDisplayName(newName);
      if (mounted) setState(() => _displayName = newName);
    }
  }

  Future<bool> _updateProfileNameOnServer(String newName) async {
    final token = await AppSession.token();
    if (token == null || token.isEmpty) return false;

    final res = await http.post(
      Uri.parse(ApiConfig.updateProfile),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': newName,
        'full_name': newName,
        'display_name': newName,
      }),
    );

    return res.statusCode == 200 || res.statusCode == 201;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'My Profile',
                  style: TextStyle(
                    color: Color(0xFF0D4B97),
                    fontSize: 38, // Full profile title
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 24),
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 46,
                      backgroundColor: Color(0xFFD9DDE2),
                      child: Icon(
                        Icons.person,
                        color: Color(0xFF5E6773),
                        size: 44,
                      ),
                    ),
                    const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      _loading ? 'Loading...' : _displayName,
                      style: const TextStyle(
                        fontSize: 31, // Full profile name
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _showEditNameDialog,
                    icon: const Icon(Icons.edit_outlined, size: 24),
                  ),
                ],
              ),
              const SizedBox(height: 34),
              _ProfileRow(
                icon: Icons.notifications_none,
                text: 'Notifications',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  );
                },
              ),
              _ProfileRow(
                icon: Icons.language,
                text: 'Languages',
                onTap: () {},
              ),
              _ProfileRow(
                icon: Icons.help_outline,
                text: 'Help & Support',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HelpSupportPage()),
                  );
                },
              ),
              _ProfileRow(
                icon: Icons.verified_user_outlined,
                text: 'Privacy Policy',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                  );
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Log Out',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 28, // Full profile logout text
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// 4. Notifications Screen
// ====================================================================
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  List<_NotificationItem> _newItems = const [];
  List<_NotificationItem> _lastWeekItems = const [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final token = await AppSession.token();
      if (token == null || token.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final res = await http.get(
        Uri.parse(ApiConfig.notifications),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final grouped = _extractNotifications(data);
        if (mounted) {
          setState(() {
            _newItems = grouped.$1;
            _lastWeekItems = grouped.$2;
          });
        }
      }
    } catch (_) {
      // Keep empty list on failure.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  (List<_NotificationItem>, List<_NotificationItem>) _extractNotifications(
    Map<String, dynamic> payload,
  ) {
    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      return (const [], const []);
    }

    List<_NotificationItem> parseList(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(
            (e) => _NotificationItem(
              reportId: int.tryParse((e['report_id'] ?? '').toString()),
              title: (e['title'] ?? 'Notification').toString(),
              department: ((e['department'] ?? e['category'])?.toString() ?? '').trim(),
              idText: 'ID #${(e['report_id'] ?? '').toString()}',
              status: (e['current_status'] ?? '').toString(),
              time: _formatReportTime((e['report_date'] ?? '').toString()),
              imageUrl: _normalizeImageUrl((e['photo_url'] ?? '').toString()),
            ),
          )
          .toList();
    }

    return (parseList(data['new']), parseList(data['last_week']));
  }

  String _formatReportTime(String raw) {
    if (raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return '${dt.day}/${dt.month}';
  }

String _normalizeImageUrl(String raw) {
    if (raw.isEmpty) return '';
    final uri = Uri.tryParse(raw);
    if (uri == null) return raw;
    if (uri.host == '127.0.0.1' || uri.host == 'localhost') {
      final base = Uri.parse(ApiConfig.baseUrl);
      return uri.replace(
        scheme: base.scheme,
        host: base.host,
        port: base.hasPort ? base.port : 443,
      ).toString();
  }
  return raw;
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.arrow_back_ios_new),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Notifications',
                    style: TextStyle(
                      color: Color(0xFF0D4B97),
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_newItems.isEmpty && _lastWeekItems.isEmpty)
                  const Center(
                    child: Text(
                      'No notifications yet',
                      style: TextStyle(fontSize: 18, color: Color(0xFF6B6B6B)),
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_newItems.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'New',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                        ..._newItems.map(
                          (n) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _NotificationCard(
                              title: n.title,
                              idText: n.idText,
                              status: n.status,
                              time: n.time,
                              imageUrl: n.imageUrl,
                              highlighted: true,
                              onTap: n.reportId == null
                                  ? null
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => TicketDetailsScreen(
                                            reportId: n.reportId!,
                                            issueNameOverride: n.department.trim().isNotEmpty &&
                                                    n.department.toLowerCase() != 'null'
                                                ? n.department
                                                : null,
                                          ),
                                        ),
                                      );
                                    },
                            ),
                          ),
                        ),
                      ],
                      if (_lastWeekItems.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(top: 8, bottom: 8),
                          child: Text(
                            'Last week',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                        ..._lastWeekItems.map(
                          (n) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _NotificationCard(
                              title: n.title,
                              idText: n.idText,
                              status: n.status,
                              time: n.time,
                              imageUrl: n.imageUrl,
                              highlighted: false,
                              onTap: n.reportId == null
                                  ? null
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => TicketDetailsScreen(
                                            reportId: n.reportId!,
                                            issueNameOverride:
                                                n.department.trim().isNotEmpty ? n.department : null,
                                          ),
                                        ),
                                      );
                                    },
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationItem {
  const _NotificationItem({
    required this.reportId,
    required this.title,
    required this.department,
    required this.idText,
    required this.status,
    required this.time,
    required this.imageUrl,
  });

  final int? reportId;
  final String title;
  final String department;
  final String idText;
  final String status;
  final String time;
  final String imageUrl;
}

// ====================================================================
// 5. Reusable UI Widgets (Home/Profile/Notifications)
// ====================================================================
class _TopIconButton extends StatelessWidget {
  const _TopIconButton({
    required this.icon,
    this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: const Color(0xFF1F2730), size: 22),
        ),
      ),
    );
  }
}

class _CreateTicketCard extends StatelessWidget {
  const _CreateTicketCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 146,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF356EAB),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 61.42,
              height: 55.83,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Icon(Icons.add_photo_alternate_outlined, color: Color(0xFFFFB733)),
              ),
            ),
            SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Ticket',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24, // Create Ticket title
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Add your issue\ninstantly',
                  style: TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 15, // Create Ticket subtitle
                    height: 1.1,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallActionCard extends StatelessWidget {
  const _SmallActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconWidth,
    required this.iconHeight,
    required this.backgroundColor,
    required this.iconColor,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final double iconWidth;
  final double iconHeight;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 170,
        padding: const EdgeInsets.all(21),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: iconWidth,
              height: iconHeight,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Icon(icon, color: iconColor),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16, // Small card title
                fontWeight: FontWeight.w700,
                color: Color(0xFF131722),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12, // Small card subtitle
                color: Color(0xFF7F7F7F),
                height: 1.25,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 20, color: Colors.black),
      title: Text(
        text,
        style: const TextStyle(
          fontSize: 16, // Profile row item text
          color: Colors.black,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.title,
    required this.idText,
    required this.status,
    required this.time,
    required this.imageUrl,
    this.onTap,
    this.highlighted = false,
  });

  final String title;
  final String idText;
  final String status;
  final String time;
  final String imageUrl;
  final VoidCallback? onTap;
  final bool highlighted;

  Color _statusColor(String status) {
    final value = status.toLowerCase();
    if (value.contains('assigned')) {
      return const Color(0xFF1214A1);
    }
    if (value.contains('canceled') || value.contains('cancelled')) {
      return const Color(0xFFE61616);
    }
    if (value.contains('in progress')) {
      return const Color(0xFFDDB104);
    }
    if (value.contains('pending')) {
      return const Color(0xFF3B3F3D);
    }
    if (value.contains('fixed')) {
      return const Color(0xFF12A150);
    }
    return const Color(0xFF004E98);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 92,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: highlighted ? const Color(0xFFC8D8E8) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: highlighted
              ? null
              : const Border(
                  bottom: BorderSide(color: Color(0xFFE6E6E6)),
                ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: imageUrl.isEmpty
                  ? Container(
                      width: 82,
                      height: 82,
                      color: const Color(0xFFE0E0E0),
                      child: const Icon(Icons.image_not_supported_outlined),
                    )
                  : Image.network(
                      imageUrl,
                      width: 82,
                      height: 82,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    idText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _statusColor(status),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 42),
              child: Text(
                time,
                style: const TextStyle(
                  color: Colors.black45,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
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
            sectionHeader("Report Follow-Up"),
            descriptionText(
              "If you want to check the status of a submitted report",
              "or clarify any details about a previous report, reach \n"
                  "out to: ",
              "02-23456789",
            ),
            const Divider(height: 30),
            sectionHeader("Report Issues"),
            descriptionText(
              "If you're facing a problem while using the app—such",
              "as difficulty uploading images, issues with the map, \n"
                  "or a technical error—you can contact our support \n"
                  "team: ",
              "02-12345678",
            ),
            const Divider(height: 30),
            sectionHeader("General Questions"),
            descriptionText(
              "For any inquiries about how to use the app or its",
              "features, you can contact: ",
              "02-34567890",
            ),
            const Divider(height: 30),
            Row(
              children: [
                const Text("💡 ", style: TextStyle(fontSize: 20)),
                sectionHeader("Quick Tips"),
              ],
            ),
            const SizedBox(height: 8),
            bulletPoint("Make sure your internet connection is stable"),
            bulletPoint("Keep your app updated"),
            bulletPoint("Enable camera access to upload images"),
            bulletPoint("Allow location access for accurate report placement"),
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
              "For urgent or dangerous situations, please contact",
              "the official emergency authorities directly:\n",
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
                'The Ain El Balad application is committed to \n'
                'protecting user privacy. By using the app, you agree to\n'
                'the following:',
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
            bullet('Report images and location'),
            bullet('Basic device info'),
            bullet('Contact details (name & phone number)'),
            const Divider(height: 30),
            sectionTitle('2. How We Use the Data'),
            bullet('Processing and forwarding reports to authorities'),
            bullet('Sending status updates'),
            bullet('Improving app performance and services'),
            const Divider(height: 30),
            sectionTitle('3. Data Sharing'),
            bullet('Shared only with authorized government entities and support teams'),
            bullet('Never shared with commercial parties'),
            const Divider(height: 30),
            sectionTitle('4. Data Security'),
            bullet('Data is encrypted and stored on secure servers'),
            const Divider(height: 30),
            sectionTitle('5. App Permissions'),
            bullet('Camera & gallery for uploading images'),
            bullet('Location for accurate report placement'),
            bullet('Notifications for report updates'),
            const Divider(height: 30),
            sectionTitle('6. User Rights'),
            bullet('Access, edit, or delete personal data (where accounts exist)'),
            bullet('Disable permissions anytime via device settings'),
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









