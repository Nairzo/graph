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
          SizedBox(
            width: 50,
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
                  // maxY += details.primaryDelta ?? 0.0;
                  // minY -= details.primaryDelta ?? 0.0;
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

    int roundToNearestMultipleY(double value, int exp) {
      final exponent = (log(value / exp) / log(exp)).ceil();
      final multiple =
          exp * exponent; // Calcula el múltiplo en lugar del exponente
      return multiple;
    }

    final double totalRange = maxY - minY;
    const int numberOfLines = 10;
    final double yInterval = totalRange / numberOfLines;
    double adjustedYAxisInterval = yInterval + (zoomY / 10);
    if (adjustedYAxisInterval < 0.1) {
      adjustedYAxisInterval = 0.1;
    }
    int intervalPrice = roundToNearestMultiple(adjustedYAxisInterval, 2);
    print(adjustedYAxisInterval);
    print(intervalPrice);

    //Dibujar líneas horizontales en el eje Y con etiquetas de valor (hacia arriba)
    // for (double lineValue = maxY;
    //     lineValue >= minY;
    //     lineValue -= intervalPrice) {
    //   final double y = height -
    //       ((lineValue - minY) * (height / (totalRange + zoomY))) +
    //       scrollOffsetY;
    //   if (y >= 0 && y <= height) {
    //     canvas.drawLine(Offset(0, y), Offset(width, y), linePaint);

    //     final TextPainter lineValuePainter = TextPainter(
    //       text: TextSpan(
    //         text: lineValue.toStringAsFixed(2),
    //         style: const TextStyle(color: Colors.black, fontSize: 12.0),
    //       ),
    //       textDirection: ui.TextDirection.ltr,
    //     );
    //     lineValuePainter.layout();
    //     lineValuePainter.paint(
    //       canvas,
    //       Offset(width + 5, y - lineValuePainter.height / 2),
    //     );
    //   }
    // }

    for (double lineValue = maxY;
        lineValue >= minY + scrollOffsetY - zoomY;
        lineValue -= intervalPrice) {
      final double y = height -
          ((lineValue - minY) * (height / (totalRange + zoomY))) +
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

    // Dibujar líneas también por encima de maxY si es visible en el canvas

    // Dibujar líneas horizontales en el eje Y con etiquetas de valor (hacia arriba)
    // for (double lineValue = maxY;
    //     lineValue >= minY;
    //     lineValue -= intervalPrice) {
    //   final double y = height -
    //       ((lineValue - minY) * (height / (totalRange + zoomY))) +
    //       scrollOffsetY;
    //   if (y >= 0 && y <= height) {
    //     canvas.drawLine(Offset(0, y), Offset(width, y), linePaint);

    //     final TextPainter lineValuePainter = TextPainter(
    //       text: TextSpan(
    //         text: lineValue.toStringAsFixed(2),
    //         style: const TextStyle(color: Colors.black, fontSize: 12.0),
    //       ),
    //       textDirection: ui.TextDirection.ltr,
    //     );
    //     lineValuePainter.layout();
    //     lineValuePainter.paint(
    //       canvas,
    //       Offset(width + 5, y - lineValuePainter.height / 2),
    //     );
    //   }
    // }

    // // Dibujar líneas horizontales adicionales mientras se desplaza verticalmente
    // for (double i = minY; i <= maxY; i += intervalPrice) {
    //   final double valuePosition = height -
    //       ((i - minY) * (height / (totalRange + zoomY))) +
    //       scrollOffsetY;
    //   if (valuePosition > 0 && valuePosition < height) {
    //     canvas.drawLine(
    //         Offset(0, valuePosition), Offset(width, valuePosition), linePaint);

    //     final TextPainter additionalLineValuePainter = TextPainter(
    //       text: TextSpan(
    //         text: i.toStringAsFixed(2),
    //         style: const TextStyle(color: Colors.black, fontSize: 12.0),
    //       ),
    //       textDirection: ui.TextDirection.ltr,
    //     );
    //     additionalLineValuePainter.layout();
    //     additionalLineValuePainter.paint(
    //       canvas,
    //       Offset(
    //           width + 5, valuePosition - additionalLineValuePainter.height / 2),
    //     );
    //   }

    // Dibujar líneas horizontales adicionales mientras se desplaza verticalmente hacia arriba
    // double positiveY = height + scrollOffsetY;
    // while (positiveY > 0) {
    //   canvas.drawLine(
    //       Offset(0, positiveY), Offset(width, positiveY), linePaint);

    //   final String valueAtLine =
    //       (minY + ((height - positiveY) * (totalRange / height)))
    //           .toStringAsFixed(2);
    //   final TextPainter additionalLineValuePainter = TextPainter(
    //     text: TextSpan(
    //       text: valueAtLine,
    //       style: const TextStyle(color: Colors.black, fontSize: 12.0),
    //     ),
    //     textDirection: ui.TextDirection.ltr,
    //   );
    //   additionalLineValuePainter.layout();
    //   additionalLineValuePainter.paint(
    //     canvas,
    //     Offset(width + 5, positiveY - additionalLineValuePainter.height / 2),
    //   );

    //   positiveY -= (height /
    //       10); // Cambia este valor para ajustar la frecuencia de las líneas
    // }

    // // Dibujar líneas horizontales adicionales mientras se desplaza verticalmente hacia abajo
    // double negativeY = height +
    //     scrollOffsetY +
    //     (height /
    //         10); // Comienza desde la posición de desplazamiento + una sección
    // while (negativeY < size.height) {
    //   canvas.drawLine(
    //       Offset(0, negativeY), Offset(width, negativeY), linePaint);

    //   final String valueAtLine =
    //       (minY + ((height - negativeY) * (totalRange / height)))
    //           .toStringAsFixed(2);
    //   final TextPainter additionalLineValuePainter = TextPainter(
    //     text: TextSpan(
    //       text: valueAtLine,
    //       style: const TextStyle(color: Colors.black, fontSize: 12.0),
    //     ),
    //     textDirection: ui.TextDirection.ltr,
    //   );
    //   additionalLineValuePainter.layout();
    //   additionalLineValuePainter.paint(
    //     canvas,
    //     Offset(width + 5, negativeY - additionalLineValuePainter.height / 2),
    //   );

    //   negativeY += (height /
    //       10); // Cambia este valor para ajustar la frecuencia de las líneas
    // }

    // Dibujar líneas horizontales cada 20 píxeles
    // final Paint horizontalLinePaint = Paint()
    //   ..color = Colors.grey.withOpacity(0.5) // Color de las líneas horizontales
    //   ..style = PaintingStyle.stroke;

    // final TextPainter valueLabelPainter = TextPainter(
    //   textDirection: ui.TextDirection.ltr,
    // );

    // double positiveLinePosition = 20.0 + (scrollOffsetY);
    // double negativeLinePosition = 20.0 + (scrollOffsetY);

    // while ((positiveLinePosition < size.height) || (negativeLinePosition > 0)) {
    //   if (positiveLinePosition < size.height && positiveLinePosition > 0) {
    //     canvas.drawLine(
    //       Offset(0, positiveLinePosition),
    //       Offset(size.width, positiveLinePosition),
    //       horizontalLinePaint,
    //     );

    //     final String valueTextPositive = (size.height - positiveLinePosition + scrollOffsetY).toStringAsFixed(0);
    //     valueLabelPainter.text = TextSpan(
    //       text: valueTextPositive,
    //       style: const TextStyle(color: Colors.black, fontSize: 12.0),
    //     );
    //     valueLabelPainter.layout();
    //     valueLabelPainter.paint(
    //       canvas,
    //       Offset(size.width - valueLabelPainter.width - 5, positiveLinePosition - valueLabelPainter.height / 2),
    //     );
    //   }

    //   if (negativeLinePosition > 0 && negativeLinePosition < size.height) {
    //     canvas.drawLine(
    //       Offset(0, negativeLinePosition),
    //       Offset(size.width, negativeLinePosition),
    //       horizontalLinePaint,
    //     );

    //     final String valueTextNegative = (size.height - negativeLinePosition + scrollOffsetY).toStringAsFixed(0);
    //     valueLabelPainter.text = TextSpan(
    //       text: valueTextNegative,
    //       style: TextStyle(color: Colors.black, fontSize: 12.0),
    //     );
    //     valueLabelPainter.layout();
    //     valueLabelPainter.paint(
    //       canvas,
    //       Offset(size.width - valueLabelPainter.width - 5, negativeLinePosition - valueLabelPainter.height / 2),
    //     );
    //   }

    //   positiveLinePosition += 40.0;
    //   negativeLinePosition -= 40.0;
    // }

    // Dibujar las velas financieras
    // for (int i = 0; i < data.length; i++) {
    //   final double candleWidth = width / data.length + zoom;
    //   // Calcular el centro de la vela
    //   final double centerX = (i * candleWidth) + scrollOffsetX;

    //   //final double centerX = i * adjustedXAxisInterval + scrollOffset;
    //   final double highY =
    //       height - (data[i].high - minY) * (height / (maxY - minY));
    //   final double lowY =
    //       height - (data[i].low - minY) * (height / (maxY - minY));
    //   final double openY = height -
    //       (data[i].open - minY - scrollOffsetY) * (height / (maxY - minY));
    //   final double closeY = height -
    //       (data[i].close - minY - scrollOffsetY) * (height / (maxY - minY));

    //   final Paint candlePaint = Paint()
    //     ..color = data[i].open < data[i].close ? Colors.green : Colors.red
    //     ..style = PaintingStyle.fill;

    //   final Paint wickPaint = Paint()
    //     ..color = data[i].open < data[i].close ? Colors.green : Colors.red
    //     ..style = PaintingStyle.stroke;

    //   // Dibujar el cuerpo de la vela
    //   canvas.drawRect(
    //     Rect.fromLTRB((centerX - candleWidth / 2).clamp(0.0, size.width), openY,
    //         (centerX + candleWidth / 2).clamp(0.0, size.width), closeY),
    //     candlePaint,
    //   );

    //   // // Dibujar las líneas superiores e inferiores de la vela (mechas)
    //   // canvas.drawLine(Offset(centerX.clamp(0.0, size.width), highY),
    //   //     Offset(centerX, openY), wickPaint);
    //   // canvas.drawLine(Offset(centerX.clamp(0.0, size.width), closeY),
    //   //     Offset(centerX, lowY), wickPaint);

    //   //Valores para dibujar los altos y bajos
    //   final wickTop =
    //       (size.height - highY + scrollOffsetY).clamp(0.0, size.height);
    //   final wickBottom =
    //       (size.height - lowY + scrollOffsetY).clamp(0.0, size.height);
    //   final wickLeft = (centerX - wickWidth / 2).clamp(0.0, size.width);
    //   final wickRight = (centerX + wickWidth / 2).clamp(0.0, size.width);

    //   //Dibujar altos y bajos
    //   canvas.drawRect(
    //       Rect.fromLTRB(wickLeft, wickTop, wickRight, wickBottom), wickPaint);
    // }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
