import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:nagada_client/sync_engine.dart'; // Core SDK dependency

enum SyncState {
  idle,
  syncing,
  retrying,
  paused,
  error,
  disconnected,
}

enum PulseTheme {
  classicNagada,
  techPulse,
}

class _PulseThemeData {
  final Color primaryColor;
  final Color accentColor;
  final Color backgroundColor;
  final Color waveformColor;
  final Color drumbeatColor;
  final List<Color> gradientColors;

  _PulseThemeData({
    required this.primaryColor,
    required this.accentColor,
    required this.backgroundColor,
    required this.waveformColor,
    required this.drumbeatColor,
    required this.gradientColors,
  });

  static _PulseThemeData fromPulseTheme(PulseTheme theme) {
    switch (theme) {
      case PulseTheme.classicNagada:
        return _PulseThemeData(
          primaryColor: Colors.brown.shade700,
          accentColor: Colors.orange.shade300,
          backgroundColor: Colors.brown.shade900,
          waveformColor: Colors.yellow.shade700,
          drumbeatColor: Colors.deepOrange.shade600,
          gradientColors: [Colors.brown.shade800, Colors.brown.shade900],
        );
      case PulseTheme.techPulse:
        return _PulseThemeData(
          primaryColor: Colors.blue.shade700,
          accentColor: Colors.cyan.shade300,
          backgroundColor: Colors.black,
          waveformColor: Colors.greenAccent.shade400,
          drumbeatColor: Colors.redAccent.shade400,
          gradientColors: [Colors.black, Colors.blueGrey.shade900],
        );
    }
  }
}

class NagadaPulseVisualizer extends StatefulWidget {
  final Stream<int> outgoingCountStream;
  final Stream<int> incomingCountStream;
  final Stream<SyncState> syncStateStream;
  final double loadFactor;
  final double size;
  final PulseTheme theme;
  final bool enableHaptics;
  final SyncEngine? syncEngine; // Optional: for UX features like pause/resume

  const NagadaPulseVisualizer({
    super.key,
    required this.outgoingCountStream,
    required this.incomingCountStream,
    required this.syncStateStream,
    this.loadFactor = 0.0,
    this.size = 72.0,
    this.theme = PulseTheme.techPulse,
    this.enableHaptics = false,
    this.syncEngine,
  });

  @override
  State<NagadaPulseVisualizer> createState() => _NagadaPulseVisualizerState();
}

class _NagadaPulseVisualizerState extends State<NagadaPulseVisualizer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _drumbeatAnimation;
  late Animation<double> _ecgAmplitudeAnimation;
  late Animation<double> _backgroundPulseAnimation;

  StreamSubscription<int>? _outgoingCountSubscription;
  StreamSubscription<int>? _incomingCountSubscription;
  StreamSubscription<SyncState>? _syncStateSubscription;

  SyncState _currentSyncState = SyncState.idle;
  int _outgoingEventCount = 0;
  int _incomingEventCount = 0;
  DateTime? _lastSyncTimestamp; // New: To track the last time sync activity occurred
  double _currentBPM = 60; // Base BPM
  double _currentLoadFactor = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _getAnimationDuration(),
    );

    _drumbeatAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.2, curve: Curves.easeOut)),
    );
    _ecgAmplitudeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 1.0, curve: Curves.easeInOut)),
    );
    _backgroundPulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 1.0, curve: Curves.linear)),
    );

    _controller.repeat();
    _controller.addListener(_animationListener);

    _outgoingCountSubscription = widget.outgoingCountStream.listen((count) {
      if (_currentSyncState != SyncState.paused) {
        setState(() {
          _outgoingEventCount = count;
          _lastSyncTimestamp = DateTime.now(); // Update timestamp on outgoing activity
          _updateBPM();
        });
        if (widget.enableHaptics) {
          HapticFeedback.lightImpact();
        }
      }
    });

    _incomingCountSubscription = widget.incomingCountStream.listen((count) {
      if (_currentSyncState != SyncState.paused) {
        setState(() {
          _incomingEventCount = count;
          _lastSyncTimestamp = DateTime.now(); // Update timestamp on incoming activity
          _updateBPM();
        });
      }
    });

    _syncStateSubscription = widget.syncStateStream.listen((state) {
      setState(() {
        _currentSyncState = state;
        if (state == SyncState.syncing || state == SyncState.idle) { // Update timestamp for active/idle sync
          _lastSyncTimestamp = DateTime.now();
        }
        _updateBPM();
        _handleSyncStateChange(state);
      });
    });
  }

  void _animationListener() {
    // This listener can be used for any effects tied directly to the controller's value
  }

  void _updateBPM() {
    double newBPM = 60.0; // Idle BPM
    _currentLoadFactor = widget.loadFactor; // Use the provided load factor

    switch (_currentSyncState) {
      case SyncState.idle:
        newBPM = 60.0; // Calm heartbeat
        break;
      case SyncState.syncing:
        newBPM = 90.0 + (30.0 * _currentLoadFactor); // Rhythmic pulse, faster with load
        break;
      case SyncState.retrying:
        newBPM = 80.0 + (40.0 * _currentLoadFactor); // Faster than idle, but not frantic. A 'waiting' pace
        break;
      case SyncState.error:
        newBPM = 120.0 + (40.0 * _currentLoadFactor); // Fast, to emphasize problem. Irregularity handled by painter
        break;
      case SyncState.paused:
        _controller.stop(); // Explicitly stop animation for paused state
        newBPM = 0.0; // No pulse when paused
        break;
      case SyncState.disconnected:
        newBPM = 20.0; // Very slow, barely pulsing
        break;
    }

    // Cap BPM at 160 as per requirements
    newBPM = min(newBPM, 160.0);

    // Only update animation controller if BPM actually changes and is not paused
    if (_currentBPM != newBPM) {
      setState(() {
        _currentBPM = newBPM;
        _controller.duration = _getAnimationDuration();
        if (_currentSyncState != SyncState.paused && !_controller.isAnimating) {
          _controller.repeat();
        }
      });
    }
  }

  Duration _getAnimationDuration() {
    if (_currentBPM == 0) return Duration.zero;
    return Duration(milliseconds: (60 * 1000 / _currentBPM).round());
  }

  void _handleSyncStateChange(SyncState state) {
    if (state == SyncState.paused) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      // If not paused and controller is not animating (e.g. was paused), restart it
      _controller.repeat();
    }
    // Visual effects for error and disconnected will primarily be handled in the painter.
    // The BPM change is handled in _updateBPM.
  }

  @override
  void didUpdateWidget(covariant NagadaPulseVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.outgoingCountStream != widget.outgoingCountStream) {
      _outgoingCountSubscription?.cancel();
      _outgoingCountSubscription = widget.outgoingCountStream.listen((count) {
        if (_currentSyncState != SyncState.paused) {
          setState(() {
            _outgoingEventCount = count;
            _updateBPM();
          });
          if (widget.enableHaptics) {
            HapticFeedback.lightImpact();
          }
        }
      });
    }
    if (oldWidget.incomingCountStream != widget.incomingCountStream) {
      _incomingCountSubscription?.cancel();
      _incomingCountSubscription = widget.incomingCountStream.listen((count) {
        if (_currentSyncState != SyncState.paused) {
          setState(() {
            _incomingEventCount = count;
            _updateBPM();
          });
        }
      });
    }
    if (oldWidget.syncStateStream != widget.syncStateStream) {
      _syncStateSubscription?.cancel();
      _syncStateSubscription = widget.syncStateStream.listen((state) {
        setState(() {
          _currentSyncState = state;
          _updateBPM();
          _handleSyncStateChange(state);
        });
      });
    }
    if (oldWidget.loadFactor != widget.loadFactor || oldWidget.theme != widget.theme) {
      _updateBPM(); // Recalculate BPM if loadFactor changes
      // No explicit setState needed here as _updateBPM will call it if BPM changes
    }
  }

  @override
  void dispose() {
    _outgoingCountSubscription?.cancel();
    _incomingCountSubscription?.cancel();
    _syncStateSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _PulseThemeData themeData = _PulseThemeData.fromPulseTheme(widget.theme);

    return GestureDetector(
      onTap: () {
        if (widget.syncEngine != null) {
          // Toggle between paused and previous state, or just unpause if in paused state
          if (_currentSyncState == SyncState.paused) {
            // How to determine previous state? For now, assume back to idle or syncing
            print('Tapped: Sync Engine control - Attempting to resume sync');
            // A real sync engine would have a resume method.
            // For now, we simulate by changing the internal state
            setState(() {
              _currentSyncState = SyncState.idle; // Simulate unpausing
              _updateBPM();
            });
          } else {
            print('Tapped: Sync Engine control - Attempting to pause sync');
            // A real sync engine would have a pause method.
            setState(() {
              _currentSyncState = SyncState.paused; // Simulate pausing
              _updateBPM();
            });
          }
        } else {
          print('Tapped: Sync Engine not provided. Cannot control sync state.');
        }
      },
      onLongPress: () {
        print('Long Pressed: Debug panel not yet implemented');
        // TODO: Implement debug panel (future use)
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _NagadaPulsePainter(
            animation: _controller,
            drumbeatAnimation: _drumbeatAnimation,
            ecgAmplitudeAnimation: _ecgAmplitudeAnimation,
            backgroundPulseAnimation: _backgroundPulseAnimation,
            currentSyncState: _currentSyncState,
            themeData: themeData,
            outgoingEventCount: _outgoingEventCount,
            incomingEventCount: _incomingEventCount,
            lastSyncTimestamp: _lastSyncTimestamp,
            loadFactor: _currentLoadFactor, // Pass current load factor from state
          ),
        ),
      ),
    );
  }
}

class _NagadaPulsePainter extends CustomPainter {
  final Animation<double> animation;
  final Animation<double> drumbeatAnimation;
  final Animation<double> ecgAmplitudeAnimation;
  final Animation<double> backgroundPulseAnimation;
  final SyncState currentSyncState;
  final _PulseThemeData themeData;
  final int outgoingEventCount;
  final int incomingEventCount;
  final DateTime? lastSyncTimestamp;
  final double loadFactor;

  _NagadaPulsePainter({
    required this.animation,
    required this.drumbeatAnimation,
    required this.ecgAmplitudeAnimation,
    required this.backgroundPulseAnimation,
    required this.currentSyncState,
    required this.themeData,
    required this.outgoingEventCount,
    required this.incomingEventCount,
    this.lastSyncTimestamp,
    required this.loadFactor,
  }) : super(repaint: animation);

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    Color color = Colors.white,
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.normal,
    TextAlign textAlign = TextAlign.center,
  }) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
    );
    textPainter.layout();
    final textOffset = Offset(offset.dx - textPainter.width / 2, offset.dy); // Center horizontally
    textPainter.paint(canvas, textOffset);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    final double centerY = height / 2;

    // Background pulse (subtle)
    final backgroundPaint = Paint()
      ..shader = LinearGradient(
        colors: themeData.gradientColors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, width, height));

    canvas.drawOval(Rect.fromLTWH(0, 0, width, height), backgroundPaint);

    // Dimming overlay for disconnected state
    if (currentSyncState == SyncState.disconnected) {
      final dimPaint = Paint()..color = Colors.black.withOpacity(0.5); // 50% black overlay
      canvas.drawRect(Rect.fromLTWH(0, 0, width, height), dimPaint);
    }

    // Drumbeat effect (outer circle for classicNagada, inner glow for techPulse)
    if (drumbeatAnimation.value > 0.0 && currentSyncState != SyncState.paused) {
      final drumOpacity = 1.0 - drumbeatAnimation.value;
      double drumExpansionFactor = 0.1; // Default expansion

      if (outgoingEventCount > 0 && currentSyncState == SyncState.syncing) {
        drumExpansionFactor = 0.2; // More pronounced drumbeat for outgoing events during syncing
      }

      final drumRadius = (width / 2) * (1.0 + drumExpansionFactor * drumbeatAnimation.value);

      final drumPaint = Paint()
        ..color = themeData.drumbeatColor.withOpacity(drumOpacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(width / 2, centerY), drumRadius, drumPaint);
    }

    // ECG Waveform
    if (currentSyncState != SyncState.paused) {
      final ecgPaint = Paint()
        ..color = themeData.waveformColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      // Adjust color for error state
      if (currentSyncState == SyncState.error) {
        ecgPaint.color = Colors.redAccent;
      }

      final Path path = Path();
      path.moveTo(0, centerY);

      // Simulate ECG waveform based on animation value
      for (double i = 0; i <= width; i += 1.0) {
        double x = i;
        double y = centerY;
        double baseAmplitude = height * 0.1; // Base amplitude for ECG

        // Adjust amplitude based on loadFactor and incoming events
        double currentAmplitude = baseAmplitude * ecgAmplitudeAnimation.value;
        if (incomingEventCount > 0 && currentSyncState == SyncState.syncing) {
          currentAmplitude += baseAmplitude * 0.5 * loadFactor; // Increase amplitude with incoming events and load
        }
        if (currentSyncState == SyncState.error) {
          currentAmplitude *= 1.5; // More pronounced for error
        }

        // Simple sine wave for ECG effect
        // Systole: sharp spike, Diastole: falling waveform
        if (animation.value < 0.2) { // Rising phase (systole)
          y = centerY - currentAmplitude * sin(pi * animation.value * 5);
        } else if (animation.value < 0.5) { // Falling phase (diastole)
          y = centerY + currentAmplitude * sin(pi * (animation.value - 0.2) * 2.5);
        } else { // Return to baseline
          y = centerY;
        }

        // Apply some irregularity for error state
        if (currentSyncState == SyncState.error) {
          y += (sin(i / (width / 20) + animation.value * 20) * (currentAmplitude * 0.2)).toDouble();
        }

        // Make the wave flow across the screen
        final double waveSpeed = 2.0; // Adjust for faster/slower wave
        final double waveOffset = (animation.value * waveSpeed * width) % width;
        final double effectiveX = (x + width - waveOffset) % width;

        if (effectiveX == 0) { // If it wraps around, start a new segment or ensure continuity
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, ecgPaint);
    }

    // Pulsating glow for retrying state
    if (currentSyncState == SyncState.retrying) {
      final retryPaint = Paint()
        ..color = Colors.orangeAccent.withOpacity(0.3 * (0.5 + 0.5 * sin(animation.value * pi * 2))) // Pulsating effect
        ..style = PaintingStyle.fill;
      canvas.drawOval(Rect.fromLTWH(0, 0, width, height), retryPaint);
    }

    // Dim overlay for paused state
    if (currentSyncState == SyncState.paused) {
      final dimPaint = Paint()
        ..color = Colors.black.withOpacity(0.6);
      canvas.drawRect(Rect.fromLTWH(0, 0, width, height), dimPaint);
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'PAUSED',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: size.width * 0.15,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(minWidth: 0, maxWidth: width);
      textPainter.paint(canvas, Offset((width - textPainter.width) / 2, (height - textPainter.height) / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _NagadaPulsePainter oldDelegate) {
    return oldDelegate.animation != animation ||
           oldDelegate.drumbeatAnimation != drumbeatAnimation ||
           oldDelegate.ecgAmplitudeAnimation != ecgAmplitudeAnimation ||
           oldDelegate.backgroundPulseAnimation != backgroundPulseAnimation ||
           oldDelegate.currentSyncState != currentSyncState ||
           oldDelegate.themeData != themeData ||
           oldDelegate.outgoingEventCount != outgoingEventCount ||
           oldDelegate.incomingEventCount != incomingEventCount ||
           oldDelegate.lastSyncTimestamp != lastSyncTimestamp ||
           oldDelegate.loadFactor != loadFactor;
  }
}
