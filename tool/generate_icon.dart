import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  const size = 1024;
  final image = img.Image(width: size, height: size);

  final white = img.ColorRgb8(255, 255, 255);
  final black = img.ColorRgb8(0, 0, 0);

  // White background
  img.fill(image, color: white);

  // --- Left ear ---
  img.fillPolygon(image,
      vertices: [
        img.Point(190, 400),
        img.Point(136, 110),
        img.Point(420, 316),
      ],
      color: black);

  // --- Right ear ---
  img.fillPolygon(image,
      vertices: [
        img.Point(834, 400),
        img.Point(888, 110),
        img.Point(604, 316),
      ],
      color: black);

  // --- Cat head (large filled circle) ---
  img.fillCircle(image, x: 512, y: 590, radius: 344, color: black);

  // --- Left eye white ---
  img.fillCircle(image, x: 384, y: 544, radius: 72, color: white);
  // Left pupil (vertical ellipse — draw as narrow tall circle)
  for (int dy = -56; dy <= 56; dy++) {
    final halfW = (26 * (1 - (dy * dy) / (56.0 * 56.0))).round();
    img.drawLine(image,
        x1: 384 - halfW, y1: 544 + dy,
        x2: 384 + halfW, y2: 544 + dy,
        color: black);
  }
  // Left eye shine
  img.fillCircle(image, x: 404, y: 520, radius: 16, color: white);

  // --- Right eye white ---
  img.fillCircle(image, x: 640, y: 544, radius: 72, color: white);
  // Right pupil
  for (int dy = -56; dy <= 56; dy++) {
    final halfW = (26 * (1 - (dy * dy) / (56.0 * 56.0))).round();
    img.drawLine(image,
        x1: 640 - halfW, y1: 544 + dy,
        x2: 640 + halfW, y2: 544 + dy,
        color: black);
  }
  // Right eye shine
  img.fillCircle(image, x: 660, y: 520, radius: 16, color: white);

  // --- Nose (small inverted triangle) ---
  img.fillPolygon(image,
      vertices: [
        img.Point(494, 624),
        img.Point(512, 600),
        img.Point(530, 624),
      ],
      color: white);

  // --- Whiskers left ---
  for (final row in [0, 1, 2]) {
    final y1 = 624 + row * 44;
    final y2 = 624 + row * 44 + (row == 0 ? 16 : row == 2 ? -16 : 0);
    for (int t = -1; t <= 1; t++) {
      img.drawLine(image,
          x1: 170, y1: y1 + t,
          x2: 456, y2: y2 + t,
          color: white);
    }
  }

  // --- Whiskers right ---
  for (final row in [0, 1, 2]) {
    final y1 = 624 + row * 44;
    final y2 = 624 + row * 44 + (row == 0 ? 16 : row == 2 ? -16 : 0);
    for (int t = -1; t <= 1; t++) {
      img.drawLine(image,
          x1: 854, y1: y1 + t,
          x2: 568, y2: y2 + t,
          color: white);
    }
  }

  // --- Mouth ---
  for (int i = 0; i <= 40; i++) {
    final t = i / 40.0;
    // Left curve: from (512,644) to (448,666)
    final x = (512 + t * (448 - 512)).round();
    final y = (644 + 28 * 4 * t * (1 - t) + t * (666 - 644)).round();
    img.fillCircle(image, x: x, y: y, radius: 4, color: white);
    // Right curve: from (512,644) to (576,666)
    final x2 = (512 + t * (576 - 512)).round();
    final y2 = (644 + 28 * 4 * t * (1 - t) + t * (666 - 644)).round();
    img.fillCircle(image, x: x2, y: y2, radius: 4, color: white);
  }

  final png = img.encodePng(image);
  File('assets/icon.png').writeAsBytesSync(png);
  print('✓ assets/icon.png generated (${size}x$size)');
}
