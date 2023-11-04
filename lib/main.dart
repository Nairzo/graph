import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/candle.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';

import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    minimumSize: Size(1024, 768),
    center: true,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    backgroundColor: Colors.transparent,
    windowButtonVisibility: false,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  final tradeDataManager = TradeDataManager();
  await tradeDataManager.getTradeData();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      home: MyHomePage(
        title: '1ero Graphx',
        tradeDataManager: tradeDataManager,
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage(
      {super.key, required this.title, required this.tradeDataManager});

  final String title;
  final TradeDataManager tradeDataManager;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 16, 15, 14),
      body:  GraphStateRegion(tradeDataManager),
    );
  }
}

class TimeFramePainter extends CustomPainter {
  final Offset? position; //Variable para manejar la posicion del cursor
  double scrollOffset; // Variable para controlar el desplazamiento horizontal
  double zoom;
  final TradeDataManager tradeDataManager;
  final String date;

  TimeFramePainter(this.tradeDataManager,
      {required this.position,
      required this.scrollOffset,
      required this.zoom,
      required this.date});
  @override
  void paint(Canvas canvas, Size size) {
    final cutomWidth =
        (size.width / tradeDataManager.dataLength) + zoom; //Ancho de las velas
    const double constantValue = 100.0;

    List<TimeScaleValue> candles = generateTimeScale(size);

    int roundToNearestMultiple(double value) {
      final exponent = (log(value / 2) / log(2)).ceil();
      final multiple = pow(2, exponent).toInt();
      return multiple;
    }

    double intervalX = (constantValue / cutomWidth);
    int intervalMinutes = roundToNearestMultiple(intervalX);
    if (intervalMinutes == 0 || intervalMinutes < 0) {
      intervalMinutes = 1;
    }

    DateTime? previousCandleDate;

    Paint line = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 0; i < candles.length; i++) {
      TimeScaleValue candle = candles[i];

      if ((i + 1) % intervalMinutes == 0) {
        if (candle.centerX > 0 && candle.centerX < size.width) {
          DateTime candleDate =
              DateTime.parse(tradeDataManager.dataList[candle.index].date!);

          String format = (previousCandleDate != null &&
                  previousCandleDate.day != candleDate.day)
              ? 'MM/dd'
              : 'HH:mm';
          final TextPainter dateTextPainter = TextPainter(
            text: TextSpan(
              text: DateFormat(format).format(candleDate),
              style: const TextStyle(color: Colors.white, fontSize: 12.0),
            ),
            textDirection: ui.TextDirection.ltr,
          );
          dateTextPainter.layout();
          dateTextPainter.paint(
              canvas,
              Offset(candle.centerX - dateTextPainter.width / 2,
                  size.height - dateTextPainter.height));

          canvas.drawLine(Offset(candle.centerX, 0),
              Offset(candle.centerX, size.height / 2 - 2), line);

          previousCandleDate = candleDate;
        }
      }
    }

    double x = position?.dx ?? 0.0;

    // Dibujar el recuadro en la derecha de la línea guía
    const double rectWidth = 50.0;

    double centerX = x - rectWidth / 2;
    final Rect rect = Rect.fromPoints(
        Offset(centerX, 0.0), Offset(centerX + rectWidth, size.height));

    final Paint rectPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    canvas.drawRect(rect, rectPaint);

    //Dibujar el margen del canvas
    canvas.drawRect(
        Rect.fromPoints(const Offset(0, 0), Offset(size.width, size.height)),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0);

    if (date != '') {
      DateTime dateParse = DateTime.parse(date);
      // Dibujar texto en el centro del rectángulo
      TextSpan span = TextSpan(
        text: DateFormat('HH:mm').format(dateParse),
        style: const TextStyle(color: Colors.white, fontSize: 12.0),
      );
      TextPainter textPainter = TextPainter(
        text: span,
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout(minWidth: 0, maxWidth: rectWidth);
      textPainter.paint(
        canvas,
        Offset(
            x - textPainter.width / 2, (size.height - textPainter.height) / 2),
      );
    }
  }

  List<TimeScaleValue> generateTimeScale(Size availableSpace) {
    double pixelsPerTime =
        (availableSpace.width / tradeDataManager.dataLength) + zoom + 2;
    //List<CandleDTO> reverse = tradeDataManager.dataList.reversed.toList();
    List<TimeScaleValue> candles = [];
    for (int i = 0; i < tradeDataManager.dataLength; i++) {
      // double centerX = (availableSpace.width - availableSpace.width / 4) -
      //     (i + 1) * pixelsPerTime +
      //     scrollOffset -
      //     zoom;

      double centerX =
          (availableSpace.width) - (i - (scrollOffset / 10)) * pixelsPerTime;

      if (centerX < 0) {
        continue; // Evitar dibujar velas fuera del canvas
      }

      //Creamos la lista de velas
      candles.add(TimeScaleValue(index: i, centerX: centerX));
    }

    return candles;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class TimeScaleValue {
  double centerX;
  final int index;

  TimeScaleValue({
    required this.centerX,
    required this.index,
  });
}

//CustomPainter para dibujar la grafica de velas
class CandleStickPainter extends CustomPainter {
  // ignore: unused_field
  final Paint _wickPaint;
  final Paint _gainPaint;
  final Paint _lossPaint;
  final TradeDataManager tradeDataManager;
  final double wickWidth = 1.5;

  final Offset? position; //Variable para manejar la posicion del cursor
  double scrollOffsetX; // Variable para controlar el desplazamiento horizontal
  double scrollOffsetY; // Variable para controlar el desplazamiento horizontal
  double zoomX;
  double zoomY;

  num maxVisiblePrice;
  num minVisiblePrice;
  List<double> priceLines;

  CandleStickPainter(
      this.tradeDataManager,
      this.position,
      this.scrollOffsetX,
      this.scrollOffsetY,
      this.zoomX,
      this.zoomY,
      this.maxVisiblePrice,
      this.minVisiblePrice,
      this.priceLines,
      {Paint? gainPaint,
      Paint? lossPaint})
      : _wickPaint = Paint()..color = Colors.grey,
        _gainPaint = Paint()..color = const Color.fromARGB(255, 84, 223, 89),
        _lossPaint = Paint()..color = const Color.fromARGB(255, 249, 64, 51);

  final financialDataBloc =
      FinancialDataBloc(); //Bloc para compartir informacion de las velas

  @override
  void paint(Canvas canvas, Size size) {
    double height = size.height;
    double width = size.width;
    num maxY = maxVisiblePrice;
    num minY = minVisiblePrice;

    List<Candletick> candles = generateCandleSticks(size);
    final cutomWidth =
        (size.width / tradeDataManager.dataLength) + zoomX; //Ancho de las velas

    int roundToNearestMultiple(double value) {
      final exponent = (log(value / 2) / log(2)).ceil();
      final multiple = pow(2, exponent).toInt();
      return multiple;
    }

    //Estilo lineas del grid
    final Paint gridLinesPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.0 //Ancho de la linea
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke;
    const double vGridLineDashWidth = 3; //tamaño de los puntos en la linea
    const double vGridLineGashSpace = 5; //Espacio entre los puntos

    const double hGridLineDashWidth = 1; // Tamaño de los puntos en la línea
    const double hGridLineDashSpace = 5; // Espacio entre los puntos

    //Dibujar lineas horizontales
    double siguienteMultiplo(double valor) {
      double multiplo;
      if (valor < 0.2) {
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
        multiplo = 0.5;
        while (multiplo <= valor) {
          multiplo += 0.5;
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

    double zoomFactor = 1.0 + (zoomY / 10);
    final num totalRange = maxY - minY;
    final double valorMedio = (maxY + minY) / 2;
    const int numberOfLines = 10;
    final double yInterval = totalRange / numberOfLines;
    double adjustedYAxisInterval = yInterval + (zoomY / 10);
    double intervalPrice = (siguienteMultiplo(adjustedYAxisInterval));
    if (intervalPrice == 0.1 || intervalPrice < 0.1) {
      intervalPrice = 0.1;
    }

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

    for (double lineValue = valorMedio;
        lineValue <= (height + scrollOffsetY) * zoomFactor;
        lineValue += intervalPrice) {
      final double y = height -
          ((lineValue - minY) * (height / (totalRange + zoomY))) +
          scrollOffsetY;
      if (y >= 0 && y <= height) {
        for (double i = 0;
            i < size.width;
            i += hGridLineDashWidth + hGridLineDashSpace) {
          canvas.drawLine(
              Offset(i, y), Offset(i + hGridLineDashWidth, y), gridLinesPaint);
        }
      }
    }

    for (double lineValue = valorMedio - intervalPrice;
        lineValue >= (0.0 + scrollOffsetY - height) * zoomFactor;
        lineValue -= intervalPrice) {
      final double y = height -
          ((lineValue - minY) * (height / (totalRange + zoomY))) +
          scrollOffsetY;
      if (y >= 0 && y <= height) {
        for (double i = 0;
            i < size.width;
            i += hGridLineDashWidth + hGridLineDashSpace) {
          canvas.drawLine(
              Offset(i, y), Offset(i + hGridLineDashWidth, y), gridLinesPaint);
        }
      }
    }

    //Estilo lineas guia
    final Paint guideLinesPaint = Paint()
      ..color = Colors.red.withOpacity(0.8)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.0 //Ancho de la linea
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke;
    const double guideLineDashWidth = 4; //tamaño de los puntos en la linea
    const double guideLineDashSpace = 10; //Espacio entre los puntos

    double constantValue = 100.0;
    double intervalX = (constantValue / cutomWidth);
    int intervalMinutes = roundToNearestMultiple(intervalX);
    if (intervalMinutes == 0 || intervalMinutes < 0) {
      intervalMinutes = 1;
    }

    for (int i = 0; i < candles.length; i++) {
      Candletick candle = candles[i];

      if ((i + 1) % intervalMinutes == 0) {
        // Dibujar línea vertical en el centerX de cada window

        if (candle.centerX > 0 && candle.centerX < size.width) {
          for (double i = 0;
              i < size.height;
              i += vGridLineDashWidth + vGridLineGashSpace) {
            final start = Offset(candle.centerX, i);
            final end = Offset(
                candle.centerX, (i + vGridLineDashWidth).clamp(0, size.height));
            canvas.drawLine(start, end, gridLinesPaint);
          }
        }
      }

      //Valores para dibujar las velas
      final candleTop = (size.height - candle.candleHighY + scrollOffsetY).clamp(
          0.0,
          size.height); //Clamp es para que se deje de dibujar despues de la posicion dada
      final candleBottom = (size.height - candle.candleLowY + scrollOffsetY)
          .clamp(0.0, size.height);
      final candleLeft =
          (candle.centerX - cutomWidth / 2).clamp(0.0, size.width);
      final candleRight =
          (candle.centerX + cutomWidth / 2).clamp(0.0, size.width);

      //Valores para dibujar los altos y bajos
      final wickTop = (size.height - candle.wickHighY + scrollOffsetY)
          .clamp(0.0, size.height);
      final wickBottom = (size.height - candle.wicklowY + scrollOffsetY)
          .clamp(0.0, size.height);
      final wickLeft = (candle.centerX - wickWidth / 2).clamp(0.0, size.width);
      final wickRight = (candle.centerX + wickWidth / 2).clamp(0.0, size.width);

      if (candleLeft < size.width && candleRight > 0) {
        //Dibujar lineas de valor mas alto y bajo de las velas
        if (wickTop.isFinite &&
            wickBottom.isFinite &&
            wickLeft.isFinite &&
            wickRight.isFinite) {
          canvas.drawRect(
              Rect.fromLTRB(wickLeft, wickTop, wickRight, wickBottom),
              candle.candlePaint); //_wickPaint
        }

        //Dibujar el open, close y ancho de las velas
        if (candleTop.isFinite &&
            candleBottom.isFinite &&
            candleLeft.isFinite &&
            candleRight.isFinite) {
          canvas.drawRect(
              Rect.fromLTRB(candleLeft, candleTop, candleRight, candleBottom),
              candle.candlePaint);
        }
      }

      //Cuando el cursor se encuentre entre el ancho de la vela comparte su informacion
      if (position != null &&
          position!.dx >= candleLeft &&
          position!.dx <= candleRight) {
        final reverse = tradeDataManager.dataList;
        final tradeData = reverse[candle.index];
        final newFinancialData = CandleDTO(
            date: tradeData.date,
            open: tradeData.open,
            close: tradeData.close,
            high: tradeData.high,
            low: tradeData.low,
            volume: tradeData.volume);
        financialDataBloc.updateFinancialData(newFinancialData);
      }
    }

    if (position != null) {
      final double x = position!.dx;
      final double y = position!.dy;

      // Dibujar la línea guia horizontal punteada
      for (double i = 0;
          i < size.width;
          i += guideLineDashWidth + guideLineDashSpace) {
        canvas.drawLine(
          Offset(i, y),
          Offset(i + guideLineDashWidth, y),
          guideLinesPaint,
        );
      }

      double price = minVisiblePrice +
          (maxVisiblePrice - minVisiblePrice) * (1.0 - (y / size.height));

      // Dibujar el recuadro en la derecha de la línea guía
      const double rectHeight = 30.0;
      const double rectWidth = 50.0;
      final double rectX = size.width; // Posición X del recuadro
      final double rectY = (y - rectHeight / 2)
          .clamp(0.0, size.height); // Posición Y del recuadro
      final Rect rect = Rect.fromPoints(
          Offset(rectX, rectY), Offset(rectX + rectWidth, rectY + rectHeight));

      //Estilo del cuadro de precio
      final Paint rectPaint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.fill;

      canvas.drawRect(rect, rectPaint);

      // Formatea el precio con dos decimales y muestra el valor en el rectángulo
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: price.toStringAsFixed(2),
          style: const TextStyle(color: Colors.white, fontSize: 12.0),
        ),
        textDirection: ui.TextDirection.ltr,
      );

      textPainter.layout(maxWidth: rectWidth);

      // Calcula la posición del texto para que esté centrado en el rectángulo
      final double textX = rectX + (rectWidth - textPainter.width) / 2;
      final double textY = rectY + (rectHeight - textPainter.height) / 2;
      textPainter.paint(canvas, Offset(textX, textY));

      // Dibujar la línea guia vertical punteada
      for (double i = 0;
          i < size.height;
          i += guideLineDashWidth + guideLineDashSpace) {
        canvas.drawLine(
          Offset(x, i),
          Offset(x, (i + guideLineDashWidth).clamp(0, size.height)),
          guideLinesPaint,
        );
      }
    }

    //Dibujar el margen del canvas
    canvas.drawRect(
        Rect.fromPoints(const Offset(0, 0), Offset(size.width, size.height)),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0);

    // // Obtener el valor de open de la última vela visible en el rango actual
    // num lastVisibleClose = 0.0; // Valor inicial
    // bool isGain = false;
    // List<CandleDTO> reverse = tradeDataManager.dataList.reversed.toList();
    // for (Candletick candle in candles) {
    //   if (candle.index >= 0 && candle.index < tradeDataManager.dataLength) {
    //     CandleDTO lastVisibleTradeData = reverse[candle.index];
    //     lastVisibleClose = lastVisibleTradeData.close!;
    //     isGain = lastVisibleTradeData.isGain();
    //   }
    // }

    // // Calcular la posición Y del cuadro en función del valor de "Open" en relación al precio máximo y mínimo
    // final double openY = size.height -
    //     ((lastVisibleClose - minVisiblePrice) /
    //         (maxVisiblePrice - minVisiblePrice) *
    //         size.height);

    // // Calcular la posición X para el cuadro en la parte derecha del rango visible del canvas
    const double rectWidth = 50.0; // Ancho del cuadro
    // final double rectX = size.width; // Posición X del cuadro

    // // Dibujar el cuadro con el valor de open en la posición Y calculada
    // final Paint rectPaint = Paint()
    //   ..color = Colors.black
    //   ..style = PaintingStyle.fill;
    // const double rectHeight = 20.0;
    // final double rectY = (openY - rectHeight / 2) +
    //     scrollOffsetY; // Centrar verticalmente según el precio
    // final Rect rect = Rect.fromPoints(
    //     Offset(rectX, rectY), Offset(rectX + rectWidth, rectY + rectHeight));
    // canvas.drawRect(rect, rectPaint);

    // final Paint borderPaint = Paint()
    //   ..color = isGain ? Colors.green : Colors.red
    //   ..style = PaintingStyle.stroke
    //   ..strokeWidth = 2.0; // Ancho del borde

    // canvas.drawRect(rect, borderPaint);

    // // Texto con el valor de open
    // final TextPainter textPainter = TextPainter(
    //   text: TextSpan(
    //     text: lastVisibleClose.toStringAsFixed(2),
    //     style: const TextStyle(color: Colors.white, fontSize: 12.0),
    //   ),
    //   textDirection: ui.TextDirection.ltr,
    // );
    // textPainter.layout(maxWidth: rectWidth);

    // // Calcular la posición del texto para que esté centrado en el cuadro
    // final double textX = rectX + (rectWidth - textPainter.width) / 2;
    // final double textY = rectY + (rectHeight - textPainter.height) / 2;
    // textPainter.paint(canvas, Offset(textX, textY));

    final Paint priceLinePaint = Paint()
      ..color = Color.fromARGB(255, 235, 255, 12)
      ..style = PaintingStyle.stroke;

    //Dibujar linea horizontal de precio
    for (var tapPositionY in priceLines) {
      double price = minVisiblePrice +
          (maxVisiblePrice - minVisiblePrice) *
              (1.0 - (tapPositionY / size.height));
      canvas.drawLine(
        Offset(0, tapPositionY + scrollOffsetY),
        Offset(width, tapPositionY + scrollOffsetY),
        priceLinePaint,
      );

      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: price.toStringAsFixed(2),
          style: const TextStyle(color: Colors.white, fontSize: 12.0),
        ),
        textDirection: ui.TextDirection.ltr,
      );

      textPainter.layout(maxWidth: rectWidth);

      textPainter.paint(
          canvas, Offset(width - textPainter.width, tapPositionY));
    }
  }

  //Genera las velas y les asigna los valores para dibujarse
  List<Candletick> generateCandleSticks(Size availableSpace) {
    double pixelsPerTime =
        (availableSpace.width / tradeDataManager.dataLength) + zoomX + 2;

    final priceRange = maxVisiblePrice - minVisiblePrice; //Rango de precio
    final pixelsPerDollar = availableSpace.height /
        priceRange; //Velas dibujadas verticalmente en el rango de precios disponible

    List<Candletick> candles = [];
    for (int i = 0; i < tradeDataManager.dataLength; i++) {
      CandleDTO window = tradeDataManager.dataList[i];

      double wickHighY = (window.high! - minVisiblePrice) * pixelsPerDollar;
      double wickLowY = (window.low! - minVisiblePrice) * pixelsPerDollar;
      double candleHighY = (window.open! - minVisiblePrice) * pixelsPerDollar;
      double candleLowY = (window.close! - minVisiblePrice) * pixelsPerDollar;
      //double centerX = (i + 1) * pixelsPerTime + scrollOffsetX - zoom;
      double centerX =
          (availableSpace.width) - (i - (scrollOffsetX / 10)) * pixelsPerTime;

      if (centerX < 0) {
        continue; // Evitar dibujar velas fuera del canvas
      }

      //Creamos la lista de velas
      candles.add(Candletick(
          index: i,
          wickHighY: wickHighY,
          wicklowY: wickLowY,
          candleHighY: candleHighY,
          candleLowY: candleLowY,
          centerX: centerX,
          candlePaint: window.isGain() ? _gainPaint : _lossPaint));
    }

    return candles;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

//CustomPainter para dibujar la grafica de volumen
class VolumePainter extends CustomPainter {
  final Paint _gainPaint;
  final Paint _lossPaint;
  final TradeDataManager tradeDataManager;
  final Offset? position; //Variable para manejar la posicion del cursor
  double scrollOffset; //Variable para controlar el desplazamiento horizontal
  num maxVisibleVolume;
  double zoom;

  VolumePainter(this.tradeDataManager, this.position, this.scrollOffset,
      this.zoom, this.maxVisibleVolume,
      {Paint? gainPaint, Paint? lossPaint})
      : _gainPaint = Paint()..color = const Color.fromARGB(255, 84, 223, 89),
        _lossPaint = Paint()..color = const Color.fromARGB(255, 249, 64, 51);

  @override
  void paint(Canvas canvas, Size size) {
    List<Bar> bars = generateBars(size);

    const volumeValueInView = 3;
    final Paint gridLinesPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.0 //Ancho de la linea
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke;

    const double hGridLineDashWidth = 1; // Tamaño de los puntos en la línea
    const double hGridLineDashSpace = 5; // Espacio entre los puntos

    for (int i = volumeValueInView; i > 0; i--) {
      final y = (size.height / volumeValueInView) * (volumeValueInView - i);
      for (double i = 0;
          i < size.width;
          i += hGridLineDashWidth + hGridLineDashSpace) {
        canvas.drawLine(
          Offset(i, y),
          Offset(i + hGridLineDashWidth, y),
          gridLinesPaint,
        );
      }
    }

    for (Bar bar in bars) {
      //Valores para el ancho  y alto de las barras
      final barLeft = (bar.centerX - bar.width / 2).clamp(0.0, size.width);
      final barRight = (bar.centerX + bar.width / 2).clamp(0.0, size.width);
      final barHeight = (size.height - bar.height).clamp(0.0, size.height);

      //Dibujamos las barras
      canvas.drawRect(
          Rect.fromLTRB(barLeft, barHeight, barRight, size.height), bar.paint);
    }

    //Estilo de la linea guia vertical
    final Paint paint = Paint()
      ..color = Colors.red
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.0 //Ancho de la linea guia
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke;
    const double dashWidth = 4; //Tamaño de los puntos
    const double dashSpace = 10; //Tamaño de espacio entre puntos

    final double x = position?.dx ?? 0;

    //Dibujamos la linea guia vertical
    for (double i = 0; i < size.height; i += dashWidth + dashSpace) {
      canvas.drawLine(
        Offset(x, i),
        Offset(x, i + dashWidth),
        paint,
      );
    }

    //Dibujamos el margen del canvas
    canvas.drawRect(
        Rect.fromPoints(const Offset(0, 0), Offset(size.width, size.height)),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0);
  }

  //Genera las barras y les asigna sus valores
  List<Bar> generateBars(Size availableSpace) {
    final pixelsPerTime =
        availableSpace.width / tradeDataManager.dataLength + 2 + zoom;
    final pixelsPerVolume = availableSpace.height / maxVisibleVolume;

    List<Bar> bars = [];
    for (int i = 0; i < tradeDataManager.dataLength; i++) {
      CandleDTO window = tradeDataManager.dataList[i];

      //double centerX = (i + 1) * pixelsPerTime + scrollOffset;
      // double centerX = (availableSpace.width - availableSpace.width / 4) -
      //     (i + 1) * pixelsPerTime +
      //     scrollOffset -
      //     zoom;

      double centerX =
          (availableSpace.width) - (i - (scrollOffset / 10)) * pixelsPerTime;

      bars.add(Bar(
          height: window.volume! * pixelsPerVolume,
          width: pixelsPerTime - 1.0,
          centerX: centerX,
          paint: window.isGain() ? _gainPaint : _lossPaint));
    }
    return bars;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

//CustomPaint para dibujar la columna de precios
class PriceRangePainter extends CustomPainter {
  num maxY;
  num minY;
  double zoomY;
  double scrollOffsetY;

  PriceRangePainter(
      {required this.maxY,
      required this.minY,
      required this.zoomY,
      required this.scrollOffsetY});

  @override
  void paint(Canvas canvas, Size size) {
    double height = size.height;
    double width = size.width;
    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 12,
    );

    //Dibujar lineas horizontales
    double siguienteMultiplo(double valor) {
      double multiplo;
      if (valor < 0.2) {
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
        multiplo = 0.5;
        while (multiplo <= valor) {
          multiplo += 0.5;
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

    double zoomFactor = 1.0 + (zoomY / 10);
    final num totalRange = maxY - minY;
    final double valorMedio = (maxY + minY) / 2;
    const int numberOfLines = 10;
    final double yInterval = totalRange / numberOfLines;
    double adjustedYAxisInterval = yInterval + (zoomY / 10);
    double intervalPrice = (siguienteMultiplo(adjustedYAxisInterval));
    if (intervalPrice == 0.1 || intervalPrice < 0.1) {
      intervalPrice = 0.1;
    }

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

    for (double lineValue = valorMedio;
        lineValue <= (height + scrollOffsetY) * zoomFactor;
        lineValue += intervalPrice) {
      final double y = height -
          ((lineValue - minY) * (height / (totalRange + zoomY))) +
          scrollOffsetY;
      if (y >= 0 && y <= height) {
        final TextPainter lineValuePainter = TextPainter(
          text: TextSpan(
            text: lineValue.toStringAsFixed(2),
            style: textStyle,
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
        lineValue >= (0.0 + scrollOffsetY - height) * zoomFactor;
        lineValue -= intervalPrice) {
      final double y = height -
          ((lineValue - minY) * (height / (totalRange + zoomY))) +
          scrollOffsetY;
      if (y >= 0 && y <= height) {
        final TextPainter lineValuePainter = TextPainter(
          text: TextSpan(
            text: lineValue.toStringAsFixed(2),
            style: textStyle,
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
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class VolumeRangePainter extends CustomPainter {
  final num maxVolume;

  VolumeRangePainter({required this.maxVolume});

  @override
  void paint(Canvas canvas, Size size) {
    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 12,
    );

    const volumeValueInView = 3;
    final interval = maxVolume / volumeValueInView;

    for (int i = volumeValueInView; i > 0; i--) {
      final volumeValue = (interval * i).toInt();
      final text = NumberFormat("#,###", "en_US").format(volumeValue);

      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: textStyle,
        ),
        textDirection: ui.TextDirection.ltr,
      );

      textPainter.layout(maxWidth: size.width);

      final x = (size.width - textPainter.width) / 2;
      final y = (size.height / volumeValueInView) * (volumeValueInView - i) -
          (textPainter.height / 2);

      textPainter.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

//Clase modelo de una barra
class Bar {
  double height;
  final double width;
  final double centerX;
  final Paint paint;

  Bar(
      {required this.height,
      required this.width,
      required this.centerX,
      required this.paint});
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

//Clase para obtener y controlar la informacion
class TradeDataManager {
  List<CandleDTO> dataList = [];
  num maxVolume = 0;
  num maxPrice = 0.0;
  num minPrice = double.infinity;

  Future<void> getTradeData() async {
    final jsonString = await rootBundle.loadString('assets/data/data.json');
    final stockDataJson = json.decode(jsonString);
    //final stockData = TradeData.fromJson(stockDataJson);

    final List<CandleDTO> stockData =
        tradeDataFromJson(json.encode(stockDataJson));

    dataList.clear();
    maxPrice = 0.0;
    minPrice = double.infinity;
    for (var candleData in stockData) {
      dataList.add(candleData);

      if (candleData.high! > maxPrice) {
        maxPrice = candleData.high!;
      }

      if (candleData.low! < minPrice) {
        minPrice = candleData.low!;
      }

      if (candleData.volume! > maxVolume) {
        maxVolume = candleData.volume!;
      }
    }
  }

  List<CandleDTO> get timeSeriesData => dataList; //Retorna la lista de velas

  int get dataLength => dataList.length; //Retorna el tamaño de la informacion

  num get maxDataVolume => maxVolume; //Retorna el volumen mas alto

  num get highestPrice => maxPrice; //Retorna el precio mas alto

  num get lowestPrice => minPrice; //Retorna el precio mas bajo
}

//Muestra las graficas en la interfaz de la aplicacion
class GraphStateRegion extends StatefulWidget {
  const GraphStateRegion(
    this.tradeDataManager, {
    super.key,
  });

  final TradeDataManager tradeDataManager;

  @override
  State<GraphStateRegion> createState() => _CandleGraphState();
}

class _CandleGraphState extends State<GraphStateRegion> {
  Offset? _position;
  String? candleInfo;
  double scrollOffsetX = 0.0;
  double scrollOffsetY = 0.0;
  double zoomX = 10.0;
  double horizontalOffset = 0.0;
  double zoomY = 0.0;
  num maxVisiblePrice = 0.0;
  num minVisiblePrice = 0.0;
  num maxVisibleVolume = 0.0;
  SystemMouseCursor cursor = SystemMouseCursors.basic;
  num visibleMinPrice = 0.0;
  num visibleMaxPrice = 0.0;
  bool isZoomedInY = false;
  bool isPriceLineCheck = false;
  List<double> priceLines = [];
  final financialDataBloc = FinancialDataBloc();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      updateVisiblePricesWhenScroll(candleCanvasSize(context));
      updateVisibleVolumeWhenScroll(candleCanvasSize(context));
    });
    visibleMinPrice = minVisiblePrice;
    visibleMaxPrice = maxVisiblePrice;
  }

  //Actualiza el valor maximo y minimo de los precios cada que se manda a llamar
  void updateVisiblePricesWhenScroll(Size size) {
    maxVisiblePrice = double.negativeInfinity;
    minVisiblePrice = double.infinity;

    for (int i = 0; i < widget.tradeDataManager.dataLength; i++) {
      CandleDTO window = widget.tradeDataManager.dataList[i];
      double pixelsPerTime =
          size.width / widget.tradeDataManager.dataLength + zoomX + 2;

      //double centerX = (size.width - size.width / 2) - (i + 1) * pixelsPerTime + scrollOffsetX - zoom;
      double centerX =
          (size.width) - (i - (scrollOffsetX / 10)) * pixelsPerTime;
      // double centerX = (size.width - size.width / 4) -
      //     (i + 1) * pixelsPerTime +
      //     scrollOffsetX -
      //     zoomX;

      if (centerX >= 0 && centerX <= size.width) {
        if (window.high! > maxVisiblePrice) {
          maxVisiblePrice = window.high!;
        }
        if (window.low! < minVisiblePrice) {
          minVisiblePrice = window.low!;
        }
      }
    }

    setState(() {});
  }

  updateVisiblePricesWhenZoom(double zoom) {
    double delta = zoom / maxVisiblePrice;
    double newMaxVisiblePrice = maxVisiblePrice + delta;
    double newMinVisiblePrice = minVisiblePrice - delta;
    double newPriceRange = newMaxVisiblePrice - newMinVisiblePrice;

    if (newPriceRange >= 0.1) {
      maxVisiblePrice = newMaxVisiblePrice;
      minVisiblePrice = newMinVisiblePrice;
    }
    setState(() {});
  }

  //Acctualiza el volumen maximo cada que se manda a llamar
  void updateVisibleVolumeWhenScroll(Size size) {
    maxVisibleVolume = 0;

    for (int i = 0; i < widget.tradeDataManager.dataLength; i++) {
      CandleDTO window = widget.tradeDataManager.dataList[i];
      double pixelsPerTime =
          size.width / widget.tradeDataManager.dataLength + zoomX + 2;

      //double centerX = (i + 1) * pixelsPerTime + scrollOffsetX;
      // double centerX = (size.width - size.width / 4) -
      //     (i + 1) * pixelsPerTime +
      //     scrollOffsetX -
      //     zoomX;
      double centerX =
          (size.width) - (i - (scrollOffsetX / 10)) * pixelsPerTime;

      if (centerX >= 0 && centerX <= size.width) {
        if (window.volume! > maxVisibleVolume) {
          maxVisibleVolume = window.volume!;
        }
      }
    }
    setState(() {});
  }

  //Tamaño que tomará el canvas
  Size candleCanvasSize(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Size(size.width / 1.2, 400);
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              height: 30,
              width: size.width / 1.2,
              child: const CandlesTopInfo(),
            ),
            IconButton(
                onPressed: () {
                  setState(() {
                    scrollOffsetX = 0.0;
                    scrollOffsetY = 0.0;
                    zoomX = 10.0;
                    isZoomedInY = false;
                    updateVisiblePricesWhenScroll(candleCanvasSize(context));
                    updateVisibleVolumeWhenScroll(candleCanvasSize(context));
                  });
                },
                icon: const Icon(
                  Icons.refresh,
                  color: Colors.white,
                )),
          ],
        ),
        Row(
          children: [
            Stack(
              children: [
                RepaintBoundary(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.precise,
                    onHover: (event) {
                      setState(() {
                        _position = event.localPosition;
                      });
                    },
                    child: Stack(
                      children: [
                        Positioned(
                            top: 60,
                            left: 40,
                            child: Image.asset(
                              'assets/images/primero_trader.png',
                              color: const Color.fromARGB(255, 134, 156, 170)
                                  .withOpacity(0.4),
                              scale: 2,
                            )),
                        Listener(
                          onPointerSignal: (PointerSignalEvent event) {
                            if (event is PointerScrollEvent) {
                              setState(() {
                                zoomX -= event.scrollDelta.dy / 100;
                                if (zoomX < 0.0) {
                                  zoomX = 0.0;
                                } else if (zoomX > 275.0) {
                                  zoomX = 275.0;
                                }
                                if (!isZoomedInY) {
                                  updateVisiblePricesWhenScroll(
                                      candleCanvasSize(context));
                                  updateVisibleVolumeWhenScroll(
                                      candleCanvasSize(context));
                                }
                              });
                            }
                          },
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                scrollOffsetX += details.delta.dx;
                                updateVisibleVolumeWhenScroll(
                                    candleCanvasSize(context));
                                if (!isZoomedInY) {
                                  updateVisiblePricesWhenScroll(
                                      candleCanvasSize(context));
                                } else {
                                  scrollOffsetY += details.delta.dy;
                                }
                                if (details.localPosition.dx >= 0 &&
                                    details.localPosition.dx <=
                                        candleCanvasSize(context).width &&
                                    details.localPosition.dy >= 0 &&
                                    details.localPosition.dy <=
                                        candleCanvasSize(context).height) {
                                  _position = details.localPosition;
                                }
                                cursor = SystemMouseCursors.grabbing;
                              });
                            },
                            onTapUp: (details) {
                              setState(() {
                                if (isPriceLineCheck) {
                                  priceLines.add(
                                      details.localPosition.dy - scrollOffsetY);
                                }
                              });
                            },
                            child: SizedBox(
                                height: candleCanvasSize(context).height,
                                width: candleCanvasSize(context).width,
                                child: CustomPaint(
                                    size: Size.infinite,
                                    painter: CandleStickPainter(
                                        widget.tradeDataManager,
                                        _position,
                                        scrollOffsetX,
                                        scrollOffsetY,
                                        zoomX,
                                        zoomY,
                                        maxVisiblePrice,
                                        minVisiblePrice,
                                        priceLines))),
                          ),
                        ),
                        const Positioned(
                          top: 20,
                          left: 10,
                          child: VolumeTooltip(),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                    bottom: 20,
                    right: 40,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            scrollOffsetX += 10;
                            updateVisiblePricesWhenScroll(
                                candleCanvasSize(context));
                            updateVisibleVolumeWhenScroll(
                                candleCanvasSize(context));
                          });
                        },
                        child: Container(
                          height: 20,
                          width: 20,
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2)),
                          child: const Center(
                              child: Icon(
                            Icons.arrow_back_ios,
                            size: 10,
                          )),
                        ),
                      ),
                    )),
                Positioned(
                    bottom: 20,
                    right: 20,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            if (scrollOffsetX > 0) {
                              scrollOffsetX -= 10;
                              updateVisiblePricesWhenScroll(
                                  candleCanvasSize(context));
                              updateVisibleVolumeWhenScroll(
                                  candleCanvasSize(context));
                            }
                          });
                        },
                        child: Container(
                          height: 20,
                          width: 20,
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2)),
                          child: const Center(
                              child: Icon(
                            Icons.arrow_forward_ios,
                            size: 10,
                          )),
                        ),
                      ),
                    )),
                Positioned(
                    bottom: 20,
                    right: 80,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            zoomX += zoomX / 4;
                            updateVisiblePricesWhenScroll(
                                candleCanvasSize(context));
                            updateVisibleVolumeWhenScroll(
                                candleCanvasSize(context));
                          });
                        },
                        child: Container(
                          height: 20,
                          width: 20,
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2)),
                          child: const Center(
                              child: Icon(
                            Icons.add,
                            size: 10,
                          )),
                        ),
                      ),
                    )),
                Positioned(
                    bottom: 20,
                    right: 100,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            zoomX -= zoomX / 5;
                            updateVisiblePricesWhenScroll(
                                candleCanvasSize(context));
                            updateVisibleVolumeWhenScroll(
                                candleCanvasSize(context));
                          });
                        },
                        child: Container(
                          height: 20,
                          width: 20,
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2)),
                          child: const Center(
                              child: Icon(
                            Icons.remove,
                            size: 10,
                          )),
                        ),
                      ),
                    )),
              ],
            ),
            MouseRegion(
              cursor: SystemMouseCursors.resizeUpDown,
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  setState(() {
                    isZoomedInY = true;
                    updateVisiblePricesWhenZoom(details.primaryDelta!);
                    zoomY += details.primaryDelta ?? 0.0;
                  });
                },
                child: SizedBox(
                  height: 400,
                  width: 50,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: PriceRangePainter(
                        maxY: maxVisiblePrice,
                        minY: minVisiblePrice,
                        zoomY: zoomY,
                        scrollOffsetY: scrollOffsetY),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Checkbox(
                  value: isPriceLineCheck,
                  onChanged: (newValue) {
                    setState(() {
                      isPriceLineCheck = newValue!;
                    });
                  },
                ),
                const Text('Linea de precio')
              ],
            ),
          ],
        ),
        SizedBox(
          height: 30,
          width: size.width / 1.2,
          child: const CandlesBottomInfo(),
        ),
        Row(
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.precise,
              onHover: (details) {
                setState(() {
                  if (details.localPosition.dx >= 0 &&
                      details.localPosition.dx <=
                          candleCanvasSize(context).width &&
                      details.localPosition.dy >= 0 &&
                      details.localPosition.dy <=
                          candleCanvasSize(context).height) {
                    _position =
                        Offset(details.localPosition.dx, _position?.dy ?? 0.0);
                  }
                });
              },
              child: SizedBox(
                height: 100,
                width: size.width / 1.2,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: VolumePainter(widget.tradeDataManager, _position,
                      scrollOffsetX, zoomX, maxVisibleVolume),
                ),
              ),
            ),
            SizedBox(
              height: 100,
              width: 60,
              child: CustomPaint(
                size: Size.infinite,
                painter: VolumeRangePainter(
                  maxVolume: maxVisibleVolume,
                ),
              ),
            ),
          ],
        ),
        MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                zoomX -= details.primaryDelta! / 20;
                if (zoomX < 0.0) {
                  zoomX = 0.0;
                } else if (zoomX > 275.0) {
                  zoomX = 275.0;
                }
                if (!isZoomedInY) {
                  updateVisiblePricesWhenScroll(candleCanvasSize(context));
                  updateVisibleVolumeWhenScroll(candleCanvasSize(context));
                }
              });
            },
            child: StreamBuilder<CandleDTO>(
                stream: financialDataBloc.financialDataStream,
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  return SizedBox(
                    height: 25,
                    width: size.width / 1.2,
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: TimeFramePainter(widget.tradeDataManager,
                          position: _position,
                          scrollOffset: scrollOffsetX,
                          zoom: zoomX,
                          date: data?.date ?? ''),
                    ),
                  );
                }),
          ),
        ),
      ],
    );
  }
}

class VolumeTooltip extends StatefulWidget {
  const VolumeTooltip({
    super.key,
  });

  @override
  State<VolumeTooltip> createState() => _VolumeTooltipState();
}

class _VolumeTooltipState extends State<VolumeTooltip> {
  final financialDataBloc = FinancialDataBloc();
  @override
  Widget build(BuildContext context) {
    return Container(
        height: 30,
        width: 140,
        decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(8)),
        child: Center(
          child: StreamBuilder<CandleDTO>(
              stream: financialDataBloc.financialDataStream,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final data = snapshot.data;
                  return RichText(
                      text: TextSpan(
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                          children: [
                        const TextSpan(text: 'Volume SMA 9  '),
                        TextSpan(
                            text:
                                '${NumberFormat("###,###", "en_US").format(data!.volume).split(',')[0]} mil',
                            style: const TextStyle(
                                color: Colors.red, fontSize: 12))
                      ]));
                }
                return RichText(
                    text: const TextSpan(
                        style: TextStyle(color: Colors.white, fontSize: 12),
                        children: [
                      TextSpan(text: 'Volume SMA 9  '),
                      TextSpan(
                          text: '0 mil',
                          style: TextStyle(color: Colors.red, fontSize: 12))
                    ]));
              }),
        ));
  }
}

class CandlesTopInfo extends StatefulWidget {
  const CandlesTopInfo({
    super.key,
  });

  @override
  State<CandlesTopInfo> createState() => _CandlesTopInfoState();
}

class _CandlesTopInfoState extends State<CandlesTopInfo> {
  final financialDataBloc = FinancialDataBloc();
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CandleDTO>(
        stream: financialDataBloc.financialDataStream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final data = snapshot.data;
            return ListView(
              scrollDirection: Axis.horizontal,
              children: [
                const CandleInfoBox(info: 'INFO'),
                CandleInfoBox(
                    info:
                        'D: ${DateFormat('EEEE d MMMM y HH:mm a').format(DateTime.parse(data!.date!))}'),
                CandleInfoBox(
                    info:
                        'O: \$${NumberFormat("#,##0.00", "en_US").format(data.open)}'),
                CandleInfoBox(
                    info:
                        'H: \$${NumberFormat("#,##0.00", "en_US").format(data.high)}'),
                CandleInfoBox(
                    info:
                        'L: \$${NumberFormat("#,##0.00", "en_US").format(data.low)}'),
                CandleInfoBox(
                    info:
                        'C: \$${NumberFormat("#,##0.00", "en_US").format(data.close)}'),
                const CandleInfoBox(info: 'R: 0.00'),
              ],
            );
          } else {
            return ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                CandleInfoBox(info: 'INFO'),
                CandleInfoBox(info: 'D: 17/10/2023 08:00 a.m.'),
                CandleInfoBox(info: 'O: \$0.00'),
                CandleInfoBox(info: 'H: \$0.00'),
                CandleInfoBox(info: 'L: \$0.00'),
                CandleInfoBox(info: 'C: \$0.00'),
                CandleInfoBox(info: 'R: 0.00'),
              ],
            );
          }
        });
  }
}

class CandlesBottomInfo extends StatefulWidget {
  const CandlesBottomInfo({
    super.key,
  });

  @override
  State<CandlesBottomInfo> createState() => _CandlesInfoState();
}

class _CandlesInfoState extends State<CandlesBottomInfo> {
  final financialDataBloc = FinancialDataBloc();
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CandleDTO>(
        stream: financialDataBloc.financialDataStream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final data = snapshot.data;
            return ListView(
              scrollDirection: Axis.horizontal,
              children: [
                CandleInfoBox(
                    info:
                        'Volume: ${NumberFormat("#,###", "en_US").format(data!.volume).replaceAll(",", ".")}'),
                const CandleInfoBox(
                    info: 'RSI (14, 70, 30, CLOSE, WILDERS, no)'),
                const CandleInfoBox(info: '62.1525'),
                const CandleInfoBox(info: '30'),
                const CandleInfoBox(info: '70'),
                DateTimeText(
                  dateTime: DateTime.parse(data.date!),
                  timeZone: DateTime.parse(data.date!).timeZoneName,
                ),
              ],
            );
          } else {
            return ListView(
              scrollDirection: Axis.horizontal,
              children: [
                const CandleInfoBox(info: 'Volume: 0.00'),
                const CandleInfoBox(
                    info: 'RSI (14, 70, 30, CLOSE, WILDERS, no)'),
                const CandleInfoBox(info: '62.1525'),
                const CandleInfoBox(info: '30'),
                const CandleInfoBox(info: '70'),
                DateTimeText(
                  dateTime: DateTime.now(),
                  timeZone: DateTime.now().timeZoneName,
                ),
              ],
            );
          }
        });
  }
}

class CandleInfoBox extends StatelessWidget {
  const CandleInfoBox({
    super.key,
    required this.info,
  });

  final String info;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(width: 1, color: Color(0xff18374A)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        info,
        style: const TextStyle(fontSize: 12, color: Colors.white),
      ),
    );
  }
}

class DateTimeText extends StatelessWidget {
  final DateTime dateTime;
  final String timeZone;

  const DateTimeText(
      {super.key, required this.dateTime, required this.timeZone});

  static String formatVolumeBarDate(DateTime dateTime) {
    final formatter = DateFormat("EEEE d MMMM y");
    return formatter.format(dateTime);
  }

  static String formatVolumeBarHour(DateTime dateTime) {
    final formatter = DateFormat("HH:mm a");
    return formatter.format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    const baseTextStyle = TextStyle(
      color: Color(0xff869caa),
      fontWeight: FontWeight.w400,
      fontSize: 12.0,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                style: baseTextStyle,
                text: " ${formatVolumeBarDate(dateTime)} - (GMT$timeZone) - ",
              ),
              TextSpan(
                style: baseTextStyle.copyWith(
                  color: const Color(0xffeeb32b),
                  fontWeight: FontWeight.w600,
                ),
                text: formatVolumeBarHour(dateTime),
              ),
            ],
          ),
        )
      ],
    );
  }
}

class FinancialDataBloc {
  static final FinancialDataBloc _singleton = FinancialDataBloc._internal();

  factory FinancialDataBloc() {
    return _singleton;
  }

  FinancialDataBloc._internal();

  final StreamController<CandleDTO> _financialDataController =
      StreamController<CandleDTO>.broadcast();

  Stream<CandleDTO> get financialDataStream => _financialDataController.stream;

  void updateFinancialData(CandleDTO data) {
    _financialDataController.add(data);
  }

  void dispose() {
    _financialDataController.close();
  }
}
