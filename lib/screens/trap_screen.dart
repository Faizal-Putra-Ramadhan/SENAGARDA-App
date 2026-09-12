import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

class TrapScreen extends StatefulWidget {
  const TrapScreen({super.key});

  @override
  State<TrapScreen> createState() => _TrapScreenState();
}

class _TrapScreenState extends State<TrapScreen> {
  String? _selectedTrapId;
  final _supabase = Supabase.instance.client;

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
            fontWeight: FontWeight.w700,
            fontSize: 26,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white70),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.white70),
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
              'Status Trap',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pantau dan kelola SENAGARDA Trap yang aktif. Data pemantauan tangkapan dan status perangkat keras secara real-time.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            
            // Summary Card
            _buildSummaryCard(),
            const SizedBox(height: 24),
            
            // Trap List from Supabase
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _supabase.from('devices').stream(primaryKey: ['id']).eq('type', 'trap').order('created_at', ascending: true),
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
                  return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                }
                
                final traps = snapshot.data ?? [];
                
                if (traps.isEmpty) {
                  return const Center(child: Text('Tidak ada Trap terdaftar.', style: TextStyle(color: Colors.white54)));
                }
                
                return Column(
                  children: traps.map((trap) {
                    final deviceId = trap['device_id'] as String;
                    final name = trap['name'] ?? 'Zone $deviceId';
                    final dbStatus = trap['status'] ?? 'offline';
                    
                    return StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _supabase
                          .from('trap_events')
                          .stream(primaryKey: ['id'])
                          .eq('device_id', deviceId)
                          .order('recorded_at', ascending: false)
                          .limit(1),
                      builder: (context, eventSnapshot) {
                        String status = dbStatus.toString().toUpperCase();
                        Color statusColor = status == 'ONLINE' ? AppTheme.primaryGreen : Colors.redAccent;
                        IconData? icon = status == 'ONLINE' ? null : Icons.wifi_off;

                        if (eventSnapshot.hasData && eventSnapshot.data!.isNotEmpty) {
                          final latestEvent = eventSnapshot.data!.first;
                          final recordedAtStr = latestEvent['recorded_at'] as String?;
                          if (recordedAtStr != null) {
                            final recordedAt = DateTime.parse(recordedAtStr);
                            final now = DateTime.now();
                            // Jika heartbeat/event terakhir lebih dari 2 menit yang lalu, anggap OFFLINE
                            if (now.difference(recordedAt).inMinutes > 2) {
                              status = 'OFFLINE';
                              statusColor = Colors.redAccent;
                              icon = Icons.wifi_off;
                            } else {
                              status = 'ONLINE';
                              statusColor = AppTheme.primaryGreen;
                              icon = null;
                            }
                          }
                        }

                        return _buildTrapListItem(
                          deviceId, 
                          name, 
                          status, 
                          statusColor,
                          icon: icon,
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
            
            const SizedBox(height: 24),
            
            // Selected Trap Details
            if (_selectedTrapId != null)
              _buildTrapDetails(_selectedTrapId!),
              
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.panelBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('TRAP YANG AKTIF', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                SizedBox(height: 4),
                Text('--', style: TextStyle(color: AppTheme.primaryGreen, fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: const [
                Text('TOTAL TERDETEKSI (24H)', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                SizedBox(height: 4),
                Text('--', style: TextStyle(color: AppTheme.accentGold, fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrapListItem(String id, String zone, String status, Color statusColor, {IconData? icon}) {
    bool isSelected = _selectedTrapId == id;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTrapId = isSelected ? null : id;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.panelBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.accentGold : Colors.white12,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: icon != null 
                      ? Icon(icon, color: Colors.white54, size: 20)
                      : const Icon(Icons.pest_control, color: Colors.white54, size: 20),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(id, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(status, style: TextStyle(color: statusColor, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(zone, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrapDetails(String deviceId) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.panelBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentGold.withOpacity(0.5)),
      ),
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase
            .from('trap_events')
            .stream(primaryKey: ['id'])
            .eq('device_id', deviceId)
            .order('recorded_at', ascending: false)
            .limit(1), // Get only latest event
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final events = snapshot.data ?? [];
          Map<String, dynamic>? latestEvent = events.isNotEmpty ? events.first : null;
          
          String powerLvl = '-- %';
          String sigLvl = '-- dBm';
          
          if (latestEvent != null && latestEvent['data'] != null) {
             final data = latestEvent['data'] as Map<String, dynamic>;
             if (data['battery'] != null) powerLvl = '${data['battery']} %';
             if (data['signal'] != null) sigLvl = '${data['signal']} dBm';
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    deviceId,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Stats Grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.2,
                children: [
                  _buildStatBox('POWER LEVEL', powerLvl, Icons.battery_full),
                  _buildStatBox('SIGNAL STRENGTH', sigLvl, Icons.signal_cellular_alt),
                  _buildStatBox('LAST EVENT', latestEvent?['event_type'] ?? 'NONE', Icons.history),
                ],
              ),
              const SizedBox(height: 24),
              
              // Actions
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.lock_open),
                  label: const Text('REMOTE RELEASE DOOR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen.withOpacity(0.2),
                    foregroundColor: AppTheme.primaryGreen,
                    side: const BorderSide(color: AppTheme.primaryGreen),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          );
        }
      )
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white54, size: 14),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
