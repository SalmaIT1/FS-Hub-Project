import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    print('Usage: dart run bin/ws_client.dart <userId> <conversationId> [clientMessageId] [mode]');
    print('mode: send (default) | listen');
    return;
  }

  final userId = args[0];
  final conversationId = args[1];
  final clientMessageId = args.length > 2 ? args[2] : 'cli-${DateTime.now().millisecondsSinceEpoch}';
  final mode = args.length > 3 ? args[3] : 'send';

  // Generate a token via mk_token.dart programmatically
  final tokenProcess = await Process.start('dart', ['run', 'bin/mk_token.dart', userId], runInShell: true);
  final tokenOut = await tokenProcess.stdout.transform(utf8.decoder).join();
  final token = tokenOut.trim();
  await tokenProcess.exitCode;

  final uri = Uri.parse('ws://localhost:8080/ws/chat/$token');
  print('Connecting to $uri');
  final socket = await WebSocket.connect(uri.toString());

  socket.listen((data) {
    try {
      final m = jsonDecode(data as String);
      print('RECV: ${jsonEncode(m)}');
    } catch (e) {
      print('RECV (raw): $data');
    }
  }, onDone: () => print('Socket closed'), onError: (e) => print('Socket error: $e'));

  if (mode == 'send') {
    // Wait a moment then send a message
    await Future.delayed(Duration(seconds: 1));

    final msg = {
      'type': 'message',
      'data': {
        'conversationId': conversationId,
        'content': '',
        'type': 'text',
        'clientMessageId': clientMessageId,
      }
    };

    print('SENDING: ${jsonEncode(msg)}');
    socket.add(jsonEncode(msg));

    // keep running to receive broadcasts
    await Future.delayed(Duration(seconds: 5));
    await socket.close();
  } else {
    // listen-only mode: keep socket open longer to receive broadcasts
    print('Listening only; waiting 20s for broadcasts...');
    await Future.delayed(Duration(seconds: 20));
    await socket.close();
  }
}
