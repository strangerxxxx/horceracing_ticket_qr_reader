# horceracing_ticket_qr_reader

JRA の勝馬投票券の QR コードを読み取り、内容を表示する flutter アプリです。

## アプリの機能について

アプリを起動し、「QR コード読み取り」ボタンを押し、馬券の QR コードを読み取ってください。  
QR コードの内容から持っている情報をできる限り復元し、JSON 形式で表示します。  
読み取りが成功したら情報の表示とともに、[netkeiba のデータベース](https://db.netkeiba.com/)の該当レースのリンクも表示します。

## 使用方法

Releases にある apk ファイルを入れてください。

コードをそのまま利用する場合は、[flutter をインストール](https://docs.flutter.dev/get-started/install)した状態でエミュレーター環境を用意し、以下コマンドを実行すると動くと思います。

```bash
flutter pub get
flutter run
```

apk ファイルへのビルドもできます。

```bash
flutter build apk --release
```

## おことわり

当然ながら JRA が QR コードの仕様を公開しているわけではないため、正しく表示されるとは限りません。バグも多いと思います。  
バグ報告や機能の追加要望があれば Pull Request や Issues をいただくか、以下にお願いします。  
[Misskey.io/@stn](https://misskey.io/@srn)  
[X/@strangerxxx](https://x.com/strangerxxx)

## 参考文献

QR コードの解析部分については、下記ブログを参考にさせていただきました。  
[JRA 日本中央競馬会の馬券レイアウトまとめ＆QR コード解析](https://ys223.blogspot.com/2019/07/jra.html)

## TODO

- デザインの改善
- 馬番表示などの改善
- 組み合わせ数、合計金額の計算・表示
- オッズ、払戻金の表示
- 履歴保存
- 文字列入力からの QR コードの再現
  - チェックデジットの仕様がわからないと難しい……
- 保存されている画像からの QR 読み取り

## License

MIT License

QR コード ® は株式会社デンソーウェーブの登録商標です。  
QR Code® is a registered trademark of DENSO WAVE INCORPORATED in Japan and in other countries.
