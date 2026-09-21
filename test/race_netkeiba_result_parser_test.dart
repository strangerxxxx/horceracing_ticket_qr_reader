import 'package:flutter_test/flutter_test.dart';
import 'package:horceracing_ticket_qr_reader/race_netkeiba_result_parser.dart';

void main() {
  test('parses NAR Torikeshi row with Num Waku horse number', () {
    const html = '''
<table>
<tr class="HorseList">
<td class="Result_Num"><div class="Rank">1</div></td>
<td class="Num Waku1"><div>1</div></td>
<td class="Num Waku"><div>1</div></td>
<td class="Horse_Info"><span class="Horse_Name"><a title="勝ち馬">勝ち馬</a></span></td>
</tr>
<tr class="HorseList Torikeshi">
<td class="Result_Num"><div class="Rank">除外</div></td>
<td class="Num Waku3"><div>3</div></td>
<td class="Num Waku"><div>3</div></td>
<td class="Horse_Info"><span class="Horse_Name">
<a href="https://db.netkeiba.com/horse/2020105055/" title="ドナルビー">ドナルビー</a>
</span></td>
</tr>
</table>
''';

    final parsed = RaceNetkeibaResultParser.parseRefundedHorses(html);
    expect(parsed.horses, {3});
    expect(parsed.frames[3], 3);
    expect(parsed.names[3], 'ドナルビー');
  });

  test('parses JRA Num Txt_C horse number with 取消', () {
    const html = '''
<table>
<tr>
<td>取消</td>
<td class="Num Waku2"><div>2</div></td>
<td class="Num Txt_C"><div>7</div></td>
<td><span class="HorseNameSpan">サンプル馬</span></td>
</tr>
</table>
''';

    final parsed = RaceNetkeibaResultParser.parseRefundedHorses(html);
    expect(parsed.horses, {7});
    expect(parsed.frames[7], 2);
    expect(parsed.names[7], 'サンプル馬');
  });
}
