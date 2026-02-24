const Map<String, String> racecourseDict = {
  "01": "JRA札幌",
  "02": "JRA函館",
  "03": "JRA福島",
  "04": "JRA新潟",
  "05": "JRA東京",
  "06": "JRA中山",
  "07": "JRA中京",
  "08": "JRA京都",
  "09": "JRA阪神",
  "10": "JRA小倉",
  "13": "園田",
  "14": "姫路",
  "26": "名古屋",
  "36": "帯広",
  "38": "門別",
  "49": "盛岡",
  "50": "水沢",
  "56": "浦和",
  "57": "船橋",
  "61": "大井",
  "62": "川崎",
  "66": "笠松",
  "68": "金沢",
  "75": "福山",
  "78": "高知",
  "80": "佐賀",
};

const Map<String, String> jyoCdDict = {
  "36": "65", // 帯広
  "38": "30", // 門別
  "49": "35", // 盛岡
  "50": "36", // 水沢
  "56": "42", // 浦和
  "57": "43", // 船橋
  "61": "44", // 大井
  "62": "45", // 川崎
  "68": "46", // 金沢
  "66": "47", // 笠松
  "26": "48", // 名古屋
  "13": "50", // 園田
  "14": "51", // 姫路
  "75": "53", // 福山
  "78": "54", // 高知
  "80": "55", // 佐賀
};

const Map<String, String> typeDict = {
  "0": "通常",
  "1": "ボックス",
  "2": "ながし",
  "3": "フォーメーション",
  "4": "クイックピック",
  "5": "応援馬券",
};

const Map<String, String> ticketofficeDict = {
  "230": "門別競馬場",
  "232": "旭川場外発売所",
  "233": "ハロンズ岩見沢",
  "235": "静内場外発売所",
  "236": "苫小牧場外発売所",
  "237": "滝川場外発売所",
  "238": "小樽場外発売所",
  "239": "中標津場外発売所",
  "240": "札幌駅前場外馬券場",
  "241": "浦河場外発売所",
  "242": "千歳場外発売所",
  "243": "函館港場外発売所",
  "244": "江別場外発売所",
  "245": "石狩場外発売所",
  "246": "登別室蘭場外発売所",
  "247": "札幌中央場外発売所",
  "249": "くしろ場外発売所",
  "260": "帯広競馬場",
  "261": "旭川場外発売所",
  "262": "北見場外発売所",
  "264": "名寄場外発売所",
  "266": "岩見沢場外発売所",
  "267": "網走場外発売所",
  "268": "琴似場外発売所",
  "269": "深川場外発売所",
  "270": "盛岡競馬場",
  "271": "水沢競馬場",
  "272": "テレトラックつがる",
  "273": "テレトラック十和田",
  "276": "テレトラック種市",
  "278": "テレトラック三本木",
  "279": "テレトラック横手",
  "283": "東京競馬場",
  "286": "秋田場外発売所",
  "300": "東京・大井競馬場",
  "301": "offtひたちなか",
  "306": "オープス中郷",
  "307": "オープス磐梯",
  "308": "益田場外発売所",
  "309": "offt大郷",
  "311": "浦和競馬場",
  "312": "川崎競馬場",
  "313": "船橋競馬場",
  "315": "ジョイホース横浜",
  "318": "f-keiba成田",
  "319": "f-keiba木更津",
  "322": "ジョイホース浜松",
  "323": "offt伊勢崎",
  "324": "ジョイホース双葉",
  "400": "名古屋場内発売所",
  "403": "弥富場外発売所",
  "404": "磯部場外発売所",
  "407": "一宮場外発売所",
  "408": "名古屋場外発売所",
  "480": "園田競馬場",
  "481": "姫路競馬場",
  "482": "WINS神戸",
  "484": "吉川場外発売所",
  "495": "DASH和歌山",
  "497": "DASH心斎橋",
  "498": "DASH呉",
  "499": "DASH岸和田",
  "500": "佐賀競馬場",
  "501": "鳥栖ミニ場外発売所",
  "503": "中津場外発売所",
  "512": "BAOO荒尾",
  "513": "BAOO博多",
  "520": "BAOO三刀屋",
  "521": "BAOO宇部",
  "522": "BAOO東広島",
  "523": "BAOO天文館",
  "524": "BAOO鳥取岩美",
  "530": "BAOO高崎",
  "531": "ニュートラック上山",
  "532": "ニュートラック松山",
  "535": "ニュートラック福島",
  "536": "J-PLACE荒尾",
};

const Map<String, String> bettingDict = {
  "1": "単勝",
  "2": "複勝",
  "3": "枠連複",
  "4": "枠連単",
  "5": "普通馬複",
  "6": "馬番連単",
  "7": "ワイド",
  "8": "馬3連複",
  "9": "馬3連単",
};

const Map<String, String> wheelExactaDict = {"1": "1着ながし", "2": "2着ながし"};

const Map<String, String> wheelTrioDict = {"3": "軸2頭ながし", "7": "軸1頭ながし"};

const Map<String, String> wheelTrifectaDict = {
  "1": "1・2着ながし",
  "2": "1・3着ながし",
  "3": "2・3着ながし",
  "4": "1着ながし",
  "5": "2着ながし",
  "6": "3着ながし",
};

Map<String, dynamic> parseHorseracingTicketQrLocal(String s) {
  List<String> underDigits = List.filled(42, "X");

  Map<String, dynamic> d = {};
  d["QR"] = s;
  _StringIterator itr = _StringIterator(s);

  String ticketFormat = itr.next();

  String racecourseCode = itr.next() + itr.next();
  d["開催場"] = racecourseDict[racecourseCode];
  underDigits[0] = racecourseCode.substring(0, 1);
  underDigits[1] = racecourseCode.substring(1, 2);

  itr.move(2);
  underDigits[2] = "1";
  underDigits[3] = "0";

  String alternativeCode = itr.next();
  if (alternativeCode != "0") {
    if (alternativeCode == "2") {
      d["開催種別"] = "代替";
    } else if (alternativeCode == "7") {
      d["開催種別"] = "継続";
    } else if (alternativeCode == "4") {
      d["開催種別"] = "代2";
    } else {
      d["開催種別"] = "不明";
    }
  }
  underDigits[4] = "0";

  String year = itr.next() + itr.next();
  String time = itr.next() + itr.next();
  String day = itr.next() + itr.next() + itr.next() + itr.next();
  d["年"] = int.parse(year);
  d["回"] = int.parse(time);
  d["日"] = int.parse(day);
  d["レース"] = int.parse(itr.next() + itr.next());
  // String suffix = [
  //   d["年"],
  //   jyoCdDict[racecourseCode],
  //   d["回"],  // レースの開催月2桁にする必要がある
  //   d["日"],  // レースの開催日2桁にする必要がある
  //   d["レース"],
  // ].map((n) => n.toString().padLeft(2, '0')).join();
  // d["URL"] = "https://db.netkeiba.com/race/20$suffix";
  String typeCode = itr.next();
  d["券種"] = typeDict[typeCode];
  underDigits[4] = typeCode;

  itr.move(2);

  for (int i = 24; i < 29; i++) {
    underDigits[i] = itr.next();
  }
  itr.move(2);
  for (int i = 20; i < 24; i++) {
    underDigits[i] = itr.next();
  }
  for (int i = 14; i < 20; i++) {
    underDigits[i] = itr.next();
  }
  for (int i = 29; i < 42; i++) {
    underDigits[i] = itr.next();
  }
  underDigits[9] = itr.next();

  String ticketofficeCode = underDigits.sublist(29, 32).join();
  d["発売所"] = ticketofficeDict[ticketofficeCode] ?? "不明";

  underDigits[4] = typeCode;
  d["購入内容"] = [];

  underDigits[5] = "0";
  underDigits[6] = "0";

  switch (typeCode) {
    case "0": // 通常
    case "5": // 応援馬券
      while (true) {
        String bettingCode = itr.next();
        if (bettingCode == "0") break;

        Map<String, dynamic> di = {};
        di["式別"] = bettingDict[bettingCode];

        int count;
        switch (bettingCode) {
          case "1":
          case "2":
            count = 1;
            break;
          case "3":
          case "5":
          case "6":
          case "7":
            count = 2;
            break;
          case "8":
          case "9":
            count = 3;
            break;
          default:
            throw ArgumentError("Unexpected betting_code: $bettingCode");
        }
        int c = (int.parse(ticketFormat) + 1) ~/ 2;
        if ((bettingCode == "3" || bettingCode == "5") && ticketFormat == "3") {
          c += 1;
        }
        di["馬番"] = [
          for (int i = 0; i < count; i++) int.parse(itr.next() + itr.next()),
        ];
        if (c > count && typeCode != "5" && bettingCode != "6") {
          itr.move((c - count) * 2);
        }

        if (bettingCode == "1" || bettingCode == "2" || bettingCode == "6") {
          String ura = itr.next() + itr.next();
          if (bettingCode == "6") {
            di["ウラ"] = ura == "01" ? "あり" : "なし";
          }
        }
        String purchaseAmountStr = "";
        for (int i = 0; i < 5; i++) {
          purchaseAmountStr += itr.next();
        }
        di["購入金額"] = int.parse("${purchaseAmountStr}00");

        if (underDigits[5] == "0") {
          underDigits[5] = bettingCode;
          //   underDigits[18] = (int.parse(underDigits[18]) + 1).toString();
        } else {
          // if (underDigits[6] == "0") {
          //     underDigits[17] = underDigits[18];
          //     underDigits[18] = "0";
          // }
          underDigits[6] = bettingCode;
          //   underDigits[18] = (int.parse(underDigits[18]) + 1).toString();
        }
        (d["購入内容"] as List).add(di);
      }
      break;

    case "1": // ボックス
      Map<String, dynamic> di = {};
      String bettingCode = itr.next();
      di["式別"] = bettingDict[bettingCode];

      List<int> nos = [];
      String purchaseAmountStr = "";
      int count;
      switch (ticketFormat) {
        case "1":
          count = 5;
          break;
        case "3":
          count = 10;
          break;
        default:
          count = 18;
      }
      for (int i = 0; i < count; i++) {
        final no = itr.next() + itr.next();
        if (no != "00") {
          nos.add(int.parse(no));
        }
      }
      di["馬番"] = nos;
      for (int i = 0; i < 5; i++) {
        purchaseAmountStr += itr.next();
      }
      di["購入金額"] = int.parse("${purchaseAmountStr}00");

      underDigits[5] = bettingCode;
      // if ((di["馬番"] as List).length < 10) {
      //   underDigits[17] = (di["馬番"] as List).length.toString();
      // } else {
      //   underDigits[17] = "1";
      //   underDigits[18] = ((di["馬番"] as List).length % 10).toString();
      // }
      (d["購入内容"] as List).add(di);
      break;

    case "2": // ながし
      Map<String, dynamic> di = {};
      String bettingCode = itr.next();
      di["式別"] = bettingDict[bettingCode];

      String wheelCode = itr.next();
      switch (bettingCode) {
        case "6":
          di["ながし"] = wheelExactaDict[wheelCode];
          break;
        case "8":
          di["ながし"] = wheelTrioDict[wheelCode];
          break;
        case "9":
          di["ながし"] = wheelTrifectaDict[wheelCode];
          break;
        default:
          di["ながし"] = "ながし";
      }
      int count = 0;
      if (bettingCode == "6" || bettingCode == "8") {
        List<int> horseNumbers = [];
        for (int j = 0; j < 2; j++) {
          for (int i = 1; i <= 18; i++) {
            if (itr.next() == "1") {
              horseNumbers.add(i);
            }
          }
        }
        di["軸"] = horseNumbers;
        List<int> innerList = [];
        for (int i = 1; i <= 18; i++) {
          if (itr.next() == "1") {
            innerList.add(i);
          }
        }
        di["相手"] = innerList;
        count = innerList.length;
      } else if (bettingCode == "9") {
        List<List<int>> horseNumbers = [];
        for (int j = 0; j < 3; j++) {
          List<int> innerList = [];
          for (int i = 1; i <= 18; i++) {
            if (itr.next() == "1") {
              innerList.add(i);
            }
          }
          horseNumbers.add(innerList);
        }
        di["馬番"] = horseNumbers;
        for (var list in (horseNumbers)) {
          if (list.length > count) {
            count = list.length;
          }
        }
      } else {
        di["軸"] = int.parse(itr.next() + itr.next());
        String purchaseAmountStr = "";
        for (int i = 0; i < 5; i++) {
          purchaseAmountStr += itr.next();
        }
        di["購入金額"] = int.parse("${purchaseAmountStr}00");
        List<int> innerList = [];
        for (int i = 1; i <= 18; i++) {
          if (itr.next() == "1") {
            innerList.add(i);
          }
        }
        di["相手"] = innerList;
        count = innerList.length;
      }
      if (bettingCode == "8" || bettingCode == "9") {
        String purchaseAmountStr = "";
        for (int i = 0; i < 5; i++) {
          purchaseAmountStr += itr.next();
        }
        di["購入金額"] = int.parse("${purchaseAmountStr}00");
      }
      if (bettingCode == "9") {
        String multiCode = itr.next();
        d["マルチ"] = multiCode == "1" ? "あり" : "なし";
        if (multiCode == "1") {
          count += 20;
        }
      }
      underDigits[5] = bettingCode;
      if (bettingCode == "6" || bettingCode == "8" || bettingCode == "9") {
        underDigits[7] = wheelCode;
      }

      // underDigits[17] = (count ~/ 10).toString();
      // underDigits[18] = (count % 10).toString();
      (d["購入内容"] as List).add(di);
      break;

    case "3": // フォーメーション
      Map<String, dynamic> di = {};
      String bettingCode = itr.next();
      di["式別"] = bettingDict[bettingCode];

      itr.next();

      List<List<int>> horseNumbers = [];
      for (int j = 0; j < 3; j++) {
        List<int> innerList = [];
        for (int i = 1; i <= 18; i++) {
          if (itr.next() == "1") {
            innerList.add(i);
          }
        }
        if (innerList.isNotEmpty) {
          horseNumbers.add(innerList);
        }
      }
      di["馬番"] = horseNumbers;

      String purchaseAmountStr = "";
      for (int i = 0; i < 5; i++) {
        purchaseAmountStr += itr.next();
      }
      di["購入金額"] = int.parse("${purchaseAmountStr}00");

      itr.next();

      // underDigits[13] = "2";
      underDigits[5] = bettingCode;
      // for (int i = 0; i < di["馬番"].length; i++) {
      //   String st = (di["馬番"][i] as List).length.toString();
      //   underDigits[16 + i] = st[st.length - 1];
      //   if (st.length == 2) {
      //     underDigits[15] = (int.parse(underDigits[15]) + (1 << i)).toString();
      //   }
      // }
      (d["購入内容"] as List).add(di);
      break;

    case "4": // クイックピック
      Map<String, dynamic> di = {};
      String bettingCode = itr.next();
      di["式別"] = bettingDict[bettingCode];

      int no = int.parse(itr.next() + itr.next());
      if (no != 0) {
        d["軸"] = no;
      }

      int positionSpecify = int.parse(itr.next());
      if (bettingCode == "6" || bettingCode == "9") {
        d["着順指定"] = positionSpecify != 0 ? "$positionSpecify着指定" : "なし";
      }

      d["組合せ数"] = int.parse(itr.next() + itr.next());

      String purchaseAmountStr = "";
      for (int i = 0; i < 5; i++) {
        purchaseAmountStr += itr.next();
      }
      di["購入金額"] = int.parse("${purchaseAmountStr}00");

      itr.move(2);

      List<List<int>> horseNumbersList = [];
      for (int i = 0; i < d["組合せ数"]; i++) {
        List<int> innerList = [];
        for (int j = 0; j < 3; j++) {
          int horseNum = int.parse(itr.next() + itr.next());
          if (horseNum != 0) {
            innerList.add(horseNum);
          }
        }
        horseNumbersList.add(innerList);
      }
      di["馬番"] = horseNumbersList;

      underDigits[5] = bettingCode;
      // underDigits[17] = (d["組合せ数"] ~/ 10).toString();
      // underDigits[18] = (d["組合せ数"] % 10).toString();
      (d["購入内容"] as List).add(di);
      break;

    default:
      throw ArgumentError("Unknown type code: $typeCode");
  }

  d["下端番号"] = joinWithSpaces(underDigits);
  return d;
}

String joinWithSpaces(List<String> underDigits) {
  final buffer = StringBuffer();

  for (int i = 0; i < underDigits.length; i++) {
    buffer.write(underDigits[i]);
    if (i == 9 ||
        i == 13 ||
        i == 23 ||
        i == 28 ||
        i == 32 ||
        i == 36 ||
        i == 40) {
      buffer.write(" ");
    }
  }

  return buffer.toString();
}

class _StringIterator {
  final String _s;
  int _currentPosition = 0;

  _StringIterator(this._s);

  String next() {
    if (_currentPosition >= _s.length) {
      throw StateError("No more elements in the string.");
    }
    return _s[_currentPosition++];
  }

  void move(int offset) {
    _currentPosition += offset;
    if (_currentPosition < 0 || _currentPosition > _s.length) {
      throw RangeError("Invalid position after move.");
    }
  }

  int get position => _currentPosition;

  set currentPosition(int pos) {
    _currentPosition = pos;
  }

  /// Peek ahead without advancing the iterator.
  String peek(int offset) {
    int pos = _currentPosition + offset;
    if (pos >= _s.length || pos < 0) {
      throw RangeError("Peek out of range");
    }
    return _s[pos];
  }
}
