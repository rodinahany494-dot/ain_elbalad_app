import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
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
                      _topIcon('assets/notification_new.png', Icons.notifications),
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
                      ),
                      const SizedBox(height: 19),
                      _taskCard(
                        context,
                        "In Progress Tasks",
                        "Continue handling each assigned task and progress it until the issue is fully fixed",
                        "assets/icons/in_progress.svg",
                        Icons.pending,
                      ),
                      const SizedBox(height: 19),
                      _taskCard(
                        context,
                        "Update Tasks",
                        "Keep this task updated by adding recent actions or changes",
                        "assets/icons/update_tasks.svg",
                        Icons.update,
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

  static Widget _topIcon(String path, IconData fallback) => Container(
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
          icon: const Icon(Icons.arrow_back, color: Colors.black),
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
                    return _buildTaskCard(task);
                  },
                ),

          /// ✅ NEW NAVBAR (بدل القديم)
          const TechNavBar(currentIndex: 3),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    Color statusColor = const Color(0xFF0056A7);
    if (task['status'] == 'Fixed') statusColor = const Color(0xFF4CAF50);
    if (task['status'] == 'In Progress') {
      statusColor = const Color(0xFFFFA500);
    }

    bool hasImage =
        task['image'] != null && task['image'].toString().isNotEmpty;

    return Center(
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
                    style:
                        const TextStyle(color: Colors.black, fontSize: 12),
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
    );
  }
}