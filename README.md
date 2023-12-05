# Custom Video Editor

Video editor designed for trimming and cropping videos.

## Features

* Crop

* Trim

## Custom video editor in display

![](https://github.com/joec05/files/blob/6798858f4c5441ec8f5a0ee994b22240d493fd91/custom_video_editor/video_editor_preview.gif?raw=true)

<br />

## How to use this package

In order to start editing a video, copy the code below and modify accordingly.

```dart
Future<void> editVideo(String videoLink) async {
    final updatedRes = await Navigator.push(context, MaterialPageRoute(builder: (context) {
      return EditVideoComponent(videoLink: videoLink);
    }));
    if(updatedRes != null && updatedRes is FinishedVideoData){
      VideoPlayerController getController = VideoPlayerController.file(File(updatedRes.url));
      await getController.initialize();
      controller = getController;
      width = updatedRes.size.width;
      height = updatedRes.size.height;
    }
}
```

