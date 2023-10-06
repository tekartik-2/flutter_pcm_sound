import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';

enum LogLevel {
  none,
  error,
  standard,
  verbose,
}

class FlutterPcmSound {
  static const MethodChannel _channel = const MethodChannel('flutter_pcm_sound/methods');

  static Function(int)? onFeedSamplesCallback;

  static LogLevel _logLevel = LogLevel.standard;

  /// set log level
  static Future<void> setLogLevel(int level) async {
    return await _invokeMethod('setLogLevel', {'log_level': level});
  }

  /// setup audio
  /// audioBufferMultiply: (android-only) You can control the size of the audio buffer 
  ///    that android uses with this argument. Valid range is 1.0 - 3.0 (typical)
  static Future<void> setup({required int sampleRate, required int channelCount, double androidBufferMultiply = 1.0}) async {
    return await _invokeMethod('setup', {
      'sample_rate': sampleRate,
      'num_channels': channelCount,
      'android_buffer_multiply': androidBufferMultiply,
    });
  }

  /// start playback
  static Future<void> play() async {
    return await _invokeMethod('play');
  }

  /// suspend playback, but does *not* clear queued samples
  static Future<void> pause() async {
    return await _invokeMethod('pause');
  }

  /// suspend playback & clear queued samples
  static Future<void> stop() async {
    return await _invokeMethod('stop');
  }

  /// clear queued samples
  static Future<void> clear() async {
    return await _invokeMethod('clear');
  }

  /// queue 16-bit samples (little endian)
  static Future<void> feed(PcmArrayInt16 buffer) async {
    return await _invokeMethod('feed', {'buffer': buffer.bytes.buffer.asUint8List()});
  }

  /// set the threshold at which we call the
  /// feed callback. i.e. if we have less than X
  /// queued frames, the feed callback will be invoked
  static Future<void> setFeedThreshold(int threshold) async {
    return await _invokeMethod('setFeedThreshold', {'feed_threshold': threshold});
  }

  /// callback is invoked when the audio buffer
  /// is in danger of running out of queued samples
  static void setFeedCallback(Function(int) callback) {
    onFeedSamplesCallback = callback;
    _channel.setMethodCallHandler(_methodCallHandler);
  }

  /// get the number of queued samples remaining
  static Future<int> remainingFrames() async {
    return await _invokeMethod('remainingFrames');
  }

  /// release all audio resources
  static Future<void> release() async {
    return await _invokeMethod('release');
  }

  static Future<T?> _invokeMethod<T>(String method, [dynamic arguments]) async {
    if (_logLevel.index >= LogLevel.standard.index) {
      String args = '';
      if (method == 'feed') {
        Uint8List data = arguments['buffer'];
        if (data.lengthInBytes > 6) {
          args = '(${data.lengthInBytes ~/ 2} samples) ${data.sublist(0, 6)} ...';
        } else {
          args = '(${data.lengthInBytes ~/ 2} samples) $data';
        }
      } else if (arguments != null) {
        args = arguments.toString();
      }
      print("[PCM] invoke: $method $args");
    }
    return await _channel.invokeMethod(method, arguments);
  }

  static Future<dynamic> _methodCallHandler(MethodCall call) async {
    if (_logLevel.index >= LogLevel.standard.index) {
      String func = '[[ ${call.method} ]]';
      String args = call.arguments.toString();
      print("[PCM] $func $args");
    }
    switch (call.method) {
      case 'OnFeedSamples':
        int remainingFrames = call.arguments["remaining_frames"];
        if (onFeedSamplesCallback != null) {
          onFeedSamplesCallback!(remainingFrames);
        }
        break;
      default:
        print('Method not implemented');
    }
  }
}

class PcmArrayInt16 {
  final ByteData bytes;

  PcmArrayInt16({required this.bytes});

  factory PcmArrayInt16.zeros({required int count}) {
    Uint8List list = Uint8List(count * 2);
    return PcmArrayInt16(bytes: list.buffer.asByteData());
  }

  factory PcmArrayInt16.empty() {
    return PcmArrayInt16.zeros(count: 0);
  }

  factory PcmArrayInt16.fromList(List<int> list) {
    var byteData = ByteData(list.length * 2);
    for (int i = 0; i < list.length; i++) {
      byteData.setInt16(i * 2, list[i], Endian.host);
    }
    return PcmArrayInt16(bytes: byteData);
  }

  operator [](int idx) {
    int vv = bytes.getInt16(idx * 2, Endian.host);
    return vv;
  }

  operator []=(int idx, int value) {
    return bytes.setInt16(idx * 2, value, Endian.host);
  }
}
