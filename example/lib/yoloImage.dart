import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:flutter_vision_example/screen/screen_berry_remove.dart';
import 'package:flutter_vision_example/screen/screen_list_berry_remove.dart';
import 'package:flutter_vision_example/src/model/bunch_position_model.dart';
import 'package:flutter_vision_example/src/util/modify_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:pytorch_lite/pytorch_lite.dart';

import 'src/util/model_prediction.dart';

class YoloImageV5 extends StatefulWidget {
  final FlutterVision vision;
  const YoloImageV5({Key? key, required this.vision}) : super(key: key);

  @override
  State<YoloImageV5> createState() => _YoloImageV5State();
}

class _YoloImageV5State extends State<YoloImageV5> {
  late List<Map<String, dynamic>> yoloResults;
  File? imageFile;
  int imageHeight = 1;
  int imageWidth = 1;
  bool isLoaded = false;
  List<Uint8List>? listImage;
  late ClassificationModel imageModel;
  List<List<double>> listOfPredictionNumber = [];
  int? indexBerryRemove;
  int countingBerry = 0;
  bool isLoadingDetect = false;
  bool isLoadingPredict = false;

  @override
  void initState() {
    super.initState();
    loadPredictModel();
    loadYoloModel().then((value) {
      setState(() {
        yoloResults = [];
        isLoaded = true;
      });
    });
  }

  @override
  void dispose() async {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    if (!isLoaded) {
      return const Scaffold(
        body: Center(
          child: Text("Model not loaded, waiting for it"),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Align(
              alignment: Alignment.topCenter,
              child: Column(
                // mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DefaultTextStyle.merge(
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      child: Text('Number of Berries: ${countingBerry}')),
                ],
              )),
        ),
        imageFile != null
            ? Image.file(
                imageFile!,
              )
            : const SizedBox(),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: pickImage,
                      child: const Text("Pick image"),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          isLoadingDetect = true;
                        });
                        await yoloOnImage();
                        setState(() {
                          isLoadingDetect = false;
                        });
                      },
                      child: isLoadingDetect
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : const Text("Detect"),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          isLoadingPredict = true;
                        });
                        await displayModifyImage();
                        setState(() {
                          isLoadingPredict = false;
                        });
                      },
                      child: isLoadingPredict
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : const Text("Predict"),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    displayBerryRemove(index: indexBerryRemove),
                    SizedBox(
                      width: 8,
                    ),
                    displayListBerryRemove(listBerry: listImage),
                  ],
                )
              ],
            ),
          ),
        ),
        //! show boxes result
        // ...displayBoxesAroundRecognizedObjects(size),
        if (indexBerryRemove != null)
          ...displayBoxesAroundRecognizedObjectsBerryShouldBeRemove(size)
      ],
    );
  }

  Future<void> loadYoloModel() async {
    await widget.vision.loadYoloModel(
        labels: 'assets/labels_berry.txt',
        modelPath: 'assets/yolov5s_2cls15_fp16_640.tflite',
        modelVersion: "yolov5",
        quantization: false,
        numThreads: 2,
        useGpu: true);
    setState(() {
      isLoaded = true;
    });
  }

  Future loadPredictModel() async {
    String pathImageModel = "assets/predict_model.pt";
    try {
      imageModel = await PytorchLite.loadClassificationModel(
          pathImageModel, 224, 224, 2,
          labelPath: "assets/labels_predict.txt");
      print("Load model successful");
    } catch (e) {
      if (e is PlatformException) {
        print("only supported for android, Error is $e");
      } else {
        print("Error is $e");
      }
    }
  }

  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();
    // Capture a photo
    final XFile? photo = await picker.pickImage(source: ImageSource.gallery);
    if (photo != null) {
      setState(() {
        imageFile = File(photo.path);
      });
    }
  }

  yoloOnImage() async {
    yoloResults.clear();
    Uint8List byte = await imageFile!.readAsBytes();
    final image = await decodeImageFromList(byte);
    imageHeight = image.height;
    imageWidth = image.width;
    final result = await widget.vision.yoloOnImage(
        bytesList: byte,
        imageHeight: image.height,
        imageWidth: image.width,
        iouThreshold: 0.8,
        confThreshold: 0.4,
        classThreshold: 0.5);
    if (result.isNotEmpty) {
      setState(() {
        yoloResults = result;
        print("Yoloresult = ${yoloResults}");
      });
    }
  }

  List<Widget> displayBoxesAroundRecognizedObjects(Size screen) {
    if (yoloResults.isEmpty) return [];

    double factorX = screen.width / (imageWidth);
    double imgRatio = imageWidth / imageHeight;
    double newWidth = imageWidth * factorX;
    double newHeight = newWidth / imgRatio;
    double factorY = newHeight / (imageHeight);
    double pady = (screen.height - newHeight) / 2;

    Color colorPick = const Color.fromARGB(255, 50, 233, 30);
    print("------------------------");
    print("Yoloresult = ${yoloResults}");
    print("------------------------");
    return yoloResults.map((result) {
      return Positioned(
        left: result["box"][0] * factorX,
        top: result["box"][1] * factorY + pady,
        width: (result["box"][2] - result["box"][0]) * factorX,
        height: (result["box"][3] - result["box"][1]) * factorY,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(10.0)),
            border: Border.all(color: Colors.pink, width: 2.0),
          ),
          child: Text(
            "${result['tag']} ${(result['box'][4] * 100).toStringAsFixed(0)}%",
            style: TextStyle(
              background: Paint()..color = colorPick,
              color: Colors.white,
              fontSize: 18.0,
            ),
          ),
        ),
      );
    }).toList();
  }

  Future<BunchPositionModel?> findPositionBunch(
      Map<String, dynamic> result) async {
    int x0Bunch = 0;
    int y0Bunch = 0;
    int x1Bunch = 0;
    int y1Bunch = 0;

    if (result["tag"] == "bunch") {
      // var bunch = result["tag"];
      x0Bunch = result["box"][0].floor();
      y0Bunch = result["box"][1].floor();
      x1Bunch = result["box"][2].floor();
      y1Bunch = result["box"][3].floor();

      // print(
      // "Position ${bunch}: ${bunchPosition.x0}, ${bunchPosition.x1}, ${bunchPosition.y0}, ${bunchPosition.y1}");
    } else {
      print("Not bunch.");
    }
    BunchPositionModel bunchPosition = BunchPositionModel(
      x0: x0Bunch,
      y0: y0Bunch,
      x1: x1Bunch,
      y1: y1Bunch,
    );

    return bunchPosition;
  }

  Future<void> displayModifyImage() async {
    BunchPositionModel? bunchPosition = BunchPositionModel();
    List<Uint8List> listTempImage = <Uint8List>[];
    Map<int, dynamic> resultModify = {};
    int tempCountingBerry = 0;

    // yoloOnImage();

    await Future.wait(yoloResults.map((result) async {
      bunchPosition = await findPositionBunch(result);
    }));

    await Future.wait(yoloResults.map((result) async {
      if (result["tag"] == "berry") {
        tempCountingBerry += 1;
      }
      resultModify = await modifyImage(
          result: result,
          bunchPosition: bunchPosition,
          listTempImage: listTempImage,
          imageFile: imageFile,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
          imageModel: imageModel);
      listImage = resultModify[0];
    }));

    int index = foundMaxValueinList(resultModify[1]);

    setState(() {
      indexBerryRemove = index;
      countingBerry = tempCountingBerry;
    });
    print("countingBerry-> ${tempCountingBerry}");
    // imageFile = null;
  }

  Widget displayBerryRemove({required int? index}) {
    print("index = ${index}");
    if (listImage != null && index != null) {
      Uint8List bytePredictBerry = listImage![index];

      setState(() {
        // listImage = null;
      });
      return ElevatedButton(
        onPressed: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: ((context) =>
                      ScreenBerryRemove(bytePredictBerry: bytePredictBerry))));
        },
        child: const Text("Berry Remove"),
      );
    }
    setState(() {
      // listImage = null;
    });
    return SizedBox.shrink();
  }

  Widget displayListBerryRemove({required List<Uint8List>? listBerry}) {
    if (listImage != null && listBerry != null) {
      setState(() {
        // listImage = null;
      });
      return ElevatedButton(
        onPressed: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: ((context) =>
                      ListBerryRemoveScreen(listImage: listBerry))));
        },
        child: const Text("List Berry"),
      );
    }
    setState(() {
      // listImage = null;
    });
    return SizedBox.shrink();
  }

  List<Widget> displayBoxesAroundRecognizedObjectsBerryShouldBeRemove(
    Size screen,
  ) {
    if (yoloResults.isEmpty) return [];

    double factorX = screen.width / (imageWidth);
    double imgRatio = imageWidth / imageHeight;
    double newWidth = imageWidth * factorX;
    double newHeight = newWidth / imgRatio;
    double factorY = newHeight / (imageHeight);
    double pady = (screen.height - newHeight) / 2;

    print("------------------------");
    print("Yoloresult = ${yoloResults[indexBerryRemove!]}");
    print("YoloresultIndex = ${indexBerryRemove}");
    print("------------------------");

    // Choose only the YOLO result at index
    Map<String, dynamic>? resultAtIndex = yoloResults[indexBerryRemove!];

    if (resultAtIndex != null) {
      return [
        Positioned(
          left: resultAtIndex["box"][0] * factorX,
          top: resultAtIndex["box"][1] * factorY + pady,
          width: (resultAtIndex["box"][2] - resultAtIndex["box"][0]) * factorX,
          height: (resultAtIndex["box"][3] - resultAtIndex["box"][1]) * factorY,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(10.0)),
              border: Border.all(color: Colors.pink, width: 2.0),
            ),
          ),
        ),
      ];
    } else {
      return [];
    }
  }
}
