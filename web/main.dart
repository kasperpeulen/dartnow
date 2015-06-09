import 'dart:html';

import 'package:dartnow/polymer.dart';

import 'package:codemirror/codemirror.dart';
import 'package:dartnow/services/dartservices.dart';
import 'package:dartnow/services/common.dart';
import 'dart:async';
import 'dart:js';
import 'dart:convert';

JsObject scope = new JsObject.fromBrowserObject($('template[is=dom-bind]'));
CodeMirror activeEditor;
PolymerBase activePad;
IFrameElement result = querySelector("iframe");
Map<String, CodeMirror> instances = {};
PolymerBase dartDoc = new PolymerBase.fromSelector("dart-doc");
PolymerBase dartIssues= new PolymerBase.fromSelector("dart-issues");
var client = new SanitizingBrowserClient();
DartservicesApi dartServices = new DartservicesApi(client, rootUrl: serverURL);
Doc getDoc() {
  return activeEditor.getDoc();
}

void main() {
  scope["selectedPage"] = 1;

  scope["refreshEditor"] = (e,o) {
    Timer.run(() => instances.forEach((_,e) => e.refresh()));
  };
  Timer.run(() {
    var a = querySelector("tutorial-simple");
    print(a);
    var b = querySelectorAll("dart-pad");
    print(b);
    var c = a.querySelectorAll("dart-pad");
    print (c);
    var d = context["Polymer"].callMethod("dom", [new JsObject.fromBrowserObject($("tutorial-simple"))]);
    print(d);
    print(d["node"]);
    var e = d.callMethod("querySelectorAll",["dart-pad"]);
    print(e);

    querySelectorAll("dart-pad").forEach((pad) {
      initPad(new PolymerBase.from(pad));
      pad.querySelectorAll(".editor").forEach((e) => initEditor(pad, e));
    });
  });

//  print(context["Polymer"].callMethod("dom", [new JsObject.fromBrowserObject($("tutorial-simple"))]));


}

void initEditor(Element pad, Element el) {
  String code = el.text.trim();
  el.querySelector("span").attributes["hidden"] = "";
  if (code == "") code = "\n";
  el.style.display = "block";
  CodeMirror editor = new CodeMirror.fromElement(el, options: {
    'continueComments': {'continueLineComment': false},
    'autoCloseTags': true,
    'autoCloseBrackets': true,
    'matchBrackets': true,
    'tabSize': 2,
    'indentUnit': 2,
    'extraKeys': {
      'Cmd-/': 'toggleComment',
      'Ctrl-/': 'toggleComment'
    },
  })
    ..setMode(el.id)
    ..getDoc().setValue(code);
  instances[pad.id + el.id] = editor;
  editor.onChange.listen((_) {

    activeEditor = editor;
    activePad = new PolymerBase.from(pad);
    activePad[el.id] = editor.getDoc().getValue();
  });

  editor.onMouseDown.listen((_) {
    activeEditor = editor;
    activePad = new PolymerBase.from(pad);
    // Delay to give codemirror time to process the mouse event.
    Timer.run(() {
      if (el.id == "dart") {
        computeDartDoc();
      } else if (el.id == "css") {
        computeCssDoc();
      }
      });
    });
}

computeCssDoc() {
  const apiUrl = "https://docs.webplatform.org/w/api.php?action=ask&format=json&query=";
  Token token = activeEditor.getTokenAt(activeEditor.getDoc().getCursor());
  if (token.type == 'property') {
    String name = token.string;
    String propertyQuery = '[[css/properties/$name]]'
    '|?Summary|?Possible_value|?Applies_to|?Inherited|?Initial_value';
    String valueQuery = '[[Value for property::css/properties/$name]]'
    '|?Property value|?Property value description';

    try {
      HttpRequest.getString(apiUrl + propertyQuery).then((property) {
        HttpRequest.getString(apiUrl + valueQuery).then((values) {
        CssProperty css = new CssProperty.fromJSON(name,property,values);
        dartDoc['csselement'] = css.name;
        dartDoc['cssdoc'] = css.summary;
        dartDoc.setAttribute("cssvalues",
        JSON.encode(css.possibleValues.map(
                (e) => {"value" : e, "description" : css.valuesWithDescription[e]}).toList()));
        dartDoc['selectedPage'] = 2;
        });
      });

    } on Error {
      return;
    }
  }
}

void computeDartDoc() {
  SourceRequest request = new SourceRequest()
    ..offset = getDoc().indexFromPos(getDoc().getCursor())
    ..source = getDoc().getValue();
  dartServices.document(request).timeout(serviceCallTimeout).then(
          (DocumentResponse result) {
        Map<String, String> info = result.info;
        if (info['description'] == null && info['dartdoc'] == null) {
          return;
        }
        if (info['dartdoc'] == null) info['dartdoc'] = "";



        dartDoc["element"] = info['description'];
        dartDoc["dartdoc"] = info['dartdoc'].replaceAllMapped(
            new RegExp(r"(\[.+\])\s(\(.+\))"), (m) {
              return m[1] + m[2];
            });
        dartDoc["dartdoc"] = dartDoc["dartdoc"].replaceAllMapped(
            new RegExp(r"(\s)\[(\w{3,})\](\s)"), (m) {
              return m[1] + "`" + m[2] + "`" + m[3];
            });
        dartDoc['selectedPage'] = 1;
        dartDoc.element.querySelectorAll("pre code").forEach((e) {
          String source = e.text.trim();
          e.text = "";
          new CodeMirror.fromElement(e, options: inlineOptions)
            ..getDoc().setValue(source);
        });
      });
}

void initPad(PolymerBase pad) {
  pad
    ..on("switch",
      (e) => instances[pad.id + numToName[pad["selectedTab"]]].refresh())
    ..on("run", (e) {
    if (pad["dart"].trim() == "") {
      pad["result"] = finalHtml("", pad["htmlmixed"], pad["css"]);
      pad["selectedPage"] = 1;
      pad["progress"] = true;
    } else {
      var input = new CompileRequest()
        ..source = pad["dart"].replaceAll("script>","scr'+'ipt>").replaceAll("head>","he'+'ad>");
      var doc = instances[pad.element.id+"dart"].getDoc();
      SourceRequest request = new SourceRequest()
        ..offset = doc.indexFromPos(doc.getCursor())
        ..source = pad["dart"];
      dartServices
        ..analyze(request).then(
              (AnalysisResults response) {
            if (response.issues.length != 0) {
              querySelector("#issues").attributes.remove("hidden");
              dartIssues["selectedPage"] = 1;
              dartIssues.setAttribute("issues", JSON.encode(response.toJson()["issues"]));
              pad["progress"] = true;
            } else {
              dartIssues["selectedPage"] = 0;
              querySelector("#issues").attributes["hidden"] = "";
              dartServices
                ..compile(input).timeout(serviceCallTimeout).then(
                      (CompileResponse response) {
                    pad["result"] = finalHtml(response.result, pad["htmlmixed"], pad["css"]);
                    pad["selectedPage"] = 1;
                    pad["progress"] = true;
                  }).catchError((e) {
                pad["progress"] = true;
              });
            }
          });
    }
  });
}

String finalHtml(String javascript, String html, String css) {
  if (html.contains("</body>")) {
    html = html.replaceFirst("</body>", "<script>$javascript</script></body>");
  } else {
    if (html.contains("</head>")) {
      html  = html.replaceFirst("</head>", "<body>" + html + "<script>$javascript</script></body>");
    } else {
      javascript.replaceAll("head>","he'+'ad>");

      html = "<body>" + html + "<script>$javascript</script></body>";
    }
  }
  if (html.contains("<head>")) {
    html  = html.replaceFirst("<head>", "<head><style>$css</style>");
  } else {
    html = "<html><head><style>$css</style></head>" + html + "</html>";
  }
  return html;
}

Map<int, String> numToName = {0: "dart", 1: "htmlmixed", 2: "css"};

Map inlineOptions = {
  "readOnly" : true,
  "mode" : "dart"
};

class CssProperty {
  String name;
  String initialValue;
  String appliesTo;
  String inherited;
  String summary;
  List<String> possibleValues;
  Map<String, String> valuesWithDescription;

  CssProperty.fromJSON(this.name, var property, var values) {
    property = JSON.decode(property);
    property
    = property["query"]["results"]["css/properties/$name"]["printouts"];
    summary = property["Summary"][0].replaceAllMapped(
        new RegExp(r"\[\[(.+)\|(.+)\]\]"), (m) {
          return "[" + m[2] + "](https://docs.webplatform.org/wiki/" + m[1] + ")";
        });
    appliesTo = property["Applies to"][0];
    inherited = property["Inherited"][0];
    initialValue = property["Initial value"][0];
    possibleValues = property["Possible value"];

    values = JSON.decode(values);
    values = values["query"]["results"];
    valuesWithDescription = {};
    values.values.forEach((result) {
      result = result["printouts"];
      String value = result["Property value"][0];
      String description = result["Property value description"][0];
      valuesWithDescription[value] = description.replaceAllMapped(
          new RegExp(r"\[\[(.+)\|(.+)\]\]"), (m) {
            return "[" + m[2] + "](https://docs.webplatform.org/wiki/" + m[1] + ")";
          });
    });
  }
//  void toHtml() {
//    $("h1 code").innerHtml = name;
//    $("#summary").innerHtml = summary;
//    $("#overview").innerHtml =
//    "<dt>Initial value</dt><dd>$initialValue</dd>"
//    "<dt>Applies to</dt><dd>$appliesTo</dd>"
//    "<dt>Inherited</dt><dd>$inherited</dd>";
//    $("#values").innerHtml = "";
//    for (String value in possibleValues) {
//      $("#values").innerHtml +=
//      "<dt><code>$value</code></dt>"
//      "<dd>${valuesWithDescription[value]}</dd>";
//    }
//    $("#read-more").onClick.listen((e)
//    => window.open(
//        "https://docs.webplatform.org/wiki/css/properties/$name",
//        "_blank"));
//  }
}
