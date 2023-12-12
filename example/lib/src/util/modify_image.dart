import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_vision_example/src/model/bunch_position_model.dart';
import 'package:flutter_vision_example/src/util/model_prediction.dart';
import 'package:image/image.dart' as img;
import 'package:pytorch_lite/pytorch_lite.dart';

Future<Map<int, dynamic>> modifyImage({
  required Map<String, dynamic> result,
  required BunchPositionModel? bunchPosition,
  required List<Uint8List> listTempImage,
  required File? imageFile,
  required int imageWidth,
  required int imageHeight,
  required ClassificationModel imageModel,
}) async {
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
    image,
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
  listTempImage.add(imageBytes);
  List<List<double>> listOfPredictionNumber =
      await runPredictModel(imageBytes: imageBytes, imageModel: imageModel);

  // displayImage = Image?.memory(imageBytes);
  // listImage = listTempImage;

  print("Yoloresult = ${result}");

  Map<int, dynamic> output = {};
  output[0] = listTempImage;
  output[1] = listOfPredictionNumber;

  return output;
}
