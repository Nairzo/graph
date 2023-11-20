import 'dart:ui';

import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math';

enum DraggingPoint { none, start, end }

DraggingPoint draggingPoint = DraggingPoint.none;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseDate = DateTime(2023, 10, 4);
    final candlesticks = List<Candlestick>.generate(100, (index) {
      final random = Random();
      final open = 80.0 + random.nextDouble() * 20.0;
      final close = 80.0 + random.nextDouble() * 20.0;
      final high = open + random.nextDouble() * 10.0;
      final low = close - random.nextDouble() * 10.0;
      final currentDate = baseDate.add(Duration(days: index));
      return Candlestick(
        open: open,
        close: close,
        high: high,
        low: low,
        date: currentDate,
      );
    });
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(),
        body: PriceChart(
            startDate: DateTime(2023, 10, 1),
            endDate: DateTime(2023, 10, 2), // Rango de un día para el ejemplo
            data: candlesticks),
      ),
    );
  }
}

class Candlestick {
  final double open;
  final double close;
  final double high;
  final double low;
  final DateTime date;

  Candlestick({
    required this.open,
    required this.close,
    required this.high,
    required this.low,
    required this.date,
  });
}

class PriceChart extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;
  final List<Candlestick> data;

  const PriceChart(
      {super.key,
      required this.startDate,
      required this.endDate,
      required this.data});

  @override
  State<PriceChart> createState() => _PriceChartState();
}

class _PriceChartState extends State<PriceChart> {
  double zoomX = 0.0;
  double zoomY = 0.0;
  double scrollOffsetX = 0.0;
  double scrollOffsetY = 0.0;
  double maxY = 110.85;
  double minY = 110.20;
  List<Offset> points = [];
  List<double> priceLines = [];
  List<int> timeLines = [];
  Offset? position;
  bool isfirstTendPointTap = false;
  List<TrendLine> trendLines = [];
  Offset startPoint = Offset.zero;
  Offset endPoint = Offset.zero;
  Offset firstTrendPoint = Offset.zero;
  TrendLine? draggingLine;
  bool isLineDragging = false;
  bool isPointDragging = false;

  bool isLineMoving = false;
  bool isSelectZoomTap = false;
  Offset zoomStartPoint = Offset.zero;
  int zoomStartX = 0;
  int zoomEndX = 0;

  @override
  void initState() {
    super.initState();
  }

  void updateVisiblePricesWhenScrollY(double delta, Size size) {
    double factor = 0.025;
    double intervaloEntreLineas = (maxY - minY) / 10;
    double desplazamiento = delta * factor * intervaloEntreLineas;

    scrollOffsetY += desplazamiento;

    setState(() {});
  }

  updateVisiblePricesWhenZoom(double zoom) {
    double factor = 0.002;
    double intervaloEntreLineas = (maxY - minY) / 10;
    double delta = zoom * factor * (intervaloEntreLineas * 10);
    double newMaxVisiblePrice = maxY + delta;
    double newMinVisiblePrice = minY - delta;
    double newPriceRange = newMaxVisiblePrice - newMinVisiblePrice;

    if (newPriceRange >= 0.01) {
      maxY = newMaxVisiblePrice;
      minY = newMinVisiblePrice;
    }
    setState(() {});
  }

  Size candleCanvasSize(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Size(size.width / 1.2, 400);
  }

  addPriceLine(double value, Size size) {
    double yPosition =
        maxY - (value * (maxY - minY) / size.height) + scrollOffsetY;

    priceLines.add(yPosition);
    setState(() {});
  }

  double _distanceFromPointToLine(
      Offset point, Offset lineStart, Offset lineEnd) {
    final double A = point.dx - lineStart.dx;
    final double B = point.dy - lineStart.dy;
    final double C = lineEnd.dx - lineStart.dx;
    final double D = lineEnd.dy - lineStart.dy;

    final double dot = A * C + B * D;
    final double lenSq = C * C + D * D;
    final double param = (lenSq != 0) ? dot / lenSq : -1;

    double closestX, closestY;

    if (param < 0) {
      closestX = lineStart.dx;
      closestY = lineStart.dy;
    } else if (param > 1) {
      closestX = lineEnd.dx;
      closestY = lineEnd.dy;
    } else {
      closestX = lineStart.dx + param * C;
      closestY = lineStart.dy + param * D;
    }

    final double dx = point.dx - closestX;
    final double dy = point.dy - closestY;

    return sqrt(dx * dx + dy * dy);
  }

  void updateZoomX(double delta, Size size) {
    double factor = 0.002;
    double pixelsPerTime = size.width / 80 + zoomX + 2;
    double desplazamiento = delta * factor * pixelsPerTime;
    zoomX += desplazamiento;
    if (zoomX < 0.0) {
      zoomX = 0.0;
    } else if (zoomX > 275.0) {
      zoomX = 275.0;
    }

    setState(() {});
  }

  void updateScrollXWhenZoom(double delta, Size size) {
    double factor = 10;
    double pixelsPerTime = size.width / 80 + zoomX + 2;
    double desplazamiento = delta * factor / pixelsPerTime;

    scrollOffsetX += desplazamiento;

    setState(() {});
  }

  int findNearestCenterX(
      double tapX, double width, double zoomX, double scrollOffsetX) {
    double pixelsPerTime = (width / 80) + zoomX + 2;
    int nearestIndex =
        ((width - tapX) / pixelsPerTime).round() + (scrollOffsetX / 10).round();
    return nearestIndex.clamp(0, 80); // Assuming 80 data points
  }

  double calculateCenterX(
      int index, double width, double zoomX, double scrollOffsetX) {
    double pixelsPerTime = (width / 80) + zoomX + 2;
    return (width) - (index - (scrollOffsetX / 10)) * pixelsPerTime;
  }

  // Añade el siguiente método a la clase _PriceChartState
  void updateLinesInRange(int start, int end, double canvasWidth) {
    // Elimina las líneas existentes dentro del rango
    trendLines.removeWhere((line) => line.index >= start && line.index <= end);

    // Añade las nuevas líneas dentro del rango
    for (int i = start; i <= end; i++) {
      double centerX = calculateCenterX(i, canvasWidth, zoomX, scrollOffsetX);
      trendLines.add(TrendLine(
          index: i,
          startPoint: Offset(centerX, 0),
          endPoint: Offset(centerX, 400)));
    }
  }

  bool isDragging = false;
  int? draggingIndex;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          MouseRegion(
            onHover: (event) {
              setState(() {
                position = event.localPosition;
              });
            },
            child: GestureDetector(
              onPanUpdate: (details) {
                if (!isLineMoving) {
                  updateScrollXWhenZoom(
                      details.delta.dx, candleCanvasSize(context));
                }
              },
              onPanEnd: (details) {
                if (isSelectZoomTap) {
                  zoomEndX = findNearestCenterX(position!.dx,
                      candleCanvasSize(context).width, zoomX, scrollOffsetX);
                  isSelectZoomTap = false;
                  isLineMoving = false;
                  // Actualiza las líneas dentro del rango zoomStartX y zoomEndX
                  updateLinesInRange(
                      zoomStartX, zoomEndX, candleCanvasSize(context).width);
                  print('$zoomStartX, $zoomEndX');
                }
              },
              onTapDown: (details) {
                setState(() {
                  if (!isSelectZoomTap) {
                    zoomStartPoint = Offset(
                        details.localPosition.dx, details.localPosition.dy);
                    zoomStartX = findNearestCenterX(details.localPosition.dx,
                        candleCanvasSize(context).width, zoomX, scrollOffsetX);
                    isSelectZoomTap = true;
                    isLineMoving = true;
                  }
                });
              },
              child: CustomPaint(
                size: Size(candleCanvasSize(context).width,
                    candleCanvasSize(context).height),
                painter: PriceChartPainter(
                    zoomX: zoomX,
                    scrollOffsetX: scrollOffsetX,
                    scrollOffsetY: scrollOffsetY,
                    maxY: maxY,
                    minY: minY,
                    zoomY: zoomY,
                    points: points,
                    position: position,
                    timeLines: timeLines,
                    isfirstTendPointTap: isfirstTendPointTap,
                    trendLines: trendLines,
                    firstTrendPoint: firstTrendPoint,
                    isDragging: isDragging,
                    draggingIndex: draggingIndex ?? 0,
                    isSelectZoomTap: isSelectZoomTap,
                    zoomStartPoint: zoomStartPoint,
                    zoomStartX: zoomStartX,
                    zoomEndX: zoomEndX),
              ),
            ),
          ),
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                updateZoomX(-details.primaryDelta!, candleCanvasSize(context));
              });
            },
            child: Container(
              height: 50,
              width: candleCanvasSize(context).width,
              color: Colors.blue,
            ),
          )
        ],
      ),
    );
  }
}

class TrendLine {
  int index;
  Offset startPoint;
  Offset endPoint;

  TrendLine(
      {required this.index,
      this.startPoint = Offset.zero,
      this.endPoint = Offset.zero});
}

//Clase modelo de una vela
class Candletick {
  final double wickHighY;
  final double wicklowY;
  final double candleHighY;
  final double candleLowY;
  double centerX;
  final Paint candlePaint;
  final int index;

  Candletick({
    required this.wickHighY,
    required this.wicklowY,
    required this.candleHighY,
    required this.candleLowY,
    required this.centerX,
    required this.candlePaint,
    required this.index,
  });
}

class CenterX {
  final int index;
  final double centerX;

  CenterX({required this.index, required this.centerX});
}

class PriceChartPainter extends CustomPainter {
  double scrollOffsetY;
  double minY;
  double maxY;
  double zoomY;
  final List<Offset> points;
  Offset? position;
  List<int> timeLines;
  bool isfirstTendPointTap;
  List<TrendLine> trendLines;
  Offset firstTrendPoint;
  bool isDragging;
  int draggingIndex;
  double zoomX;
  double scrollOffsetX;

  bool isSelectZoomTap;
  Offset zoomStartPoint;
  int zoomStartX;
  int zoomEndX;

  PriceChartPainter(
      {required this.scrollOffsetY,
      required this.maxY,
      required this.minY,
      required this.zoomY,
      required this.points,
      required this.position,
      required this.timeLines,
      required this.isfirstTendPointTap,
      required this.trendLines,
      required this.firstTrendPoint,
      required this.isDragging,
      required this.draggingIndex,
      required this.zoomX,
      required this.scrollOffsetX,
      required this.isSelectZoomTap,
      required this.zoomStartPoint,
      required this.zoomStartX,
      required this.zoomEndX,
      Paint? gainPaint,
      Paint? lossPaint});

  @override
  void paint(Canvas canvas, Size size) {
    List<CenterX> centers = generateSpaces(size, zoomStartX, zoomEndX);
    final cutomWidth = (size.width / 80) + zoomX; //Ancho de las velas

    int roundToNearestMultiple(double value) {
      final exponent = (log(value / 2) / log(2)).ceil();
      final multiple = pow(2, exponent).toInt();
      return multiple;
    }

    final Paint gridLinesPaint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.0 //Ancho de la linea
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke;
    const double vGridLineDashWidth = 3; //tamaño de los puntos en la linea
    const double vGridLineGashSpace = 5; //Espacio entre los puntos

    final Paint zoomBoxPaint = Paint()
      ..color = Color.fromARGB(120, 30, 29, 29)
      ..style = PaintingStyle.fill;
    double constantValue = 100.0;
    double intervalX = (constantValue / cutomWidth);
    int intervalMinutes = roundToNearestMultiple(intervalX);
    if (intervalMinutes == 0 || intervalMinutes < 0) {
      intervalMinutes = 1;
    }

    for (int i = 0; i < centers.length; i++) {
      CenterX center = centers[i];
      if ((i + 1) % intervalMinutes == 0) {
        // Dibujar línea vertical en el centerX de cada window

        if (center.centerX > 0 && center.centerX < size.width) {
          for (double i = 0;
              i < size.height;
              i += vGridLineDashWidth + vGridLineGashSpace) {
            final start = Offset(center.centerX, i);
            final end = Offset(
                center.centerX, (i + vGridLineDashWidth).clamp(0, size.height));
            canvas.drawLine(start, end, gridLinesPaint);
          }
          final TextPainter dateTextPainter = TextPainter(
            text: TextSpan(
              text: center.index.toString(),
              style: const TextStyle(color: Colors.black, fontSize: 12.0),
            ),
            textDirection: ui.TextDirection.ltr,
          );
          dateTextPainter.layout();
          dateTextPainter.paint(
              canvas,
              Offset(center.centerX - dateTextPainter.width / 2,
                  size.height / 2 - dateTextPainter.height / 2));
        }
      }
    }

    if (isSelectZoomTap) {
      canvas.drawRect(Rect.fromPoints(zoomStartPoint, position!), zoomBoxPaint);
    }

    final Paint priceLinePaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke;

    // for (int x in timeLines) {
    //   // Calcula el centerX utilizando la función calculateCenterX
    //   double centerX = calculateCenterX(x, size.width, zoomX, scrollOffsetX);

    //   final start = Offset(centerX, 0);
    //   final end = Offset(centerX, size.height);
    //   canvas.drawLine(start, end, priceLinePaint);
    // }

    // //Dibujamos el margen del canvas
    canvas.drawRect(
        Rect.fromPoints(const Offset(0, 0), Offset(size.width, size.height)),
        Paint()
          ..color = const Color.fromARGB(255, 0, 0, 0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0);
  }

  double calculateCenterX(int index, double width, double zoomX,
      double scrollOffsetX, int dataLenght) {
    double pixelsPerTime = (width / 80) + zoomX + 2;
    return (width) - (index - (scrollOffsetX / 10)) * pixelsPerTime;
  }

  List<CenterX> generateSpaces(Size availableSpace, int start, int end) {
    List<CenterX> candles = [];
    for (int i = start; i <= end; i++) {
      double centerX = calculateCenterX(
          i, availableSpace.width, zoomX, scrollOffsetX, (start - end).abs());

      if (centerX < 0) {
        continue; // Evitar dibujar líneas fuera del canvas
      }

      candles.add(CenterX(index: i, centerX: centerX));
    }

    return candles;
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

// import 'dart:ui';

// import 'package:flutter/material.dart';
// import 'dart:ui' as ui;
// import 'dart:math';

// enum DraggingPoint { none, start, end }

// DraggingPoint draggingPoint = DraggingPoint.none;

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final baseDate = DateTime(2023, 10, 4);
//     final candlesticks = List<Candlestick>.generate(100, (index) {
//       final random = Random();
//       final open = 80.0 + random.nextDouble() * 20.0;
//       final close = 80.0 + random.nextDouble() * 20.0;
//       final high = open + random.nextDouble() * 10.0;
//       final low = close - random.nextDouble() * 10.0;
//       final currentDate = baseDate.add(Duration(days: index));
//       return Candlestick(
//         open: open,
//         close: close,
//         high: high,
//         low: low,
//         date: currentDate,
//       );
//     });
//     return MaterialApp(
//       home: Scaffold(
//         appBar: AppBar(),
//         body: PriceChart(
//             startDate: DateTime(2023, 10, 1),
//             endDate: DateTime(2023, 10, 2), // Rango de un día para el ejemplo
//             data: candlesticks),
//       ),
//     );
//   }
// }

// class Candlestick {
//   final double open;
//   final double close;
//   final double high;
//   final double low;
//   final DateTime date;

//   Candlestick({
//     required this.open,
//     required this.close,
//     required this.high,
//     required this.low,
//     required this.date,
//   });
// }

// class PriceChart extends StatefulWidget {
//   final DateTime startDate;
//   final DateTime endDate;
//   final List<Candlestick> data;

//   const PriceChart(
//       {super.key,
//       required this.startDate,
//       required this.endDate,
//       required this.data});

//   @override
//   State<PriceChart> createState() => _PriceChartState();
// }

// class _PriceChartState extends State<PriceChart> {
//   double zoom = 0.0;
//   double zoomY = 0.0;
//   double scrollOffsetX = 0.0;
//   double scrollOffsetY = 0.0;
//   double maxY = 110.85;
//   double minY = 110.20;
//   List<Offset> points = [];
//   List<double> priceLines = [];
//   Offset? position;
//   bool isfirstTendPointTap = false;
//   List<TrendLine> trendLines = [];
//   Offset startPoint = Offset.zero;
//   Offset endPoint = Offset.zero;
//   Offset firstTrendPoint = Offset.zero;
//   TrendLine? draggingLine;
//   bool isLineDragging = false;
//   bool isPointDragging = false;

//   @override
//   void initState() {
//     super.initState();
//   }

//   void updateVisiblePricesWhenScrollY(double delta, Size size) {
//     double factor = 0.025;
//     double intervaloEntreLineas = (maxY - minY) / 10;
//     double desplazamiento = delta * factor * intervaloEntreLineas;

//     scrollOffsetY += desplazamiento;

//     setState(() {});
//   }

//   updateVisiblePricesWhenZoom(double zoom) {
//     double factor = 0.002;
//     double intervaloEntreLineas = (maxY - minY) / 10;
//     double delta = zoom * factor * (intervaloEntreLineas * 10);
//     double newMaxVisiblePrice = maxY + delta;
//     double newMinVisiblePrice = minY - delta;
//     double newPriceRange = newMaxVisiblePrice - newMinVisiblePrice;

//     if (newPriceRange >= 0.01) {
//       maxY = newMaxVisiblePrice;
//       minY = newMinVisiblePrice;
//     }
//     setState(() {});
//   }

//   Size candleCanvasSize(BuildContext context) {
//     Size size = MediaQuery.of(context).size;
//     return Size(size.width / 1.2, 400);
//   }

//   addPriceLine(double value, Size size) {
//     double yPosition =
//         maxY - (value * (maxY - minY) / size.height) + scrollOffsetY;

//     priceLines.add(yPosition);
//     setState(() {});
//   }

//   double _distanceFromPointToLine(
//       Offset point, Offset lineStart, Offset lineEnd) {
//     final double A = point.dx - lineStart.dx;
//     final double B = point.dy - lineStart.dy;
//     final double C = lineEnd.dx - lineStart.dx;
//     final double D = lineEnd.dy - lineStart.dy;

//     final double dot = A * C + B * D;
//     final double lenSq = C * C + D * D;
//     final double param = (lenSq != 0) ? dot / lenSq : -1;

//     double closestX, closestY;

//     if (param < 0) {
//       closestX = lineStart.dx;
//       closestY = lineStart.dy;
//     } else if (param > 1) {
//       closestX = lineEnd.dx;
//       closestY = lineEnd.dy;
//     } else {
//       closestX = lineStart.dx + param * C;
//       closestY = lineStart.dy + param * D;
//     }

//     final double dx = point.dx - closestX;
//     final double dy = point.dy - closestY;

//     return sqrt(dx * dx + dy * dy);
//   }

//   double _distanceBetweenPoints(Offset point1, Offset point2) {
//     final double dx = point1.dx - point2.dx;
//     final double dy = point1.dy - point2.dy;
//     return sqrt(dx * dx + dy * dy);
//   }

//   bool _isPointOnLine(Offset point, Offset lineStart, Offset lineEnd) {
//     return _distanceFromPointToLine(point, lineStart, lineEnd) < 10.0;
//   }

//   bool _isPointClicked(Offset point, Offset linePoint) {
//     return _distanceBetweenPoints(point, linePoint) < 10.0;
//   }

//   bool isDragging = false;
//   int? draggingIndex;

//   @override
//   Widget build(BuildContext context) {
//     Size size = MediaQuery.of(context).size;
//     return Center(
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.center,
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           MouseRegion(
//             onHover: (event) {
//               setState(() {
//                 position = event.localPosition;
//               });
//             },
//             child: GestureDetector(
//               onPanUpdate: (details) {
//                 setState(() {
//                   if (draggingLine != null) {
//                     if (isLineDragging) {
//                       draggingLine!.startPoint += details.delta;
//                       draggingLine!.endPoint += details.delta;
//                     } else if (isPointDragging) {
//                       if (draggingPoint == DraggingPoint.start) {
//                         draggingLine!.startPoint += details.delta;
//                       } else if (draggingPoint == DraggingPoint.end) {
//                         draggingLine!.endPoint += details.delta;
//                       }
//                     }
//                   } else {
//                     updateVisiblePricesWhenScrollY(details.delta.dy, size);
//                   }
//                 });
//               },
//               onPanEnd: (details) {
//                 setState(() {
//                   draggingLine = null;
//                   draggingPoint = DraggingPoint.none;
//                   isLineDragging = false;
//                   isPointDragging = false;
//                 });
//               },
//               onTapUp: (details) {
//                 setState(() {
//                   if (!isfirstTendPointTap) {
//                     firstTrendPoint = details.localPosition;
//                     startPoint = details.localPosition;
//                     isfirstTendPointTap = true;
//                   } else {
//                     endPoint = details.localPosition;
//                     isfirstTendPointTap = false;

//                     TrendLine trendLine = TrendLine(
//                       index: trendLines.length,
//                       startPoint: startPoint,
//                       endPoint: endPoint,
//                     );

//                     trendLines.add(trendLine);
//                   }
//                 });
//               },
//               onTapDown: (details) {
//                 setState(() {
//                   for (var i = 0; i < trendLines.length; i++) {
//                     final trendLine = trendLines[i];
//                     final startPoint = trendLine.startPoint;
//                     final endPoint = trendLine.endPoint;

//                     if (_isPointClicked(details.localPosition, startPoint)) {
//                       isPointDragging = true;
//                       draggingLine = trendLine;
//                       draggingIndex = i;
//                       draggingPoint = DraggingPoint.start;
//                     } else if (_isPointClicked(
//                         details.localPosition, endPoint)) {
//                       isPointDragging = true;
//                       draggingLine = trendLine;
//                       draggingIndex = i;
//                       draggingPoint = DraggingPoint.end;
//                     } else if (_isPointOnLine(
//                         details.localPosition, startPoint, endPoint)) {
//                       isLineDragging = true;
//                       draggingLine = trendLine;
//                       draggingIndex = i;
//                     }
//                   }
//                 });
//               },
//               child: CustomPaint(
//                 size: Size(candleCanvasSize(context).width,
//                     candleCanvasSize(context).height),
//                 painter: PriceChartPainter(
//                     scrollOffsetY: scrollOffsetY,
//                     maxY: maxY,
//                     minY: minY,
//                     zoomY: zoomY,
//                     points: points,
//                     position: position,
//                     priceLines: priceLines,
//                     isfirstTendPointTap: isfirstTendPointTap,
//                     trendLines: trendLines,
//                     firstTrendPoint: firstTrendPoint,
//                     isDragging: isDragging,
//                     draggingIndex: draggingIndex ?? 0),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class TrendLine {
//   int index;
//   Offset startPoint;
//   Offset endPoint;

//   TrendLine(
//       {required this.index,
//       this.startPoint = Offset.zero,
//       this.endPoint = Offset.zero});
// }

// class PriceChartPainter extends CustomPainter {
//   double scrollOffsetY;
//   double minY;
//   double maxY;
//   double zoomY;
//   final List<Offset> points;
//   Offset? position;
//   List<double> priceLines;
//   bool isfirstTendPointTap;
//   List<TrendLine> trendLines;
//   Offset firstTrendPoint;
//   bool isDragging;
//   int draggingIndex;

//   PriceChartPainter(
//       {required this.scrollOffsetY,
//       required this.maxY,
//       required this.minY,
//       required this.zoomY,
//       required this.points,
//       required this.position,
//       required this.priceLines,
//       required this.isfirstTendPointTap,
//       required this.trendLines,
//       required this.firstTrendPoint,
//       required this.isDragging,
//       required this.draggingIndex});

//   @override
//   void paint(Canvas canvas, Size size) {
//     final Paint linePaint = Paint()
//       ..color = Colors.blue
//       ..strokeWidth = 2.0
//       ..style = PaintingStyle.stroke;

//     final Paint trendPoint = Paint()
//       ..color = Colors.blue
//       ..style = PaintingStyle.fill;

//     if (isfirstTendPointTap) {
//       canvas.drawLine(firstTrendPoint, position!, linePaint);
//       canvas.drawCircle(firstTrendPoint, 6, trendPoint);

//       for (int i = 0; i <= 4; i++) {
//         double fraction = i / 4.0;
//         double y =
//             firstTrendPoint.dy + fraction * (position!.dy - firstTrendPoint.dy);

//         final List<Color> shadeColors = [
//           Colors.white.withOpacity(0.2),
//           Colors.pink.withOpacity(0.2),
//           Colors.orange.withOpacity(0.2),
//           Colors.green.withOpacity(0.2),
//           Colors.blue.withOpacity(0.2),
//         ];

//         final Paint shadePaint = Paint()..color = shadeColors[i];


//         double previousFraction = (i - 1) / 4.0;
//         double previousY =
//             firstTrendPoint.dy + previousFraction * (position!.dy - firstTrendPoint.dy);

//         Offset rectStart = Offset(firstTrendPoint.dx, y);
//         Offset rectEnd = Offset(position!.dx, previousY);

//         canvas.drawRect(Rect.fromPoints(rectStart, rectEnd), shadePaint);

//         canvas.drawLine(
//           Offset(firstTrendPoint.dx, y),
//           Offset(position!.dx, y),
//           linePaint,
//         );

//         double percentage = (fraction * 100).round().toDouble();
//         TextPainter(
//           text: TextSpan(
//             text: '$percentage%',
//             style: const TextStyle(color: Colors.black, fontSize: 10),
//           ),
//           textDirection: TextDirection.ltr,
//         )
//           ..layout(minWidth: 0, maxWidth: size.width)
//           ..paint(canvas, Offset(position!.dx - 30, y - 15));
//       }
//     }

//     for (var i = 0; i < trendLines.length; i++) {
//       final trendLine = trendLines[i];
//       final startPoint = trendLine.startPoint;
//       final endPoint = trendLine.endPoint;

//       // Dibujar la línea
//       canvas.drawLine(startPoint, endPoint, linePaint);

//       for (int i = 0; i <= 4; i++) {
//         double fraction = i / 4.0;
//         double y = startPoint.dy + fraction * (endPoint.dy - startPoint.dy);
//         final List<Color> shadeColors = [
//           Colors.white.withOpacity(0.2),
//           Colors.pink.withOpacity(0.2),
//           Colors.orange.withOpacity(0.2),
//           Colors.green.withOpacity(0.2),
//           Colors.blue.withOpacity(0.2),
//         ];

//         final Paint shadePaint = Paint()..color = shadeColors[i];

//         double previousFraction = (i - 1) / 4.0;
//         double previousY =
//             startPoint.dy + previousFraction * (endPoint.dy - startPoint.dy);

//         Offset rectStart = Offset(startPoint.dx, y);
//         Offset rectEnd = Offset(endPoint.dx, previousY);

//         canvas.drawRect(Rect.fromPoints(rectStart, rectEnd), shadePaint);

//         canvas.drawLine(
//           Offset(startPoint.dx, y),
//           Offset(endPoint.dx, y),
//           linePaint,
//         );

//         double percentage = (fraction * 100).round().toDouble();
//         TextPainter(
//           text: TextSpan(
//             text: '$percentage%',
//             style: const TextStyle(color: Colors.black, fontSize: 10),
//           ),
//           textDirection: TextDirection.ltr,
//         )
//           ..layout(minWidth: 0, maxWidth: size.width)
//           ..paint(canvas, Offset(endPoint.dx - 30, y - 15));
//       }

//       // Dibujar los puntos de inicio y fin
//       canvas.drawCircle(startPoint, 6, trendPoint);
//       canvas.drawCircle(endPoint, 6, trendPoint);
//     }

//     // //Dibujamos el margen del canvas
//     canvas.drawRect(
//         Rect.fromPoints(const Offset(0, 0), Offset(size.width, size.height)),
//         Paint()
//           ..color = const Color.fromARGB(255, 0, 0, 0)
//           ..style = PaintingStyle.stroke
//           ..strokeWidth = 1.0);
//   }

//   double _distanceBetweenPoints(Offset point1, Offset point2) {
//     final double dx = point1.dx - point2.dx;
//     final double dy = point1.dy - point2.dy;
//     return sqrt(dx * dx + dy * dy);
//   }

//   double _distanceFromPointToLine(
//       Offset point, Offset lineStart, Offset lineEnd) {
//     final double A = point.dx - lineStart.dx;
//     final double B = point.dy - lineStart.dy;
//     final double C = lineEnd.dx - lineStart.dx;
//     final double D = lineEnd.dy - lineStart.dy;

//     final double dot = A * C + B * D;
//     final double lenSq = C * C + D * D;
//     final double param = (lenSq != 0) ? dot / lenSq : -1;

//     double closestX, closestY;

//     if (param < 0) {
//       closestX = lineStart.dx;
//       closestY = lineStart.dy;
//     } else if (param > 1) {
//       closestX = lineEnd.dx;
//       closestY = lineEnd.dy;
//     } else {
//       closestX = lineStart.dx + param * C;
//       closestY = lineStart.dy + param * D;
//     }

//     final double dx = point.dx - closestX;
//     final double dy = point.dy - closestY;

//     return sqrt(dx * dx + dy * dy);
//   }

//   void drawShadedRectangle(
//       Canvas canvas, double startY, double endY, double nextY) {
//     final Rect shadedRect = Rect.fromPoints(
//       Offset(position!.dx, startY),
//       Offset(position!.dx, nextY),
//     );

//     final Paint shadePaint = Paint()..color = Colors.blue.withOpacity(0.2);

//     canvas.drawRect(shadedRect, shadePaint);
//   }

//   @override
//   bool shouldRepaint(CustomPainter oldDelegate) {
//     return true;
//   }
// }
