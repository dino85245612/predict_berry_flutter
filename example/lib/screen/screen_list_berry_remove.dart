import 'dart:typed_data';

import 'package:flutter/material.dart';

class ListBerryRemoveScreen extends StatelessWidget {
  const ListBerryRemoveScreen({
    super.key,
    required List<Uint8List> listImage,
  }) : _listImage = listImage;
  final List<Uint8List> _listImage;

  @override
  Widget build(BuildContext context) {
    return _listImage.isNotEmpty
        ? GridView.count(
            crossAxisCount: 5,
            children: createListImage(),
          )
        : SizedBox();
  }

  List<Widget> createListImage() {
    List<Widget> listImageWidget = <Widget>[];
    // print("buildListImage-> ${listImage?.length}");

    if (_listImage.isNotEmpty) {
      for (int i = 0; i < _listImage.length; i++) {
        listImageWidget.add(Image.memory(_listImage![i]));
      }
    }
    return listImageWidget;
  }
}
