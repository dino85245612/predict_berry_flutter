import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:flutter_vision_example/BunchPosition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:pytorch_lite/pytorch_lite.dart';

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
  Image? displayImage;
  List<Uint8List>? listImage;
  List<ResultObjectDetection?> objDetect = [];
  late ClassificationModel _imageModel;
  // List<double?>? testIndex;

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
        imageFile != null ? Image.file(imageFile!) : const SizedBox(),
        // whiteImage != null ? Positioned(child: whiteImage!) : SizedBox(),
        listImage != null
            ? GridView.count(
                crossAxisCount: 5,
                children: createListImage(),
              )
            : SizedBox(),
        Align(
          alignment: Alignment.bottomCenter,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: pickImage,
                child: const Text("Pick image"),
              ),
              ElevatedButton(
                onPressed: yoloOnImage,
                child: const Text("Detect"),
              ),
              SizedBox(
                width: 8,
              ),
              ElevatedButton(
                onPressed: displayModifyImage,
                child: const Text("Modify"),
              )
            ],
          ),
        ),
        ...displayBoxesAroundRecognizedObjects(size),
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
      _imageModel = await PytorchLite.loadClassificationModel(
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

  Future<Image?> modifyImage(Map<String, dynamic> result,
      BunchPosition? bunchPosition, List<Uint8List> listTempImage) async {
    const double meanR = 0.485;
    const double meanG = 0.456;
    const double meanB = 0.406;
    const double stdR = 0.229;
    const double stdG = 0.224;
    const double stdB = 0.225;

    Uint8List byte = await imageFile!.readAsBytes();
    var image = img.decodeJpg(byte);
    image = image!.convert(format: img.Format.float64);

    print("Start to  modify picture");

    final x0 = result["box"][0].floor();
    final y0 = result["box"][1].floor();
    final x1 = result["box"][2].round();
    final y1 = result["box"][3].round();
    final width = x1 - x0;
    final height = y1 - y0;

    //!Painting white color
    if (result["tag"] == "berry") {
      final range = image?.getRange(x0, y0, width, height);
      while (range != null && range.moveNext()) {
        final pixel = range.current;
        pixel.r = pixel.maxChannelValue;
        pixel.g = pixel.maxChannelValue;
        pixel.b = pixel.maxChannelValue;
      }
    }

    //!Crop a image depends on bunch position.
    // Image copyCrop(Image src, { required int x, required int y, required int width, required int height, num radius = 0})
    image = img.copyCrop(
      image!,
      x: bunchPosition!.x0!,
      y: bunchPosition.y0!,
      width: bunchPosition.width(),
      height: bunchPosition.height(),
    );

    //!Resize to 224x224
    // Image copyResize(Image src, { int? width, int? height, bool? maintainAspect, Color? backgroundColor, Interpolation interpolation = Interpolation.nearest })
    image = img.copyResize(
      image,
      width: 224,
      height: 224,
      maintainAspect: false,
    );

    //! Normalize the image
    final rangeImage = image?.getRange(0, 0, imageWidth, imageHeight);
    while (rangeImage != null && rangeImage.moveNext()) {
      final pixel = rangeImage.current;
      //?For real modify variable
      // pixel.r = (((pixel.r).toDouble() / 255.0 - meanR) / stdR);
      // pixel.g = (((pixel.g).toDouble() / 255.0 - meanG) / stdG);
      // pixel.b = (((pixel.b).toDouble() / 255.0 - meanB) / stdB);

      //?For demo image.
      pixel.rNormalized = ((pixel.rNormalized - meanR) / stdR);
      pixel.gNormalized = ((pixel.gNormalized - meanG) / stdG);
      pixel.bNormalized = ((pixel.bNormalized - meanB) / stdB);
    }

    // image.convert(format: img.Format.uint8);

    Uint8List imageBytes = img.encodeJpg(image);
    runPredictModel(imageBytes);
    // listImage?.clear();
    listTempImage.add(imageBytes);

    setState(() {
      yoloResults.clear();
      displayImage = Image?.memory(imageBytes);
      listImage = listTempImage;
    });

    return displayImage;
  }

  Future<BunchPosition?> findPositionBunch(Map<String, dynamic> result) async {
    if (result["tag"] == "bunch") {
      var bunch = result["tag"];
      BunchPosition bunchPosition = BunchPosition(
        x0: result["box"][0].floor(),
        y0: result["box"][1].floor(),
        x1: result["box"][2].round(),
        y1: result["box"][3].round(),
      );

      print(
          "Position ${bunch}: ${bunchPosition.x0}, ${bunchPosition.x1}, ${bunchPosition.y0}, ${bunchPosition.y1}");

      return bunchPosition;
    } else {
      print("Not bunch.");
    }
    return null;
  }

  Future<void> displayModifyImage() async {
    // await modifyImage(yoloResults[0]);
    BunchPosition? bunchPosition = BunchPosition();

    await Future.wait(yoloResults.map((result) async {
      bunchPosition = await findPositionBunch(result);
    }));

    List<Uint8List> listTempImage = <Uint8List>[];
    await Future.wait(yoloResults.map((result) async {
      await modifyImage(result, bunchPosition, listTempImage);
    }));

    imageFile = null;
  }

  List<Widget> createListImage() {
    List<Widget> listImageWidget = <Widget>[];
    // print("buildListImage-> ${listImage?.length}");

    if (listImage != null) {
      for (int i = 0; i < listImage!.length; i++) {
        listImageWidget.add(Image.memory(listImage![i]));
      }
    }
    return listImageWidget;
  }

  Future<void> runPredictModel(Uint8List imageBytes) async {
    objDetect = [];

    String label = await _imageModel!.getImagePrediction(imageBytes);
    label = "${label ?? ""}";
    print("label -> ${label}");

    List<double?>? predictionList =
        await _imageModel.getImagePredictionList(imageBytes);
    // testIndex!.add(predictionList);
    // print(testIndex!.length);
    print("predictionList -> ${predictionList}");

    // List<double?>? predictionListProbabilities =
    //     await _imageModel!.getImagePredictionListProbabilities(imageBytes);
    // //Gettting the highest Probability
    // double maxScoreProbability = double.negativeInfinity;
    // double sumOfProbabilities = 0;
    // int index = 0;
    // for (int i = 0; i < predictionListProbabilities!.length; i++) {
    //   if (predictionListProbabilities[i]! > maxScoreProbability) {
    //     maxScoreProbability = predictionListProbabilities[i]!;
    //     sumOfProbabilities =
    //         sumOfProbabilities + predictionListProbabilities[i]!;
    //     index = i;
    //   }
    // }
    // print("predictionListProbabilities -> ${predictionListProbabilities}");
    // print("index -> ${index}");
    // print("sumOfProbabilities -> ${sumOfProbabilities}");
    // print("maxScoreProbability -> ${maxScoreProbability}");

    setState(() {
      //this.objDetect = objDetect;
      // _image = File(image.path);
    });
  }
}
