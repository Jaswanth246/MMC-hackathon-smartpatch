import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';

const String serviceUUID = "12345678-1234-1234-1234-123456789abc";
const String footUUID = "12345678-1234-1234-1234-123456789ac0";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const SmartPatchApp());
}

class SmartPatchApp extends StatelessWidget {
  const SmartPatchApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Patch – Patient',
      theme: ThemeData.dark(),
      home: const PatientIdSetupScreen(),
    );
  }
}

class FootSensor {
  final int number;  // 🔢 Sensor number 1-6
  final String name;
  final Offset position;
  double value;
  FootSensor({
    required this.number,
    required this.name, 
    required this.position,
    this.value = 0,
  });
}

class PatientIdSetupScreen extends StatefulWidget {
  const PatientIdSetupScreen({super.key});

  @override
  State<PatientIdSetupScreen> createState() => _PatientIdSetupScreenState();
}

class _PatientIdSetupScreenState extends State<PatientIdSetupScreen> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final DatabaseReference _firebaseRef = FirebaseDatabase.instance.ref();
  
  bool _isChecking = false;
  String? _errorMessage;
  bool _showPassword = false;
  String? _currentMode; // "new", "existing", or null
  bool _idValid = false;

  // 🔥 CHECK 1: Does ID exist? → EXISTING vs NEW user flow
  Future<void> _checkPatientId() async {
    final id = _idController.text.trim().toUpperCase();
    
    if (id.length < 3 || id.length > 8) {
      setState(() {
        _errorMessage = "Patient ID must be 3-8 characters (PAT001)";
        _currentMode = null;
      });
      return;
    }

    if (!RegExp(r'^PAT\d+$').hasMatch(id)) {
      setState(() {
        _errorMessage = "Use format: PAT001, PAT002, etc.";
        _currentMode = null;
      });
      return;
    }

    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await _firebaseRef.child('patients/$id').once();
      final exists = snapshot.snapshot.value != null;

      setState(() {
        _isChecking = false;
        if (exists) {
          _currentMode = "existing";
          _errorMessage = "👤 EXISTING USER - Enter your password";
          _idValid = true;
        } else {
          _currentMode = "new";
          _errorMessage = "✅ NEW USER - '$id' available! Set password";
          _idValid = true;
        }
      });
    } catch (e) {
      setState(() {
        _isChecking = false;
        _errorMessage = "Network error. Try again.";
        _currentMode = null;
      });
    }
  }

  // 🔥 NEW USER: Create with password
  Future<void> _createNewUser() async {
    if (!_idValid || _currentMode != "new") return;
    
    final patientId = _idController.text.trim().toUpperCase();
    final password = _passwordController.text;
    
    if (password.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password must be 4+ characters")),
      );
      return;
    }
    
    try {
      await _firebaseRef.child('patients/$patientId').set({
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'status': 'active',
        'name': patientId,
        'password': password, // 🔥 SECURE: Hash in production!
      });

      // Create vitals structure
      await _firebaseRef.child('patients/$patientId/current').set({
        'glucose': 0.0, 'urea': 0.0, 'creatinine': 0.0,
        'dcrs': 0.0, 'risk': 'UNKNOWN'
      });
      await _firebaseRef.child('patients/$patientId/alerts').set({});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ $patientId created! Welcome!")),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => PatientDashboard(patientId: patientId)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // 🔥 EXISTING USER: Login with password
  Future<void> _loginExistingUser() async {
    if (!_idValid || _currentMode != "existing") return;
    
    final patientId = _idController.text.trim().toUpperCase();
    final password = _passwordController.text;
    
    try {
      final snapshot = await _firebaseRef.child('patients/$patientId').once();
      final patientData = snapshot.snapshot.value as Map<dynamic, dynamic>?;
      
      if (patientData?['password'] == password) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("✅ Welcome back, $patientId!")),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => PatientDashboard(patientId: patientId)),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Wrong password!")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.withOpacity(0.1),
                  ),
                  child: const Icon(
                    Icons.monitor_heart,
                    size: 80,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 32),

                const Text(
                  "Smart Patch",
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _currentMode == "new" ? "Create Account" :
                  _currentMode == "existing" ? "Welcome Back" : "Patient Login",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 48),

                // ID Input Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D1E33),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.badge, color: Colors.blue.shade300),
                          const SizedBox(width: 12),
                          const Text(
                            "Patient ID",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 🔥 Patient ID Field
                      TextField(
                        controller: _idController,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: "PAT001",
                          prefixIcon: Icon(Icons.person, color: Colors.blue.shade300),
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.3),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade700),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Colors.blue, width: 2),
                          ),
                        ),
                        onChanged: (_) => setState(() => _errorMessage = null),
                        onEditingComplete: _checkPatientId,
                      ),
                      const SizedBox(height: 20),

                      // 🔥 PASSWORD Field (Dynamic - only shows after ID check)
                      if (_currentMode != null) ...[
                        TextField(
                          controller: _passwordController,
                          obscureText: !_showPassword,
                          style: const TextStyle(fontSize: 20, color: Colors.white),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText: _currentMode == "new" ? "Choose password (4+ chars)" : "Enter your password",
                            prefixIcon: Icon(Icons.lock, color: Colors.blue.shade300),
                            suffixIcon: IconButton(
                              icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setState(() => _showPassword = !_showPassword),
                            ),
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.3),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => _currentMode == "new" ? _createNewUser() : _loginExistingUser(),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Status Message
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _idValid 
                                ? Colors.green.withOpacity(0.2)
                                : Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _idValid ? Colors.green : Colors.red,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _idValid ? Icons.check_circle : Icons.info,
                                color: _idValid ? Colors.green : Colors.orange,
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(_errorMessage!)),
                            ],
                          ),
                        ),

                      const SizedBox(height: 24),

                      // 🔥 DYNAMIC BUTTONS
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isChecking || _idValid ? null : _checkPatientId,
                              icon: _isChecking
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.search),
                              label: Text(_isChecking ? "Checking..." : "Check ID"),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _idValid && _passwordController.text.length >= 4 
                                  ? (_currentMode == "new" ? _createNewUser : _loginExistingUser)
                                  : null,
                              icon: const Icon(Icons.arrow_forward),
                              label: Text(_currentMode == "new" ? "Create" : "Login"),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Text(
                  "Format: PAT001, PAT002, etc.",
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PatientDashboard extends StatefulWidget {
  final String patientId;
  const PatientDashboard({super.key, required this.patientId});
  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  final FlutterReactiveBle flutterReactiveBle = FlutterReactiveBle();
  
  // 🔥 WiFi Config State
  final TextEditingController _wifiSsidController = TextEditingController();
  final TextEditingController _wifiPasswordController = TextEditingController();
  String? _currentWifiSsid;

  final DatabaseReference _firebaseRef = FirebaseDatabase.instance.ref();
  StreamSubscription<DatabaseEvent>? _firebaseSubscription;
  String dataSource = "Firebase ☁️";
  StreamSubscription<DiscoveredDevice>? scanSub;
  StreamSubscription<ConnectionStateUpdate>? leftConnectionSub;
  StreamSubscription<ConnectionStateUpdate>? rightConnectionSub;
  StreamSubscription<List<int>>? leftDataSub;
  StreamSubscription<List<int>>? rightDataSub;
  StreamSubscription<BleStatus>? statusSub;

  double glucose = 0;
  double urea = 0;
  double creatinine = 0;
  double dcrs = 0.0;
  int lastUpdateTimestamp = 0;
  int leftLastUpdateTimestamp = 0;
  int rightLastUpdateTimestamp = 0;
  Timer? _statusCheckTimer;
  bool patchOnline = false;
  bool leftOnline = false;
  bool rightOnline = false;
  String leftDeviceId = 'Left Sole ESP32';
  String rightDeviceId = 'Right Sole ESP32';
  BleStatus bleStatus = BleStatus.unknown;
  
  String _debugInfo = "";
  int leftLastUpdate = 0;
  int rightLastUpdate = 0;

  late List<FootSensor> leftSensors;
  late List<FootSensor> rightSensors;

  @override
  void initState() {
    super.initState();
    initSensors();
    _initBle();
    _listenToLiveData();

    _statusCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        _updateDeviceStatus();
      }
    });
  }

  void initSensors() {
    // LEFT FOOT: 6 Sensors (numbered 1-6)
    leftSensors = [
      FootSensor(number: 1, name: "1st Met", position: const Offset(0.755, 0.395)),
      FootSensor(number: 2, name: "2-3 Met", position: const Offset(0.67, 0.35)),
      FootSensor(number: 3, name: "4-5 Met", position: const Offset(0.57, 0.355)),
      FootSensor(number: 4, name: "Medial Midfoot", position: const Offset(0.66, 0.54)),
      FootSensor(number: 5, name: "Lateral Midfoot", position: const Offset(0.725, 0.57)),
      FootSensor(number: 6, name: "Medial Heel", position: const Offset(0.68, 0.78)),
    ];

    // RIGHT FOOT: PROPERLY MIRRORED (flip X + adjust for right foot position)
    rightSensors = [
      FootSensor(number: 1, name: "1st Met", position: const Offset(0.22, 0.395)), // 1-0.755=0.245 → ~0.22
      FootSensor(number: 2, name: "2-3 Met", position: const Offset(0.31, 0.35)),  // 1-0.67=0.33 → ~0.31
      FootSensor(number: 3, name: "4-5 Met", position: const Offset(0.41, 0.355)), // 1-0.57=0.43 → ~0.41
      FootSensor(number: 4, name: "Medial Midfoot", position: const Offset(0.32, 0.54)),
      FootSensor(number: 5, name: "Lateral Midfoot", position: const Offset(0.265, 0.57)),
      FootSensor(number: 6, name: "Medial Heel", position: const Offset(0.30, 0.78)),
    ];
  }

  Future<void> _initBle() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();

    statusSub ??= flutterReactiveBle.statusStream.listen((status) {
      if (mounted) setState(() => bleStatus = status);
      
      if (status == BleStatus.ready) {
        startScan();
      } else if (status == BleStatus.poweredOff) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please enable Bluetooth'),
              action: SnackBarAction(label: 'Retry', onPressed: _initBle),
            ),
          );
        }
      }
    });

    final initialStatus = await flutterReactiveBle.statusStream.first;
    if (initialStatus == BleStatus.ready) {
      startScan();
    }
  }

  void startScan() {
    scanSub?.cancel();
    scanSub = flutterReactiveBle.scanForDevices(withServices: []).listen(
      (device) {
        debugPrint('🔍 Found: ${device.name ?? "Unknown"} (${device.id})');
        
        // LEFT SOLE ESP32
        if (device.name?.contains('Left') == true && !leftOnline) {
          debugPrint('🎯 Left Sole ESP32 found! Connecting...');
          connectLeftSole(device.id);
        }
        // RIGHT SOLE ESP32  
        else if (device.name?.contains('Right') == true && !rightOnline) {
          debugPrint('🎯 Right Sole ESP32 found! Connecting...');
          connectRightSole(device.id);
        }
        debugPrint('🔍 ALL: ${device.name ?? "NoName"} (${device.id})');

        // Your 3 devices:
        if (device.name?.startsWith('SmartPatch_') == true && !patchOnline) connectVitalsPatch(device.id);
        if (device.name?.contains('Left') == true && !leftOnline) connectLeftSole(device.id);
        if (device.name?.contains('Right') == true && !rightOnline) connectRightSole(device.id);
      },
      onError: (e) {
        debugPrint('❌ Scan error: $e');
      },
    );
  }

  Future<void> connectVitalsPatch(String deviceId) async {
    debugPrint('🔌 Connecting Vitals Patch: $deviceId');
    // TODO: Implement Vitals Patch connection logic
  }

  Future<void> connectLeftSole(String deviceId) async {
    try {
      debugPrint('🔌 Connecting Left Sole: $deviceId');
      leftConnectionSub?.cancel();
      
      leftConnectionSub = flutterReactiveBle
          .connectToDevice(id: deviceId, connectionTimeout: const Duration(seconds: 10))
          .listen((connectionState) {
        if (connectionState.connectionState == DeviceConnectionState.connected) {
          _subscribeToLeftSoleData(deviceId);
          _sendPatientIdToPatch(deviceId); // 🔥 ADD THIS LINE
          if (mounted) setState(() => leftOnline = true);  // ✅
        } else if (connectionState.connectionState == DeviceConnectionState.disconnected) {
          if (mounted) {
            setState(() {
              leftOnline = false;  // ✅ Force offline
              for (var sensor in leftSensors) sensor.value = 0;  // Clear sensors
            });
          }
        }
      });
      
      if (mounted) setState(() {
        leftOnline = true;
        leftDeviceId = deviceId;
      });
    } catch (e) {
      debugPrint('❌ Left Sole connect failed: $e');
    }
  }

  Future<void> connectRightSole(String deviceId) async {
    try {
      debugPrint('🔌 Connecting Right Sole: $deviceId');
      rightConnectionSub?.cancel();
      
      rightConnectionSub = flutterReactiveBle
          .connectToDevice(id: deviceId, connectionTimeout: const Duration(seconds: 10))
          .listen((connectionState) {
        if (connectionState.connectionState == DeviceConnectionState.connected) {
          _subscribeToRightSoleData(deviceId);
          _sendPatientIdToPatch(deviceId); // 🔥 ADD THIS LINE
          if (mounted) setState(() => rightOnline = true);  // ✅
        } else if (connectionState.connectionState == DeviceConnectionState.disconnected) {
          if (mounted) {
            setState(() {
              rightOnline = false;  // ✅ Force offline
              for (var sensor in rightSensors) sensor.value = 0;  // Clear sensors
            });
          }
        }
      });
      
      if (mounted) setState(() {
        rightOnline = true;
        rightDeviceId = deviceId;
      });
    } catch (e) {
      debugPrint('❌ Right Sole connect failed: $e');
    }
  }

  // 🔥 SEND PATIENT ID TO PATCH after connection
  void _sendPatientIdToPatch(String deviceId) async {
    try {
      const configServiceUUID = "12345678-1234-1234-1234-123456789abc";
      const configUUID = "12345678-1234-1234-1234-123456789abd";

      final char = QualifiedCharacteristic(
        serviceId: Uuid.parse(configServiceUUID),
        characteristicId: Uuid.parse(configUUID),
        deviceId: deviceId,
      );

      String patientCommand = "PATIENT:${widget.patientId}";
      await flutterReactiveBle.writeCharacteristicWithResponse(char, value: patientCommand.codeUnits);

      debugPrint('👤 Sent Patient ID: $patientCommand');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Patient ID sent to patch: ${widget.patientId}")),
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to send patient ID: $e');
    }
  }

  void _subscribeToLeftSoleData(String deviceId) {
    final char = QualifiedCharacteristic(
      serviceId: Uuid.parse(serviceUUID),
      characteristicId: Uuid.parse(footUUID),
      deviceId: deviceId,
    );

    leftDataSub = flutterReactiveBle.subscribeToCharacteristic(char).listen((data) {
      final dataString = String.fromCharCodes(data);
      debugPrint('📡 Left Sole: $dataString');
      
      // Left sole sends: "sensor1,sensor2,sensor3,sensor4,sensor5,sensor6"
      final parts = dataString.split(',');
      if (parts.length == 6 && mounted) {
        setState(() {
          for (int i = 0; i < 6; i++) {
            leftSensors[i].value = double.tryParse(parts[i].trim()) ?? 0;
          }
        });
      }
    });
  }

  void _subscribeToRightSoleData(String deviceId) {
    final char = QualifiedCharacteristic(
      serviceId: Uuid.parse(serviceUUID),
      characteristicId: Uuid.parse(footUUID),
      deviceId: deviceId,
    );

    rightDataSub = flutterReactiveBle.subscribeToCharacteristic(char).listen((data) {
      final dataString = String.fromCharCodes(data);
      debugPrint('📡 Right Sole: $dataString');
      
      // Right sole sends: "sensor1,sensor2,sensor3,sensor4,sensor5,sensor6"  
      final parts = dataString.split(',');
      if (parts.length == 6 && mounted) {
        setState(() {
          for (int i = 0; i < 6; i++) {
            rightSensors[i].value = double.tryParse(parts[i].trim()) ?? 0;
          }
        });
      }
    });
  }

  void _listenToLiveData() {
    // PATCH (keep existing)
    _firebaseRef.child('patients/${widget.patientId}/current').onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        
        // 🔥 DEBUG: See what timestamp format you're getting
        debugPrint('🔍 PATCH TIMESTAMP RAW: ${data['timestamp']} (type: ${data['timestamp'].runtimeType})');
        
        setState(() {
          glucose = double.tryParse(data['glucose']?.toString() ?? '0') ?? 0;
          urea = double.tryParse(data['urea']?.toString() ?? '0') ?? 0;
          creatinine = double.tryParse(data['creatinine']?.toString() ?? '0') ?? 0;
          dcrs = double.tryParse(data['dcrs']?.toString() ?? '0') ?? 0;
          lastUpdateTimestamp = int.tryParse(data['timestamp']?.toString() ?? '0') ?? 0;
          
          // 🔥 DEBUG: See what gets stored
          debugPrint('🔍 lastUpdateTimestamp stored: $lastUpdateTimestamp');
          debugPrint('🔍 Current time: ${DateTime.now().millisecondsSinceEpoch ~/ 1000}');
          
          dataSource = "Live ☁️";
        });
      }
    });

    // LEFT FOOT - DIAGNOSTIC
    _firebaseRef.child('patients/${widget.patientId}/foot_pressure/left_current').onValue.listen((event) {
      debugPrint('🔍 LEFT DATA: ${event.snapshot.value}'); // 🔥 SEE RAW DATA
      if (event.snapshot.value != null && mounted) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          leftSensors[0].value = double.tryParse(data['s1']?.toString() ?? '0') ?? 0;
          leftSensors[1].value = double.tryParse(data['s2']?.toString() ?? '0') ?? 0;
          leftSensors[2].value = double.tryParse(data['s3']?.toString() ?? '0') ?? 0;
          leftSensors[3].value = double.tryParse(data['s4']?.toString() ?? '0') ?? 0;
          leftSensors[4].value = double.tryParse(data['s5']?.toString() ?? '0') ?? 0;
          leftSensors[5].value = double.tryParse(data['s6']?.toString() ?? '0') ?? 0;
          
          // 🔥 DEBUG: Show ALL left sensor values
          _debugInfo += "LEFT: S1=${leftSensors[0].value}, S2=${leftSensors[1].value} | ";
          leftLastUpdate = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        });
      }
    });

    // RIGHT FOOT - DIAGNOSTIC  
    _firebaseRef.child('patients/${widget.patientId}/foot_pressure/right_current').onValue.listen((event) {
      debugPrint('🔍 RIGHT DATA: ${event.snapshot.value}'); // 🔥 SEE RAW DATA
      if (event.snapshot.value != null && mounted) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          rightSensors[0].value = double.tryParse(data['s1']?.toString() ?? '0') ?? 0;
          rightSensors[1].value = double.tryParse(data['s2']?.toString() ?? '0') ?? 0;
          rightSensors[2].value = double.tryParse(data['s3']?.toString() ?? '0') ?? 0;
          rightSensors[3].value = double.tryParse(data['s4']?.toString() ?? '0') ?? 0;
          rightSensors[4].value = double.tryParse(data['s5']?.toString() ?? '0') ?? 0;
          rightSensors[5].value = double.tryParse(data['s6']?.toString() ?? '0') ?? 0;
          
          // 🔥 DEBUG: Show ALL right sensor values
          _debugInfo += "RIGHT: S1=${rightSensors[0].value}, S2=${rightSensors[1].value} | ";
          rightLastUpdate = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        });
      }
    });
  }

  void _updateDeviceStatus() {
    int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    setState(() {
      // Patch status (existing)
      patchOnline = lastUpdateTimestamp > 0 && (now - lastUpdateTimestamp) < 15;
      
      leftOnline = leftLastUpdate > 0 && (now - leftLastUpdate) < 15;  // 🔥 USE OUR OWN TIMESTAMPS
      rightOnline = rightLastUpdate > 0 && (now - rightLastUpdate) < 15;
      
      _debugInfo += "Status: L:$leftOnline R:$rightOnline | ";
    });
  }

  Future<void> _sendWifiToPatch() async {
    final ssid = _wifiSsidController.text;
    final password = _wifiPasswordController.text;
    
    try {
      // 🔥 SEND WIFI VIA BLE (different characteristic)
      const wifiServiceUUID = "12345678-1234-1234-1234-123456789abd"; // New service
      const wifiUUID = "12345678-1234-1234-1234-123456789ac1";     // New char
      
      if (leftOnline || rightOnline) {
        final deviceId = leftOnline ? leftDeviceId : rightDeviceId;
        final char = QualifiedCharacteristic(
          serviceId: Uuid.parse(wifiServiceUUID),
          characteristicId: Uuid.parse(wifiUUID),
          deviceId: deviceId,
        );
        
        // Format: "WIFI:ssid,password"
        final wifiData = "WIFI:$ssid,$password";
        await flutterReactiveBle.writeCharacteristicWithResponse(char, value: wifiData.codeUnits);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ WiFi credentials sent! Restart patch.")),
          );
          setState(() => _currentWifiSsid = ssid);
          _wifiSsidController.clear();
          _wifiPasswordController.clear();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("❌ Connect to patch first!")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  void _showWifiConfigurationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Configure Patch WiFi"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Send new WiFi credentials to patch via BLE"),
              const SizedBox(height: 20),
              TextField(
                controller: _wifiSsidController,
                decoration: const InputDecoration(
                  labelText: "WiFi SSID",
                  prefixIcon: Icon(Icons.wifi),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _wifiPasswordController,
                decoration: const InputDecoration(
                  labelText: "Password",
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 20),
              Text(
                _currentWifiSsid ?? "No WiFi stored",
                style: TextStyle(
                  color: _currentWifiSsid != null ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (_wifiSsidController.text.isNotEmpty && _wifiPasswordController.text.isNotEmpty) {
                _sendWifiToPatch();
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.send),
            label: const Text("Send to Patch"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _wifiSsidController.dispose();
    _wifiPasswordController.dispose();
    scanSub?.cancel();
    leftConnectionSub?.cancel();
    rightConnectionSub?.cancel();
    leftDataSub?.cancel();
    rightDataSub?.cancel();
    statusSub?.cancel();
    _firebaseSubscription?.cancel();
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Smart Patch ($dataSource)"),
        actions: [
          IconButton(
            icon: const Icon(Icons.wifi_find),
            onPressed: _showWifiConfigurationDialog,
            tooltip: 'Configure Patch WiFi',
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PatientChatScreen(patientId: widget.patientId),
                ),
              );
            },
            tooltip: 'Chat with Doctor',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _listenToLiveData();
              _initBle();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _patientIdCard(),
            const SizedBox(height: 16),
            _deviceStatusCard(),
            const SizedBox(height: 20),
            _vitalsCard(),
            const SizedBox(height: 20),
            _dcrsCard(),
            const SizedBox(height: 20),
            _alertsCard(),
            const SizedBox(height: 20),
            const Text(
              "Foot Pressure Values",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _footPressureValuesCard(),
            const SizedBox(height: 20),
            const Text(
              "Foot Pressure Heatmap (6 Sensors/Foot)",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Transform.flip(
              flipX: true,  // 🔥 MIRRORS left↔right perfectly
              child: FootPressureWidget(
                leftSensors: leftSensors,
                rightSensors: rightSensors,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Updated widgets with numbered sensors
  Widget _deviceStatusCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Device Status", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          DeviceStatus("🔸 Smart Patch", patchOnline),  // ✅ ADDED BACK
          DeviceStatus("👞 Left Sole ESP32 (S1-6)", leftOnline),
          DeviceStatus("👞 Right Sole ESP32 (S1-6)", rightOnline),
          const SizedBox(height: 8),
          Text(
            "Cloud: ${dataSource == 'Live ☁️' ? '✅ Connected' : '🔄 Loading'}",
            style: TextStyle(
              color: dataSource == 'Live ☁️' ? Colors.green : Colors.orange,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );

  String _getTimeSinceUpdate() {
    int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    int diff = now - lastUpdateTimestamp;
    
    if (diff < 60) return "${diff}s ago";
    if (diff < 3600) return "${(diff / 60).floor()}m ago";
    return "${(diff / 3600).floor()}h ago";
  }

  Widget _patientIdCard() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.person, size: 40),
        title: Text("Patient ID: ${widget.patientId}"),
        subtitle: const Text("Status: Monitoring"),
      ),
    );
  }

  Widget _vitalsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Vitals", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _vitalItem("Glucose", patchOnline ? glucose.toStringAsFixed(1) : "-"),
                _vitalItem("Urea", patchOnline ? urea.toStringAsFixed(1) : "-"),
                _vitalItem("Creatinine", patchOnline ? creatinine.toStringAsFixed(2) : "-"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _vitalItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _dcrsCard() {
    return Card(
      color: (patchOnline && dcrs > 0.7) ? Colors.red.withOpacity(0.2) : 
             (patchOnline && dcrs > 0.4) ? Colors.orange.withOpacity(0.2) : null,
      child: ListTile(
        title: const Text("DCRS Score"),
        trailing: Text(
          patchOnline ? dcrs.toStringAsFixed(2) : "-", 
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
        ),
      ),
    );
  }

  Widget _alertsCard() {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.notifications, color: Colors.orange),
        title: Text("Recent Alerts"),
        subtitle: Text("No critical alerts detected."),
      ),
    );
  }

  Widget _footPressureValuesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text("Left Foot", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      ...leftSensors.map((s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("S${s.number} ${s.name}:", style: const TextStyle(fontSize: 12)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Color.lerp(Colors.green, Colors.red, (s.value / 100).clamp(0, 1)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "${s.value.toStringAsFixed(0)}%",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      const Text("Right Foot", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      ...rightSensors.map((s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("S${s.number} ${s.name}:", style: const TextStyle(fontSize: 12)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Color.lerp(Colors.green, Colors.red, (s.value / 100).clamp(0, 1)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "${s.value.toStringAsFixed(0)}%",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PatientChatScreen extends StatefulWidget {
  final String patientId;
  const PatientChatScreen({super.key, required this.patientId});

  @override
  State<PatientChatScreen> createState() => _PatientChatScreenState();
}

class _PatientChatScreenState extends State<PatientChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final DatabaseReference _chatRef = FirebaseDatabase.instance.ref();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> messages = [];

  @override
  void initState() {
    super.initState();
    _listenToMessages();
  }

  void _listenToMessages() {
    _chatRef.child('patients/${widget.patientId}/chat').onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> loadedMessages = [];

        data.forEach((key, value) {
          final msgData = Map<String, dynamic>.from(value as Map);
          loadedMessages.add({
            'id': key,
            'message': msgData['message'] ?? '',
            'sender': msgData['sender'] ?? 'unknown',
            'timestamp': msgData['timestamp'] ?? 0,
          });
        });

        // Sort by timestamp (oldest first)
        loadedMessages.sort((a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int));

        setState(() {
          messages = loadedMessages;
        });

        // Auto-scroll to bottom
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _chatRef.child('patients/${widget.patientId}/chat').push().set({
      'message': message,
      'sender': 'patient',
      'timestamp': timestamp,
    });

    _messageController.clear();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat with Doctor'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet\nStart a conversation with your doctor',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isPatient = msg['sender'] == 'patient';
                      final time = DateTime.fromMillisecondsSinceEpoch(msg['timestamp'] * 1000);

                      return Align(
                        alignment: isPatient ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: isPatient ? Colors.blue : Colors.grey[800],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg['message'],
                                style: const TextStyle(fontSize: 16, color: Colors.white),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Input field
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DeviceStatus extends StatelessWidget {
  final String label;
  final bool isOnline;
  const DeviceStatus(this.label, this.isOnline, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isOnline ? Colors.green : Colors.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: isOnline ? Colors.green.withOpacity(0.4) : Colors.red.withOpacity(0.4),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          if (isOnline)
            const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
        ],
      ),
    );
  }
}

class FootPressureWidget extends StatelessWidget {
  final List<FootSensor> leftSensors;
  final List<FootSensor> rightSensors;

  const FootPressureWidget({
    super.key,
    required this.leftSensors,
    required this.rightSensors,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;

          Color _getSensorColor(double value) {
            if (value < 25) return Color.lerp(Colors.green, Colors.lightGreen, (value / 25).clamp(0, 1))!;
            if (value < 50) return Color.lerp(Colors.yellow, Colors.orange, ((value - 25) / 25).clamp(0, 1))!;
            if (value < 75) return Color.lerp(Colors.orange, Colors.deepOrange, ((value - 75) / 25).clamp(0, 1))!;
            return Color.lerp(Colors.deepOrange, Colors.red, ((value - 75) / 25).clamp(0, 1))!;
          }

          // 🔥 FIX 2: Extract sensor circle builder with side label
          Widget _buildSensorCircle(FootSensor s, double dx, double dy, Size size, String side) {
            Color color = _getSensorColor(s.value);
            final sensorSize = 24.0 + (s.value / 100 * 16);  // 24-40px

            return Positioned(
              left: dx - (sensorSize / 2),
              top: dy - (sensorSize / 2),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Heatmap glow effect
                  Container(
                    width: sensorSize * 2,
                    height: sensorSize * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          color.withOpacity(0.3),
                          color.withOpacity(0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  // Main sensor circle
                  Container(
                    width: sensorSize,
                    height: sensorSize,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.6),
                          blurRadius: 12,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                  // Sensor number (Counter-flipped)
                  Transform(
                    transform: Matrix4.identity()..scale(-1.0, 1.0),
                    alignment: Alignment.center,
                    child: Text(
                      '${s.number}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        shadows: [Shadow(blurRadius: 2, color: Colors.black54)],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // 🔥 FIX 1: Separate left vs right sensor builders
          Widget buildLeftSensor(FootSensor s) {
            final dx = s.position.dx * size.width;
            final dy = s.position.dy * size.height;
            return _buildSensorCircle(s, dx, dy, size, 'LEFT');
          }

          Widget buildRightSensor(FootSensor s) {
            final dx = s.position.dx * size.width;  // Right foot has its own positions now
            final dy = s.position.dy * size.height;
            return _buildSensorCircle(s, dx, dy, size, 'RIGHT');
          }

          return Stack(
            children: [
              Image.asset(
                'assets/images/feet.png',
                width: size.width,
                height: size.height,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: size.width,
                  height: size.height,
                  color: Colors.grey[900],
                  child: const Text(
                    'feet.png missing\nCheck pubspec.yaml assets',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
              // 🔥 LEFT SENSORS ONLY
              ...rightSensors.map(buildLeftSensor),
              // 🔥 RIGHT SENSORS ONLY  
              ...leftSensors.map(buildRightSensor),
            ],
          );
        },
      ),
    );
  }
}
