class BunchPosition {
  late int? x0;
  late int? y0;
  late int? x1;
  late int? y1;

  BunchPosition({
    this.x0,
    this.y0,
    this.x1,
    this.y1,
  });

  int width() {
    return x1! - x0!;
  }

  int height() {
    return y1! - y0!;
  }
}
