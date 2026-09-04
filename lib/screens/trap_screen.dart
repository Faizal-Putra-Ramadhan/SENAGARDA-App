import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TrapScreen extends StatefulWidget {
  const TrapScreen({super.key});

  @override
  State<TrapScreen> createState() => _TrapScreenState();
}

class _TrapScreenState extends State<TrapScreen> {
  String? _selectedTrapId;

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
            
            // Trap List
            _buildTrapListItem('TRP-001-A', 'Sawah Pak Aris', 'Terdeteksi Tikus', '98%', Colors.orange),
            _buildTrapListItem('TRP-002-B', 'Sawah Pak Budi', 'Siap Beroperasi', '85%', AppTheme.primaryGreen),
            _buildTrapListItem('TRP-003-C', 'Sawah Pak Chandra', 'Offline', '--%', Colors.redAccent, icon: Icons.wifi_off),
            // _buildTrapListItem('TRP-004-D', 'Sawah Pak Doni', 'Idle / Armed', '92%', AppTheme.primaryGreen),
            
            const SizedBox(height: 24),
            
            // Selected Trap Details (mocking TRP-001-A)
            if (_selectedTrapId == 'TRP-001-A')
              _buildTrapDetails(),
              
            const SizedBox(height: 80), // Padding for bottom nav
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
                Text('2 / 3', style: TextStyle(color: AppTheme.primaryGreen, fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: const [
                Text('TOTAL TERDETEKSI (24H)', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                SizedBox(height: 4),
                Text('03', style: TextStyle(color: AppTheme.accentGold, fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrapListItem(String id, String zone, String status, String battery, Color statusColor, {IconData? icon}) {
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
                      : null,
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
                    Text('$battery Batt', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrapDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.panelBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentGold.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TRP-001-A',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white54),
                onPressed: () {},
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Container(
              //   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              //   decoration: BoxDecoration(
              //     color: AppTheme.accentGold.withOpacity(0.2),
              //     borderRadius: BorderRadius.circular(4),
              //     border: Border.all(color: AppTheme.accentGold.withOpacity(0.5)),
              //   ),
              //   child: const Text('CAPTURE DETECTED', style: TextStyle(color: AppTheme.accentGold, fontSize: 10, fontWeight: FontWeight.bold)),
              // ),
              // const SizedBox(width: 12),
              // const Text('Last Sync: 2 mins ago', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          // const SizedBox(height: 24),
          // const Text('INTERNAL CAMERA FEED', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          // const SizedBox(height: 12),
          
          // Camera feed placeholder
          Container(
            // height: 180,
            // width: double.infinity,
            // decoration: BoxDecoration(
            //   color: Colors.black,
            //   borderRadius: BorderRadius.circular(8),
            //   border: Border.all(color: Colors.white12),
            // ),
            child: Stack(
              children: [
                // Center(
                //   child: Icon(Icons.camera_alt, color: Colors.white12, size: 48),
                // ),
                // Positioned(
                //   top: 8, left: 8,
                //   child: Container(
                //     padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                //     color: Colors.black54,
                //     child: const Text('REC_CAM_01', style: TextStyle(color: Colors.white, fontSize: 10)),
                //   ),
                // ),
                // Positioned(
                //   bottom: 8, right: 8,
                //   child: Row(
                //     children: [
                //       Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                //       const SizedBox(width: 4),
                //       const Text('MOTION DETECTED', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                //     ],
                //   ),
                // ),
              ],
            ),
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
              _buildStatBox('POWER LEVEL', '98.2 %', Icons.battery_full),
              _buildStatBox('SIGNAL STRENGTH', '-68 dBm', Icons.signal_cellular_alt),
              // _buildStatBox('TEMPERATURE', '24.5 °C', Icons.thermostat),
              _buildStatBox('UPTIME', '14d 08h', Icons.access_time),
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
      ),
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
