import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_tasks/app/share_intake.dart';

void main() {
  test('a page from ZT Browser: title from the subject, address as a link', () {
    final t = sharedTaskDraft(subject: 'Good article', text: 'Good article\nhttps://example.com/a?b=1');
    expect(t.title, 'Good article');
    expect(t.links, ['https://example.com/a?b=1']);
    expect(t.description, isNull);
  });

  test('no subject: the first text line is the title, the rest the description', () {
    final t = sharedTaskDraft(text: 'Buy milk\nand bread https://shop.example');
    expect(t.title, 'Buy milk');
    expect(t.description, 'and bread');
    expect(t.links, ['https://shop.example']);
  });

  test('only an address: it is the title and the link', () {
    final t = sharedTaskDraft(text: '  https://x.org  ');
    expect(t.title, 'https://x.org');
    expect(t.links, ['https://x.org']);
  });

  test('punctuation around an address in prose is not part of the link', () {
    final t = sharedTaskDraft(text: 'Read this: https://example.com/article. (https://x.org/a)');
    expect(t.links, ['https://example.com/article', 'https://x.org/a']);
    expect(t.description, isNull);
    expect(t.title, 'Read this:');
  });

  test('symbols and emoji in the shared text are kept', () {
    final t = sharedTaskDraft(text: 'Revenue - expenses = profit\n🎉\nsee https://x.org/a .');
    expect(t.title, 'Revenue - expenses = profit');
    expect(t.description, '🎉\nsee');
    expect(t.links, ['https://x.org/a']);
  });

  test('brackets that belong to the address stay', () {
    final t = sharedTaskDraft(text: 'https://en.wikipedia.org/wiki/Tel_Aviv_(city)');
    expect(t.links, ['https://en.wikipedia.org/wiki/Tel_Aviv_(city)']);
  });
}
