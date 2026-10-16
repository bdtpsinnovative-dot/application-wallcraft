import 'package:flutter/material.dart';
import 'in_app_doc_viewer_stub.dart'
    if (dart.library.html) 'in_app_doc_viewer_web.dart';

Widget getInAppDocView(String url) => buildInAppDocView(url);

void triggerWebDownload(String url, String filename) => downloadFileWeb(url, filename);
