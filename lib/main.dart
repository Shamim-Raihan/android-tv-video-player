import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fullscreen landscape for Android TV
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const TvVideoApp());
}

class TvVideoApp extends StatelessWidget {
  const TvVideoApp({super.key});

  @override
  Widget build(BuildContext ctx) {
    return const MaterialApp(
      title: 'Video Uttara RPO',
      debugShowCheckedModeBanner: false,
      home: VideoPlayerScreen(),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with WidgetsBindingObserver {
  static const String _assetVideoPath = 'assets/videos/video.mp4';
  static const String _fallbackNetworkUrl =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';

  VideoPlayerController? _controller;
  bool _hasError = false;
  String _errorMsg = '';
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _keepScreenAwake();
    _initPlayer();
  }

  Future<void> _keepScreenAwake() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {}
  }

  Future<void> _initPlayer() async {
    _retryTimer?.cancel();
    setState(() {
      _hasError = false;
      _errorMsg = '';
    });

    try {
      // Dispose previous controller first to free up TV hardware decoder
      final oldController = _controller;
      _controller = null;
      await oldController?.dispose();

      VideoPlayerController controller;

      // Check if local asset video exists using lightweight AssetManifest
      bool assetExists = false;
      try {
        final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
        assetExists = manifest.listAssets().contains(_assetVideoPath);
      } catch (_) {
        assetExists = false;
      }

      if (assetExists) {
        controller = VideoPlayerController.asset(_assetVideoPath);
      } else {
        controller = VideoPlayerController.networkUrl(
          Uri.parse(_fallbackNetworkUrl),
        );
      }

      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(1.0);
      await controller.play();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMsg = e.toString();
      });

      // Auto retry after 5s if failed (e.g. network reconnection)
      _retryTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) _initPlayer();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.resumed) {
      _controller!.play();
      _keepScreenAwake();
    } else if (state == AppLifecycleState.paused) {
      _controller!.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    _controller?.dispose();
    WakelockPlus.disable().ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_hasError) {
      return Center(
        child: Text(
          'Error loading video. Retrying...\n$_errorMsg',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white24,
          strokeWidth: 2,
        ),
      );
    }

    final size = ctrl.value.size;

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: size.width > 0 ? size.width : 1920,
          height: size.height > 0 ? size.height : 1080,
          child: VideoPlayer(ctrl),
        ),
      ),
    );
  }
}
