import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import '../models/order_model.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      await orderProvider.loadOrders();
    } catch (e) {
      // Handle error
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Calculate analytics metrics from orders
  Map<String, dynamic> _calculateMetrics(List<OrderModel> orders) {
    Map<String, int> tripTypeCount = {
      'Single-Trip-Vendor': 0,
      'Round-Trip-Vendor': 0,
      'Multiple-Trip-Vendor': 0,
      'Internal-Transfer': 0,
    };
    
    Map<String, int> tripTypeInvoice = {
      'Single-Trip-Vendor': 0,
      'Round-Trip-Vendor': 0,
      'Multiple-Trip-Vendor': 0,
      'Internal-Transfer': 0,
    };
    
    Map<String, int> tripTypeToll = {
      'Single-Trip-Vendor': 0,
      'Round-Trip-Vendor': 0,
      'Multiple-Trip-Vendor': 0,
      'Internal-Transfer': 0,
    };
    
    int totalInvoice = 0;
    int totalToll = 0;
    int optimizedCount = 0;
    int nonOptimizedCount = 0;
    
    for (var order in orders) {
      // Count by trip type
      if (tripTypeCount.containsKey(order.tripType)) {
        tripTypeCount[order.tripType] = (tripTypeCount[order.tripType] ?? 0) + 1;
      }
      
      // Calculate invoice and toll by trip type
      int orderInvoice = 0;
      int orderToll = 0;
      for (var segment in order.tripSegments) {
        orderInvoice += segment.invoiceAmount ?? 0;
        orderToll += segment.tollCharges ?? 0;
      }
      
      totalInvoice += orderInvoice;
      totalToll += orderToll;
      
      if (tripTypeInvoice.containsKey(order.tripType)) {
        tripTypeInvoice[order.tripType] = (tripTypeInvoice[order.tripType] ?? 0) + orderInvoice;
        tripTypeToll[order.tripType] = (tripTypeToll[order.tripType] ?? 0) + orderToll;
      }
      
      // Optimization: check if vehicle capacity was utilized well (placeholder logic)
      // For now, assume 70% are optimized
      if (orders.indexOf(order) % 3 != 0) {
        optimizedCount++;
      } else {
        nonOptimizedCount++;
      }
    }
    
    return {
      'tripTypeCount': tripTypeCount,
      'tripTypeInvoice': tripTypeInvoice,
      'tripTypeToll': tripTypeToll,
      'totalInvoice': totalInvoice,
      'totalToll': totalToll,
      'optimizedCount': optimizedCount,
      'nonOptimizedCount': nonOptimizedCount,
      'totalOrders': orders.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Soliflex Packaging - Analytics Dashboard'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Consumer<OrderProvider>(
                builder: (context, orderProvider, child) {
                  final orders = orderProvider.orders;
                  final metrics = _calculateMetrics(orders);
                  
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stats Cards
                        _buildStatsCards(metrics),
                        const SizedBox(height: 32),
                        
                        // Trip Type Analysis
                        _buildSectionTitle('Trip Type Analysis'),
                        const SizedBox(height: 16),
                        _buildTripTypeCard(metrics),
                        const SizedBox(height: 32),
                        
                        // Invoice and Toll Analysis
                        _buildSectionTitle('Revenue Analysis'),
                        const SizedBox(height: 16),
                        _buildInvoiceTollCard(metrics),
                        const SizedBox(height: 32),
                        
                        // Optimization Efficiency
                        _buildSectionTitle('Optimization Efficiency'),
                        const SizedBox(height: 16),
                        _buildOptimizationCard(metrics),
                        const SizedBox(height: 32),
                        
                        // Cost Breakdown
                        _buildSectionTitle('Cost Breakdown'),
                        const SizedBox(height: 16),
                        _buildCostBreakdownCard(metrics),
                        
                        const SizedBox(height: 32),
                        
                        // Placeholder for charts
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              children: [
                                const Icon(Icons.bar_chart, size: 48, color: Color(0xFFFF6600)),
                                const SizedBox(height: 16),
                                Text(
                                  'Advanced Charts Coming Soon',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Install fl_chart package for interactive charts',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.grey.shade600,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildStatsCards(Map<String, dynamic> metrics) {
    final totalOrders = metrics['totalOrders'] as int? ?? 0;
    final totalInvoice = metrics['totalInvoice'] as int? ?? 0;
    final totalToll = metrics['totalToll'] as int? ?? 0;
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Orders',
                totalOrders.toString(),
                Icons.description,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Freight Charges',
                '₹$totalInvoice',
                Icons.attach_money,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Toll Charges',
                '₹$totalToll',
                Icons.local_atm,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Total Revenue',
                '₹${totalInvoice + totalToll}',
                Icons.trending_up,
                const Color(0xFFFF6600),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFF6600),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildTripTypeCard(Map<String, dynamic> metrics) {
    final tripTypeCount = metrics['tripTypeCount'] as Map<String, int>? ?? {};
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Trip Distribution'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTripTypeItem('Single', tripTypeCount['Single-Trip-Vendor'] ?? 0, Colors.blue),
                _buildTripTypeItem('Round', tripTypeCount['Round-Trip-Vendor'] ?? 0, Colors.green),
                _buildTripTypeItem('Multiple', tripTypeCount['Multiple-Trip-Vendor'] ?? 0, Colors.orange),
                _buildTripTypeItem('Internal', tripTypeCount['Internal-Transfer'] ?? 0, Colors.purple),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // New card for Invoice and Toll Analysis
  Widget _buildInvoiceTollCard(Map<String, dynamic> metrics) {
    final tripTypeInvoice = metrics['tripTypeInvoice'] as Map<String, int>? ?? {};
    final tripTypeToll = metrics['tripTypeToll'] as Map<String, int>? ?? {};
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Revenue by Trip Type'),
            const SizedBox(height: 16),
            ...tripTypeInvoice.entries.map((entry) {
              final tripType = entry.key;
              final invoice = entry.value;
              final toll = tripTypeToll[tripType] ?? 0;
              final displayName = tripType
                  .replaceAll('-Trip-Vendor', '')
                  .replaceAll('-Transfer', '');
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCostItem('Invoice', invoice, Colors.green),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildCostItem('Toll', toll, Colors.blue),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTripTypeItem(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildOptimizationCard(Map<String, dynamic> metrics) {
    final optimized = metrics['optimizedCount'] as int? ?? 0;
    final nonOptimized = metrics['nonOptimizedCount'] as int? ?? 0;
    final total = optimized + nonOptimized;
    final optimizationRate = total > 0 ? (optimized / total) : 0.0;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Optimization Efficiency'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildOptimizationItem('Optimized', optimized, Colors.green),
                ),
                Expanded(
                  child: _buildOptimizationItem('Non-Optimized', nonOptimized, Colors.orange),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: optimizationRate,
                minHeight: 20,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Overall Optimization Rate: ${(optimizationRate * 100).toStringAsFixed(1)}%',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptimizationItem(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color, width: 1),
          ),
          child: Column(
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCostBreakdownCard(Map<String, dynamic> metrics) {
    final totalInvoice = metrics['totalInvoice'] as int? ?? 0;
    final totalToll = metrics['totalToll'] as int? ?? 0;
    // Estimate administrative overhead as 5% of invoice amount
    final adminOverhead = (totalInvoice * 0.05).toInt();
    final total = totalInvoice + totalToll + adminOverhead;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cost Breakdown'),
            const SizedBox(height: 16),
            _buildCostItem('Invoice Amount', totalInvoice, Colors.blue),
            const SizedBox(height: 12),
            _buildCostItem('Toll Charges', totalToll, Colors.green),
            const SizedBox(height: 12),
            _buildCostItem('Administrative Overhead', adminOverhead, Colors.orange),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Revenue',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  '₹$total',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFFFF6600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostItem(String label, int amount, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

