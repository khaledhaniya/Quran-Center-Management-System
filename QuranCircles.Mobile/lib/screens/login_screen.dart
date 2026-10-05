import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'main_navigation_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String? _errorMessage;
  String _serverUrl = ApiService.baseUrl;
  String _centerName = 'مركز البيان لتعليم القرآن الكريم';
  String _mosqueName = 'مسجد علي بن أبي طالب';
  bool _showDemoAccounts = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _animController.forward();
    _fetchCenterSettings();
  }

  @override
  void dispose() {
    _animController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _fetchCenterSettings() async {
    try {
      final s = await ApiService.getSystemSettings();
      if (s != null && mounted) {
        setState(() {
          if (s['centerName'] != null && s['centerName'].toString().trim().isNotEmpty) {
            _centerName = s['centerName'].toString().trim();
          }
          if (s['mosqueName'] != null && s['mosqueName'].toString().trim().isNotEmpty) {
            _mosqueName = s['mosqueName'].toString().trim();
          }
        });
      }
    } catch (_) {}
  }

  void _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'يرجى إدخال اسم المستخدم وكلمة المرور للمتابعة.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await ApiService.login(username, password);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MainNavigationScreen(currentUser: user),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _quickFill(String user, String pass) {
    _usernameController.text = user;
    _passwordController.text = pass;
    _login();
  }

  void _showServerConfigModal() {
    final urlController = TextEditingController(text: ApiService.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.dns_rounded, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text('إعداد خادم الربط (API)', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('أدخل رابط السيرفر المحلي أو السحابي:', style: AppTheme.cairoStyle(fontSize: 12, color: Colors.grey.shade700)),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                hintText: 'https://albayan-ali-center.tryasp.net/api',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: AppTheme.cairoStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              ApiService.setBaseUrl(urlController.text.trim());
              setState(() {
                _serverUrl = ApiService.baseUrl;
              });
              Navigator.pop(ctx);
            },
            child: Text('حفظ الرابط', style: AppTheme.cairoStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF042114),
      body: Stack(
        children: [
          // Background Islamic Gradient & Motifs
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF02170D),
                    Color(0xFF06331E),
                    Color(0xFF0A442A),
                    Color(0xFF02150C),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // Decorative Top Radial Lights
          Positioned(
            top: -120,
            right: -60,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFD4AF37).withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF10B981).withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main Login Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Luxury Emblem Badge
                      Container(
                        width: 105,
                        height: 105,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE5C07B), Color(0xFF9E7C33), Color(0xFFE5C07B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
                              blurRadius: 28,
                              spreadRadius: 2,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFF062D1C),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(8),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.mosque_rounded,
                                size: 48,
                                color: Color(0xFFE5C07B),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Center Title & Mosque
                      Text(
                        _centerName,
                        textAlign: TextAlign.center,
                        style: AppTheme.cairoStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFF3E5AB),
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              offset: const Offset(0, 2),
                              blurRadius: 6,
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.mosque_outlined, size: 15, color: Color(0xFFD4AF37)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _mosqueName,
                              textAlign: TextAlign.center,
                              style: AppTheme.cairoStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'المنظومة الرقمية الشاملة لإدارة وتحفيظ القرآن الكريم',
                        textAlign: TextAlign.center,
                        style: AppTheme.cairoStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 26),

                      // Login Card (Glassmorphism Luxury Container)
                      Container(
                        constraints: const BoxConstraints(maxWidth: 420),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.5), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.login_rounded, color: AppTheme.primary, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  'تسجيل الدخول للنظام',
                                  style: AppTheme.cairoStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F3E28),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'أدخل اسم المستخدم المعتمد وكلمة المرور الحالية',
                              textAlign: TextAlign.center,
                              style: AppTheme.cairoStyle(
                                fontSize: 11.5,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Error Banner
                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFF87171)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: AppTheme.cairoStyle(
                                          fontSize: 12,
                                          color: const Color(0xFF991B1B),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Username Input Field
                            TextField(
                              controller: _usernameController,
                              textInputAction: TextInputAction.next,
                              style: AppTheme.cairoStyle(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                              decoration: InputDecoration(
                                labelText: 'اسم المستخدم / رقم الهوية',
                                labelStyle: AppTheme.cairoStyle(fontSize: 12, color: Colors.grey.shade700),
                                hintText: 'مثال: ahmad أو 400123456',
                                hintStyle: AppTheme.cairoStyle(fontSize: 12, color: Colors.grey.shade400),
                                prefixIcon: const Icon(Icons.person_rounded, color: AppTheme.primary, size: 22),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Password Input Field with Eye Toggle
                            TextField(
                              controller: _passwordController,
                              obscureText: !_isPasswordVisible,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _login(),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Color(0xFF1E293B)),
                              decoration: InputDecoration(
                                labelText: 'كلمة المرور',
                                labelStyle: AppTheme.cairoStyle(fontSize: 12, color: Colors.grey.shade700),
                                hintText: 'أدخل كلمة المرور الحالية...',
                                hintStyle: AppTheme.cairoStyle(fontSize: 12, color: Colors.grey.shade400),
                                prefixIcon: const Icon(Icons.lock_rounded, color: AppTheme.primary, size: 22),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                    color: _isPasswordVisible ? AppTheme.primary : Colors.grey.shade500,
                                    size: 22,
                                  ),
                                  tooltip: _isPasswordVisible ? 'إخفاء كلمة المرور' : 'إظهار كلمة المرور',
                                  onPressed: () {
                                    setState(() {
                                      _isPasswordVisible = !_isPasswordVisible;
                                    });
                                  },
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),

                            // Submit Button
                            Container(
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF0F5A38), Color(0xFF15803D)],
                                  begin: Alignment.centerRight,
                                  end: Alignment.centerLeft,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0F5A38).withValues(alpha: 0.35),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            'دخول النظام المعتمد',
                                            style: AppTheme.cairoStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Demo Quick-Fill Accordion
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _showDemoAccounts = !_showDemoAccounts;
                          });
                        },
                        icon: Icon(
                          _showDemoAccounts ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          color: const Color(0xFFD4AF37),
                          size: 20,
                        ),
                        label: Text(
                          _showDemoAccounts ? 'إخفاء الحسابات التجريبية' : 'عرض حسابات التجربة السريعة',
                          style: AppTheme.cairoStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFE5C07B),
                          ),
                        ),
                      ),

                      if (_showDemoAccounts) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildQuickChip('المطور', 'dev', 'dev123', Icons.terminal_rounded),
                            _buildQuickChip('المدير', 'admin', 'admin123', Icons.admin_panel_settings_rounded),
                            _buildQuickChip('المعلم', 'ahmad', '123456', Icons.school_rounded),
                            _buildQuickChip('الطالب', 'mohammad', '123456', Icons.person_outline_rounded),
                            _buildQuickChip('ولي الأمر', 'parent100', '123456', Icons.family_restroom_rounded),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Server Connection Config Button
                      GestureDetector(
                        onTap: _showServerConfigModal,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cloud_sync_outlined, size: 14, color: Color(0xFFD4AF37)),
                              const SizedBox(width: 6),
                              Text(
                                'خادم الربط: ${_serverUrl.replaceAll('https://', '').replaceAll('http://', '')}',
                                style: AppTheme.cairoStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.75)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String label, String username, String pass, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, size: 14, color: const Color(0xFF0F5A38)),
      backgroundColor: Colors.white.withValues(alpha: 0.9),
      side: BorderSide(color: const Color(0xFFD4AF37).withValues(alpha: 0.5)),
      label: Text(
        label,
        style: AppTheme.cairoStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF06331E),
        ),
      ),
      onPressed: () => _quickFill(username, pass),
    );
  }
}
