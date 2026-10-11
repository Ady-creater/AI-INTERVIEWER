const backend = String.fromEnvironment(
  'BACKEND',
  defaultValue: '127.0.0.1:8000',
);
final isLocal = backend.startsWith('127.') || backend.startsWith('localhost');
final httpBase = '${isLocal ? 'http' : 'https'}://$backend';
final wsUrl = '${isLocal ? 'ws' : 'wss'}://$backend/ws';
