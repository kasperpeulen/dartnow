import 'dart:html';

import 'package:dartnow/polymer.dart';

import 'package:codemirror/codemirror.dart';
import 'package:dartnow/services/dartservices.dart';
import 'package:dartnow/services/common.dart';
import 'dart:async';
import 'dart:js';
import 'dart:convert';

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
  querySelectorAll("dart-pad").forEach((pad) {
    initPad(new PolymerBase.from(pad));
    pad.querySelectorAll(".editor").forEach((e) => initEditor(pad, e));
  });
}

void initEditor(Element pad, Element el) {
  String code = el.text.trim();
  el.querySelector("span").attributes["hidden"] = "";
  if (code == "") code = "\n";
  el.style.display = "block";
  CodeMirror editor = new CodeMirror.fromElement(el, options: {
    'continueComments': {'continueLineComment': false},
    'autofocus': true,
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
    if (el.id != "dart") return;
    Timer.run(() {
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
                      return m[1]+m[2];
                    });
                dartDoc["dartdoc"] = dartDoc["dartdoc"].replaceAllMapped(
                    new RegExp(r"(\s)\[(\w{3,})\](\s)"), (m) {
                      return m[1]+"`"+m[2]+"`"+m[3];
                    });
                dartDoc['selectedPage'] = 1;
                dartDoc.element.querySelectorAll("pre code").forEach((e) {
                  String source = e.text.trim();
                  e.text = "";
                  new CodeMirror.fromElement(e,options: inlineOptions)
                ..getDoc().setValue(source);
                });
                context["Polymer"].callMethod("updateStyles");
          });
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
        ..source = pad["dart"];
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