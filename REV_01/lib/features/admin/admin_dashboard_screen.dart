import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../models/admin_dashboard_model.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final service = AdminService();
  bool loading = true;
  Map<String, dynamic>? data;

  @override
  void initState() {
    super.initState();
    service
        .fetchDashboard()
        .then((d) {
          if (!mounted) return;
          setState(() {
            data = d;
            loading = false;
          });
        })
        .catchError((e) {
          if (!mounted) return;
          setState(() {
            loading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load dashboard: $e')),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final summaryMap = data ?? <String, dynamic>{};
    final dashboard = AdminDashboard.fromMap(summaryMap);
    final categorySummary = dashboard.categorySummary;

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _MetricCard('Members', dashboard.totalMembers.toString()),
                _MetricCard(
                  'Trusted Partners',
                  dashboard.totalTrustedPartners.toString(),
                ),
                _MetricCard(
                  'Online R\$',
                  dashboard.totalOnlinePurchases.toStringAsFixed(2),
                ),
                _MetricCard(
                  'In-Store R\$',
                  dashboard.totalInStorePurchases.toStringAsFixed(2),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Online Purchases by Category'),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: categorySummary
                      .map(
                        (e) => PieChartSectionData(
                          value:
                              double.tryParse(
                                (e['total_amount'] ?? '0').toString(),
                              ) ??
                              0,
                          title: e['category']?.toString() ?? '',
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ExpansionPanelList.radio(
              children: categorySummary.map((cat) {
                final catName = cat['category'] as String? ?? 'Unknown';
                final details = dashboard.categoryDetails[catName] ?? [];
                return ExpansionPanelRadio(
                  value: catName,
                  headerBuilder: (context, isExpanded) =>
                      ListTile(title: Text(catName)),
                  body: DataTable(
                    columns: const [
                      DataColumn(label: Text('Product')),
                      DataColumn(label: Text('Quantity')),
                    ],
                    rows: details.map((d) {
                      return DataRow(
                        cells: [
                          DataCell(Text(d['product_name']?.toString() ?? '')),
                          DataCell(Text(d['quantity']?.toString() ?? '0')),
                        ],
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  const _MetricCard(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        width: 80,
        height: 80,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value, style: const TextStyle(fontSize: 18)),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}
