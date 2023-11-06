import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math';

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

  @override
  void initState() {
    super.initState();
  }

  void updateVisiblePricesWhenScrollY(double delta, Size size) {
    double factor =
        0.025; // Puedes ajustar este factor para controlar la velocidad del desplazamiento
    double intervaloEntreLineas =
        (maxY - minY) / 10; // Puedes ajustar el número de líneas
    double desplazamiento = delta * factor * intervaloEntreLineas;

    scrollOffsetY += desplazamiento;

    setState(() {});
  }

  updateVisiblePricesWhenZoom(double zoom) {
    double factor = 0.01;
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

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Center(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                updateVisiblePricesWhenScrollY(details.delta.dy, size);
              });
            },
            child: CustomPaint(
              size: Size(size.width / 2, size.height / 2),
              painter: PriceChartPainter(
                  scrollOffsetY: scrollOffsetY,
                  maxY: maxY,
                  minY: minY,
                  zoomY: zoomY),
            ),
          ),
          const SizedBox(
            width: 60,
          ),
          MouseRegion(
            cursor: SystemMouseCursors.resizeUpDown,
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                setState(() {
                  zoomY += details.delta.dy;
                  updateVisiblePricesWhenZoom(details.delta.dy);
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
  double scrollOffsetY;
  double minY;
  double maxY;
  double zoomY;

  PriceChartPainter(
      {required this.scrollOffsetY,
      required this.maxY,
      required this.minY,
      required this.zoomY});

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;

    final Paint linePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke;

    //Dibujar lineas horizontales
    double siguienteMultiplo(double valor) {
      double multiplo;
      if (valor < 0.01) {
        multiplo = 0.01;
        while (multiplo <= valor) {
          multiplo += 0.01;
        }
      } else if (valor < 0.02) {
        multiplo = 0.02;
        while (multiplo <= valor) {
          multiplo += 0.02;
        }
      } else if (valor < 0.05) {
        multiplo = 0.05;
        while (multiplo <= valor) {
          multiplo += 0.05;
        }
      } else if (valor < 0.2) {
        multiplo = 0.1;
        while (multiplo <= valor) {
          multiplo += 0.1;
        }
      } else if (valor < 0.5) {
        multiplo = 0.2;
        while (multiplo <= valor) {
          multiplo += 0.2;
        }
      } else if (valor < 1) {
        multiplo = 0.2;
        while (multiplo <= valor) {
          multiplo += 0.2;
        }
      } else if (valor < 5) {
        multiplo = 2;
        while (multiplo <= valor) {
          multiplo *= 2;
        }
      } else {
        int entero = valor.round();
        multiplo = 10;
        while (multiplo <= entero) {
          multiplo *= 2;
        }
      }

      return multiplo;
    }

    final num totalRange = maxY - minY;
    final double valorMedio = (maxY + minY) / 2;
    const int numberOfLines = 10;
    final double yInterval = totalRange / numberOfLines;
    double intervalPrice = (siguienteMultiplo(yInterval));
    if (intervalPrice == 0.01 || intervalPrice < 0.01) {
      intervalPrice = 0.01;
    }
    //double delta = scrollOffsetY / maxVisiblePrice;

    for (double lineValue = valorMedio;
        lineValue <= (height + scrollOffsetY * zoomY) ;
        lineValue += intervalPrice) {
      final double y =
          height - ((lineValue - minY - scrollOffsetY) * (height / totalRange));
      if (y >= 0 && y <= height) {
        canvas.drawLine(Offset(0.0, y), Offset(size.width, y), linePaint);

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
          Offset(width / 2 - lineValuePainter.width / 2,
              y - lineValuePainter.height / 2),
        );
      }
    }

    for (double lineValue = valorMedio - intervalPrice;
        lineValue >= (0.0 + scrollOffsetY - height);
        lineValue -= intervalPrice) {
      final double y =
          height - ((lineValue - minY - scrollOffsetY) * (height / totalRange));
      if (y >= 0 && y <= height) {
        canvas.drawLine(Offset(0.0, y), Offset(size.width, y), linePaint);

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
          Offset(width / 2 - lineValuePainter.width / 2,
              y - lineValuePainter.height / 2),
        );
      }
    }
    //Dibujamos el margen del canvas
    canvas.drawRect(
        Rect.fromPoints(const Offset(0, 0), Offset(size.width, size.height)),
        Paint()
          ..color = const Color.fromARGB(255, 0, 0, 0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
