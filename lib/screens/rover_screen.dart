import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

class RoverScreen extends StatelessWidget {
  const RoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'NAWASENA',
          style: TextStyle(
            color: AppTheme.accentGold,
            letterSpacing: 1.2,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700, // Menunjuk ke Poppins Regular
            fontSize: 26,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white70),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pemantauan SENAGARDA Rover',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Kelola pemantauan, status, dan pengoperasian SENAGARDA Rover',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            
            // Deploy Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text('Tambah Rover Baru'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen.withOpacity(0.8),
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Annual Chart
            _buildAnnualChart(),
            const SizedBox(height: 16),
            
            // Fleet Readiness & Actions
            Row(
              children: [
                Expanded(child: _buildFleetReadiness()),
              ],
            ),
            const SizedBox(height: 16),
            Row(

            ),
            const SizedBox(height: 32),
            
            // Registry
            Row(
              children: const [
                Icon(Icons.list, color: Colors.white54, size: 20),
                SizedBox(width: 8),
                Text('ROVER YANG SEDANG AKTIF SAAT INI', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              ],
            ),
            const SizedBox(height: 16),
            
            // Rover Registry from Supabase
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client
                  .from('devices')
                  .stream(primaryKey: ['id'])
                  .eq('type', 'rover')
                  .order('created_at', ascending: true),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  final errStr = snapshot.error.toString();
                  if (errStr.contains('SocketException') || errStr.contains('Failed host lookup')) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: AppTheme.accentGold),
                            SizedBox(height: 16),
                            Text('Menunggu koneksi internet...', style: TextStyle(color: Colors.white54)),
                          ],
                        ),
                      ),
                    );
                  }
                  if (errStr.contains('RealtimeSubscribeException') || errStr.contains('channelError')) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_off, color: Colors.white38, size: 40),
                            SizedBox(height: 12),
                            Text('Mode Offline', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
                            SizedBox(height: 4),
                            Text('Tidak dapat terhubung ke server.\nPeriksa koneksi internet Anda.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  }
                  return Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red));
                }
                
                final rovers = snapshot.data ?? [];
                
                if (rovers.isEmpty) {
                  return const Center(child: Text('Tidak ada Rover terdaftar.', style: TextStyle(color: Colors.white54)));
                }

                return Column(
                  children: rovers.map((rover) {
                    final deviceId = rover['device_id'] as String;
                    final name = rover['name'] ?? 'Rover $deviceId';
                    final dbStatus = rover['status'] ?? 'offline';
                    
                    return StreamBuilder<List<Map<String, dynamic>>>(
                      stream: Supabase.instance.client
                          .from('rover_operations')
                          .stream(primaryKey: ['id'])
                          .eq('device_id', deviceId)
                          .order('recorded_at', ascending: false)
                          .limit(1),
                      builder: (context, eventSnapshot) {
                        String status = dbStatus.toString().toUpperCase();
                        bool isOnline = status == 'ONLINE';
                        
                        String batt = '--';
                        
                        if (eventSnapshot.hasData && eventSnapshot.data!.isNotEmpty) {
                          final latestEvent = eventSnapshot.data!.first;
                          final recordedAtStr = latestEvent['recorded_at'] as String?;
                          if (latestEvent['bats'] != null) {
                            batt = '${latestEvent['bats']}%';
                          }
                          
                          if (recordedAtStr != null) {
                            final recordedAt = DateTime.parse(recordedAtStr);
                            final now = DateTime.now();
                            // Jika heartbeat/telemetri terakhir lebih dari 2 menit yang lalu, anggap OFFLINE
                            if (now.difference(recordedAt).inMinutes > 2) {
                              status = 'OFFLINE';
                              isOnline = false;
                            } else {
                              status = 'ONLINE';
                              isOnline = true;
                            }
                          }
                        }

                        Color color = isOnline ? AppTheme.primaryGreen : Colors.white38;
                        
                        return _buildRegistryItem(
                          deviceId, 
                          name, 
                          status, 
                          batt, // Battery dari rover_operations
                          '--', // Signal
                          'Sawah', 
                          color,
                          disabled: !isOnline
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
            
            const SizedBox(height: 80), // Padding for bottom nav
          ],
        ),
      ),
    );
  }

  Widget _buildAnnualChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.panelBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Jam Pengoperasian Tahunan', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                  
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppTheme.primaryGreen, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    const Text('PEMANTAUAN REAL-TIME', style: TextStyle(color: Colors.white, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 100,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
                        if (value.toInt() >= 0 && value.toInt() < months.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(months[value.toInt()], style: const TextStyle(color: Colors.white38, fontSize: 8)),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 11,
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 20), FlSpot(1, 35), FlSpot(2, 45), FlSpot(3, 40),
                      FlSpot(4, 60), FlSpot(5, 75), FlSpot(6, 65), FlSpot(7, 85),
                      FlSpot(8, 70), FlSpot(9, 90), FlSpot(10, 80), FlSpot(11, 95),
                    ],
                    isCurved: true,
                    color: AppTheme.primaryGreen,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.primaryGreen.withOpacity(0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Colors.white12),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TOTAL JAM', style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1.0)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: const [
                        Text('1,420', style: TextStyle(color: AppTheme.primaryGreen, fontSize: 24, fontWeight: FontWeight.bold)),
                        Padding(
                          padding: EdgeInsets.only(bottom: 4.0, left: 4.0),
                          child: Text('jam', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Peningkatan Efisiensi', style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1.0)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: const [
                        Text('+24.5', style: TextStyle(color: AppTheme.accentGold, fontSize: 24, fontWeight: FontWeight.bold)),
                        Padding(
                          padding: EdgeInsets.only(bottom: 4.0, left: 2.0),
                          child: Text('%', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFleetReadiness() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.panelBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TOTAL AKTIF ROVER', style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const [
              Text('1', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              Padding(
                padding: EdgeInsets.only(bottom: 6.0, left: 4.0),
                child: Text('/ 2 Aktif', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: 8 / 12,
            backgroundColor: Colors.white12,
            color: AppTheme.primaryGreen,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppTheme.panelBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ],
      ),
    );
  }

  Widget _buildRegistryItem(String id, String name, String status, String batt, String sig, String location, Color color, {bool disabled = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.panelBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Opacity(
        opacity: disabled ? 0.5 : 1.0,
        child: Column(
          children: [
            Container(height: 2, color: color, width: double.infinity),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(4)),
                        child: Text(id, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                      ),
                      const SizedBox(width: 8),
                      Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    children: [
                      if (!disabled) Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      if (!disabled) const SizedBox(width: 6),
                      Text(status, style: TextStyle(color: disabled ? Colors.white54 : color, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(child: _buildRegistryStat('BATT', batt, disabled ? Colors.white38 : (batt == '15%' ? AppTheme.accentGold : Colors.white))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildRegistryStat('SIG', sig, Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Colors.white12),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: Colors.white54, size: 14),
                      const SizedBox(width: 4),
                      Text(location, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                  const Icon(Icons.settings_outlined, color: Colors.white54, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistryStat(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: valueColor, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
