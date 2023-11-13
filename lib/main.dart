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
  double zoom = 0.0;
  double zoomY = 0.0;
  double scrollOffsetX = 0.0;
  double scrollOffsetY = 0.0;
  double maxY = 110.85;
  double minY = 110.20;
  List<Offset> points = [];
  List<double> priceLines = [];
  Offset? position;
  bool isfirstTendPointTap = false;
  List<TrendLine> trendLines = [];
  Offset startPoint = Offset.zero;
  Offset endPoint = Offset.zero;
  Offset firstTrendPoint = Offset.zero;
  TrendLine? draggingLine;
  bool isLineDragging = false;
  bool isPointDragging = false;

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

  double _distanceBetweenPoints(Offset point1, Offset point2) {
    final double dx = point1.dx - point2.dx;
    final double dy = point1.dy - point2.dy;
    return sqrt(dx * dx + dy * dy);
  }

  bool _isPointOnLine(Offset point, Offset lineStart, Offset lineEnd) {
    return _distanceFromPointToLine(point, lineStart, lineEnd) < 10.0;
  }

  bool _isPointClicked(Offset point, Offset linePoint) {
    return _distanceBetweenPoints(point, linePoint) < 10.0;
  }

  bool isDragging = false;
  int? draggingIndex;

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Center(
      child: Row(
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
                setState(() {
                  if (draggingLine != null) {
                    if (isLineDragging) {
                      draggingLine!.startPoint += details.delta;
                      draggingLine!.endPoint += details.delta;
                    } else if (isPointDragging) {
                      if (draggingPoint == DraggingPoint.start) {
                        draggingLine!.startPoint += details.delta;
                      } else if (draggingPoint == DraggingPoint.end) {
                        draggingLine!.endPoint += details.delta;
                      }
                    }
                  } else {
                    updateVisiblePricesWhenScrollY(details.delta.dy, size);
                  }
                });
              },
              onPanEnd: (details) {
                setState(() {
                  draggingLine = null;
                  draggingPoint = DraggingPoint.none;
                  isLineDragging = false;
                  isPointDragging = false;
                });
              },
              onTapUp: (details) {
                setState(() {
                  if (!isfirstTendPointTap) {
                    firstTrendPoint = details.localPosition;
                    startPoint = details.localPosition;
                    isfirstTendPointTap = true;
                  } else {
                    endPoint = details.localPosition;
                    isfirstTendPointTap = false;

                    TrendLine trendLine = TrendLine(
                      index: trendLines.length,
                      startPoint: startPoint,
                      endPoint: endPoint,
                    );

                    trendLines.add(trendLine);
                  }
                });
              },
              onTapDown: (details) {
                setState(() {
                  for (var i = 0; i < trendLines.length; i++) {
                    final trendLine = trendLines[i];
                    final startPoint = trendLine.startPoint;
                    final endPoint = trendLine.endPoint;

                    if (_isPointClicked(details.localPosition, startPoint)) {
                      isPointDragging = true;
                      draggingLine = trendLine;
                      draggingIndex = i;
                      draggingPoint = DraggingPoint.start;
                    } else if (_isPointClicked(
                        details.localPosition, endPoint)) {
                      isPointDragging = true;
                      draggingLine = trendLine;
                      draggingIndex = i;
                      draggingPoint = DraggingPoint.end;
                    } else if (_isPointOnLine(
                        details.localPosition, startPoint, endPoint)) {
                      isLineDragging = true;
                      draggingLine = trendLine;
                      draggingIndex = i;
                    }
                  }
                });
              },
              child: CustomPaint(
                size: Size(candleCanvasSize(context).width,
                    candleCanvasSize(context).height),
                painter: PriceChartPainter(
                    scrollOffsetY: scrollOffsetY,
                    maxY: maxY,
                    minY: minY,
                    zoomY: zoomY,
                    points: points,
                    position: position,
                    priceLines: priceLines,
                    isfirstTendPointTap: isfirstTendPointTap,
                    trendLines: trendLines,
                    firstTrendPoint: firstTrendPoint,
                    isDragging: isDragging,
                    draggingIndex: draggingIndex ?? 0),
              ),
            ),
          ),
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

class PriceChartPainter extends CustomPainter {
  double scrollOffsetY;
  double minY;
  double maxY;
  double zoomY;
  final List<Offset> points;
  Offset? position;
  List<double> priceLines;
  bool isfirstTendPointTap;
  List<TrendLine> trendLines;
  Offset firstTrendPoint;
  bool isDragging;
  int draggingIndex;

  PriceChartPainter(
      {required this.scrollOffsetY,
      required this.maxY,
      required this.minY,
      required this.zoomY,
      required this.points,
      required this.position,
      required this.priceLines,
      required this.isfirstTendPointTap,
      required this.trendLines,
      required this.firstTrendPoint,
      required this.isDragging,
      required this.draggingIndex});

  @override
  void paint(Canvas canvas, Size size) {
    //final double width = size.width;
    //final double height = size.height;

    final Paint linePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke;

    // final Paint priceLinePaint = Paint()
    //   ..color = Colors.yellow
    //   ..style = PaintingStyle.stroke;

    final Paint trendPoint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    if (isfirstTendPointTap) {
      canvas.drawLine(firstTrendPoint, position!, linePaint);
      canvas.drawCircle(firstTrendPoint, 6, trendPoint);
    }

    for (var i = 0; i < trendLines.length; i++) {
      final trendLine = trendLines[i];
      final startPoint = trendLine.startPoint;
      final endPoint = trendLine.endPoint;

      // Dibujar la línea
      canvas.drawLine(startPoint, endPoint, linePaint);

      // Dibujar los puntos de inicio y fin
      canvas.drawCircle(startPoint, 6, trendPoint);
      canvas.drawCircle(endPoint, 6, trendPoint);
    }

    // //Dibujamos el margen del canvas
    canvas.drawRect(
        Rect.fromPoints(const Offset(0, 0), Offset(size.width, size.height)),
        Paint()
          ..color = const Color.fromARGB(255, 0, 0, 0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0);
  }

  double _distanceBetweenPoints(Offset point1, Offset point2) {
    final double dx = point1.dx - point2.dx;
    final double dy = point1.dy - point2.dy;
    return sqrt(dx * dx + dy * dy);
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

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
