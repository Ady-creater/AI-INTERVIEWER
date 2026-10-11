import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraWidget extends StatefulWidget {
  final CameraController cameraController;
  const CameraWidget({super.key, required this.cameraController});

  @override
  State<CameraWidget> createState() => CameraWidgetState();
}

class CameraWidgetState extends State<CameraWidget> {
  bool toggleMic = true;
  bool toggleCam = true;
  @override
  Widget build(BuildContext context) {
    if (!widget.cameraController.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      body: Column(
        children: [
          Center(
            child: Container(
              margin: EdgeInsets.fromLTRB(3, 25, 3, 30),
              height: 300,
              width: 300,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadiusGeometry.circular(16),
                child: AspectRatio(
                  aspectRatio: 1 / widget.cameraController.value.aspectRatio,
                  child: CameraPreview(widget.cameraController),
                ),
              ),
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    toggleMic = !toggleMic;
                  });
                },
                icon: Icon(toggleMic ? Icons.mic : Icons.mic_off),
                iconSize: 35,
                style: IconButton.styleFrom(
                  backgroundColor: toggleMic ? Colors.blue : Colors.red,
                  elevation: 20,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadiusGeometry.circular(10),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    toggleCam = !toggleCam;
                  });
                },
                icon: Icon(toggleCam ? Icons.videocam : Icons.videocam_off),
                iconSize: 35,
                style: IconButton.styleFrom(
                  backgroundColor: toggleCam ? Colors.blue : Colors.red,
                  elevation: 20,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadiusGeometry.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
