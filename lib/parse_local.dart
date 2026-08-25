import 'package:horceracing_ticket_qr_reader/string_iterator.dart';

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
  "249": "釧路場外発売所",
  "260": "帯広競馬場",
  "261": "旭川場外発売所",
  "262": "北見場外発売所",
  "263": "釧路場外発売所",
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
  "280": "テレトラック山本",
  "283": "東京競馬場",
  "286": "秋田場外発売所",
  "287": "テレトラック石鳥谷",
  "300": "東京・大井競馬場",
  "301": "offtひたちなか",
  "302": "offt後楽園",
  "303": "offt汐留",
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
  "327": "オフト京王閣",
  "400": "名古屋場内発売所",
  "403": "弥富場外発売所",
  "404": "磯部場外発売所",
  "406": "大須場外発売所",
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
  "3": "枠番連複",
  "4": "枠番連単",
  "5": "普通馬複",
  "6": "馬番連単",
  "7": "ワイド",
  "8": "馬3連複",
  "9": "馬3連単",
};

const Map<String, String> wheelExactaDict = {"1": "1着ながし", "2": "2着ながし"};

const Map<String, String> wheelTrioDict = {"3": "軸2頭ながし", "7": "軸1頭ながし"};

/// 地方競馬の3連単ながしコード（フォーマット1〜3）
/// JRA および地方フォーマット4以降とは異なる
const Map<String, String> wheelTrifectaDict = {
  "1": "1着ながし",
  "2": "2着ながし",
  "3": "1・2着ながし",
  "4": "2・3着ながし",
  "5": "1・3着ながし",
  "6": "3着ながし",
};

/// 地方フォーマット4以降の3連単ながしコード（JRAと同じ並び）
const Map<String, String> wheelTrifectaDictFmt4 = {
  "1": "1・2着ながし",
  "2": "1・3着ながし",
  "3": "2・3着ながし",
  "4": "1着ながし",
  "5": "2着ながし",
  "6": "3着ながし",
};

Map<String, String> _trifectaWheelDict(String ticketFormat) {
  final formatNo = int.tryParse(ticketFormat) ?? 1;
  return formatNo >= 4 ? wheelTrifectaDictFmt4 : wheelTrifectaDict;
}

Map<String, dynamic> parseHorseracingTicketQrLocal(String s) {
  List<String> underDigits = List.filled(42, "X");

  Map<String, dynamic> d = {};
  d["QR"] = s;
  StringIterator itr = StringIterator(s);

  String ticketFormat = itr.next();

  String racecourseCode = itr.next() + itr.next();
  d["開催場"] = racecourseDict[racecourseCode];
  d["場コード"] = racecourseCode;
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
      d["開催種別"] = "不明($alternativeCode)";
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

  // 地方発売のJRA馬券は netkeiba 中央URLを直接組み立てる
  if (_isJraRacecourse(racecourseCode)) {
    final ticketYear = d["年"] as int;
    final yyyy = ticketYear <= 18
        ? ticketYear + 2018
        : (ticketYear <= 31 ? ticketYear + 1988 : 2000 + ticketYear);
    final id =
        '$yyyy'
        '${racecourseCode.padLeft(2, '0')}'
        '${(d["回"] as int).toString().padLeft(2, '0')}'
        '${(d["日"] as int).toString().padLeft(2, '0')}'
        '${(d["レース"] as int).toString().padLeft(2, '0')}';
    d["URL"] = "https://db.netkeiba.com/race/$id";
  }

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
  d["発売所"] = ticketofficeDict[ticketofficeCode] ?? "不明($ticketofficeCode)";

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
          case "4":
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
        // フォーマット3は単勝・複勝・枠連・馬連の馬番欄が広い
        if (ticketFormat == "3" &&
            (bettingCode == "1" ||
                bettingCode == "2" ||
                bettingCode == "3" ||
                bettingCode == "5")) {
          c += 1;
        }
        // 馬番欄はフォーマット幅 c スロット（余りは00）。
        // 馬番連単(6)と必要頭数が c を超える式別は実頭数ぶんだけ読む。
        final slotCount = (bettingCode == "6" || count > c || typeCode == "5")
            ? count
            : c;
        final slotNumbers = [
          for (int i = 0; i < slotCount; i++)
            int.parse(itr.next() + itr.next()),
        ];
        di["馬番"] = slotNumbers.take(count).toList();

        // ウラ/予備2桁:
        // - 応援馬券の単勝・複勝: 常に2桁（金額の直前）
        // - フォーマット1の単勝・複勝: 2桁
        // - 馬番連単: フォーマット2以降はウラ欄（01=あり）
        if ((bettingCode == "1" || bettingCode == "2") &&
            (ticketFormat == "1" || typeCode == "5")) {
          itr.move(2);
        } else if (bettingCode == "6" && ticketFormat != "1") {
          final ura = itr.next() + itr.next();
          di["ウラ"] = ura == "01" ? "あり" : "なし";
        }

        String purchaseAmountStr = "";
        for (int i = 0; i < 5; i++) {
          purchaseAmountStr += itr.next();
        }
        di["購入金額"] = int.parse("${purchaseAmountStr}00");

        if (bettingCode == "6" && ticketFormat == "1") {
          di["ウラ"] = underDigits[9] == "2" ? "あり" : "なし";
        }

        if (underDigits[5] == "0") {
          underDigits[5] = bettingCode;
        } else {
          underDigits[6] = bettingCode;
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
          di["ながし"] = _trifectaWheelDict(ticketFormat)[wheelCode];
          break;
        default:
          di["ながし"] = "ながし";
      }
      int count = 0;
      if (bettingCode == "6") {
        // 地方の馬番連単ながし: 軸(2桁) + 金額(5) + 相手ビットマップ(18)
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
      } else if (bettingCode == "3" ||
          bettingCode == "5" ||
          bettingCode == "7" ||
          bettingCode == "8") {
        // 枠番連複・普通馬複・ワイド・馬3連複ながし:
        // 軸ビットマップ2面 + 相手ビットマップ1面 + 金額
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
        for (var list in horseNumbers) {
          if (list.length > count) {
            count = list.length;
          }
        }
      } else {
        throw ArgumentError("Unexpected nagashi betting_code: $bettingCode");
      }
      if (bettingCode == "3" ||
          bettingCode == "5" ||
          bettingCode == "7" ||
          bettingCode == "8" ||
          bettingCode == "9") {
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

      underDigits[5] = bettingCode;
      (d["購入内容"] as List).add(di);
      break;

    default:
      throw ArgumentError("Unknown type code: $typeCode");
  }

  d["下端番号"] = joinWithSpaces(underDigits);
  return d;
}

bool _isJraRacecourse(String code) {
  final n = int.tryParse(code);
  return n != null && n >= 1 && n <= 10;
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
