import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:flutter_vision_example/yoloImage.dart';
import 'package:flutter_vision_example/yoloVideo.dart';
import 'package:image/image.dart' as image;

enum Options { none, imagev5, imagev8, imagev8seg, frame, tesseract, vision }

main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  runApp(
    const MaterialApp(
      home: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late FlutterVision vision;
  Options option = Options.none;
  @override
  void initState() {
    super.initState();
    vision = FlutterVision();
  }

  @override
  void dispose() async {
    super.dispose();
    await vision.closeTesseractModel();
    await vision.closeYoloModel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: task(option),
      floatingActionButton: SpeedDial(
        //margin bottom
        icon: Icons.menu, //icon on Floating action button
        activeIcon: Icons.close, //icon when menu is expanded on button
        backgroundColor: Colors.black12, //background color of button
        foregroundColor: Colors.white, //font color, icon color in button
        activeBackgroundColor:
            Colors.deepPurpleAccent, //background color when menu is expanded
        activeForegroundColor: Colors.white,
        visible: true,
        closeManually: false,
        curve: Curves.bounceIn,
        overlayColor: Colors.black,
        overlayOpacity: 0.5,
        buttonSize: const Size(56.0, 56.0),
        children: [
          SpeedDialChild(
            //speed dial child
            child: const Icon(Icons.video_call),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            label: 'Yolo on Frame',
            labelStyle: const TextStyle(fontSize: 18.0),
            onTap: () {
              setState(() {
                option = Options.frame;
              });
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.camera),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            label: 'YoloV5 on Image',
            labelStyle: const TextStyle(fontSize: 18.0),
            onTap: () {
              setState(() {
                option = Options.imagev5;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget task(Options option) {
    if (option == Options.frame) {
      return YoloVideo(vision: vision);
    }
    if (option == Options.imagev5) {
      return YoloImageV5(vision: vision);
    }
    return const Center(child: Text("Choose Task"));
  }
}

image.Image padToSquare(image.Image image, int size, Color color) {
  return image;
}

image.Image resize(image.Image image, int width, int height) {
  return image;
}

image.Image normalize(List<double> mean, List<double> std, image.Image image) {
  return image;
}

// Define your custom image transformation function
image.Image berryRemovingTransforms(image.Image inputImage) {
  // Pad to square with black padding
  int desiredSize = 224;
  inputImage = padToSquare(inputImage, desiredSize, Colors.white);

  // Resize the image
  inputImage = resize(inputImage, 224, 224);

  // Convert to Tensor
  // final tensor = TensorImage.fromImage(inputImage);

  // Normalize the image
  //todo by yourself
  // tensor.normalize(mean: [0.485, 0.456, 0.406], std: [0.229, 0.224, 0.225]);
  inputImage =
      normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225], inputImage);
  // Return the transformed image
  return inputImage;
}

// Image createCuttingInput(
//     List<int> berryBboxXyxy, List<int> selectedBunchBbox, Image bgrImage) {
//   // berryBboxXyxy = berryBboxXyxy.map((doubleValue) => doubleValue.toInt()).toList();
//   // Image targetImage = bgrImage;
//   // for (int y = berryBboxXyxy[1]; y < berryBboxXyxy[3]; y++) {
//   // for (int x = berryBboxXyxy[0]; x < berryBboxXyxy[2]; x++) {
//   // targetImage.setPixel(x, y, getColor(255, 255, 255));
//   // }
//   // }
//   berryBboxXyxy targetImage = targetImage.crop(selectedBunchBbox[0],
//       selectedBunchBbox[1], selectedBunchBbox[2], selectedBunchBbox[3]);
//   return berryRemovingTransforms(targetImage);
// }


