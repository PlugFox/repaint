import 'package:flutter/material.dart';
import 'package:repaintexample/src/common/util/app_zone.dart';
import 'package:repaintexample/src/common/widget/app.dart';

void main() => appZone(
      () => runApp(App(
        initalRoute:
            WidgetsBinding.instance.platformDispatcher.defaultRouteName,
      )),
    );
