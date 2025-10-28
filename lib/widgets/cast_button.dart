import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import '../services/cast_service.dart';

class CastButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String hlsUrl;
  final String title;

  const CastButton({
    Key? key,
    this.onPressed,
    required this.hlsUrl,
    required this.title,
  }) : super(key: key);

  @override
  State<CastButton> createState() => _CastButtonState();
}

class _CastButtonState extends State<CastButton>
    with TickerProviderStateMixin {
  final CastService _castService = CastService();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  
  bool _isConnected = false;
  String? _deviceName;
  bool _isDiscovering = false;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Listen to cast state changes
    _castService.isConnectedStream.listen((connected) {
      if (mounted) {
        setState(() {
          _isConnected = connected;
        });
      }
    });

    _castService.deviceNameStream.listen((deviceName) {
      if (mounted) {
        setState(() {
          _deviceName = deviceName;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleCastButtonPress() async {
    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    if (_isConnected) {
      // Show disconnect option
      _showDisconnectDialog();
    } else {
      // Show device selection
      await _showDeviceSelectionDialog();
    }
  }

  Future<void> _showDeviceSelectionDialog() async {
    setState(() {
      _isDiscovering = true;
    });

    try {
      final devices = await _castService.discoverDevices();
      
      if (!mounted) return;

      setState(() {
        _isDiscovering = false;
      });

      if (devices.isEmpty) {
        _showNoDevicesDialog();
        return;
      }

      _showDeviceListDialog(devices);
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isDiscovering = false;
      });
      
      _showErrorDialog('Failed to discover devices: $e');
    }
  }

  void _showDeviceListDialog(List<GoogleCastDevice> devices) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        title: const Text(
          'Select Cast Device',
          style: TextStyle(
            color: Colors.cyan,
            fontFamily: 'VT323',
            fontSize: 24,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              return ListTile(
                title: Text(
                  device.friendlyName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'VT323',
                    fontSize: 18,
                  ),
                ),
                subtitle: Text(
                  device.deviceID,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontFamily: 'CourierPrimeCode',
                    fontSize: 12,
                  ),
                ),
                leading: const Icon(
                  Icons.cast,
                  color: Colors.cyan,
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _connectToDevice(device);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey,
                fontFamily: 'VT323',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNoDevicesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        title: const Text(
          'No Devices Found',
          style: TextStyle(
            color: Colors.cyan,
            fontFamily: 'VT323',
            fontSize: 24,
          ),
        ),
        content: const Text(
          'No Chromecast devices found on your network.\n\nMake sure your Chromecast is connected to the same WiFi network.',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'CourierPrimeCode',
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(
                color: Colors.cyan,
                fontFamily: 'VT323',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        title: const Text(
          'Error',
          style: TextStyle(
            color: Colors.red,
            fontFamily: 'VT323',
            fontSize: 24,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'CourierPrimeCode',
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(
                color: Colors.red,
                fontFamily: 'VT323',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDisconnectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        title: const Text(
          'Stop Casting',
          style: TextStyle(
            color: Colors.cyan,
            fontFamily: 'VT323',
            fontSize: 24,
          ),
        ),
        content: Text(
          'Stop casting to $_deviceName?',
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'CourierPrimeCode',
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey,
                fontFamily: 'VT323',
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _castService.stopCasting();
            },
            child: const Text(
              'Stop',
              style: TextStyle(
                color: Colors.red,
                fontFamily: 'VT323',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _connectToDevice(GoogleCastDevice device) async {
    try {
      final success = await _castService.connectToDevice(device);
      if (success) {
        // Start casting the HLS stream
        await _castService.startCasting(widget.hlsUrl, widget.title);
      } else {
        if (mounted) {
          _showErrorDialog('Failed to connect to ${device.friendlyName}');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Connection error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTap: _isDiscovering ? null : _handleCastButtonPress,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.48),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _isConnected 
                        ? Colors.green.withOpacity(_glowAnimation.value)
                        : Colors.cyan.withOpacity(_glowAnimation.value),
                    blurRadius: 8 + (_glowAnimation.value * 8),
                    spreadRadius: 1 + (_glowAnimation.value * 2),
                  ),
                ],
              ),
              child: Center(
                child: _isDiscovering
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.cyan),
                        ),
                      )
                    : Icon(
                        _isConnected ? Icons.cast_connected : Icons.cast,
                        color: _isConnected ? Colors.green : Colors.cyan,
                        size: 24,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}
