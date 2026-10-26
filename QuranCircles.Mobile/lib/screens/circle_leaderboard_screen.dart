import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class CircleLeaderboardScreen extends StatefulWidget {
  const CircleLeaderboardScreen({super.key});

  @override
  State<CircleLeaderboardScreen> createState() => _CircleLeaderboardScreenState();
}

class _CircleLeaderboardScreenState extends State<CircleLeaderboardScreen> {
  late Future<List<Map<String, dynamic>>> board;

  @override
  void initState() {
    super.initState();
    board = ApiService.getCircleLeaderboard();
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: const Text('صدارة الحلقات'), actions: [
            IconButton(
              onPressed: () => setState(() => board = ApiService.getCircleLeaderboard()),
              icon: const Icon(Icons.refresh),
            )
          ]),
          body: FutureBuilder<List<Map<String, dynamic>>>(
            future: board,
            builder: (context, snapshot) {
              if (!snapshot.hasData && !snapshot.hasError) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('تعذر تحميل الصدارة: ${snapshot.error}'));
              }
              final rows = snapshot.data!;
              if (rows.isEmpty) return const Center(child: Text('لا توجد حلقات نشطة حالياً.'));
              return ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text('${index + 1}')),
                      title: Text(row['circleName']?.toString() ?? '',
                          style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${row['teacherName'] ?? ''} • ${row['studentCount'] ?? 0} طالب'),
                      trailing: Text('${row['overallScore'] ?? 0}',
                          style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    ),
                  );
                },
              );
            },
          ),
        ),
      );
