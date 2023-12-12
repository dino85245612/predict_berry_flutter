import 'dart:typed_data';

import 'package:pytorch_lite/pytorch_lite.dart';

Future<List<List<double>>> runPredictModel({
  required Uint8List imageBytes,
  required ClassificationModel imageModel,
}) async {
  // List<ResultObjectDetection?> objDetect = [];
  List<List<double>> listOfPredictionNumber = [];

  // String label = await imageModel.getImagePrediction(imageBytes);
  // label = "${label ?? ""}";
  // print("label -> ${label}");

  List<double>? predictionList =
      await imageModel.getImagePredictionList(imageBytes);

  listOfPredictionNumber.add(predictionList);

  return listOfPredictionNumber;
}

int foundMaxValueinList(List<List<double>> list) {
  double max = double.negativeInfinity;
  int maxIndex = -1;

  for (int i = 0; i < list.length; i++) {
    List<double> innerList = list[i];

    if (innerList.length > 1) {
      double value = innerList[1];

      if (value > max) {
        max = value;
        maxIndex = i;
      }
    }
  }

  if (maxIndex != -1) {
    print('Maximum value in index 1: $max');
    print('Index of the inner list with max value: $maxIndex');
    // print(yoloResults[maxIndex]);
  }

  return maxIndex;
}
