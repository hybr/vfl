import 'dart:async';

class EventBus {
  final Map<String, List<Function>> _listeners = {};
  final StreamController<Event> _eventController = StreamController<Event>.broadcast();

  Stream<Event> get events => _eventController.stream;

  void on(String eventName, Function callback) {
    if (!_listeners.containsKey(eventName)) {
      _listeners[eventName] = [];
    }
    _listeners[eventName]!.add(callback);
  }

  void off(String eventName, Function callback) {
    if (_listeners.containsKey(eventName)) {
      _listeners[eventName]!.remove(callback);
      if (_listeners[eventName]!.isEmpty) {
        _listeners.remove(eventName);
      }
    }
  }

  void emit(String eventName, Map<String, dynamic> data) {
    final event = Event(
      name: eventName,
      data: data,
      timestamp: DateTime.now(),
    );

    _eventController.add(event);

    if (_listeners.containsKey(eventName)) {
      for (final callback in _listeners[eventName]!) {
        try {
          if (callback is Function(Event)) {
            callback(event);
          } else if (callback is Function(Map<String, dynamic>)) {
            callback(data);
          } else {
            callback();
          }
        } catch (e) {
          print('Error in event listener for $eventName: $e');
        }
      }
    }
  }

  void dispose() {
    _listeners.clear();
    _eventController.close();
  }
}

class Event {
  final String name;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final String id;

  Event({
    required this.name,
    required this.data,
    required this.timestamp,
  }) : id = DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}