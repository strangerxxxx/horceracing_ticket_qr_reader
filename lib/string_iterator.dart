/// QRコード文字列を1文字ずつ読み進めるイテレータ。
/// parse.dart と parse_local.dart の両方で使用する。
class StringIterator {
  final String _s;
  int _currentPosition = 0;

  StringIterator(this._s);

  /// 現在位置の1文字を返し、位置を1つ進める。
  String next() {
    if (_currentPosition >= _s.length) {
      throw StateError('StringIterator: No more elements in the string.');
    }
    return _s[_currentPosition++];
  }

  /// 位置を [offset] 文字分スキップする。
  void move(int offset) {
    _currentPosition += offset;
    if (_currentPosition < 0 || _currentPosition > _s.length) {
      throw RangeError(
        'StringIterator: Invalid position after move: $_currentPosition',
      );
    }
  }

  /// 現在の読み取り位置を返す。
  int get position => _currentPosition;

  set currentPosition(int pos) {
    _currentPosition = pos;
  }

  /// 位置を進めずに [offset] 先の文字を返す。
  String peek(int offset) {
    final pos = _currentPosition + offset;
    if (pos < 0 || pos >= _s.length) {
      throw RangeError('StringIterator: Peek out of range: $pos');
    }
    return _s[pos];
  }
}
