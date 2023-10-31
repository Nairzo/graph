import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

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
  double minY = 100.21;
  double maxY = 201.50;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Center(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    scrollOffsetX += details.primaryDelta ?? 0.0;
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    scrollOffsetX += details.delta.dx;
                    scrollOffsetY += details.delta.dy;
                  });
                },
                child: CustomPaint(
                  size: Size(size.width / 2, size.height / 2),
                  painter: PriceChartPainter(
                      zoomY: zoomY,
                      zoom: zoom,
                      scrollOffsetX: scrollOffsetX,
                      scrollOffsetY: scrollOffsetY,
                      startDate: widget.startDate,
                      endDate: widget.endDate,
                      data: widget.data,
                      maxY: maxY,
                      minY: minY),
                ),
              ),
              const SizedBox(
                height: 50,
              ),
              MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      zoom += details.primaryDelta! / 20;
                      if (zoom < -3.0) {
                        zoom = -3.0; // Establece el valor mínimo en 2.0
                      } else if (zoom > 125.0) {
                        zoom = 125.0;
                      }
                    });
                  },
                  child: Container(
                    height: 50,
                    width: size.width / 2,
                    color: Colors.blue,
                  ),
                ),
              )
            ],
          ),
          const SizedBox(
            width: 60,
          ),
          MouseRegion(
            cursor: SystemMouseCursors.resizeUpDown,
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                setState(() {
                  zoomY += details.primaryDelta ?? 0.0;
                  print(zoomY);
                  if (zoomY < -90) {
                    zoomY = -90;
                  }
                });
              },
              child: Container(
                height: size.height / 2,
                width: 50,
                color: Colors.blue,
              ),
            ),
          )
        ],
      ),
    );
  }
}

class PriceChartPainter extends CustomPainter {
  final DateTime startDate;
  final DateTime endDate;
  double zoom;
  double zoomY;
  double scrollOffsetX;
  double scrollOffsetY;
  final List<Candlestick> data;
  double minY;
  double maxY;

  PriceChartPainter(
      {required this.startDate,
      required this.zoom,
      required this.scrollOffsetX,
      required this.scrollOffsetY,
      required this.zoomY,
      required this.endDate,
      required this.data,
      required this.maxY,
      required this.minY});

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    final int minutes = endDate.difference(startDate).inMinutes;

    final Paint linePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke;

    // Ajustar el ancho de los minutos
    double adjustedXAxisInterval = (width / data.length) + zoom;
    //double adjustedXAxisInterval = xAxisInterval + zoom;

    const double constantValue =
        100.0; // Ajusta este valor según tus necesidades.

    int roundToNearestMultiple(double value, int exp) {
      final exponent = (log(value / exp) / log(exp)).ceil();
      final multiple = pow(exp, exponent).toInt();
      return multiple;
    }

    //final int interval = (constantValue / adjustedXAxisInterval).ceil();
    double interval = (constantValue / adjustedXAxisInterval);
    int intervalMinutes = roundToNearestMultiple(interval, 2);
    if (intervalMinutes == 0 || intervalMinutes < 0) {
      intervalMinutes = 1;
    }

    // Dibujar líneas verticales (eje X) y etiquetas de tiempo
    for (int i = 0; i <= minutes; i += intervalMinutes) {
      final double centerX = i * adjustedXAxisInterval + scrollOffsetX;
      if (centerX > 0 && centerX < width) {
        // Dibujar la línea vertical
        canvas.drawLine(Offset(centerX, 0), Offset(centerX, height), linePaint);

        final DateTime currentDateTime = startDate.add(Duration(minutes: i));

        // Formato de la fecha y hora como una cadena
        final String timeLabel = DateFormat.Hm().format(currentDateTime);

        // Dibujar la etiqueta de tiempo debajo de la línea
        final TextPainter timeLabelPainter = TextPainter(
          text: TextSpan(
            text: timeLabel,
            style: const TextStyle(color: Colors.black, fontSize: 12.0),
          ),
          textDirection: ui.TextDirection.ltr,
        );
        timeLabelPainter.layout();
        timeLabelPainter.paint(
          canvas,
          Offset(centerX - timeLabelPainter.width / 2, height + 5),
        );
      }
    }

    final double totalRange = maxY - minY;
    const int numberOfLines = 10;
    final double yInterval = totalRange / numberOfLines;
    double adjustedYAxisInterval = yInterval + (zoomY / 10);
    if (adjustedYAxisInterval < 1) {
      adjustedYAxisInterval = 1;
    }
    int intervalPrice = (roundToNearestMultiple(adjustedYAxisInterval, 2));
    print(adjustedYAxisInterval);
    print(intervalPrice);


    for (double lineValue = maxY;
        lineValue >= minY - intervalPrice;
        lineValue -= intervalPrice) {
      final double y = (height - ((lineValue - minY) * (height / (totalRange + zoomY )))) +
          scrollOffsetY;
      if (y >= 0 && y <= height) {
        canvas.drawLine(Offset(0, y), Offset(width, y), linePaint);

        final TextPainter lineValuePainter = TextPainter(
          text: TextSpan(
            text: lineValue.toStringAsFixed(2),
            style: const TextStyle(color: Colors.black, fontSize: 12.0),
          ),
          textDirection: ui.TextDirection.ltr,
        );
        lineValuePainter.layout();
        lineValuePainter.paint(
          canvas,
          Offset(width + 5, y - lineValuePainter.height / 2),
        );
      }
    }

    for (double lineValue = maxY;
        lineValue <= maxY + scrollOffsetY;
        lineValue += intervalPrice) {
      final double y =
          height - ((lineValue - minY) * (height / (totalRange + zoomY ))) + scrollOffsetY;
      if (y >= 0 && y <= height) {
        canvas.drawLine(Offset(0, y), Offset(width, y), linePaint);

        final TextPainter lineValuePainter = TextPainter(
          text: TextSpan(
            text: lineValue.toStringAsFixed(2),
            style: const TextStyle(color: Colors.black, fontSize: 12.0),
          ),
          textDirection: ui.TextDirection.ltr,
        );
        lineValuePainter.layout();
        lineValuePainter.paint(
          canvas,
          Offset(width + 5, y - lineValuePainter.height / 2),
        );
      }
    }

    for (double lineValue = minY - intervalPrice;
        lineValue >= minY + scrollOffsetY;
        lineValue -= intervalPrice) {
      final double y =
          height - ((lineValue - minY) * (height / (totalRange + zoomY ))) + scrollOffsetY;
      if (y >= 0 && y <= height) {
        canvas.drawLine(Offset(0, y), Offset(width, y), linePaint);

        final TextPainter lineValuePainter = TextPainter(
          text: TextSpan(
            text: lineValue.toStringAsFixed(2),
            style: const TextStyle(color: Colors.black, fontSize: 12.0),
          ),
          textDirection: ui.TextDirection.ltr,
        );
        lineValuePainter.layout();
        lineValuePainter.paint(
          canvas,
          Offset(width + 5, y - lineValuePainter.height / 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
