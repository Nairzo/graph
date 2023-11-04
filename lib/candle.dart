import 'dart:convert';

List<CandleDTO> tradeDataFromJson(String str) =>
    List<CandleDTO>.from(json.decode(str).map((x) => CandleDTO.fromJson(x)));

String tradeDataToJson(List<CandleDTO> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

class CandleDTO {
  String? date;
  num? open;
  num? low;
  num? high;
  num? close;
  num? volume;

  CandleDTO({
    this.date,
    this.open,
    this.low,
    this.high,
    this.close,
    this.volume,
  });

  CandleDTO.fromJson(Map<String, dynamic> json) {
    date = json['date'];
    open = json['open'];
    low = json['low'];
    high = json['high'];
    close = json['close'];
    volume = json['volume'];
  }

  Map<String, dynamic> toJson() => {
        "date": date,
        "open": open,
        "low": low,
        "high": high,
        "close": close,
        "volume": volume,
      };

  bool isGain() {
    num openPrice = open!;
    num closePrice = close!;
    num profitOrLoss = closePrice - openPrice;

    if (profitOrLoss > 0) {
      return true;
    }

    return false;
  }
}
