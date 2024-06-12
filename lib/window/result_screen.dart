import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../utils/dialog.dart';
import 'package:http_parser/http_parser.dart';
import 'package:fluttertoast/fluttertoast.dart';



@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text("TEST"),
    ),
    body: Center(
      child: Text('test'),
    ),
  );
}