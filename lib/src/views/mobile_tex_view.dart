import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_tex/src/models/tex_view_container.dart';
import 'package:flutter_tex/src/utils/tex_view_rendering_engine.dart';
import 'package:flutter_tex/src/utils/tex_view_server.dart';
import 'package:flutter_tex/src/utils/tex_view_style.dart';
import 'package:webview_flutter/webview_flutter.dart';

///A Flutter Widget to render Mathematics / Maths, Physics and Chemistry, Statistics / Stats Equations based on LaTeX with full HTML and JavaScript support.
class TeXView extends StatefulWidget {
  final Key key;

  /// A list of TeXViewChild.
  @required
  final List<TeXViewContainer> children;

  /// Style TeXView Widget with [TeXViewStyle].
  final TeXViewStyle style;

  /// Render Engine to render TeX.
  final TeXViewRenderingEngine renderingEngine;

  /// Fixed Height for TeXView. (Avoid using fixed height for TeXView, let it to adopt the height by itself)
  final double height;

  /// Show a loading widget before rendering completes.
  final Widget loadingWidget;

  /// Show or hide loadingWidget.
  final bool showLoadingWidget;

  /// On Tap Callback when a TeXViewChild is tapped.
  final Function(String childID) onTap;

  /// Callback when TEX rendering finishes.
  final Function(double height) onRenderFinished;

  /// Callback when TeXView loading finishes.
  final Function(String message) onPageFinished;

  /// Keep widget Alive. (True by default).
  final bool keepAlive;

  final double heightCorrection;

  TeXView(
      {this.key,
      this.children,
      this.style,
      this.height,
      this.loadingWidget,
      this.showLoadingWidget,
      this.onTap,
      this.keepAlive,
      this.onRenderFinished,
      this.onPageFinished,
      this.renderingEngine,
      this.heightCorrection})
      : super(key: key);

  @override
  _TeXViewState createState() => _TeXViewState();
}

class _TeXViewState extends State<TeXView> with AutomaticKeepAliveClientMixin {
  static int viewInstanceCount = 0;

  WebViewController _teXWebViewController;
  int _teXViewServerPort = 5353 + viewInstanceCount;
  TeXViewServer _flutterTeXServer;
  double _teXViewHeight = 1;
  String lastTeXHTML;

  _TeXViewState() {
    _flutterTeXServer = TeXViewServer(_teXViewServerPort);
    viewInstanceCount += 1;
  }

  @override
  bool get wantKeepAlive => widget.keepAlive ?? true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    updateKeepAlive();
    _initTeXView();
    return IndexedStack(
      index: widget.showLoadingWidget ? _teXViewHeight == 1 ? 1 : 0 : 0,
      children: <Widget>[
        Container(
          height: widget.height ?? _teXViewHeight,
          child: WebView(
            onPageFinished: _onPageFinished,
            onWebViewCreated: _onWebViewCreated,
            javascriptChannels: Set.from([
              JavascriptChannel(
                  name: 'RenderedTeXViewHeight',
                  onMessageReceived: _renderedTeXViewHeightHandler),
              JavascriptChannel(
                  name: 'TeXViewChildTapCallback',
                  onMessageReceived: _teXViewChildTapCallbackHandler),
            ]),
            javascriptMode: JavascriptMode.unrestricted,
          ),
        ),
        widget.loadingWidget ??
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  CircularProgressIndicator(),
                  Divider(
                    height: 5,
                    color: Colors.transparent,
                  ),
                  Text("Rendering TeXView...!")
                ],
              ),
            )
      ],
    );
  }

  @override
  void dispose() {
    _flutterTeXServer.close();
    viewInstanceCount -= 1;
    super.dispose();
  }

  String getJsonRawTeXHTML() {
    return jsonEncode({
      "children": widget.children.map((child) => child.toJson()).toList(),
      "style": widget.style?.initStyle()
    });
  }

  void handleRequest(HttpRequest request) {
    try {
      if (request.method == 'GET' &&
          request.uri.queryParameters['query'] == "getRawTeXHTML") {
        request.response.write(getJsonRawTeXHTML());
      } else {}
    } catch (e) {
      print('Exception in handleRequest: $e');
    }
  }

  @override
  void initState() {
    _flutterTeXServer.start(handleRequest);
    super.initState();
  }

  String _getTeXViewUrl() {
    return Uri.encodeFull(
        "http://localhost:$_teXViewServerPort/packages/flutter_tex/src/flutter_tex_libs/${widget.renderingEngine?.getEngineName()}/index.html?teXViewServerPort=$_teXViewServerPort&viewInstanceCount=$viewInstanceCount&configurations=${widget.renderingEngine?.getConfigurations()}");
  }

  void _initTeXView() {
    if (_teXWebViewController != null && getJsonRawTeXHTML() != lastTeXHTML) {
      if (widget.showLoadingWidget) {
        _teXViewHeight = 1;
      }
      _teXWebViewController.loadUrl(_getTeXViewUrl());
      this.lastTeXHTML = getJsonRawTeXHTML();
    }
  }

  void _onPageFinished(message) {
    if (widget.onPageFinished != null) {
      widget.onPageFinished(message);
    }
  }

  void _onWebViewCreated(WebViewController controller) {
    _teXWebViewController = controller;
    _initTeXView();
  }

  void _renderedTeXViewHeightHandler(JavascriptMessage javascriptMessage) {
    double viewHeight = double.parse(javascriptMessage.message);
    if (_teXViewHeight != viewHeight) {
      setState(() {
        _teXViewHeight = viewHeight;
      });
    }
    if (widget.onRenderFinished != null) {
      widget.onRenderFinished(_teXViewHeight);
    }
  }

  void _teXViewChildTapCallbackHandler(JavascriptMessage javascriptMessage) {
    if (widget.onTap != null) {
      widget.onTap(javascriptMessage.message);
    }
  }
}
