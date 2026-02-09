import 'dart:convert';
import 'dart:io';

Future<String> mkToken(String userId) async {
  final p = await Process.start('dart', ['run', 'bin/mk_token.dart', userId], runInShell: true);
  final out = await p.stdout.transform(utf8.decoder).join();
  await p.exitCode;
  return out.trim();
}

Future<void> main(List<String> args) async {
  final conv = args.isNotEmpty ? args[0] : '1';
  final t1 = await mkToken('1');
  final t2 = await mkToken('2');

  final uri1 = Uri.parse('ws://localhost:8080/ws/chat/$t1');
  final uri2 = Uri.parse('ws://localhost:8080/ws/chat/$t2');

  print('Connecting listener (user 1) to $uri1');
  final s1 = await WebSocket.connect(uri1.toString());
  s1.listen((d) => print('LISTENER RECV: $d'), onDone: () => print('listener done'));

  print('Connecting sender (user 2) to $uri2');
  final s2 = await WebSocket.connect(uri2.toString());
  s2.listen((d) => print('SENDER RECV: $d'), onDone: () => print('sender done'));

  // Wait then send
  await Future.delayed(Duration(seconds: 1));
  final msg = {
    'type': 'message',
    'data': {
      'conversationId': conv,
      'content': '',
      'type': 'text',
      'clientMessageId': 'pair-${DateTime.now().millisecondsSinceEpoch}'
    }
  };

  print('SENDER sending: ${jsonEncode(msg)}');
  s2.add(jsonEncode(msg));

  // wait to receive
  await Future.delayed(Duration(seconds: 3));

  await s2.close();
  await s1.close();
}
