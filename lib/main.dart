// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'VideoEditor.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:device_info_plus/device_info_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Editor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final ImagePicker _picker = ImagePicker();

  Future<void> pickVideo() async {
    try {
      bool permissionIsGranted = false;
      ph.Permission? permission;
      if(Platform.isAndroid){
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if(androidInfo.version.sdkInt <= 32){
          permission = ph.Permission.storage;
        }else{
          permission = ph.Permission.photos;
        }
      }
      permissionIsGranted = await permission!.isGranted;
      if(!permissionIsGranted){
        await permission.request();
        permissionIsGranted = await permission.isGranted;
      }
      if(permissionIsGranted){
        final XFile? pickedFile = await _picker.pickVideo(
          source: ImageSource.gallery,
        );
        if(pickedFile != null){
          String videoUri = pickedFile.path;
          await editVideo(videoUri);
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> editVideo(String videoLink) async {
    final updatedRes = await Navigator.push(context, MaterialPageRoute(builder: (context) {
      return EditVideoComponent(videoLink: videoLink);
    }));
    if(updatedRes != null && updatedRes is FinishedVideoData){
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Save file to device', textAlign: TextAlign.center,),
            content: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: (){
                    Navigator.of(context).pop();
                    downloadFile(updatedRes.url);
                  }, 
                  child: const Text('Yes')
                ),
                ElevatedButton(
                  onPressed: (){
                    Navigator.of(context).pop();
                  }, child: const Text('No')
                )
              ],
            ),
          );
        }
      );
    }
  }

  void downloadFile(String url) async{
    Directory directory = await Directory('/storage/emulated/0/custom_video_editor').create(recursive: true);
    File originalFile = File(url);
    String filePath = '${directory.path}/${url.split('/').last}.mp4';
    await originalFile.copy(filePath).then((value){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File successfully saved to device!!!'),
          duration: Duration(seconds: 4),
        )
      );
    });
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Editor'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Color.fromARGB(255, 111, 211, 181), Color.fromARGB(255, 146, 63, 74), Color.fromARGB(255, 123, 129, 40)
              ],
              stops: [
                0.25, 0.5, 0.75
              ],
            ),
          ),
        )
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => pickVideo(),
              child: const Text('Pick Video')
            ),  
          ],
        ),
      )
    );
  }
}