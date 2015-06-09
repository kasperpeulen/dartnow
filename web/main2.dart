//import 'dart:html';
//import 'dart:js';
//import 'dart:convert';
//
//var $ = querySelector;
//JsObject scope = new JsObject.fromBrowserObject($('template[is=dom-bind]'));
//const String url =
//'https://dart-services.appspot.com/api/dartservices/v1/compile';
//
//void main() {
//  scope['selected'] = 0;
//  scope['html'] = '<p>Hello world!</p>';
//  scope['css'] = 'p {font-size: 20px;}';
//  scope['dart'] =
//  'import \'dart:html\'; void main() => querySelector(\'p\').text = \'Is this working?\';';
//  scope['showOutput'] = (e, object) {
//    compileDart();
//  };
//}
//compileDart() async {
//  var request = await HttpRequest.request(
//      url,
//      method: 'POST',
//      sendData: JSON.encode({'source': scope['dart']}));
//  var compiled = JSON.decode(request.response)['result'];
//  scope['htmloutput'] = '<html><head><style>${scope['css']}</style>'
//  '<body>${scope['html']}<script>$compiled</script></body></head>';
//}
//import 'dart:html';
//import 'dart:js';
//
//var $ = querySelector;
//var scope =
//new JsObject.fromBrowserObject($('template[is=dom-bind]'));
//TextAreaElement html = $('#html');
//TextAreaElement css = $('#css');
//
//void main() {
//  scope['selected'] = 0;
//  scope['showOutput'] = (e, object) {
//    scope['htmloutput'] =
//    '<!doctype html>'
//    '<ht'+'ml>'
//    '  <he'+'ad><style>${css.value}</style></he'+'ad>'
//    '  <body>${html.value}</body>'
//    '</ht'+'ml>';
//  };
//}

import 'dart:html';
import 'dart:js';
import 'dart:convert';

var $ = querySelector;
var scope =
new JsObject.fromBrowserObject($('template[is=dom-bind]'));
TextAreaElement html = $('#html');
TextAreaElement css = $('#css');
const String url =
'https://dart-services.appspot.com/api/dartservices/v1/compile';

void main() {
  scope['selected'] = 0;
  scope['showOutput'] = (e, object) {
    compileDart();
  };
}
compileDart() async {
  var request = await HttpRequest.request(
      url,
      method: 'POST',
      sendData: JSON.encode({'source': scope['dart']}));
  var compiled = JSON.decode(request.response)['result'];
  scope['htmloutput'] =
  '<!doctype html>'
  '<ht'+'ml>'
  '  <he'+'ad><style>${css.value}</style></he'+'ad>'
  '  <body>${html.value}<sc'+'ipt>$compiled</s'+'cript></body>'
  '</ht'+'ml>';
}