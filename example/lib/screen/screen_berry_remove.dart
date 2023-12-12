import 'dart:typed_data';

import 'package:flutter/material.dart';

class ScreenBerryRemove extends StatelessWidget {
  const ScreenBerryRemove({
    super.key,
    required Uint8List bytePredictBerry,
  }) : _bytePredictBerry = bytePredictBerry;
  final Uint8List _bytePredictBerry;

  @override
  Widget build(BuildContext context) {
    return Image.memory(_bytePredictBerry);
  }
}
