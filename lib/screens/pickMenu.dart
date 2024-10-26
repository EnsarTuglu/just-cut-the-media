import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:tektektrimmer/screens/videos/videoEdit.dart';
import 'package:video_player/video_player.dart';
import '../database_helper.dart';

class PickMenu extends StatefulWidget {
  @override
  _PickMenuState createState() => _PickMenuState();
}

class PickMenus extends StatelessWidget {
  const PickMenus({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pick Menu'),
      ),
      body: Center(
        child: Text('This is the Pick Menu screen!'),
      ),
    );
  }
}

class _PickMenuState extends State<PickMenu> {
  VideoPlayerController? _videoPlayerController;
  File? _video;
  File? _image;
  final picker = ImagePicker();
  int _selectedIndex = 0;
  final FlutterFFmpeg _flutterFFmpeg = FlutterFFmpeg();

  Future<void> _pickVideoFromGallery() async {
    final video = await picker.pickVideo(source: ImageSource.gallery);

    if (video != null) {
      _video = File(video.path);
      // Video edit ekranına geçiş
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => VideoEditScreen(videoFile: _video!)),
      );
    }
  }



  Future<void> _pickImageFromGallery() async {
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      // Resmi seçtikten sonra hemen kırpma işlemini başlat
      await _cropImage(image.path);
    }
  }

  Future<void> _cropImage(String path) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Resmi Kırp',
          toolbarColor: Colors.white,
          toolbarWidgetColor: Colors.black, // Burayı siyah yapıyoruz
          activeControlsWidgetColor: Colors.black,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: 'Resmi Kırp',
          cancelButtonTitle: 'İptal',
          doneButtonTitle: 'Tamam',
        ),
      ],
    );

    if (croppedFile != null) {
      setState(() {
        _image = File(croppedFile.path); // Kırpılan resmi kaydet
      });

      await _saveImageToGallery(croppedFile.path);
    }
  }

  Future<void> _saveImageToGallery(String imagePath) async {
    try {
      final assetEntity = await PhotoManager.editor.saveImageWithPath(imagePath);
      if (assetEntity != null) {
        print('Resim başarıyla galeriye kaydedildi.');

        // Veritabanına kaydet
        await DatabaseHelper().insertTaslak({
          'media_id': assetEntity.id.toString(),
          'media_type': 'image',
          'media_url': imagePath
        });

        print('Veritabanına kaydedildi: $imagePath');
      } else {
        print('Resim galeriye kaydedilemedi.');
      }
    } catch (e) {
      print('Hata: $e');
    }
  }

  Future<void> _captureVideoWithCamera() async {
    final video = await picker.pickVideo(source: ImageSource.camera);

    if (video != null) {
      _video = File(video.path);

      // Video çekildikten sonra VideoEditScreen'e yönlendir
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoEditScreen(videoFile: _video!),
        ),
      );
    }
  }
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 1) {
        _pickVideoFromGallery();
      } else if (index == 2) {
        _captureVideoWithCamera();
      } else {
        _closeVideo();
      }
    });
  }

  void _closeVideo() {
    setState(() {
      _video = null;
      _videoPlayerController?.dispose();
      _videoPlayerController = null;
      _image = null; // Resmi kapatma işlemi
    });
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text(
            "Quick Cut App",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.deepPurple,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.cut, color: Colors.white),
              onPressed: () {
                // Makas simgesine tıklama işlemi
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            // Geçişli arka plan
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple, Colors.blue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Column(
              children: [
                if (_video != null && _videoPlayerController != null)
                  _videoPlayerController!.value.isInitialized
                      ? Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        height: MediaQuery.of(context).size.height * 0.7,
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: VideoPlayer(_videoPlayerController!),
                        ),
                      ),
                      Positioned(
                        top: 20,
                        right: 20,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: _closeVideo,
                        ),
                      ),
                    ],
                  )
                      : Container()
                else if (_image != null) // Eğer resim varsa göster
                  Container(
                    width: double.infinity,
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: Image.file(_image!, fit: BoxFit.cover), // Resmi ekle
                  )
                else
                  Expanded(
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Oval dikdörtgen
                          Container(
                            height: 205,
                            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 30),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildButton(Icons.video_collection_outlined, _pickVideoFromGallery),
                                    const SizedBox(width: 20),
                                    _buildButton(Icons.image, _pickImageFromGallery), // Resim ikonu
                                    const SizedBox(width: 20),
                                    _buildButton(Icons.camera_alt, _captureVideoWithCamera),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  "Yeni Oluştur +",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home, color: Colors.white),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.photo_library, color: Colors.white),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt, color: Colors.white),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person, color: Colors.white),
              label: '',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white,
          backgroundColor: Colors.deepPurple,
          type: BottomNavigationBarType.fixed,
          onTap: _onItemTapped,
        ),
      ),
    );
  }

  Widget _buildButton(IconData icon, Function onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(10),
      child: IconButton(
        iconSize: 60,
        icon: Icon(icon),
        onPressed: () => onPressed(),
      ),
    );
  }
}
