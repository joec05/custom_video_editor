import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter/log.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:ffmpeg_kit_flutter/statistics.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';

enum EditType{
  crop, trim, none,
}

class FinishedVideoData {
  final String url;
  final Size size;

  FinishedVideoData(this.url, this.size);
}

class EditVideoComponent extends StatelessWidget {
  const EditVideoComponent({super.key, required this.videoLink});
  final String videoLink;

  @override
  Widget build(BuildContext context){
    return EditVideoComponentState(videoLink: videoLink);
  }
}

class EditVideoComponentState extends StatefulWidget{
  final String videoLink;

  const EditVideoComponentState({super.key, required this.videoLink});
  
  @override
  State<EditVideoComponentState> createState() => VideoEditorState();
}

class VideoEditorState extends State<EditVideoComponentState> {
  double draggableSliderWidth = 2;
  double trimmerHeight = 40;
  double circularTogglerDiameter = 17.5;
  double totalTrimmerSize = getScreenWidth() * 0.85 ;
  double ballDiameter = 20.0;
  ValueNotifier<List> thumbnails = ValueNotifier([]);
  late ValueNotifier<VideoPlayerController> playerController;
  double sizeScale = 0;
  int totalVideoDuration = 0;
  late double appBarHeight;
  ValueNotifier<double> draggedLeftTrim = ValueNotifier(0);
  ValueNotifier<double> draggedWidthTrim = ValueNotifier(getScreenWidth() * 0.85) ;
  ValueNotifier<double> startTrimmedDuration = ValueNotifier(0);
  ValueNotifier<double> endTrimmedDuration = ValueNotifier(0);
  bool leftLastDragged = true;
  ValueNotifier<double> draggedWidthCrop = ValueNotifier(0);
  ValueNotifier<double> draggedTopCrop = ValueNotifier(0);
  ValueNotifier<double> draggedLeftCrop = ValueNotifier(0);
  ValueNotifier<double> draggedHeightCrop = ValueNotifier(0);
  ValueNotifier<double> videoWidth = ValueNotifier(0);
  ValueNotifier<double> videoHeight = ValueNotifier(0);
  ValueNotifier<double> currentWidthCrop = ValueNotifier(0);
  ValueNotifier<double> currentHeightCrop = ValueNotifier(0);
  ValueNotifier<double> currentTopCrop = ValueNotifier(0);
  ValueNotifier<double> currentLeftCrop = ValueNotifier(0);
  ValueNotifier<EditType> currentEditType = ValueNotifier(EditType.none);
  ValueNotifier<bool> videoIsPlaying = ValueNotifier(false);
  double linesWidth = 2;
  double linesHeight = 2;
  double cropBallSize = 20;
  double trimBallSize = 15;
  Color lineColor = Colors.grey;
  double limitCroppedSize = 50;
  ValueNotifier<double> currentPosition = ValueNotifier(0);
  ValueNotifier<double> trimDraggedLeft = ValueNotifier(0);
  ValueNotifier<double> trimDraggedRight = ValueNotifier(0);
  ValueNotifier<double> trimLeftDraggedLeft = ValueNotifier(0);
  ValueNotifier<double> trimRightDraggedLeft = ValueNotifier(0);
  double thumbnailImgWidth = (getScreenWidth() / ((getScreenWidth() / 50).floor())) * 0.85;
  ValueNotifier<int> progressPercentage = ValueNotifier(0);
  ValueNotifier<double> totalSliderWidth = ValueNotifier(0);

  @override
  void initState(){
    super.initState();
    appBarHeight = 0;
    initializeController();
    loadThumbnails();
    playerController.value.addListener(() {
      if(playerController.value.value.position.inMilliseconds.toInt() >= endTrimmedDuration.value.toInt()){
        if(playerController.value.value.position.inMilliseconds.toInt() >= playerController.value.value.duration.inMilliseconds.toInt()){
          playerController.value.play();
        }
        playerController.value.seekTo(Duration(milliseconds: startTrimmedDuration.value.toInt()));
      }
      if(playerController.value.value.isPlaying){
        videoIsPlaying.value = true;
      }else{
        videoIsPlaying.value = false;
      }
      currentPosition.value = (playerController.value.value.position.inMilliseconds / totalVideoDuration);
    });
    trimDraggedLeft.value = min(max(draggedLeftTrim.value + (getScreenWidth() - totalTrimmerSize) / 2 - draggableSliderWidth / 2 , (getScreenWidth() - totalTrimmerSize) / 2 - draggableSliderWidth / 2), totalTrimmerSize + (getScreenWidth() - totalTrimmerSize) / 2 - draggableSliderWidth / 2);
    trimDraggedRight.value = min(max((getScreenWidth() - totalTrimmerSize) / 2 + totalTrimmerSize - draggedLeftTrim.value - draggedWidthTrim.value , (getScreenWidth() - totalTrimmerSize) / 2 - draggableSliderWidth / 2), totalTrimmerSize + (getScreenWidth() - totalTrimmerSize) / 2 - draggableSliderWidth / 2);
    trimLeftDraggedLeft.value = draggedLeftTrim.value + (getScreenWidth() - totalTrimmerSize) / 2 - draggableSliderWidth / 2;
    trimRightDraggedLeft.value = min(draggedLeftTrim.value +draggedWidthTrim.value+ (getScreenWidth() - totalTrimmerSize) / 2 - draggableSliderWidth / 2 + draggableSliderWidth, totalTrimmerSize + (getScreenWidth() - totalTrimmerSize) / 2 + draggableSliderWidth / 2) ;
    totalSliderWidth.value = totalTrimmerSize;
  }

  Future<void> loadThumbnails() async {
    try {
      final int thumbnailCount = (getScreenWidth() / 50).floor();
      final int thumbnailInterval = totalVideoDuration ~/ thumbnailCount;
      List generateThumbnails = [];
      for (int i = 0; i < thumbnailCount; i++) {
        final Uint8List? thumbnail = await VideoThumbnail.thumbnailData(
          video: widget.videoLink,
          imageFormat: ImageFormat.JPEG,
          timeMs: i * thumbnailInterval,
          quality: 100,
        );
        if(thumbnail != null){
          generateThumbnails.add(thumbnail);
        }
      }
      thumbnails.value = generateThumbnails;
    } catch (e) {
      print('Error generating thumbnails: $e');
    }
  }

  Size getSizeScale(degrees, width, height, screenWidth, screenHeight){
    double targetWidth = screenWidth;
    double targetHeight = screenHeight;

    double scaleWidth = targetWidth / width;
    double scaleHeight = targetHeight / height;

    double scale = scaleWidth < scaleHeight ? scaleWidth : scaleHeight;
    sizeScale = scale;

    double resizedWidth = width * scale;
    double resizedHeight = height * scale;

    return Size(resizedWidth, resizedHeight);
  }
  
  void initializeController() async{
    playerController = ValueNotifier(VideoPlayerController.file(File(widget.videoLink)));
    await playerController.value.initialize();
    Size newSize = getSizeScale(0, playerController.value.value.size.width, playerController.value.value.size.height, getScreenWidth(), getScreenHeight());
    videoWidth.value = newSize.width;
    videoHeight.value = newSize.height;
    draggedWidthCrop.value = newSize.width;
    draggedHeightCrop.value = newSize.height;
    currentWidthCrop.value = newSize.width;
    currentHeightCrop.value = newSize.height;
    totalVideoDuration = playerController.value.value.duration.inMilliseconds.toInt();
    endTrimmedDuration.value = playerController.value.value.duration.inMilliseconds.toDouble();
  }

  String _formatDuration(Duration duration) {
    String hours = (duration.inHours).toString().padLeft(2, '0');
    String minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    String seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

    if (hours == '00') {
      return '$minutes:$seconds';
    } else {
      return '$hours:$minutes:$seconds';
    }
  }

  Offset applyCropComponentTranslateOffset(){
    double width = currentWidthCrop.value;
    double height = currentHeightCrop.value;
    double left = currentLeftCrop.value;
    double top = currentTopCrop.value;
    return Offset((videoWidth.value - width)/2 - left, (videoHeight.value - height)/2 -top);
  }

  Widget croppedVideoComponent(child){
    return Center(
      child: Stack(
        children: [
          Positioned(
            child: child
          ),
          Positioned(
            top: 0, left: 0,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(width: 0, color: Colors.white),
                color: Colors.white
              ),
              width: currentLeftCrop.value,
              height: currentTopCrop.value,
            )
          ),
          Positioned(
            top: 0, left: currentLeftCrop.value,
            child: Container(
              width: currentWidthCrop.value,
              height: currentTopCrop.value,
              decoration: BoxDecoration(
                border: Border.all(width: 0, color: Colors.white),
                color: Colors.white
              )
            )
          ),
          Positioned(
            top: 0, left: currentLeftCrop.value + currentWidthCrop.value,
            child: Container(
              width: max(0, videoWidth.value - (currentLeftCrop.value + currentWidthCrop.value)),
              height: currentHeightCrop.value + currentTopCrop.value,
              decoration: BoxDecoration(
                border: Border.all(width: 0, color: Colors.white),
                color: Colors.white
              ),
            )
          ),
          Positioned(
            top: currentTopCrop.value, left: 0,
            child: Container(
              width: currentLeftCrop.value,
              height: max(0, videoHeight.value - (currentTopCrop.value)),
              decoration: BoxDecoration(
                border: Border.all(width: 0, color: Colors.white),
                color: Colors.white
              ),
            )
          ),
          Positioned(
            top: currentTopCrop.value + currentHeightCrop.value, left: currentLeftCrop.value,
            child:Container(
              width: currentWidthCrop.value,
              height: max(0, videoHeight.value - (currentTopCrop.value + currentHeightCrop.value)),
              decoration: BoxDecoration(
                border: Border.all(width: 0, color: Colors.white),
                color: Colors.white
              ),
            )
          ),
          Positioned(
            top: currentTopCrop.value + currentHeightCrop.value, left: currentLeftCrop.value + currentWidthCrop.value,
            child: Container(
              width: max(0, videoWidth.value - (currentLeftCrop.value + currentWidthCrop.value)),
              height: max(0, videoHeight.value - (currentTopCrop.value + currentHeightCrop.value)),
              decoration: BoxDecoration(
                border: Border.all(width: 0, color: Colors.white),
                color: Colors.white
              ),
            )
          ),
        ]
      )
    );
  }

  Widget cropRectangleComponent(){
    return Transform.translate(
      offset: applyCropComponentTranslateOffset(),
      child: Stack(
        children: <Widget>[
          Positioned(
            child: Stack(
              children: [
                Positioned(
                  child: croppedVideoComponent(
                    Container(
                      width: videoWidth.value,
                      height: videoHeight.value,
                      child: VideoPlayer(playerController.value),
                    )
                  )
                ),
                Positioned(
                  top: currentTopCrop.value, left: currentLeftCrop.value,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.5)
                    ),
                    width: draggedLeftCrop.value - currentLeftCrop.value,
                    height: draggedTopCrop.value - currentTopCrop.value,
                  )
                ),
                Positioned(
                  top: draggedTopCrop.value, left: currentLeftCrop.value,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.5)
                    ),
                    width: draggedLeftCrop.value - currentLeftCrop.value,
                    height: draggedHeightCrop.value,
                  )
                ),
                Positioned(
                  top: draggedTopCrop.value + draggedHeightCrop.value, left: currentLeftCrop.value,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.5)
                    ),
                    width: max(0, (draggedLeftCrop.value - currentLeftCrop.value)),
                    height: max(0, currentHeightCrop.value - (draggedTopCrop.value - currentTopCrop.value) - draggedHeightCrop.value),
                  )
                ),
                Positioned(
                  top: currentTopCrop.value, left: draggedLeftCrop.value,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.5)
                    ),
                    width: draggedWidthCrop.value,
                    height: draggedTopCrop.value - currentTopCrop.value,
                  )
                ),
                Positioned(
                  top: draggedTopCrop.value + draggedHeightCrop.value, left: draggedLeftCrop.value,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.5)
                    ),
                    width: max(0, draggedWidthCrop.value),
                    height: max(0, currentHeightCrop.value - (draggedTopCrop.value - currentTopCrop.value) - draggedHeightCrop.value),
                  )
                ),
                Positioned(
                  top: currentTopCrop.value, left: draggedLeftCrop.value + draggedWidthCrop.value,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.5)
                    ),
                    width: max(0, currentWidthCrop.value - (draggedLeftCrop.value - currentLeftCrop.value) - draggedWidthCrop.value),
                    height: max(0, draggedTopCrop.value - currentTopCrop.value),
                  )
                ),
                Positioned(
                  top: draggedTopCrop.value, left: draggedLeftCrop.value + draggedWidthCrop.value,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.5)
                    ),
                    width: max(0, currentWidthCrop.value - (draggedLeftCrop.value - currentLeftCrop.value) - draggedWidthCrop.value),
                    height: max(0, draggedHeightCrop.value)
                  )
                ),
                Positioned(
                  top: draggedTopCrop.value + draggedHeightCrop.value, left: draggedLeftCrop.value + draggedWidthCrop.value,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.5)
                    ),
                    width: max(0, currentWidthCrop.value - (draggedLeftCrop.value - currentLeftCrop.value) - draggedWidthCrop.value),
                    height: max(0, currentHeightCrop.value - (draggedTopCrop.value - currentTopCrop.value) - draggedHeightCrop.value),
                  )
                ),
              ]
            ),
          ),
          Positioned(
            left: draggedLeftCrop.value - (cropBallSize-linesWidth)/2,
            top: draggedTopCrop.value + draggedHeightCrop.value/2 - (cropBallSize-linesHeight)/2 ,
            child: GestureDetector(
              onPanUpdate: (details){
                draggedLeftCrop.value += details.delta.dx;
                draggedWidthCrop.value -= details.delta.dx;
                draggedLeftCrop.value = max(currentLeftCrop.value, min(draggedLeftCrop.value, currentWidthCrop.value - limitCroppedSize + currentLeftCrop.value));
                draggedWidthCrop.value = max(limitCroppedSize, min(draggedWidthCrop.value, currentWidthCrop.value));
              },
              child: Container(
                width: cropBallSize,
                height: cropBallSize,
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle
                ),
              )
            )
          ),
          Positioned(
            left: draggedLeftCrop.value + draggedWidthCrop.value/2 - (cropBallSize-linesWidth)/2,
            top: draggedTopCrop.value - (cropBallSize-linesHeight)/2,
            child: GestureDetector(
              onPanUpdate: (details){
                draggedTopCrop.value += details.delta.dy;
                draggedHeightCrop.value -= details.delta.dy;
                draggedTopCrop.value = max(currentTopCrop.value, min(draggedTopCrop.value, currentHeightCrop.value - limitCroppedSize + currentTopCrop.value));
                draggedHeightCrop.value = max(limitCroppedSize, min(draggedHeightCrop.value, currentHeightCrop.value));
              },
              child: Container(
                width: cropBallSize,
                height: cropBallSize,
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle
                ),
              )
            )
          ),    
          Positioned(
            left: draggedLeftCrop.value + draggedWidthCrop.value - (cropBallSize-linesWidth)/2 - linesWidth,
            top: draggedTopCrop.value + draggedHeightCrop.value/2 - (cropBallSize-linesHeight)/2 ,
            child: GestureDetector(
              onPanUpdate: (details) {
                if(draggedWidthCrop.value + details.delta.dx + draggedLeftCrop.value <= currentWidthCrop.value + currentLeftCrop.value){
                  draggedWidthCrop.value += details.delta.dx;
                  draggedWidthCrop.value = max(limitCroppedSize, min(draggedWidthCrop.value, currentWidthCrop.value));
                }
              },
              child: Container(
                width: cropBallSize,
                height: cropBallSize,
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle
                ),
              )
            )
          ),
          Positioned(
            left: draggedLeftCrop.value + draggedWidthCrop.value/2 - (cropBallSize-linesWidth)/2,
            top: draggedTopCrop.value + draggedHeightCrop.value - (cropBallSize-linesHeight)/2 - linesHeight,
            child: GestureDetector(
              onPanUpdate: (details) {
                if(draggedHeightCrop.value + details.delta.dy + draggedTopCrop.value <= currentHeightCrop.value + currentTopCrop.value){
                  draggedHeightCrop.value += details.delta.dy;
                  draggedHeightCrop.value = max(draggedHeightCrop.value, limitCroppedSize);
                }
              },
              child: Container(
                width: cropBallSize,
                height: cropBallSize,
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle
                ),
              )
            )
          ),
          Positioned(
            child: croppedVideoComponent(
              Container(
                width: videoWidth.value,
                height: videoHeight.value,
              )
            )
          ),
        ],
      )
    );
  }

  Widget trimComponent(){
    return Center(
      child: Container(
        height: trimmerHeight,
        child: Row(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    left: (getScreenWidth() - totalTrimmerSize) / 2 - draggableSliderWidth / 2 ,
                    right: (getScreenWidth() - totalTrimmerSize) / 2 - draggableSliderWidth / 2,
                    child: thumbnailsList()
                  ),
                  Positioned(
                    left: trimDraggedLeft.value,
                    right: trimDraggedRight.value,
                    child: Container(
                      height: trimmerHeight
                    )
                  ),
                  Positioned(
                    left: (getScreenWidth() - totalTrimmerSize) / 2 - draggableSliderWidth / 2 + (playerController.value.value.position.inMilliseconds / totalVideoDuration) * totalTrimmerSize,
                    child: Container(
                      width: 2.5,
                      color: Colors.black,
                      height: trimmerHeight,
                    ) 
                  ),
                  Positioned(
                    left: (getScreenWidth() - totalTrimmerSize) / 2 - draggableSliderWidth / 2 ,
                    child: Container(
                      color: Colors.grey.withOpacity(0.5),
                      width: draggedLeftTrim.value,
                      height: trimmerHeight
                    )
                  ),
                  Positioned(
                    right: (getScreenWidth() - totalTrimmerSize) / 2 - draggableSliderWidth / 2,
                    child: Container(
                      color: Colors.grey.withOpacity(0.5),
                      width: max(0, totalTrimmerSize - draggedLeftTrim.value - draggedWidthTrim.value),
                      height: trimmerHeight
                    )
                  ),
                  Positioned(
                    left: trimDraggedLeft.value- trimBallSize / 2,
                    top: (trimmerHeight - trimBallSize) / 2,
                    child: GestureDetector(
                      onPanUpdate: (details){
                        if(draggedLeftTrim.value + details.delta.dx >= 0){
                          draggedLeftTrim.value += details.delta.dx;
                          draggedWidthTrim.value -= details.delta.dx;
                          draggedWidthTrim.value = max(0, draggedWidthTrim.value);
                          startTrimmedDuration.value =(draggedLeftTrim.value / (totalSliderWidth.value)) * totalVideoDuration;
                          currentPosition.value = startTrimmedDuration.value;
                          endTrimmedDuration.value = ((draggedWidthTrim.value+ draggedLeftTrim.value) / (totalSliderWidth.value)) * totalVideoDuration;
                          trimDraggedLeft.value = min(max(draggedLeftTrim.value + (getScreenWidth() - totalTrimmerSize) / 2 - draggableSliderWidth / 2 , (getScreenWidth() - totalTrimmerSize) / 2 - draggableSliderWidth / 2), totalTrimmerSize + (getScreenWidth() - totalTrimmerSize) / 2 - draggableSliderWidth / 2);
                          trimDraggedRight.value = min(max((getScreenWidth() - totalTrimmerSize) / 2 + totalTrimmerSize - draggedLeftTrim.value - draggedWidthTrim.value , (getScreenWidth() - totalTrimmerSize) / 2 - draggableSliderWidth / 2), totalTrimmerSize + (getScreenWidth() - totalTrimmerSize) / 2 - draggableSliderWidth / 2);
                          trimLeftDraggedLeft.value = draggedLeftTrim.value + (getScreenWidth() - totalTrimmerSize) / 2 - draggableSliderWidth / 2 ;
                          print('$startTrimmedDuration is start durationyy');
                        }
                      },
                      onPanEnd: (details){
                        playerController.value.seekTo(Duration(milliseconds: startTrimmedDuration.value.toInt()));
                        playerController.value.play();
                      },
                      child: Container(
                        width: trimBallSize,
                        height: trimBallSize,
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle
                        ),
                      )
                    )
                  ),
                  Positioned(
                    left: trimRightDraggedLeft.value - trimBallSize / 2,
                    top: (trimmerHeight - trimBallSize) / 2,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        if(draggedLeftTrim.value + draggedWidthTrim.value + details.delta.dx <= totalTrimmerSize){
                          draggedWidthTrim.value += details.delta.dx;
                          draggedWidthTrim.value = max(0, draggedWidthTrim.value);
                          endTrimmedDuration.value = ((draggedWidthTrim.value+draggedLeftTrim.value) / (totalSliderWidth.value)) * totalVideoDuration;
                          trimDraggedLeft.value = min(max(draggedLeftTrim.value + (getScreenWidth() - totalTrimmerSize) / 2 - draggableSliderWidth / 2 , (getScreenWidth() - totalTrimmerSize) / 2 - draggableSliderWidth / 2), totalTrimmerSize + (getScreenWidth() - totalTrimmerSize) / 2 - draggableSliderWidth / 2);
                          trimDraggedRight.value = min(max((getScreenWidth() - totalTrimmerSize) / 2 + totalTrimmerSize - draggedLeftTrim.value - draggedWidthTrim.value , (getScreenWidth() - totalTrimmerSize) / 2 - draggableSliderWidth / 2), totalTrimmerSize + (getScreenWidth() - totalTrimmerSize) / 2 - draggableSliderWidth / 2);
                          trimRightDraggedLeft.value = min(draggedLeftTrim.value +draggedWidthTrim.value+ (getScreenWidth() - totalTrimmerSize) / 2 - draggableSliderWidth / 2 + draggableSliderWidth, totalTrimmerSize + (getScreenWidth() - totalTrimmerSize) / 2 + draggableSliderWidth / 2) ;
                          print('$endTrimmedDuration is end');
                        }
                      },
                      onPanEnd: (details){
                        playerController.value.seekTo(Duration(milliseconds: startTrimmedDuration.value.toInt()));
                        playerController.value.play();
                      },
                      child: Container(
                        width: trimBallSize,
                        height: trimBallSize,
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle
                        ),
                      )
                    )
                  ),
                ],
              )
            )
          ]
        )
      )
    );
  }

  Widget thumbnailsList(){
    return Container(
      decoration: BoxDecoration(border: Border.all(width: 1, color: Colors.black)),
      height: trimmerHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        itemCount: thumbnails.value.length,
        itemBuilder: (context, i){
          return Image.memory(thumbnails.value[i], width: thumbnailImgWidth, height: trimmerHeight);
        }
      )
    );
  }

  Future<String> _createFolderInAppDocDir() async {
    Directory directory = await getApplicationDocumentsDirectory();
    final Directory directoryPathFolder = Directory('${directory.path}/output/');
    return '${directoryPathFolder.path}/${Uuid().v4()}.mp4';
  }

  Duration millisecondsToDuration(double milliseconds) {
    int microseconds = (milliseconds * 1000).toInt();
    int hours = microseconds ~/ Duration.microsecondsPerHour;
    microseconds -= hours * Duration.microsecondsPerHour;
    int minutes = microseconds ~/ Duration.microsecondsPerMinute;
    microseconds -= minutes * Duration.microsecondsPerMinute;
    int seconds = microseconds ~/ Duration.microsecondsPerSecond;
    microseconds -= seconds * Duration.microsecondsPerSecond;
    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      microseconds: microseconds,
    );
  }

  Future<void> saveTrimmedVideo() async {
    playerController.value.pause();
    Timer.periodic(const Duration(milliseconds: 1000), (Timer timer) async{
      timer.cancel();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_){
          return ValueListenableBuilder<int>(
            valueListenable: progressPercentage,
            builder: (context, int percentage, child) {
              return AlertDialog(
                title: Text('Please wait...'),
                content: Container(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(
                        height: getScreenHeight() * 0.025,
                      ),
                      Text('$percentage%')
                    ]
                  )
                )
              );
                }
          );
        }
      );
      String inputFilePath = await copyVideoToTempDirectory();
      String startTime = millisecondsToDuration(startTrimmedDuration.value).toString();
      String endTime =  millisecondsToDuration(endTrimmedDuration.value).toString();
      String outputFilePath = await _createFolderInAppDocDir();
      String currentMessage = '';
      FFmpegKit.executeAsync('-y -i "$inputFilePath" -ss $startTime -to $endTime -filter:v "crop=${draggedWidthCrop.value / sizeScale}:${draggedHeightCrop.value / sizeScale}:${draggedLeftCrop.value / sizeScale}:${draggedTopCrop.value / sizeScale}" "$outputFilePath"', (session) async {
        FFmpegKitConfig.enableLogCallback((log) async{
          final message = log.getMessage();
          currentMessage = '';
          debugPrint(message);
        });

        final returnCode = await session.getReturnCode();
        if (ReturnCode.isSuccess(returnCode)) {
          Navigator.of(context).pop();
          Navigator.pop(context, FinishedVideoData(
            outputFilePath,
            Size(currentWidthCrop.value, currentHeightCrop.value)
          ));
        } else if (ReturnCode.isCancel(returnCode)) {
          Navigator.of(context).pop();
          showDialog(
            context: context,
            builder: (_){
              return AlertDialog(
                title: Text('Process has been cancelled'),
                content: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Ok')
                )
              );
            }
          );
        } else {
          Navigator.of(context).pop();
          showDialog(
            context: context,
            builder: (_){
              return AlertDialog(
                title: Text(currentMessage),
                content: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Ok')
                )
              );
            }
          );
        }
        
        Timer.periodic(const Duration(milliseconds: 1000), (Timer timer) async{
          timer.cancel();
          progressPercentage.value = 0;
        });
      }, (Log log) {},
      (Statistics statistics) {
        int timeInMilliseconds = statistics.getTime();
        if (timeInMilliseconds > 0) {
          progressPercentage.value = ((
            (timeInMilliseconds/1000).round() * 1000) / 
            (((endTrimmedDuration.value - startTrimmedDuration.value) /1000).round() * 1000) 
          * 100).round();
        }
      });
    });
  }

  Future<String> copyVideoToTempDirectory() async {
    Directory directory = await getTemporaryDirectory();
    final Directory directoryPathFolder = Directory('${directory.path}/${Uuid().v4()}.mp4');
    File originalFile = File(widget.videoLink);
    File newFile = await originalFile.copy(directoryPathFolder.path);
    return newFile.path;
  }

  void dispose(){
    super.dispose();
    playerController.value.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    appBarHeight = MediaQuery.of(context).padding.top + kToolbarHeight;
    return ValueListenableBuilder<EditType>(
      valueListenable: currentEditType,
      builder: (context, EditType editType, child) {
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: const [
                Text(
                  'Video Editor',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              editType == EditType.crop ?
                Container(
                  child: ElevatedButton(
                    onPressed: (){
                      currentTopCrop.value = draggedTopCrop.value;
                      currentLeftCrop.value = draggedLeftCrop.value;
                      currentWidthCrop.value = draggedWidthCrop.value;
                      currentHeightCrop.value = draggedHeightCrop.value;
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        side: BorderSide.none,
                        borderRadius: BorderRadius.circular(0),
                      ),
                    ),  
                    child: Text('Crop')
                  ),
                )
              : Container(),
              Container(
                child: ElevatedButton(
                  onPressed: (){
                    saveTrimmedVideo();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      side: BorderSide.none,
                      borderRadius: BorderRadius.circular(0),
                    ),
                  ),  
                  child: Text('Done')
                )
              )
            ]
          ),
          body: Center(
            child: ValueListenableBuilder<double>(
              valueListenable: videoHeight,
              builder: (context, double videoHeight, child) {
                return ValueListenableBuilder<double>(
                  valueListenable: videoWidth,
                  builder: (context, double videoWidth, child) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        editType == EditType.none ?
                          Flexible(
                            child: Container(
                              height: 0.8 * getScreenHeight() - appBarHeight,
                              child: Transform.translate(
                                offset: applyCropComponentTranslateOffset(),
                                child: croppedVideoComponent(
                                  Container(
                                    width: videoWidth,
                                    height: videoHeight,
                                    child: VideoPlayer(playerController.value),
                                  )
                                )
                              )
                            )
                          )
                        : editType == EditType.trim ?
                          Flexible(
                            child: Container(
                              height: 0.7 * getScreenHeight() - appBarHeight,
                              child: Transform.translate(
                                offset: applyCropComponentTranslateOffset(),
                                child: croppedVideoComponent(
                                  Container(
                                    width: videoWidth,
                                    height: videoHeight,
                                    child: VideoPlayer(playerController.value),
                                  )
                                )
                              )
                            )
                          )
                        : editType == EditType.crop ?
                          Flexible(
                            child: Container(
                              height: 0.8 * getScreenHeight() - appBarHeight,
                              child: Center(
                                child: ValueListenableBuilder<double>(
                                  valueListenable: currentTopCrop,
                                  builder: (context, double topCurrentValue, child) {
                                    return ValueListenableBuilder<double>(
                                      valueListenable: currentHeightCrop,
                                      builder: (context, double heightCurrentValue, child) {
                                        return ValueListenableBuilder<double>(
                                          valueListenable: currentLeftCrop,
                                          builder: (context, double leftCurrentValue, child) {
                                            return ValueListenableBuilder<double>(
                                              valueListenable: currentWidthCrop,
                                              builder: (context, double widthCurrentValue, child) {
                                                return ValueListenableBuilder<double>(
                                                  valueListenable: draggedTopCrop,
                                                  builder: (context, double topCropValue, child) {
                                                    return ValueListenableBuilder<double>(
                                                      valueListenable: draggedHeightCrop,
                                                      builder: (context, double heightCropValue, child) {
                                                        return ValueListenableBuilder<double>(
                                                          valueListenable: draggedLeftCrop,
                                                          builder: (context, double leftCropValue, child) {
                                                            return ValueListenableBuilder<double>(
                                                              valueListenable: draggedWidthCrop,
                                                              builder: (context, double widthCropValue, child) {
                                                                return Column(
                                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                                  children: [
                                                                    cropRectangleComponent()
                                                                  ]
                                                                );
                                                              }
                                                            );
                                                          }
                                                        );
                                                      }
                                                    );
                                                  }
                                                );
                                              }
                                            );
                                          }
                                        );
                                      }
                                    );
                                  }
                                )
                              )
                            )
                          )
                        : Container(),
                        Column(
                          children: [
                            editType == EditType.trim ?
                              Container(
                                height: 0.1 * getScreenHeight(),
                                child: ValueListenableBuilder<List>(
                                  valueListenable: thumbnails,
                                  builder: (context, List thumbnails, Widget? child) {
                                    return ValueListenableBuilder<double>(
                                      valueListenable: draggedLeftTrim,
                                      builder: (context, double leftTrimmed, child) {
                                        return ValueListenableBuilder<double>(
                                          valueListenable: draggedWidthTrim,
                                          builder: (context, double widthTrimmed, child) {
                                            return ValueListenableBuilder<double>(
                                              valueListenable: currentPosition,
                                              builder: (context, double position, child) {
                                                return ValueListenableBuilder<double>(
                                                  valueListenable: trimDraggedLeft,
                                                  builder: (context, double trimmedLeft, child) {
                                                    return ValueListenableBuilder<double>(
                                                      valueListenable: trimDraggedRight,
                                                      builder: (context, double trimmedRight, child) {
                                                        return ValueListenableBuilder<double>(
                                                          valueListenable: trimLeftDraggedLeft,
                                                          builder: (context, double trimLeftDraggedLeft, child) {
                                                            return ValueListenableBuilder<double>(
                                                              valueListenable: trimRightDraggedLeft,
                                                              builder: (context, double trimRightDraggedLeft, Widget? child) {
                                                                return ValueListenableBuilder<double>(
                                                                  valueListenable: totalSliderWidth,
                                                                  builder: (context, double totalSliderWidth, Widget? child) {
                                                                    return Column(
                                                                      children: [
                                                                        trimComponent(),
                                                                      ],
                                                                    );
                                                                  }
                                                                );
                                                              }
                                                            );
                                                          }
                                                        );
                                                      }
                                                    );
                                                  }
                                                );
                                              }
                                            );
                                          }
                                        );
                                      }
                                    );
                                  }
                                )
                              )
                            : Container(),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: getScreenWidth() * 0.05),
                              height: 0.1 * getScreenHeight(),
                              width: double.infinity,
                              decoration: BoxDecoration(border: Border(bottom: BorderSide(width: 2, color: Color.fromARGB(255, 88, 64, 64)), top: BorderSide(width: 2, color: Color.fromARGB(255, 88, 64, 64)))),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  editType == EditType.trim ?
                                    Expanded(
                                      child: ValueListenableBuilder<double>(
                                        valueListenable: startTrimmedDuration,
                                        builder: (context, double startDuration, child) {
                                          return Text(_formatDuration(Duration(milliseconds: startDuration.toInt())));
                                        }
                                      )
                                    )
                                  : Container(),
                                  Expanded(
                                    flex: 4,
                                    child: ValueListenableBuilder<bool>(
                                      valueListenable: videoIsPlaying,
                                      builder: (context, bool isPlaying, child) {
                                        return GestureDetector(
                                          onTap: (){
                                            if(isPlaying){
                                              playerController.value.pause();
                                            }else{
                                              playerController.value.play();
                                            }
                                          },
                                          child: isPlaying ?
                                            Icon(Icons.pause, size: 30)
                                          : Icon(Icons.play_arrow, size: 30)
                                        );
                                      }
                                    )
                                  ),
                                  editType == EditType.trim ?
                                    Expanded(
                                      child: ValueListenableBuilder<double>(
                                        valueListenable: endTrimmedDuration,
                                        builder: (context, double endDuration, child) {
                                          return Text(_formatDuration(Duration(milliseconds: endDuration.toInt())));
                                        }
                                      )
                                    )
                                  : Container(),
                                ]
                              )
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(getScreenWidth() * 0.0125),
                                  color: editType == EditType.crop ? Colors.grey : Colors.transparent,
                                  margin: EdgeInsets.symmetric(horizontal: 0.015* getScreenWidth(), vertical: 0.015 * getScreenHeight()),
                                  child: InkWell(
                                    onTap: () {
                                      currentEditType.value = EditType.crop;
                                    },
                                    child: const Icon(
                                      Icons.crop,
                                      size: 30,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.all(getScreenWidth() * 0.0125),
                                  color: editType == EditType.trim ? Colors.grey : Colors.transparent,
                                  margin: EdgeInsets.symmetric(horizontal: 0.015* getScreenWidth(), vertical: 0.015 * getScreenHeight()),
                                  child: InkWell(
                                    onTap: () {
                                      currentEditType.value = EditType.trim;
                                    },
                                    child: const Icon(
                                      Icons.cut,
                                      size: 30,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          ]
                        )
                      ]
                    );
                  }
                );
              }
            )
          )
        );
      }
    );
  }
}

double getScreenHeight(){
  return PlatformDispatcher.instance.views.first.physicalSize.height / PlatformDispatcher.instance.views.first.devicePixelRatio;
}

double getScreenWidth(){
  return PlatformDispatcher.instance.views.first.physicalSize.width / PlatformDispatcher.instance.views.first.devicePixelRatio;
}
