import 'package:flutter/material.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';

class VideoEditScreen extends StatefulWidget {
  final File videoFile;

  VideoEditScreen({required this.videoFile});

  @override
  _VideoEditScreenState createState() => _VideoEditScreenState(videoFile: videoFile);
}

class _VideoEditScreenState extends State<VideoEditScreen> {
  VideoPlayerController? _videoPlayerController;
  final File videoFile;
  final FlutterFFmpeg _flutterFFmpeg = FlutterFFmpeg();
  List<File> _thumbnails = [];
  double _duration = 30.0;
  bool _isLoading = false;
  bool _isPlaying = false;

  double _leftBarPosition = 0;
  double _rightBarPosition = 328;
  double _currentStartTime = 0;
  double _currentEndTime = 0;

  _VideoEditScreenState({required this.videoFile});

  @override
  void initState() {
    super.initState();
    _videoPlayerController = VideoPlayerController.file(videoFile)
      ..initialize().then((_) {
        setState(() {
          _duration = _videoPlayerController!.value.duration.inSeconds.toDouble();
          final double containerWidth = MediaQuery.of(context).size.width - 40;
          const double rightBarOffset = 22.0;
          _rightBarPosition = containerWidth - rightBarOffset;
        });
        _generateThumbnails();
      });
  }

  Future<void> _cropVideo() async {
    if (_duration < 5.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Bu video 5 saniyeden kısa. Kırpma işlemi gerçekleştirilemez."),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    String outputPath = '${widget.videoFile.parent.path}/output_cropped_video.mp4';

    String command = "-i ${widget.videoFile.path} -ss $_currentStartTime -to $_currentEndTime -c:v libx264 -preset ultrafast -crf 30 $outputPath";

    // FFmpeg işlemi için bekleme
    await Future.delayed(const Duration(seconds: 13));

    int result = await _flutterFFmpeg.execute(command);
    setState(() {
      _isLoading = false;
    });

    if (result == 0) {
      print("Video başarıyla kırpıldı.");
      await _saveVideoToGallery(outputPath);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Kırpma işlemi tamamlandı."),
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      print("Video kırpma hatası: $result");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Video kırpma hatası."),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _saveVideoToGallery(String videoPath) async {
    final file = File(videoPath);

    if (await file.exists()) {
      print('Video dosyası bulundu, kaydetmeye çalışıyorum...');

      final result = await PhotoManager.editor.saveVideo(file, title: "");

      if (result != null) {
        print('Video başarıyla galeriye kaydedildi: ${result.id}');
      } else {
        print('Video galeriye kaydedilemedi. Geri dönüş null.');
      }
    } else {
      print('Video dosyası bulunamadı: $videoPath');
    }
  }

  Future<void> _generateThumbnails() async {
    setState(() {
      _isLoading = true;
    });

    String outputDir = '${videoFile.parent.path}/thumbnails';
    Directory(outputDir).createSync();

    double duration = _videoPlayerController!.value.duration.inSeconds.toDouble();

    if (duration < 10) {
      duration = 10;
    }

    List<String> commands = [];
    for (int i = 0; i < 10; i++) {
      double timePoint = duration * (i / 10);
      commands.add("-ss $timePoint -i ${videoFile.path} -vframes 1 $outputDir/output${i + 1}.jpg");
    }

    for (String command in commands) {
      await _flutterFFmpeg.execute(command);
    }

    List<File> thumbnails = Directory(outputDir)
        .listSync()
        .where((file) => file.path.endsWith(".jpg"))
        .map((file) => File(file.path))
        .toList();

    setState(() {
      _thumbnails = thumbnails;
      _isLoading = false;
    });
  }

  void _togglePlayPause() {
    setState(() {
      if (_isPlaying) {
        _videoPlayerController?.pause();
      } else {
        _videoPlayerController?.play();
      }
      _isPlaying = !_isPlaying;
    });
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    super.dispose();
  }

  Future<void> _updateCurrentFrame() async {
    final double videoPosition = (_leftBarPosition / (MediaQuery.of(context).size.width - 40)) * _duration;
    await _videoPlayerController?.pause();
    await _videoPlayerController?.seekTo(Duration(seconds: videoPosition.toInt()));
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    final double containerWidth = MediaQuery.of(context).size.width - 40;
    final double videoDuration = _videoPlayerController != null && _videoPlayerController!.value.isInitialized
        ? _videoPlayerController!.value.duration.inSeconds.toDouble()
        : 0;

    _currentStartTime = (_leftBarPosition / containerWidth) * videoDuration;
    _currentEndTime = (_rightBarPosition / containerWidth) * videoDuration;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Video Kırp"),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cut),
            onPressed: _cropVideo,
          ),
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: _togglePlayPause,
          ),
        ],
      ),
      body: Column(
        children: [
          Flexible(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8, // Genişliği %80 yap
              height: MediaQuery.of(context).size.height * 0.7, // Yüksekliği %30 yap
              child: _videoPlayerController != null && _videoPlayerController!.value.isInitialized
                  ? VideoPlayer(_videoPlayerController!)
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),

          SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center, // Ortala
            children: [
              // Soldaki zaman göstergesi
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  "${_currentStartTime.toStringAsFixed(1)}s",
                  style: const TextStyle(color: Colors.grey), // Rengi gri yap
                ),
              ),
              // Dar bir Container
              Container(
                width: 65, // Genişliği buradan ayarlayabilirsin
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Sağdaki zaman göstergesi
                    Text(
                      "|  ${_currentEndTime.toStringAsFixed(1)}s", // Gerekli boşluk kaldırıldı
                      style: const TextStyle(color: Colors.grey), // Rengi gri yap
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 5),

          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20.0),
            height: 70,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 4),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10.0,
                  spreadRadius: 5.0,
                ),
              ],
            ),
            child: Stack(
              children: [
                Row(
                  children: _thumbnails.map((thumbnail) {
                    return Expanded(
                      child: Container(
                        child: Image.file(
                          thumbnail,
                          fit: BoxFit.cover,
                          height: 90,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                Positioned(
                  left: _leftBarPosition,
                  bottom: 0,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        double newValue = _leftBarPosition + details.delta.dx;
                        if (newValue >= 0 && newValue <= (_rightBarPosition - 17)) {
                          _leftBarPosition = newValue;
                          // Yeni başlangıç zamanını hesapla
                          _currentStartTime = (_leftBarPosition / containerWidth) * videoDuration;
                          _updateCurrentFrame(); // Çerçeveyi güncelle
                        }
                      });
                    },
                    child: Container(
                      width: 17,
                      height: 65,
                      color: Colors.white,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 3,
                            height: 20,
                            color: Colors.grey,
                          ),
                          SizedBox(width: 4),
                          Container(
                            width: 3,
                            height: 20,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: _rightBarPosition,
                  bottom: 0,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        double newValue = _rightBarPosition + details.delta.dx;
                        if (newValue <= containerWidth && newValue >= (_leftBarPosition + 17)) {
                          _rightBarPosition = newValue;
                          // Yeni bitiş zamanını hesapla
                          _currentEndTime = (_rightBarPosition / containerWidth) * videoDuration;
                        }
                      });
                    },
                    child: Container(
                      width: 17,
                      height: 65,
                      color: Colors.white,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 3,
                            height: 20,
                            color: Colors.grey,
                          ),
                          SizedBox(width: 4),
                          Container(
                            width: 3,
                            height: 20,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: null,
    );
  }
}
