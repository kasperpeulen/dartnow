library dartnow.polymer;

import "dart:html";
import 'dart:async';
import 'dart:js';

/**
 * Finds the first descendant element of this document that matches the specified group of selectors.
 */
Element $(String selectors) => querySelector(selectors);

class PolymerBase {
  HtmlElement element;
  Map<String, Stream> _eventStreams = {};
  JsObject _js;

  JsObject get js {
    if (_js == null) {
      _js = new JsObject.fromBrowserObject(element);
    }
    return _js;
  }

  PolymerBase(String tag) {
    element = new Element.tag(tag);
  }
  PolymerBase.fromSelector(String selector) {
    element = $(selector);
  }
  PolymerBase.from(this.element);

  operator [](String propertyName) => js[propertyName];

  operator []=(String propertyName, dynamic value) {
    js[propertyName] = value;
  }

  dynamic call(String methodName, [List args]) => js.callMethod(methodName, args);

  dynamic property(String name) => js[name];

  void setProperty(String name, String value) {
    js[name] = value;
  }

  Stream listen(String eventName, {Function converter, bool sync: false}) {
    if (!_eventStreams.containsKey(eventName)) {
      StreamController controller = new StreamController.broadcast(sync: sync);
      _eventStreams[eventName] = controller.stream;
      element.on[eventName].listen((e) {
        controller.add(converter == null ? e : converter(e));
      });
    }

    return _eventStreams[eventName];
  }

  void on(String eventName, void onData(CustomEvent event), {Function converter, bool sync: false}) {
    if (!_eventStreams.containsKey(eventName)) {
      StreamController controller = new StreamController.broadcast(sync: sync);
      _eventStreams[eventName] = controller.stream;
      element.on[eventName].listen((e) {
        controller.add(converter == null ? e : converter(e));
      });
    }
    _eventStreams[eventName].listen((e) {
      onData(e);
    });
  }

  String attribute(String name) => element.getAttribute(name);
  void setAttribute(String name, [String value = '']) => element.setAttribute(name, value);

  String get id => attribute('id');
  set id(String value) => setAttribute('id', value);


  String clearAttribute(String name) => element.attributes.remove(name);

}