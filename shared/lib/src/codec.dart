import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

typedef Message = List<dynamic>;

const encoder = _Encoder();
const decoder = _Decoder();

class _Encoder extends Converter<Message, List<int>> {
  const _Encoder();

  @override
  Uint8List convert(Message input) => Uint8List.sublistView(
        const StandardMessageCodec().encodeMessage(input)!,
      );

  @override
  Sink<Message> startChunkedConversion(Sink<List<int>> sink) =>
      _EnvelopeEncoder(sink);
}

class _Decoder extends Converter<Uint8List, Message> {
  const _Decoder();

  @override
  Message convert(Uint8List input) =>
      const StandardMessageCodec().decodeMessage(ByteData.sublistView(input))
          as Message;

  @override
  Sink<Uint8List> startChunkedConversion(Sink<Message> sink) =>
      _ChunkedDecoder(sink);
}

class _EnvelopeEncoder implements ChunkedConversionSink<Message> {
  final Sink<List<int>> _out;

  _EnvelopeEncoder(this._out);

  @override
  void add(Message chunk) {
    final messageBytes = encoder.convert(chunk);
    assert(messageBytes.lengthInBytes > 0);
    _out
      ..add(
        Uint8List.sublistView(
          ByteData(4)..setInt32(0, messageBytes.lengthInBytes),
        ),
      )
      ..add(messageBytes);
  }

  @override
  void close() => _out.close();
}

class _ChunkedDecoder implements ChunkedConversionSink<Uint8List> {
  final Sink<Message> _out;
  int _nextSize = 0;
  final _buffer = BytesBuilder(copy: false);

  _ChunkedDecoder(this._out);

  Uint8List _takeBytes(int size) {
    final bytes = _buffer.takeBytes();
    _buffer.add(bytes.sublist(size));
    return bytes.sublist(0, size);
  }

  bool _emitEnvelope() {
    if (_nextSize == 0) {
      if (_buffer.length >= 4) {
        _nextSize = ByteData.sublistView(_takeBytes(4)).getInt32(0);
      } else {
        return false;
      }
    }

    assert(_nextSize > 0);
    if (_buffer.length >= _nextSize) {
      _out.add(decoder.convert(_takeBytes(_nextSize)));
      _nextSize = 0;
      return true;
    } else {
      return false;
    }
  }

  @override
  void add(Uint8List chunk) {
    _buffer.add(chunk);
    while (_emitEnvelope()) {}
  }

  @override
  void close() {
    if (_buffer.isNotEmpty) {
      scheduleMicrotask(_out.close);
      throw const FormatException('Buffer has outstanding data.');
    }
    _out.close();
  }
}
