import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

void main() {
  runApp(MaterialApp(home: CallScreen()));
}

class CallScreen extends StatefulWidget {
  @override
  _CallScreenState createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    _initializeRenderers().then((_) {
      _createPeerConnection().then((pc) {
        _peerConnection = pc;
      }).catchError((e) {
        print('Error creating peer connection: $e');
      });
    }).catchError((e) {
      print('Error initializing renderers: $e');
    });
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _peerConnection?.dispose();
    _localStream?.dispose();
    super.dispose();
  }

  Future<void> _initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    print('Renderers initialized');
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    final Map<String, dynamic> configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    };

    final Map<String, dynamic> offerSdpConstraints = {
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': true,
      },
      'optional': [],
    };

    RTCPeerConnection pc = await createPeerConnection(configuration, offerSdpConstraints);

    _localStream = await _getUserMedia().catchError((e) {
      print('Error getting user media: $e');
    });

    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        pc.addTrack(track, _localStream!);
      });
      _localRenderer.srcObject = _localStream;
      print('Local stream assigned to local renderer');
    }

    pc.onAddStream = (MediaStream stream) {
      _remoteRenderer.srcObject = stream;
      print('Remote stream received');
    };

    return pc;
  }

  Future<MediaStream> _getUserMedia() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'mandatory': {
          'minWidth': '640',
          'minHeight': '480',
          'minFrameRate': '30',
        },
        'facingMode': 'user',
        'optional': [],
      }
    };

    MediaStream stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    print('Got user media: ${stream.id}');
    return stream;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('WebRTC Client')),
      body: Column(
        children: [
          Expanded(
            child: RTCVideoView(_localRenderer, mirror: true),
          ),
          Expanded(
            child: RTCVideoView(_remoteRenderer),
          ),
        ],
      ),
    );
  }
}
