import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'app_config.dart';
import 'app_session.dart';
import 'second_page.dart';
import 'map_screen.dart';
import 'ticket_screens.dart';

Route _instantRoute(Widget page) {
  return PageRouteBuilder(
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (_, animation, __) => page,
    transitionsBuilder: (_, __, ___, child) => child,
  );
}

String? _extractTokenFromBody(dynamic body) {
  if (body is! Map<String, dynamic>) return null;
  final direct = body['token']?.toString();
  if (direct != null && direct.isNotEmpty) return direct;
  final data = body['data'];
  if (data is Map<String, dynamic>) {
    final t = data['token']?.toString() ?? data['access_token']?.toString();
    if (t != null && t.isNotEmpty) return t;
  }
  return body['access_token']?.toString();
}

class _SocialAuthPayload {
  final String provider;
  final String? email;
  final String socialId;
  final String? firstName;
  final String? lastName;

  const _SocialAuthPayload({
    required this.provider,
    required this.socialId,
    this.email,
    this.firstName,
    this.lastName,
  });
}

Future<void>? _googleSignInInit;

Future<void> _ensureGoogleSignInInitialized() {
  if (ApiConfig.googleWebClientId.isEmpty) {
    throw Exception('Google Web Client ID is missing.');
  }
  _googleSignInInit ??= GoogleSignIn.instance.initialize(
    serverClientId: ApiConfig.googleWebClientId,
  );
  return _googleSignInInit!;
}

({String? firstName, String? lastName}) _splitName(String? name) {
  final trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty) {
    return (firstName: null, lastName: null);
  }
  final parts = trimmed.split(RegExp(r'\s+'));
  if (parts.length == 1) {
    return (firstName: parts.first, lastName: null);
  }
  return (
    firstName: parts.first,
    lastName: parts.sublist(1).join(' '),
  );
}

Future<_SocialAuthPayload?> _signInWithGoogle() async {
  await _ensureGoogleSignInInitialized();
  final account = await GoogleSignIn.instance.authenticate(
    scopeHint: const ['email', 'profile'],
  );

  if (account.id.isEmpty) {
    throw Exception('Google sign-in did not return a social id.');
  }

  final nameParts = _splitName(account.displayName);

  return _SocialAuthPayload(
    provider: 'google',
    socialId: account.id,
    email: account.email,
    firstName: nameParts.firstName,
    lastName: nameParts.lastName,
  );
}

Future<_SocialAuthPayload?> _signInWithFacebook() async {
  final result = await FacebookAuth.instance.login(
    permissions: const ['email', 'public_profile'],
  );

  if (result.status == LoginStatus.cancelled) return null;
  if (result.status != LoginStatus.success || result.accessToken == null) {
    throw Exception(result.message ?? 'Facebook sign-in failed.');
  }

  final userData = await FacebookAuth.instance.getUserData(
    fields: 'id,name,first_name,last_name,email',
  );
  final socialId = userData['id']?.toString() ?? '';
  if (socialId.isEmpty) {
    throw Exception('Facebook sign-in did not return a social id.');
  }

  final rawFirstName = userData['first_name']?.toString();
  final rawLastName = userData['last_name']?.toString();
  final parsedName = _splitName(userData['name']?.toString());

  return _SocialAuthPayload(
    provider: 'facebook',
    socialId: socialId,
    email: userData['email']?.toString(),
    firstName: rawFirstName ?? parsedName.firstName,
    lastName: rawLastName ?? parsedName.lastName,
  );
}

Future<void> _finishSocialLogin(
  BuildContext context,
  _SocialAuthPayload payload,
) async {
  final response = await http.post(
    Uri.parse(ApiConfig.socialLogin),
    headers: const {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: jsonEncode({
      'email': payload.email,
      'social_id': payload.socialId,
      'social_type': payload.provider,
      'first_name': payload.firstName,
      'last_name': payload.lastName,
    }),
  );

  if (response.statusCode != 200 && response.statusCode != 201) {
    throw Exception('Social login failed: ${response.statusCode}');
  }

  final body = jsonDecode(response.body);
  final token = _extractTokenFromBody(body);
  if (token == null || token.isEmpty) {
    throw Exception('Social login succeeded but no auth token was returned.');
  }

  final email = payload.email ??
      (body is Map<String, dynamic> ? body['email']?.toString() : null);
  final displayName = [
    payload.firstName?.trim(),
    payload.lastName?.trim(),
  ].where((part) => part != null && part.isNotEmpty).join(' ').trim();
  final responseName = displayName.isNotEmpty
      ? displayName
      : (body is Map<String, dynamic> ? body['name']?.toString() : null);
  await AppSession.saveAuth(
    token: token,
    email: email,
    displayName: responseName,
  );

  if (!context.mounted) return;
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const HomeScreen()),
    (route) => false,
  );
}

Future<void> _runSocialLogin(
  BuildContext context, {
  required Future<_SocialAuthPayload?> Function() signIn,
}) async {
  try {
    final payload = await signIn();
    if (payload == null) return;
    await _finishSocialLogin(context, payload);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
    );
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ain El Balad App',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          surfaceTintColor: Colors.white,
        ),
      ),
      home: SplashScreen(),
      routes: {
        '/home': (_) => const HomeScreen(),
        '/create': (_) => const CreateTicketScreen(),
        '/track': (_) => const TrackTicketScreen(),
        '/map': (_) => const MapScreen(),
      },
    );
  }
}

// ====================================================================
// 1. Splash Screen
// ====================================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      // بعد 3 ثواني انتقلي لـ Splash2Screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const Splash2Screen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF004E98),
      body: Center(
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: 496,
          child: Image.asset(
            "assets/Logo.png",
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

// ===================== SPLASH 2 SCREEN =====================
class Splash2Screen extends StatelessWidget {
  const Splash2Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B4F9B),
      body: Stack(
        children: [
          // Logo
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 50),
              child: SizedBox(
                height: 405,
                child: Image.asset(
                  "assets/Logo.png",
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // Bottom container زي الـ Onboarding
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 345,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFEAEAEA),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(50),
                  topRight: Radius.circular(50),
                ),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 30,
                vertical: 40,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'AIN EL BALAD',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Choose how you want to Log in',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: Color(0xFF6B6B6B),
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: 343,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(context, _instantRoute(const OnboardingFlowScreen()));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFA500),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'as user',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: 343,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFA500),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'as Technician',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== TECHNICIAN SCREEN =====================
class TechnicianScreen extends StatelessWidget {
  const TechnicianScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Technician')),
      body: const Center(
        child: Text(
          'Technician Screen',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}

// ====================================================================
// 2. Onboarding Flow Screen
// ====================================================================
class OnboardingFlowScreen extends StatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  static const Color primaryOrange = Color(0xFFFFA500);
  static const Color cardBackground = Color(0xFFEAEAEA);
  static const Color inactiveDotColor = Color(0xFFCACACA);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDot(bool isActive) {
    const double dotSize = 16.0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      height: dotSize,
      width: dotSize,
      decoration: BoxDecoration(
        color: isActive ? primaryOrange : inactiveDotColor,
        borderRadius: BorderRadius.circular(dotSize / 2),
        border: Border.all(
          color: const Color(0xFF5F5F5F),
          width: 1,
        ),
      ),
    );
  }

  Widget _buildDotsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _buildDot(_currentPage == 0),
        _buildDot(_currentPage == 1),
        _buildDot(_currentPage == 2),
      ],
    );
  }

  Widget _buildPage({
    required String imageAsset,
    required String text,
    required int index,
    required bool last,
  }) {
    final screenHeight = MediaQuery.of(context).size.height;
    final imageSectionHeight = screenHeight * 0.60;
    final cardSectionHeight = screenHeight * 0.45;

    return Stack(
      children: [
        SizedBox(
          height: imageSectionHeight,
          width: double.infinity,
          child: Image.asset(
            imageAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: cardSectionHeight,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: cardBackground,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(50),
                topRight: Radius.circular(50),
              ),
            ),
            padding: const EdgeInsets.only(
              top: 40,
              left: 30,
              right: 30,
              bottom: 80,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'AIN EL BALAD',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B6B6B),
                    height: 1.4,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 125,
          left: 0,
          right: 0,
          child: _buildDotsRow(),
        ),
        Positioned(
          bottom: 30,
          right: 30,
          child: FloatingActionButton(
            onPressed: () {
              if (last) {
                Navigator.pushReplacement(
                  context,
                  _instantRoute(const LoginScreen()),
                );
              } else {
                _controller.nextPage(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOut,
                );
              }
            },
            backgroundColor: const Color(0xFFEAEAEA),
            elevation: 0,
            shape: const CircleBorder(
              side: BorderSide(color: primaryOrange, width: 3),
            ),
            child: const Icon(
              Icons.arrow_forward,
              color: primaryOrange,
              size: 28,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _controller,
        onPageChanged: (index) => setState(() => _currentPage = index),
        children: [
          _buildPage(
            imageAsset: 'assets/onboarding1.png',
            text:
                'Spot and report any local issue easily from broken roads to faulty lighting and help make your neighborhood better with Ain El Balad.',
            index: 0,
            last: false,
          ),
          _buildPage(
            imageAsset: 'assets/onboarding2.png',
            text:
                'Snap, locate, and submit issues in seconds — your report reaches the authorities quickly and easily.',
            index: 1,
            last: false,
          ),
          _buildPage(
            imageAsset: 'assets/onboarding3.png',
            text:
                'Track your report step by step and see real-time updates until the issue is fixed.',
            index: 2,
            last: true,
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// 3. Onboarding Screen 1
// ====================================================================
class OnboardingScreen1 extends StatelessWidget {
  const OnboardingScreen1({super.key});

  static const Color primaryOrange = Color(0xFFFFA500);
  static const Color cardBackground = Color(0xFFEAEAEA);
  static const Color inactiveDotColor = Color(0xFFCACACA);

  Widget _buildDot(bool isActive) {
    const double dotSize = 16.0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      height: dotSize,
      width: dotSize,
      decoration: BoxDecoration(
        color: isActive ? primaryOrange : inactiveDotColor,
        borderRadius: BorderRadius.circular(dotSize / 2),
        border: Border.all(
          color: const Color(0xFF5F5F5F),
          width: 1,
        ),
      ),
    );
  }

  Widget _buildDotsRow(int currentScreen) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _buildDot(currentScreen == 1),
        _buildDot(currentScreen == 2),
        _buildDot(currentScreen == 3),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final imageSectionHeight = screenHeight * 0.60;
    final cardSectionHeight = screenHeight * 0.45;

    return Scaffold(
      body: Stack(
        children: [
          SizedBox(
            height: imageSectionHeight,
            width: double.infinity,
            child: Image.asset(
              "assets/onboarding1.png",
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: cardSectionHeight,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: cardBackground,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(50),
                  topRight: Radius.circular(50),
                ),
              ),
              padding: const EdgeInsets.only(
                  top: 40, left: 30, right: 30, bottom: 80),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'AIN EL BALAD',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 18),
                  Text(
                    "Spot and report any local issue easily from broken roads to faulty lighting and help make your neighborhood better with Ain El Balad.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B6B6B),
                      height: 1.4,
                    ),
                  ),
                  Spacer(),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 125,
            left: 0,
            right: 0,
            child: _buildDotsRow(1),
          ),
          Positioned(
            bottom: 30,
            right: 30,
            child: FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(_instantRoute(const OnboardingScreen2()));
              },
              backgroundColor: const Color(0xFFEAEAEA),
              elevation: 0,
              shape: const CircleBorder(
                side: BorderSide(color: primaryOrange, width: 3),
              ),
              child: const Icon(
                Icons.arrow_forward,
                color: primaryOrange,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// 3. Onboarding Screen 2
// ====================================================================
class OnboardingScreen2 extends StatelessWidget {
  const OnboardingScreen2({super.key});

  static const Color primaryOrange = Color(0xFFFFA500);
  static const Color cardBackground = Color(0xFFEAEAEA);
  static const Color inactiveDotColor = Color(0xFFCACACA);

  Widget _buildDot(bool isActive) {
    const double dotSize = 16.0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      height: dotSize,
      width: dotSize,
      decoration: BoxDecoration(
        color: isActive ? primaryOrange : inactiveDotColor,
        borderRadius: BorderRadius.circular(dotSize / 2),
        border: Border.all(
          color: const Color(0xFF5F5F5F),
          width: 1,
        ),
      ),
    );
  }

  Widget _buildDotsRow(int currentScreen) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _buildDot(currentScreen == 1),
        _buildDot(currentScreen == 2),
        _buildDot(currentScreen == 3),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final imageSectionHeight = screenHeight * 0.60;
    final cardSectionHeight = screenHeight * 0.45;

    return Scaffold(
      body: Stack(
        children: [
          // ======= صورة من ملفات المشروع =======
          SizedBox(
            height: imageSectionHeight,
            width: double.infinity,
            child: Image.asset(
              "assets/onboarding2.png",
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: cardSectionHeight,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: cardBackground,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(50),
                  topRight: Radius.circular(50),
                ),
              ),
              padding: const EdgeInsets.only(
                  top: 40, left: 30, right: 30, bottom: 80),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'AIN EL BALAD',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                        height: 1.2),
                  ),
                  SizedBox(height: 18),
                  Text(
                    "Snap, locate, and submit issues in seconds — your report reaches the authorities quickly and easily.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B6B6B),
                        height: 1.4),
                  ),
                  Spacer(),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 125,
            left: 0,
            right: 0,
            child: _buildDotsRow(2),
          ),
          Positioned(
            bottom: 30,
            right: 30,
            child: FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(_instantRoute(const OnboardingScreen3()));
              },
              backgroundColor: const Color(0xFFEAEAEA),
              elevation: 0,
              shape: const CircleBorder(
                side: BorderSide(color: primaryOrange, width: 3),
              ),
              child: const Icon(Icons.arrow_forward,
                  color: primaryOrange, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// 4. Onboarding Screen 3 → الانتقال للـ Login
// ====================================================================

class OnboardingScreen3 extends StatelessWidget {
  const OnboardingScreen3({super.key});

  static const Color primaryOrange = Color(0xFFFFA500);
  static const Color cardBackground = Color(0xFFEAEAEA);
  static const Color inactiveDotColor = Color(0xFFCACACA);

  Widget _buildDot(bool isActive) {
    const double dotSize = 16.0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      height: dotSize,
      width: dotSize,
      decoration: BoxDecoration(
        color: isActive ? primaryOrange : inactiveDotColor,
        borderRadius: BorderRadius.circular(dotSize / 2),
        border: Border.all(
          color: const Color(0xFF5F5F5F),
          width: 1,
        ),
      ),
    );
  }

  Widget _buildDotsRow(int currentScreen) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _buildDot(currentScreen == 1),
        _buildDot(currentScreen == 2),
        _buildDot(currentScreen == 3),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final imageSectionHeight = screenHeight * 0.60;
    final cardSectionHeight = screenHeight * 0.45;

    return Scaffold(
      body: Stack(
        children: [
          // ======= صورة من ملفات المشروع =======
          SizedBox(
            height: imageSectionHeight,
            width: double.infinity,
            child: Image.asset(
              "assets/onboarding3.png",
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: cardSectionHeight,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: cardBackground,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(50),
                  topRight: Radius.circular(50),
                ),
              ),
              padding: const EdgeInsets.only(
                  top: 40, left: 30, right: 30, bottom: 80),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'AIN EL BALAD',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                        height: 1.2),
                  ),
                  SizedBox(height: 18),
                  Text(
                    "Track your report step by step and see real-time updates until the issue is fixed.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B6B6B),
                        height: 1.4),
                  ),
                  Spacer(),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 125,
            left: 0,
            right: 0,
            child: _buildDotsRow(3),
          ),
          Positioned(
            bottom: 30,
            right: 30,
            child: FloatingActionButton(
              onPressed: () {
                Navigator.pushReplacement(context, _instantRoute(const LoginScreen()));
              },
              backgroundColor: const Color(0xFFEAEAEA),
              elevation: 0,
              shape: const CircleBorder(
                side: BorderSide(color: primaryOrange, width: 2),
              ),
              child: const Icon(Icons.arrow_forward,
                  color: primaryOrange, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}

// ================== Login Screen ==================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const double fsTitle = 24; // Login title
  static const double fsSubtitle = 14; // Welcome text
  static const double fsLabel = 16; // Field labels (Email/Password)
  static const double fsHint = 16.5; // Field hint text
  static const double fsLink = 16; // Forget Password link
  static const double fsButton = 20; // Log In button text
  static const double fsDivider = 17; // "Or Login with"
  static const double fsBottom = 16; // Bottom account text

  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  Future<void> _login() async {
    if (_email.text.trim().isEmpty || _password.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await http.post(
        Uri.parse(ApiConfig.login),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': _email.text.trim(),
          'password': _password.text.trim(),
        }),
      );

      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        final body = jsonDecode(res.body);
        final token = _extractToken(body);
        if (token != null && token.isNotEmpty) {
          await AppSession.saveAuth(token: token, email: _email.text.trim());
        }
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login failed')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server unreachable')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _extractToken(dynamic body) {
    if (body is! Map<String, dynamic>) return null;
    final direct = body['token']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      final t = data['token']?.toString() ?? data['access_token']?.toString();
      if (t != null && t.isNotEmpty) return t;
    }
    return body['access_token']?.toString();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenHeight = MediaQuery.of(context).size.height;
            double vs(double px) {
              final val = px * (screenHeight / 812);
              return val.clamp(px * 0.7, px * 1.3);
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: vs(22)),
                      const Center(
                        child: Text(
                          'Login Account',
                          style: TextStyle(
                            fontSize: fsTitle, // Login title
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF044A8D),
                          ),
                        ),
                      ),
                      SizedBox(height: vs(8)),
                      const Text(
                        'Welcome Back!',
                        style: TextStyle(
                            fontSize: fsSubtitle, fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: vs(62)),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Email Address',
                            style: TextStyle(
                                fontSize: fsLabel,
                                fontWeight: FontWeight.w600)),
                      ),
                      SizedBox(height: vs(4)),
                      TextField(
                        controller: _email,
                        decoration: _inputDecoration('Enter email address', fsHint),
                      ),
                      SizedBox(height: vs(32)),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Password',
                            style: TextStyle(
                                fontSize: fsLabel,
                                fontWeight: FontWeight.w600)),
                      ),
                      SizedBox(height: vs(4)),
                      TextField(
                        controller: _password,
                        obscureText: _obscure,
                        decoration: _inputDecoration('Password', fsHint).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                                _obscure ? Icons.visibility_off : Icons.visibility),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      SizedBox(height: vs(8)),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordScreen()),
                            );
                          },
                          child: const Text(
                            'Forget Password?',
                            style: TextStyle(
                              fontSize: fsLink, // Forget Password link
                              color: Color(0xFF044A8D),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: vs(68)),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFA500),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _loading
                              ? const CircularProgressIndicator(color: Colors.black)
                              : const Text(
                                  'Log In',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: fsButton, // Log In button text
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(height: vs(73)),
                      const Row(
                        children: [
                          Expanded(child: Divider(color: Color(0xFF9A9A9A))),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              'Or Login with',
                              style: TextStyle(
                                fontSize: fsDivider, // "Or Login with"
                                color: Color(0xFF666666),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Color(0xFF9A9A9A))),
                        ],
                      ),
                      SizedBox(height: vs(28)),
                      _SocialIconsRow(
                        onFacebookTap: () => _runSocialLogin(
                          context,
                          signIn: _signInWithFacebook,
                        ),
                        onGoogleTap: () => _runSocialLogin(
                          context,
                          signIn: _signInWithGoogle,
                        ),
                      ),
                      SizedBox(height: vs(20)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Don\u2019t have an account? ",
                            style: TextStyle(
                                fontSize: fsBottom,
                                fontWeight: FontWeight.w600),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const StyledSignUpScreen()),
                              );
                            },
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(
                                color: Color(0xFF044A8D),
                                fontSize: fsBottom, // Sign Up link
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: vs(16)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SocialIconsRow extends StatelessWidget {
  final VoidCallback? onFacebookTap;
  final VoidCallback? onGoogleTap;

  const _SocialIconsRow({
    this.onFacebookTap,
    this.onGoogleTap,
  });

  @override
  Widget build(BuildContext context) {
    const double iconBox = 59;
    const double fbIconSize = 59;
    const double googleIconSize = 59;
    const double gap = 28;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onFacebookTap,
          child: SizedBox(
            width: iconBox,
            height: iconBox,
            child: Center(
              child: SvgPicture.asset(
                'assets/icons/facebook_logo.svg',
                width: fbIconSize,
                height: fbIconSize,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(width: gap),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onGoogleTap,
          child: SizedBox(
            width: iconBox,
            height: iconBox,
            child: Center(
              child: SvgPicture.asset(
                'assets/icons/google_logo.svg',
                width: googleIconSize,
                height: googleIconSize,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

InputDecoration _inputDecoration(String hint, double hintSize) {
  return InputDecoration(
    filled: true,
    fillColor: const Color(0xFFF3F3F3),
    hintText: hint,
    hintStyle: TextStyle(color: const Color(0xFFA0A0A0), fontSize: hintSize), // Field hint
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade500, width: 1.8),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade500, width: 1.8),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF044A8D), width: 2),
    ),
  );
}

// ------------------- SIGNUP SCREEN -------------------
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // Controllers
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController birthDateController = TextEditingController();

  bool hidePassword1 = true;
  bool hidePassword2 = true;
  bool agreePrivacy = false;
  bool _passwordTouched = false;

  @override
  void initState() {
    super.initState();
    passwordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    if (!_passwordTouched && passwordController.text.isNotEmpty) {
      setState(() => _passwordTouched = true);
      return;
    }
    setState(() {});
  }
  
  @override
void dispose() {
  firstNameController.dispose();
  lastNameController.dispose();
  phoneController.dispose();           // 👈 مهم
  emailController.dispose();
  birthDateController.dispose();      // 👈 مهم
  passwordController.dispose();
  confirmPasswordController.dispose();
  super.dispose();
}

  bool _hasMinLength(String v) => v.length >= 8;
  bool _hasUppercase(String v) => RegExp(r'[A-Z]').hasMatch(v);
  bool _hasNumber(String v) => RegExp(r'\d').hasMatch(v);
  bool _hasSpecial(String v) => RegExp(r'[*&#@]').hasMatch(v);

  bool _allRulesPassed(String v) =>
      _hasMinLength(v) && _hasUppercase(v) && _hasNumber(v) && _hasSpecial(v);

  Color _ruleColor(bool passed, String value) {
    if (!_passwordTouched || value.isEmpty) {
      return Colors.grey;
    }
    return passed ? Colors.green : Colors.red;
  }

  // ====== SIGN UP FUNCTION ======
  Future<void> signUp() async {
    final url = Uri.parse(
        "https://deanne-thoughtless-extendedly.ngrok-free.dev/api/user/register");

    try {
      final firstName = firstNameController.text.trim();
      final lastName = lastNameController.text.trim();
      final phone = phoneController.text.trim();
      final email = emailController.text.trim();
      final dateOfBirth = birthDateController.text.trim();
      final password = passwordController.text.trim();
      final confirmPassword = confirmPasswordController.text.trim();

      if (firstName.isEmpty ||
          lastName.isEmpty ||
          phone.isEmpty ||
          email.isEmpty ||
          dateOfBirth.isEmpty ||
          password.isEmpty ||
          confirmPassword.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please fill all required fields"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "first_name": firstName,
          "last_name": lastName,
          "phone": phone,
          "email": email,
          "date_of_birth": dateOfBirth,
          "password": password,
          "password_confirmation": confirmPassword,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print("Verification Code: ${data['verification_code']}");
        print("✅ Sign Up Success: $data");
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerifyScreen(email: email),
          ),
        );
      } else {
        print("❌ Sign Up Failed: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Sign Up Failed ❌"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Something went wrong ❌"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.05;
    final pwd = passwordController.text;
    final pwdBorderColor = !_passwordTouched || pwd.isEmpty
        ? Colors.grey
        : (_allRulesPassed(pwd) ? Colors.green : Colors.red);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4, bottom: 20),
                child: Text(
                  "Create Account",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff044a8d)),
                ),
              ),
              // ===== First Name =====
              TextField(
                controller: firstNameController,
                decoration: InputDecoration(
                  hintText: "First Name",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                ),
              ),
              const SizedBox(height: 8),
              // ===== Last Name =====
              TextField(
                controller: lastNameController,
                decoration: InputDecoration(
                  hintText: "Last Name",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                ),
              ),
              const SizedBox(height: 8),
              // ===== Email =====
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  hintText: "Email",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                ),
              ),
              const SizedBox(height: 8),
              // ===== Password =====
              TextField(
                controller: passwordController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: pwdBorderColor)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: pwdBorderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: pwdBorderColor, width: 2),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  suffixIcon: IconButton(
                    icon: Icon(hidePassword1
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setState(() => hidePassword1 = !hidePassword1),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    Text(
                      "Minimum 8 characters",
                      style: TextStyle(
                        fontSize: 12.5,
                        color: _ruleColor(_hasMinLength(pwd), pwd),
                      ),
                    ),
                    Text(
                      "At least one uppercase letter",
                      style: TextStyle(
                        fontSize: 12.5,
                        color: _ruleColor(_hasUppercase(pwd), pwd),
                      ),
                    ),
                    Text(
                      "At least one number",
                      style: TextStyle(
                        fontSize: 12.5,
                        color: _ruleColor(_hasNumber(pwd), pwd),
                      ),
                    ),
                    Text(
                      "At least one special character(*&#@)",
                      style: TextStyle(
                        fontSize: 12.5,
                        color: _ruleColor(_hasSpecial(pwd), pwd),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // ===== Confirm Password =====
              TextField(
                controller: confirmPasswordController,
                obscureText: hidePassword2,
                decoration: InputDecoration(
                  hintText: "Confirm Password",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  suffixIcon: IconButton(
                    icon: Icon(hidePassword2
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setState(() => hidePassword2 = !hidePassword2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // ===== Checkbox =====
              Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: agreePrivacy,
                      onChanged: (v) =>
                          setState(() => agreePrivacy = v ?? false),
                      activeColor: const Color(0xff044a8d),
                      side: const BorderSide(
                          color: Color(0xff044a8d), width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "I agree with privacy policy",
                    style: TextStyle(fontSize: 16, color: Color(0xff044a8d)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // ===== Sign Up Button =====
              Center(
                child: SizedBox(
                  width: 343,
                  height: 48,
                  child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFA500),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: signUp,
                  child: const Text(
                    "Sign Up",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff000000)),
                  ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              // ===== Or Login with =====
              Row(
                children: const [
                  Expanded(child: Divider()),
                  Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text("Or Login with")),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
              // ===== Social Icons =====
              _SocialIconsRow(
                onFacebookTap: () => _runSocialLogin(
                  context,
                  signIn: _signInWithFacebook,
                ),
                onGoogleTap: () => _runSocialLogin(
                  context,
                  signIn: _signInWithGoogle,
                ),
              ),
              const SizedBox(height: 25),
              // ===== Already Have Account =====
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already Have An Account? ",
                      style: TextStyle(fontSize: 16, color: Colors.black)),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                    child: const Text("Log in",
                        style: TextStyle(
                            fontSize: 16,
                            color: Color(0xff044a8d),
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

// ================== Forgot Password Screen ==================
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController emailController = TextEditingController();
  bool isLoading = false;

  // دالة لإرسال طلب إعادة تعيين كلمة المرور
  Future<void> sendForgotPassword() async {
    final url = Uri.parse(
        "https://deanne-thoughtless-extendedly.ngrok-free.dev/api/user/password/forgot");

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": emailController.text.trim()}),
      );

      setState(() => isLoading = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print("✅ Forgot Password Success: $data");

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Reset code sent successfully ✅"),
            backgroundColor: Colors.green,
          ),
        );

        // التوجيه للشاشة التالية بعد إرسال الكود
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VerificationScreen(email: emailController.text),
          ),
        );
      } else {
        final data = jsonDecode(response.body);
        print("❌ Forgot Password Failed: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? "Failed to send reset code ❌"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      print("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Something went wrong ❌"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xff1e88e5);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: const Text(
                'Forgot Password?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF004E98),
                ),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: const Text(
                "No worries, we'll send you reset instructions.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Image.network(
                'https://i.ibb.co/Df7cw7HH/IMG.jpg',
                height: 250,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'Email Address',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'Enter email address',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(
                    color: Colors.grey.shade400,
                    width: 1.0,
                  ),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 16.0, horizontal: 15.0),
              ),
            ),
            const SizedBox(height: 60),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: isLoading ? null : sendForgotPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFA500),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 5,
                ),
                child: isLoading
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                      )
                    : const Text(
                        'Send Code',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================== Verification Screen ==================
class VerificationScreen extends StatefulWidget {
  final String email;

  const VerificationScreen({Key? key, required this.email}) : super(key: key);

  @override
  _VerificationScreenState createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final String imageUrl = 'https://i.ibb.co/k6r6BNW1/IMG.jpg';
  final List<TextEditingController> _otpControllers =
      List.generate(4, (_) => TextEditingController());
  bool _isLoading = false;

  // دالة التحقق من الكود
  Future<void> verifyCode() async {
    String code = _otpControllers.map((c) => c.text.trim()).join();

    if (code.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the 4-digit code")),
      );
      return;
    }

    setState(() => _isLoading = true);

    final url = Uri.parse(
      'https://deanne-thoughtless-extendedly.ngrok-free.dev/api/user/password/verify',
    );

    try {
      // إرسال الإيميل والكود مع بعض للـ Backend
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "email": widget.email,
          "code": code,
        }),
      );

      print("Status code: ${response.statusCode}");
      print("Body: ${response.body}");

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // نجاح التحقق، خذ reset_token من السيرفر
        final resetToken = data['reset_token'] ?? code;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(
              email: widget.email,
              token: resetToken,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? "Verification failed")),
        );
      }
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Something went wrong")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    for (var c in _otpControllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            const SizedBox(height: 16),
            const Text(
              'Verification',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xff1e3a8a),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter the code to continue',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Image.network(imageUrl, height: 250, fit: BoxFit.contain),
            const SizedBox(height: 32),
            const Text('We sent a code to',
                style: TextStyle(fontSize: 16, color: Colors.black),
                textAlign: TextAlign.center),
            Text(widget.email,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
                textAlign: TextAlign.center),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                4,
                (index) => OtpInput(controller: _otpControllers[index]),
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {},
              child: const Text(
                "Didn't receive the code? Send Again",
                style: TextStyle(
                  color: Color(0xff1e3a8a),
                  decoration: TextDecoration.underline,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : verifyCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFA500),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 5,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text(
                        'Continue',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OtpInput extends StatelessWidget {
  final TextEditingController controller;

  const OtpInput({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      width: 60,
      child: TextField(
        controller: controller,
        onChanged: (value) {
          if (value.length == 1) FocusScope.of(context).nextFocus();
        },
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        decoration: InputDecoration(
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: const BorderSide(color: Colors.grey)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: const BorderSide(color: Colors.grey)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: const BorderSide(color: Color(0xFFFFA500), width: 2)),
        ),
      ),
    );
  }
}

// ================== Reset Password Screen ==================
class ResetPasswordScreen extends StatefulWidget {
  final String email;
  final String token;

  const ResetPasswordScreen({
    Key? key,
    required this.email,
    required this.token,
  }) : super(key: key);

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _passwordTouched = false;

  static const Color primaryBlue = Color(0xFF2B5B91);
  static const Color primaryOrange = Color(0xFFFFA500);

  @override
  void initState() {
    super.initState();
    passwordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    if (!_passwordTouched && passwordController.text.isNotEmpty) {
      setState(() => _passwordTouched = true);
      return;
    }
    setState(() {});
  }

  bool _hasMinLength(String v) => v.length >= 8;
  bool _hasUppercase(String v) => RegExp(r'[A-Z]').hasMatch(v);
  bool _hasNumber(String v) => RegExp(r'\d').hasMatch(v);
  bool _hasSpecial(String v) => RegExp(r'[*&#@]').hasMatch(v);

  bool _allRulesPassed(String v) =>
      _hasMinLength(v) && _hasUppercase(v) && _hasNumber(v) && _hasSpecial(v);

  Color _ruleColor(bool passed, String value) {
    if (!_passwordTouched || value.isEmpty) {
      return Colors.grey;
    }
    return passed ? Colors.green : Colors.red;
  }

  Future<void> resetPassword() async {
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    setState(() => _isLoading = true);

    final url = Uri.parse(
      'https://deanne-thoughtless-extendedly.ngrok-free.dev/api/user/password/reset',
    );

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "email": widget.email,
          "token": widget.token,
          "password": password,
          "password_confirmation": confirmPassword,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Password reset successfully ✅"),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? "Reset failed ❌")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Something went wrong ❌")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pwd = passwordController.text;
    final pwdBorderColor = !_passwordTouched || pwd.isEmpty
        ? Colors.grey
        : (_allRulesPassed(pwd) ? Colors.green : Colors.red);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 20),

            /// Title
            Text(
              'Set New Password',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: primaryBlue,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Create an unique password',
              style: TextStyle(fontSize: 14),
            ),

            const SizedBox(height: 25),

            /// Image
            Image.asset(
              "assets/reset_password.png",
              height: 220,
            ),

            const SizedBox(height: 30),

            /// Password
            const FieldLabel('Password'),
            const SizedBox(height: 8),
            CustomFormField(
              controller: passwordController,
              hint: 'Enter New password',
              isPassword: true,
              isVisible: _isPasswordVisible,
              borderColor: pwdBorderColor,
              onToggleVisibility: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  Text(
                    "Minimum 8 characters",
                    style: TextStyle(
                      fontSize: 12.5,
                      color: _ruleColor(_hasMinLength(pwd), pwd),
                    ),
                  ),
                  Text(
                    "At least one uppercase letter",
                    style: TextStyle(
                      fontSize: 12.5,
                      color: _ruleColor(_hasUppercase(pwd), pwd),
                    ),
                  ),
                  Text(
                    "At least one number",
                    style: TextStyle(
                      fontSize: 12.5,
                      color: _ruleColor(_hasNumber(pwd), pwd),
                    ),
                  ),
                  Text(
                    "At least one special character(*&#@)",
                    style: TextStyle(
                      fontSize: 12.5,
                      color: _ruleColor(_hasSpecial(pwd), pwd),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            /// Confirm Password
            const FieldLabel('Confirm Password'),
            const SizedBox(height: 8),
            CustomFormField(
              controller: confirmPasswordController,
              hint: 'Enter password Again',
              isPassword: true,
              isVisible: _isConfirmPasswordVisible,
              onToggleVisibility: () {
                setState(() {
                  _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                });
              },
            ),

            const SizedBox(height: 30),

            /// Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : resetPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryOrange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text(
                        'Reset Password',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            GestureDetector(
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: Text(
                'Back to log in',
                style: TextStyle(
                  color: primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
class OtpCircleField extends StatelessWidget {
  const OtpCircleField({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF5F5F5F),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: const TextField(
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          counterText: "",
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isCollapsed: true,
        ),
      ),
    );
  }
}

class OtpVerifyScreen extends StatefulWidget {
  final String email;

  const OtpVerifyScreen({
    super.key,
    required this.email,
  });

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final TextEditingController _otp1Controller = TextEditingController();
  final TextEditingController _otp2Controller = TextEditingController();
  final TextEditingController _otp3Controller = TextEditingController();
  final TextEditingController _otp4Controller = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _otp1Controller.dispose();
    _otp2Controller.dispose();
    _otp3Controller.dispose();
    _otp4Controller.dispose();
    super.dispose();
  }

  Future<void> _verifyEmail() async {
    final code = [
      _otp1Controller.text.trim(),
      _otp2Controller.text.trim(),
      _otp3Controller.text.trim(),
      _otp4Controller.text.trim(),
    ].join();

    if (code.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 4-digit code')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.verifyEmail),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': widget.email,
          'code': code,
          'verification_code': code,
        }),
      );

      if (!mounted) return;

      dynamic data;
      if (response.body.isNotEmpty) {
        try {
          data = jsonDecode(response.body);
        } catch (_) {
          data = null;
        }
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        await AppSession.clear();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        final message = data is Map<String, dynamic>
            ? (data['message']?.toString() ?? 'Verification failed')
            : 'Verification failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verify failed: ${response.statusCode} $message')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verify error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _digitField(TextEditingController controller) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF5F5F5F),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        decoration: const InputDecoration(
          counterText: "",
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isCollapsed: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: SizedBox(
                  width: 343,
                  height: 365,
                  child: Image.asset(
                    'assets/otp_image.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      const Text(
                        "To keep your account secure and verify your\nemail, We've sent a 4-digit OTP code",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          letterSpacing: 0.15,
                          color: Color(0xFF000000),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "to ${widget.email}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          letterSpacing: 0.15,
                          color: Color(0xFF000000),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: SizedBox(
                  width: 343,
                  height: 60,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _digitField(_otp1Controller),
                      _digitField(_otp2Controller),
                      _digitField(_otp3Controller),
                      _digitField(_otp4Controller),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF000000),
                    ),
                    children: [
                      TextSpan(text: "Didn't receive email? "),
                      TextSpan(
                        text: "Resend OTP",
                        style: TextStyle(
                          color: Color(0xFF004E98),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 343,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFA500),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          "Verify",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF000000),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ================== Helpers ==================
class FieldLabel extends StatelessWidget {
  final String label;
  const FieldLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class CustomFormField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool isPassword;
  final bool isVisible;
  final VoidCallback? onToggleVisibility;
  final Color? borderColor;

  const CustomFormField({
    super.key,
    required this.controller,
    required this.hint,
    this.isPassword = false,
    this.isVisible = false,
    this.onToggleVisibility,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? !isVisible : false,
      decoration: InputDecoration(
        hintText: hint,
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  isVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.grey,
                ),
                onPressed: onToggleVisibility,
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor ?? Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor ?? Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: borderColor ?? _ResetPasswordScreenState.primaryBlue,
            width: 2,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class StyledSignUpScreen extends StatefulWidget {
  const StyledSignUpScreen({super.key});

  @override
  State<StyledSignUpScreen> createState() => _StyledSignUpScreenState();
}

class _StyledSignUpScreenState extends State<StyledSignUpScreen> {
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController birthDateController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  DateTime? _selectedBirthDate;

  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  bool _agreedToPolicy = false;
  bool _passwordTouched = false;

  @override
  void initState() {
    super.initState();
    passwordController.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    birthDateController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _onPasswordChanged() {
    if (!_passwordTouched && passwordController.text.isNotEmpty) {
      setState(() => _passwordTouched = true);
      return;
    }
    setState(() {});
  }

  bool _hasMinLength(String v) => v.length >= 8;
  bool _hasUppercase(String v) => RegExp(r'[A-Z]').hasMatch(v);
  bool _hasNumber(String v) => RegExp(r'\d').hasMatch(v);
  bool _hasSpecial(String v) => RegExp(r'[*&#@]').hasMatch(v);

  bool _allRulesPassed(String v) =>
      _hasMinLength(v) && _hasUppercase(v) && _hasNumber(v) && _hasSpecial(v);

  Color _ruleColor(bool passed, String value) {
    if (!_passwordTouched || value.isEmpty) {
      return Colors.grey;
    }
    return passed ? Colors.green : Colors.red;
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _formatApiDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _pickBirthDate() async {
    FocusScope.of(context).unfocus();

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (selectedDate != null) {
      setState(() {
        _selectedBirthDate = selectedDate;
        birthDateController.text = _formatDate(selectedDate);
      });
    }
  }

  InputDecoration _fieldDecoration(
    String hint, {
    Color borderColor = const Color(0xFFA0A0A0),
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFFB3B3B3),
        fontSize: 16,
      ),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF044A8D), width: 2.2),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required double width,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
    Color borderColor = const Color(0xFFA0A0A0),
    List<TextInputFormatter>? inputFormatters,
  }) {
    return SizedBox(
      width: width,
      height: 48,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        readOnly: readOnly,
        onTap: onTap,
        inputFormatters: inputFormatters,
        style: const TextStyle(fontSize: 16, color: Colors.black),
        decoration: _fieldDecoration(
          hint,
          borderColor: borderColor,
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  Future<void> signUp() async {
    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final phone = phoneController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();
    final dateOfBirth = _selectedBirthDate != null
        ? _formatApiDate(_selectedBirthDate!)
        : birthDateController.text.trim();

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        phone.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty ||
        dateOfBirth.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all required fields"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password confirmation does not match"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final response = await http.post(
      Uri.parse(ApiConfig.register),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: jsonEncode({
        "first_name": firstName,
        "last_name": lastName,
        "phone": phone,
        "email": email,
        "date_of_birth": dateOfBirth,
        "password": password,
        "password_confirmation": confirmPassword,
      }),
    );

    if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
      if (!mounted) return;
      final data = jsonDecode(response.body);
      print("Verification Code: ${data['verification_code']}");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerifyScreen(email: email),
        ),
      );
    } else {
      print("Sign Up Failed: ${response.statusCode} ${response.body}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Sign Up Failed: ${response.statusCode} ${response.body}",
            maxLines: 3,
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fieldWidth = math.min(MediaQuery.of(context).size.width - 32, 343.0);
    final pwd = passwordController.text;
    final pwdBorderColor = !_passwordTouched || pwd.isEmpty
        ? const Color(0xFFA0A0A0)
        : (_allRulesPassed(pwd) ? Colors.green : Colors.red);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.arrow_back, size: 28),
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  "Create Account",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF044A8D),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _buildField(
                controller: firstNameController,
                hint: "Enter First Name",
                width: fieldWidth,
              ),
              const SizedBox(height: 10),
              _buildField(
                controller: lastNameController,
                hint: "Enter Last Name",
                width: fieldWidth,
              ),
              const SizedBox(height: 10),
              _buildField(
                controller: phoneController,
                hint: "Enter Phone Number",
                width: fieldWidth,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 10),
              _buildField(
                controller: emailController,
                hint: "Enter Email address",
                width: fieldWidth,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              _buildField(
                controller: birthDateController,
                hint: "DD\\MM\\YYY",
                width: fieldWidth,
                readOnly: true,
                onTap: _pickBirthDate,
              ),
              const SizedBox(height: 14),
              _buildField(
                controller: passwordController,
                hint: "Password",
                width: fieldWidth,
                obscureText: _hidePassword,
                borderColor: pwdBorderColor,
                suffixIcon: IconButton(
                  icon: Icon(
                    _hidePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey.shade700,
                  ),
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                ),
              ),
              const SizedBox(height: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: (_passwordTouched && pwd.isNotEmpty)
                    ? Column(
                        key: const ValueKey('password_rules_visible'),
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    "Minimum 8 characters",
                                    maxLines: 1,
                                    softWrap: false,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: _ruleColor(_hasMinLength(pwd), pwd),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    "At least one uppercase letter",
                                    maxLines: 1,
                                    softWrap: false,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: _ruleColor(_hasUppercase(pwd), pwd),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    "At least one number",
                                    maxLines: 1,
                                    softWrap: false,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: _ruleColor(_hasNumber(pwd), pwd),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    "At least one special character(*&#@)",
                                    maxLines: 1,
                                    softWrap: false,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: _ruleColor(_hasSpecial(pwd), pwd),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : const SizedBox.shrink(
                        key: ValueKey('password_rules_hidden'),
                      ),
              ),
              const SizedBox(height: 10),
              _buildField(
                controller: confirmPasswordController,
                hint: "Confirm Password",
                width: fieldWidth,
                obscureText: _hideConfirmPassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _hideConfirmPassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey.shade700,
                  ),
                  onPressed: () => setState(
                      () => _hideConfirmPassword = !_hideConfirmPassword),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Checkbox(
                    value: _agreedToPolicy,
                    onChanged: (value) {
                      setState(() => _agreedToPolicy = value ?? false);
                    },
                    activeColor: const Color(0xFF044A8D),
                    side: const BorderSide(
                      color: Color(0xFF044A8D),
                      width: 1.5,
                    ),
                  ),
                  const Text(
                    "I agree with privacy policy",
                    style: TextStyle(
                      fontSize: 15.5,
                      color: Color(0xFF044A8D),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: signUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFA500),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Sign Up",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: Colors.grey.shade500,
                      thickness: 1,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      "Or Login with",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF555555),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: Colors.grey.shade500,
                      thickness: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SocialIconsRow(
                onFacebookTap: () => _runSocialLogin(
                  context,
                  signIn: _signInWithFacebook,
                ),
                onGoogleTap: () => _runSocialLogin(
                  context,
                  signIn: _signInWithGoogle,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Already Have An Account? ",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                    child: const Text(
                      "Log in",
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF044A8D),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

