```
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'VideoEditor.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  ImagePicker _picker = ImagePicker();
  List links = [];
  List components = [];
  List controllers = [];

  Future<void> pickVideo() async {
    try {
      if(true){
        final XFile? pickedFile = await _picker.pickVideo(
          source: ImageSource.gallery,
        );
        if(pickedFile != null ){
          String videoLUri = pickedFile.path;
          VideoPlayerController getController = VideoPlayerController.file(File(videoLUri));
          await getController.initialize();
          controllers.add(getController);
          links.add(pickedFile.path);
          components.add(
            Container(
              margin: EdgeInsets.symmetric(vertical: 20),
              width: getController.value.size.width, height: getController.value.size.height,
              child: VideoPlayer(getController)
            )
          );
          setState(() {});
        }
      }
    } catch (e) {
    }
  }

  Future<void> editVideo(String videoLink) async {
    final updatedRes = await Navigator.push(context, MaterialPageRoute(builder: (context) {
      return EditVideoComponent(videoLink: videoLink);
    }));
    if(updatedRes != null && updatedRes is FinishedVideoData){
      int index = links.indexOf(videoLink);
      controllers[index].dispose();
      components[index] = Container();
      links[index] = '';

      VideoPlayerController getController = VideoPlayerController.file(File(updatedRes.url));
      await getController.initialize();
      setState(() {
        links.insert(index, updatedRes.url);
        controllers.insert(index, getController);
        components.insert(
          index,
          Container(
            margin: EdgeInsets.symmetric(vertical: 20),
            width: updatedRes.size.width, height: updatedRes.size.height,
            child: VideoPlayer(getController)
          )
        );
      });
    }
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: ListView(
          children: [
            ElevatedButton(
              onPressed: () => pickVideo(),
              child: Text('Pick Video')
            ),
            
            for(int i = 0; i < links.length; i++)
            Stack(
              children: [
                Positioned(
                  child: components[i]
                ),
                Positioned(
                  top: 15, right: 0.03 * getScreenWidth(),
                  child: Container(
                    width: 0.075 * getScreenWidth(),
                    height: 0.075 * getScreenWidth(),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: GestureDetector(
                      onTap: (){
                        links[i] = '';
                        components[i] = Container();
                        controllers[i].dispose();
                        setState(() {});
                      },
                      child: Icon(Icons.delete, size: 25, color: Colors.white)
                    )
                  )
                ),
                Positioned(
                  top: 15, right: 0.13 * getScreenWidth(),
                  child: Container(
                    width: 0.075 * getScreenWidth(),
                    height: 0.075 * getScreenWidth(),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: GestureDetector(
                      onTap: () => editVideo(links[i]),
                      child: Icon(Icons.edit, size: 25, color: Colors.white)
                    )
                  )
                ),
              ],
            )
          ],
        ),
      )
    );
  }
}
```