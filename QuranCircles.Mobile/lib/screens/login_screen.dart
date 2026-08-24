import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'main_navigation_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController(text: 'admin123');
  bool _isLoading = false;
  String _serverUrl = ApiService.baseUrl;

  void _login() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await ApiService.login(
        _usernameController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MainNavigationScreen(currentUser: user),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ),
      );
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
        title: Text('إعداد رابط الخادم (API)', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: urlController,
          decoration: const InputDecoration(
            hintText: 'مثال: http://10.0.2.2:5070/api أو http://localhost:5070/api',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              ApiService.setBaseUrl(urlController.text.trim());
              setState(() {
                _serverUrl = ApiService.baseUrl;
              });
              Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.accent, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),
                  padding: const EdgeInsets.all(6),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.mosque,
                        size: 52,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'مركز البيان لتعليم القرآن الكريم',
                  style: AppTheme.cairoStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                Text(
                  'مسجد علي بن أبي طالب - نظام الحلقات المتقدم',
                  style: AppTheme.cairoStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 30),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'تسجيل الدخول',
                          style: AppTheme.cairoStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),

                        TextField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: 'اسم المستخدم',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'كلمة المرور',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                        ),
                        const SizedBox(height: 24),

                        ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('دخول النظام'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  'تجربة سريعة للأدوار المختلفة:',
                  style: AppTheme.cairoStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.code, size: 16, color: AppTheme.primary),
                      label: const Text('المطور (dev)'),
                      onPressed: () => _quickFill('dev', 'dev123'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.admin_panel_settings, size: 16, color: AppTheme.primary),
                      label: const Text('المدير (admin)'),
                      onPressed: () => _quickFill('admin', 'admin123'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.verified, size: 16, color: AppTheme.primary),
                      label: const Text('مشرف (wael)'),
                      onPressed: () => _quickFill('wael', 'wael123'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.school, size: 16, color: AppTheme.primary),
                      label: const Text('المعلم (ahmad)'),
                      onPressed: () => _quickFill('ahmad', '123456'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.person, size: 16, color: AppTheme.primary),
                      label: const Text('الطالب (mohammad)'),
                      onPressed: () => _quickFill('mohammad', '123456'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.family_restroom, size: 16, color: AppTheme.primary),
                      label: const Text('ولي الأمر (parent100)'),
                      onPressed: () => _quickFill('parent100', '123456'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                TextButton.icon(
                  onPressed: _showServerConfigModal,
                  icon: const Icon(Icons.settings_remote, size: 16),
                  label: Text(
                    'الخادم الحالي: $_serverUrl',
                    style: AppTheme.cairoStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
