import 'package:flutter/material.dart';
import 'connect_screen.dart';
import 'control_screen.dart';
import '../services/rover_service.dart';

class ControlTab extends StatefulWidget {
  const ControlTab({super.key});

  @override
  State<ControlTab> createState() => _ControlTabState();
}

class _ControlTabState extends State<ControlTab> {
  RoverService? _roverService;

  void _handleConnected(RoverService service) {
    setState(() {
      _roverService = service;
    });
  }

  void _handleDisconnected() {
    setState(() {
      _roverService = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // We use a Navigator to push the DevicePickerScreen internally within this tab,
    // or just let ConnectScreen do a normal Navigator push (it will cover the bottom bar).
    // If we want the bottom bar to remain visible, we need an internal navigator,
    // but covering it is usually fine for a modal picker.
    
    if (_roverService == null) {
      return ConnectScreen(onConnected: _handleConnected);
    } else {
      return ControlScreen(
        roverService: _roverService!,
        onDisconnect: _handleDisconnected,
      );
    }
  }
}
