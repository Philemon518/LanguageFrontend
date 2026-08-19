import 'dart:js_interop';

@JS('CANTO_API_BASE')
external String? get _cantoApiBase;

String? readRuntimeApiBase() => _cantoApiBase;
