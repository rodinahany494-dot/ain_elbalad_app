import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:ain_elbalad/app_config.dart';
import 'package:ain_elbalad/app_session.dart';
import 'package:ain_elbalad/widgets/tech_nav_bar.dart';

// ================= 1. TECHNICIAN LOGIN SCREEN =================
class TechnicianLoginScreen extends StatefulWidget {
  const TechnicianLoginScreen({super.key});

  @override
  State<TechnicianLoginScreen> createState() => _TechnicianLoginScreenState();
}

class _TechnicianLoginScreenState extends State<TechnicianLoginScreen> {
  bool isObscure = true;
  bool isLoggingIn = false;

  // Controllers للتحكم في مدخلات النص
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Future<void> _handleLogin() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("برجاء إدخال البيانات")),
      );
      return;
    }

    setState(() => isLoggingIn = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.technicianLogin),
        body: {'email': email, 'password': password},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true) {
          // حفظ بيانات الجلسة والتوكن
          await AppSession.saveAuth(
            token: data['token'],
            displayName: data['user']?['name'],
            email: data['user']?['email'],
          );

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const TechnicianHomeScreen()),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("بيانات الدخول غير صحيحة")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("خطأ سيرفر: ${response.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تعذر الاتصال بالسيرفر")),
      );
    } finally {
      if (mounted) setState(() => isLoggingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              const Center(
                child: Text(
                  "Login Account",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF004E98),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  "Welcome Back!",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 23),
              Center(
                child: SizedBox(
                  height: 325,
                  width: 343,
                  child: Image.asset(
                    "assets/login.png",
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Email Address",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black26),
                ),
                child: TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    hintText: "Enter your email address",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Password",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black26),
                ),
                child: TextField(
                  controller: passwordController,
                  obscureText: isObscure,
                  decoration: InputDecoration(
                    hintText: "Enter password",
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 14,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => isObscure = !isObscure),
                      icon: Icon(
                        isObscure ? Icons.visibility_off : Icons.visibility,
                        color: Colors.black,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFA500),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: isLoggingIn ? null : _handleLogin,
                  child: isLoggingIn
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text(
                          "Log In",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= 2. TECHNICIAN HOME SCREEN =================
class TechnicianHomeScreen extends StatelessWidget {
  const TechnicianHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              "assets/home_background.png",
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: const Color(0xFF004E98).withOpacity(0.38),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _topIcon('assets/profile_new.png', Icons.person),
                      _topIcon(
                        'assets/notification_new.png',
                        Icons.notifications,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 64, 16, 96),
                    children: [
                      _taskCard(
                        context,
                        "My Tasks",
                        "View all tasks assigned to you and start working on reported issues",
                        "assets/icons/my_tasks.svg",
                        Icons.assignment,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const TasksScreen()),
                        ),
                      ),
                      const SizedBox(height: 19),
                      _taskCard(
                        context,
                        "Completed Tasks",
                        "View all Tasks you have submitted",
                        "assets/icons/completed_tasks.svg",
                        Icons.check_circle,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CompletedTasksScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 19),
                      _taskCard(
                        context,
                        "In Progress Tasks",
                        "Continue handling each assigned task and progress it until the issue is fully fixed",
                        "assets/icons/in_progress.svg",
                        Icons.pending,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const InProgressTasksScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 19),
                      _taskCard(
                        context,
                        "Update Tasks",
                        "Keep this task updated by adding recent actions or changes",
                        "assets/icons/update_tasks.svg",
                        Icons.update,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const UpdateTaskScreen(
                              taskId: '',
                              status: 'In Progress',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF2A6BA9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _navItem('assets/icons/completed_tasks.svg', Icons.check_circle_outline),
                  _navItem('assets/icons/in_progress.svg', Icons.trending_up),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFA500),
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(
                      'assets/home_new.png',
                      width: 24,
                      height: 24,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TasksScreen()),
                    ),
                    child: _navItem('assets/icons/my_tasks.svg', Icons.list_alt),
                  ),
                  _navItem('assets/icons/update_tasks.svg', Icons.update),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _topIcon(
    String path,
    IconData fallback, {
    VoidCallback? onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Image.asset(
              path,
              width: 24,
              height: 24,
              errorBuilder: (c, e, s) => Icon(
                fallback,
                size: 20,
                color: Colors.black,
              ),
            ),
          ),
        ),
      );

  static Widget _taskCard(
    BuildContext context,
    String title,
    String subtitle,
    String path,
    IconData fallback, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: SizedBox(
          width: 343,
          height: 135,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
            decoration: BoxDecoration(
              color: const Color(0xFF2A6BA9),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 67,
                  height: 67,
                  child: SvgPicture.asset(
                    path,
                    fit: BoxFit.contain,
                    placeholderBuilder: (c) => Icon(
                      fallback,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _navItem(String path, IconData icon) => SvgPicture.asset(
        path,
        width: 24,
        height: 24,
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      );
}


// ================= 3. NOTIFICATIONS SCREEN  =================
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<_NotificationItem> notifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final token = await AppSession.token();
      final response = await http.get(
        Uri.parse(ApiConfig.technicianNotifications),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final payload = data['data'] ?? {};
        final newItems = payload['new'];
        final lastWeekItems = payload['last_week'];

        final items = <_NotificationItem>[];

        if (newItems is List) {
          items.addAll(
            newItems.map(
              (item) => _NotificationItem.fromJson(
                Map<String, dynamic>.from(item),
                group: 'New',
              ),
            ),
          );
        }

        if (lastWeekItems is List) {
          items.addAll(
            lastWeekItems.map(
              (item) => _NotificationItem.fromJson(
                Map<String, dynamic>.from(item),
                group: 'Last week',
              ),
            ),
          );
        }

        setState(() {
          notifications = items;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final newItems =
        notifications.where((n) => n.group == 'New').toList();
    final lastWeekItems =
        notifications.where((n) => n.group == 'Last week').toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SizedBox(
            height: 76 + MediaQuery.of(context).padding.top,
          ),
          const Text(
            'Notifications',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF004E98),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : notifications.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_none,
                              size: 70,
                              color: Color(0xFFCCDCEA),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No Notifications Yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF404040),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          if (newItems.isNotEmpty) ...[
                            const Text(
                              'New',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...newItems.map(
                              (n) => NotificationCard(notification: n),
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (lastWeekItems.isNotEmpty) ...[
                            const Text(
                              'Last week',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...lastWeekItems.map(
                              (n) => NotificationCard(notification: n),
                            ),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _NotificationItem {
  final String title;
  final String id;
  final String desc;
  final String time;
  final String badge;
  final bool isBlue;
  final bool hasImage;
  final String group;
  final String imageUrl;

  _NotificationItem({
    required this.title,
    required this.id,
    required this.desc,
    required this.time,
    required this.badge,
    required this.isBlue,
    required this.hasImage,
    required this.group,
    required this.imageUrl,
  });

  factory _NotificationItem.fromJson(
    Map<String, dynamic> json, {
    required String group,
  }) {
    final String photo = json['photo']?.toString() ?? '';
    return _NotificationItem(
      title: json['title']?.toString() ?? '',
      id: 'ID ${json['report_id']?.toString() ?? ''}',
      desc: json['description']?.toString() ?? '',
      time: json['time_ago']?.toString() ?? '',
      badge: json['type']?.toString() ?? '',
      isBlue: group == 'New',
      hasImage: photo.isNotEmpty,
      group: group,
      imageUrl: photo,
    );
  }
}

class NotificationCard extends StatelessWidget {
  final _NotificationItem notification;

  const NotificationCard({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: notification.isBlue
            ? const Color(0xFFCCDCEA)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: notification.isBlue
            ? null
            : Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notification.hasImage)
            Padding(
              padding: const EdgeInsets.only(left: 9, top: 9, bottom: 9),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  notification.imageUrl,
                  width: 116,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 116,
                    height: 120,
                    color: Colors.grey[300],
                  ),
                ),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.badge,
                    style: const TextStyle(
                      color: Color(0xFF004E98),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF000000),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.id,
                    style: const TextStyle(color: Color(0xFF404040)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.desc,
                    style: const TextStyle(color: Color(0xFF404040)),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      notification.time,
                      style: const TextStyle(color: Color(0xFF5F5F5F)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= 3. COMPLETED TASKS SCREEN  =================
class CompletedTasksScreen extends StatefulWidget {
  const CompletedTasksScreen({super.key});

  @override
  State<CompletedTasksScreen> createState() => _CompletedTasksScreenState();
}

class _CompletedTasksScreenState extends State<CompletedTasksScreen> {
  List<Map<String, dynamic>> completedTasks = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompletedTasks();
  }

  Future<void> _loadCompletedTasks() async {
    try {
      final token = await AppSession.token();
      final response = await http.get(
        Uri.parse(ApiConfig.completedTasks),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tasks = data['data'];
        setState(() {
          completedTasks = tasks is List
              ? List<Map<String, dynamic>>.from(tasks)
              : <Map<String, dynamic>>[];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Image.asset(
            'assets/icons/arrow_back.png',
            width: 24,
            height: 24,
          ),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => const TechnicianHomeScreen(),
              ),
              (route) => false,
            );
          },
        ),
        title: const Text(
          "Completed Tasks",
          style: TextStyle(
            color: Color(0xFF1A436A),
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                itemCount: completedTasks.length,
                itemBuilder: (context, index) =>
                      _CompletedTaskCard(task: completedTasks[index]),
                ),
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF004A99),
                borderRadius: BorderRadius.circular(35),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((255 * 0.15).round()),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildNavItem(Icons.description, isSelected: true),
                  _buildNavItem(Icons.cached),
                  _buildNavItem(Icons.home_outlined),
                  _buildNavItem(Icons.assignment_outlined),
                  _buildNavItem(Icons.history),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, {bool isSelected = false}) {
    return isSelected
        ? Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFF9A825),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          )
        : Icon(
            icon,
            color: Colors.white.withAlpha((255 * 0.7).round()),
            size: 26,
          );
  }
}

class _CompletedTaskCard extends StatelessWidget {
  final Map<String, dynamic> task;

  const _CompletedTaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final String photoUrl = task['photo']?.toString() ?? '';
    final String title = task['description']?.toString() ?? '';
    final String reportId = task['report_id']?.toString() ?? '';
    final String doneDate = task['done_date']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CompletedTaskDetailsScreen(
              taskId: reportId,
            ),
          ),
        );
      },
      child: Center(
        child: Container(
          width: 343,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFD9E7F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (photoUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    photoUrl,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "ID #$reportId",
                      style:
                          const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Fixed",
                      style: TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Done : $doneDate",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= 4. COMPLETED TASK DETAILS SCREEN  =================
class CompletedTaskDetailsScreen extends StatefulWidget {
  final String taskId;

  const CompletedTaskDetailsScreen({super.key, required this.taskId});

  @override
  State<CompletedTaskDetailsScreen> createState() =>
      _CompletedTaskDetailsScreenState();
}

class _CompletedTaskDetailsScreenState extends State<CompletedTaskDetailsScreen> {
  bool isLoading = true;
  Map<String, dynamic> taskData = {};

  @override
  void initState() {
    super.initState();
    _loadCompletedTaskDetails();
  }

  int? _parseTaskId(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned);
  }

  Future<void> _loadCompletedTaskDetails() async {
    try {
      final taskId = _parseTaskId(widget.taskId);
      if (taskId == null) {
        if (!mounted) return;
        setState(() => isLoading = false);
        return;
      }

      final token = await AppSession.token();
      final response = await http.get(
        Uri.parse(ApiConfig.technicianCompletedTaskDetails(taskId)),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          taskData = data['data'] ?? {};
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF0054A5);
    final String id = taskData['id']?.toString() ?? widget.taskId;
    final String location = taskData['location']?.toString() ?? '';
    final String description = taskData['description']?.toString() ?? '';
    final String duration = taskData['duration']?.toString() ?? '';
    final String finalStatus = taskData['final_status']?.toString() ?? '';
    final String category = taskData['category']?.toString() ?? '';
    final String doneAt = taskData['done_at']?.toString() ?? '';
    final String beforePhoto = taskData['before_photo']?.toString() ?? '';
    final String afterPhoto = taskData['after_photo']?.toString() ?? '';
    final String technicianNote =
        taskData['technician_note']?.toString() ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Image.asset(
            'assets/icons/arrow_back.png',
            width: 24,
            height: 24,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Completed Tasks Details',
          style: TextStyle(
            color: primaryBlue,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildImageColumn("Before", beforePhoto),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildImageColumn("After", afterPhoto),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow("ID :", id),
                        _buildDetailRow("Location :", location),
                        _buildDetailRow("Description :", description),
                        _buildDetailRow("Duration :", duration),
                        _buildDetailRow(
                          "Final Status :",
                          finalStatus,
                          valueColor: const Color(0xFF2E7D32),
                        ),
                        _buildDetailRow("Category :", category),
                        _buildDetailRow("Done :", doneAt),
                        _buildDetailRow("Technician Note :", technicianNote),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.all(16),
        height: 60,
        decoration: BoxDecoration(
          color: primaryBlue,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
                icon: const Icon(Icons.assignment_turned_in_outlined,
                    color: Colors.white),
                onPressed: () {}),
            IconButton(
                icon: const Icon(Icons.history, color: Colors.white),
                onPressed: () {}),
            IconButton(
                icon: const Icon(Icons.home_outlined, color: Colors.white),
                onPressed: () {}),
            IconButton(
                icon:
                    const Icon(Icons.description_outlined, color: Colors.white),
                onPressed: () {}),
            IconButton(
                icon: const Icon(Icons.assignment_ind_outlined,
                    color: Colors.white),
                onPressed: () {}),
          ],
        ),
      ),
    );
  }

  Widget _buildImageColumn(String label, String imageUrl) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 250,
            color: Colors.grey[300],
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: double.infinity,
                    height: 250,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(Icons.image, size: 50, color: Colors.grey),
                    ),
                  )
                : const Center(
                    child: Icon(Icons.image, size: 50, color: Colors.grey),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0054A5),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                color: valueColor ?? Colors.black87,
                fontWeight:
                    valueColor != null ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= 3. TASKS SCREEN  =================
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<dynamic> tasks = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      final token = await AppSession.token();
      final response = await http.get(
        Uri.parse(ApiConfig.myTasks),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          tasks = data['data'] ?? [];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Image.asset(
            'assets/icons/arrow_back.png',
            width: 24,
            height: 24,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Tasks",
          style: TextStyle(
            color: Color(0xFF004E98),
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),

      body: Stack(
        children: [
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return _buildTaskCard(
                      task,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TaskDetailsScreen(
                            taskId: task['report_id']?.toString() ?? '',
                          ),
                        ),
                      ),
                    );
                  },
                ),

          /// ✅ NEW NAVBAR (بدل القديم)
          const TechNavBar(currentIndex: 3),
        ],
      ),
    );
  }

  Widget _buildTaskCard(
    Map<String, dynamic> task, {
    VoidCallback? onTap,
  }) {
    final String status = task['status']?.toString().toLowerCase() ?? '';
    Color statusColor = const Color(0xFF0056A7);
    if (status.contains('fixed')) {
      statusColor = const Color(0xFF4CAF50);
    } else if (status.contains('in progress')) {
      statusColor = const Color(0xFFFFA500);
    } else if (status.contains('canceled') || status.contains('cancelled')) {
      statusColor = const Color(0xFFAE0505);
    }

    bool hasImage =
        task['image'] != null && task['image'].toString().isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Container(
          width: 343,
          height: 155,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFD9E7F2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasImage) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    task['image'],
                    width: 127,
                    height: 127,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 12),
              ],

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task['description'] ?? 'No Title',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task['location'] ?? '',
                      style: const TextStyle(color: Colors.black, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "ID #${task['report_id']}",
                      style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                          color: Colors.black),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task['status'] ?? '',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task['category'] ?? '',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= 4. TASK DETAILS SCREEN  =================
class TaskDetailsScreen extends StatefulWidget {
  final String taskId;

  const TaskDetailsScreen({super.key, required this.taskId});

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  bool isLoading = true;
  bool isStartingTask = false;
  Map<String, dynamic> taskData = {};

  final Color primaryBlue = const Color(0xFF004E98);
  final Color lightBlueCard = const Color(0xFFCCDCEA);
  final Color orangeButton = const Color(0xFFFFA500);

  Color _statusColor(String status) {
    final value = status.toLowerCase();
    if (value.contains('fixed')) {
      return const Color(0xFF4CAF50);
    }
    if (value.contains('completed')) {
      return const Color(0xFF4CAF50);
    }
    if (value.contains('in progress')) {
      return const Color(0xFFFFA500);
    }
    if (value.contains('canceled') || value.contains('cancelled')) {
      return const Color(0xFFAE0505);
    }
    return const Color(0xFF0056A7);
  }

  String _statusLabel(String status) {
    final value = status.toLowerCase();
    if (value.contains('completed')) {
      return 'Fixed';
    }
    return status;
  }

  @override
  void initState() {
    super.initState();
    _loadTaskDetails();
  }

  Future<void> _loadTaskDetails() async {
    try {
      final taskId = int.tryParse(widget.taskId);
      if (taskId == null) {
        if (!mounted) return;
        setState(() => isLoading = false);
        return;
      }

      final token = await AppSession.token();
      final response = await http.get(
        Uri.parse(ApiConfig.technicianTaskDetails(taskId)),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          taskData = data['data'] ?? {};
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> _startTask() async {
    final taskId = int.tryParse(widget.taskId);
    if (taskId == null || isStartingTask) return;

    setState(() => isStartingTask = true);

    try {
      final token = await AppSession.token();
      final response = await http.post(
        Uri.parse(ApiConfig.technicianStartTask(taskId)),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true) {
          setState(() {
            taskData['status'] = data['data']?['status'] ?? 'In Progress';
            isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Task started')),
          );
          return;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start task')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start task')),
      );
    } finally {
      if (mounted) {
        setState(() => isStartingTask = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String taskId = taskData['report_id']?.toString() ?? widget.taskId;
    final String description = taskData['description']?.toString() ?? '';
    final String location = taskData['location']?.toString() ?? '';
    final String status = taskData['status']?.toString() ?? '';
    final String category = taskData['category']?.toString() ?? '';
    final String priority = taskData['priority']?.toString() ?? '';
    final String issueDate = taskData['issue_date']?.toString() ?? '';
    final String imageUrl = taskData['image']?.toString() ?? '';
    final String statusLabel = _statusLabel(status);
    final Color statusColor = _statusColor(status);
    final bool showStartButton = status.toLowerCase().contains('new task');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Image.asset(
            'assets/icons/arrow_back.png',
            width: 24,
            height: 24,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Task Details',
          style: TextStyle(
            color: Color(0xFF004E98),
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 128),
                  child: Container(
                    decoration: BoxDecoration(
                      color: lightBlueCard,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 291,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            image: imageUrl.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(imageUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: imageUrl.isEmpty
                              ? const Icon(Icons.image,
                                  color: Colors.grey, size: 50)
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              "ID  ",
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w500,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              taskId,
                              style: TextStyle(
                                color: primaryBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        buildDetailRow("Description :", description),
                        buildDetailRow("Location :", location),
                        buildDetailRow("Status :", statusLabel,
                            valueColor: statusColor),
                        buildDetailRow("Category :", category),
                        buildDetailRow("Priority :", priority),
                        buildDetailRow("Issue Date :", issueDate),
                        const SizedBox(height: 20),
                        if (showStartButton) ...[
                          Center(
                            child: SizedBox(
                              width: 111,
                              height: 40,
                              child: ElevatedButton(
                                onPressed: isStartingTask ? null : _startTask,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: orangeButton,
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: isStartingTask
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.black,
                                        ),
                                      )
                                    : const Text(
                                        "Start Task",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
                ),
          const TechNavBar(currentIndex: 3),
        ],
      ),
    );
  }

  Widget buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: valueColor ?? Colors.black54,
                fontWeight:
                    valueColor != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= 5. IN PROGRESS TASKS SCREEN  =================
class InProgressTasksScreen extends StatefulWidget {
  const InProgressTasksScreen({super.key});

  @override
  State<InProgressTasksScreen> createState() => _InProgressTasksScreenState();
}

class _InProgressTasksScreenState extends State<InProgressTasksScreen> {
  List<Map<String, dynamic>> tasks = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      final token = await AppSession.token();
      final response = await http.get(
        Uri.parse(ApiConfig.inProgressTasks),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['data'];
        setState(() {
          tasks = items is List
              ? List<Map<String, dynamic>>.from(items)
              : <Map<String, dynamic>>[];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Image.asset(
                      'assets/icons/arrow_back.png',
                      width: 24,
                      height: 24,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'In Progress Tasks',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF004E98),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : tasks.isEmpty
                      ? const Center(
                          child: Text(
                            'No tasks yet',
                            style: TextStyle(color: Colors.black),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: tasks.length,
                          itemBuilder: (context, index) {
                            return _InProgressTaskCard(task: tasks[index]);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InProgressTaskCard extends StatelessWidget {
  final Map<String, dynamic> task;

  const _InProgressTaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final String imageUrl = task['image']?.toString() ?? '';
    final String title = task['description']?.toString() ?? '';
    final String id = task['report_id']?.toString() ?? '';
    final String category = task['category']?.toString() ?? '';
    final String location = task['location']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TaskDetailsScreen(taskId: id),
          ),
        );
      },
      child: Container(
        width: 343,
        height: 155,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFCCDCEA),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (imageUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    width: 127,
                    height: 127,
                    color: Colors.grey[200],
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      imageUrl.isNotEmpty ? 8 : 12,
                      8,
                      8,
                      8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, height: 1.5),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'ID $id',
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 1),
                        const Text(
                          'In Progress',
                          style: TextStyle(
                            color: Color(0xFFFFA500),
                            fontSize: 14,
                            height: 1.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          category,
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: SizedBox(
                      width: 72,
                      height: 26,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UpdateTaskScreen(
                                taskId: id,
                                status: task['status']?.toString() ?? 'In Progress',
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFA500),
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(72, 26),
                          fixedSize: const Size(72, 26),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Update',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= 6. UPDATE TASK SCREEN  =================
class UpdateTaskScreen extends StatefulWidget {
  final String taskId;
  final String status;

  const UpdateTaskScreen({
    super.key,
    required this.taskId,
    required this.status,
  });

  @override
  State<UpdateTaskScreen> createState() => _UpdateTaskScreenState();
}

class _UpdateTaskScreenState extends State<UpdateTaskScreen> {
  final TextEditingController commentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? selectedImage;
  bool isSubmitting = false;
  bool isLoadingTask = false;
  String? resolvedTaskId;
  String resolvedStatus = 'In Progress';

  @override
  void initState() {
    super.initState();
    resolvedTaskId = widget.taskId.trim().isNotEmpty ? widget.taskId.trim() : null;
    resolvedStatus = widget.status.trim().isNotEmpty ? widget.status.trim() : 'In Progress';
    if (resolvedTaskId == null) {
      _loadDefaultTask();
    }
  }

  Future<void> _loadDefaultTask() async {
    setState(() => isLoadingTask = true);

    try {
      final token = await AppSession.token();
      final response = await http.get(
        Uri.parse(ApiConfig.inProgressTasks),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['data'];
        if (items is List && items.isNotEmpty) {
          final last = Map<String, dynamic>.from(items.last);
          setState(() {
            resolvedTaskId = last['report_id']?.toString();
            resolvedStatus = last['status']?.toString() ?? 'In Progress';
            isLoadingTask = false;
          });
          return;
        }
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => isLoadingTask = false);
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (!mounted) return;
    if (image != null) {
      setState(() => selectedImage = image);
    }
  }

  Future<void> _submitUpdate() async {
    final taskId = int.tryParse(resolvedTaskId ?? '');
    if (taskId == null || isSubmitting) return;

    setState(() => isSubmitting = true);

    try {
      final token = await AppSession.token();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.technicianSubmitUpdate(taskId)),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.fields['comment'] = commentController.text.trim();

      if (selectedImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('photo', selectedImage!.path),
        );
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Update submitted')),
          );
          Navigator.pop(context, true);
          return;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit update')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit update')),
      );
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String displayTaskId = resolvedTaskId ?? widget.taskId;
    final bool showNavBar = MediaQuery.of(context).viewInsets.bottom == 0;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Image.asset(
            'assets/icons/arrow_back.png',
            width: 24,
            height: 24,
          ),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Update Task Order',
          style: TextStyle(
            color: Color(0xFF004A8E),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: isLoadingTask
          ? const Center(child: CircularProgressIndicator())
          : (resolvedTaskId == null || resolvedTaskId!.isEmpty)
              ? const Center(
                  child: Text(
                    'No in progress tasks available',
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              : Stack(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                      child: Center(
                        child: SizedBox(
                          width: 343,
                          height: 620,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFD6E3F3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.all(20),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  GestureDetector(
                                    onTap: _pickImage,
                                    child: SizedBox(
                                      width: 327,
                                      height: 282,
                                      child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFB0B0B0),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                        image: selectedImage != null
                                            ? DecorationImage(
                                                image: FileImage(File(
                                                    selectedImage!.path)),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: selectedImage == null
                                          ? const Icon(
                                              Icons.camera_alt_outlined,
                                              size: 100,
                                              color: Colors.white,
                                            )
                                          : null,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Adding a photo is optional',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 14),
                                  ),
                                  const SizedBox(height: 25),
                                  Row(
                                    children: [
                                      const Text(
                                        'ID ',
                                        style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w500),
                                      ),
                                      Text(
                                        '#$resolvedTaskId',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      const Text(
                                        'Status : ',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        resolvedStatus,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Color(0xFFFFA500),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: 327,
                                    height: 48,
                                    child: TextField(
                                      controller: commentController,
                                      maxLines: 1,
                                      textAlignVertical:
                                          TextAlignVertical.center,
                                      decoration: InputDecoration(
                                        hintText: 'Add your comment',
                                        filled: true,
                                        fillColor:
                                            Colors.white.withOpacity(0.5),
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 14,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                              color: Colors.grey),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                              color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  SizedBox(
                                    width: 130,
                                    height: 40,
                                    child: ElevatedButton(
                                      onPressed:
                                          isSubmitting ? null : _submitUpdate,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFFFFA500),
                                        foregroundColor: Colors.black,
                                        elevation: 0,
                                        shadowColor: Colors.transparent,
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(130, 40),
                                        fixedSize: const Size(130, 40),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                      child: isSubmitting
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.black87,
                                              ),
                                            )
                                          : const Text(
                                              'Submit Update',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (showNavBar) const TechNavBar(currentIndex: 4),
                  ],
                ),
    );
  }
}
