import 'package:carlauncher4/core/theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formato de miles', () {
    expect(miles(84760), '84.760');
    expect(miles(500), '500');
  });
}
