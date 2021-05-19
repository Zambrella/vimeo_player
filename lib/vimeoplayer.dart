library vimeoplayer;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'src/quality_links.dart';
import 'dart:async';
import 'src/fullscreen_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

//Класс видео плеера
class VimeoPlayer extends StatefulWidget {
  final String id;
  final bool? autoPlay;
  final bool? looping;
  final int? position;
  final Widget spinner;
  final Color backgroundLoadingColor;

  VimeoPlayer({
    required this.id,
    this.autoPlay,
    this.looping,
    this.position,
    required this.spinner,
    required this.backgroundLoadingColor,
    Key? key,
  }) : super(key: key);

  @override
  _VimeoPlayerState createState() => _VimeoPlayerState(id, autoPlay, looping, position);
}

class _VimeoPlayerState extends State<VimeoPlayer> {
  String _id;
  bool? autoPlay = false;
  bool? looping = false;
  bool _overlay = true;
  bool fullScreen = false;
  int? position;

  _VimeoPlayerState(this._id, this.autoPlay, this.looping, this.position);

  //Custom controller
  VideoPlayerController? _controller;
  Future<void>? initFuture;

  //Quality Class
  late QualityLinks _quality;
  late Map _qualityValues;
  var _qualityValue;

  //Переменная перемотки
  bool _seek = false;

  //Переменные видео
  double? videoHeight;
  double? videoWidth;
  late double videoMargin;

  @override
  void initState() {
    //Create class
    _quality = QualityLinks(_id);

    //Initalization of video controllers while getting data from Vimeo
    _quality.getQualitiesSync().then((value) {
      _qualityValues = value;
      _qualityValue = value[value.lastKey()];
      _controller = VideoPlayerController.network(_qualityValue);
      _controller!.setLooping(looping == null ? false : true);
      if (autoPlay!) _controller!.play();
      initFuture = _controller!.initialize();

      //Updates app's state and redraws it
      setState(() {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitDown, DeviceOrientation.portraitUp]);
      });
    });

    // On the video page there is the priority for a portrait orientation
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitDown, DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIOverlays(SystemUiOverlay.values);

    super.initState();
  }

  //Draws player's elements
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: AlignmentDirectional.center,
        children: <Widget>[
          GestureDetector(
            child: FutureBuilder(
                future: initFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    //Controlling of player's width and height
                    double delta = MediaQuery.of(context).size.width - MediaQuery.of(context).size.height * _controller!.value.aspectRatio;

                    //Calculation of player's width and height according to sides
                    // and orientation of a device
                    if (MediaQuery.of(context).orientation == Orientation.portrait || delta < 0) {
                      videoHeight = MediaQuery.of(context).size.width / _controller!.value.aspectRatio;
                      videoWidth = MediaQuery.of(context).size.width;
                      videoMargin = 0;
                    } else {
                      videoHeight = MediaQuery.of(context).size.height;
                      videoWidth = videoHeight! * _controller!.value.aspectRatio;
                      videoMargin = (MediaQuery.of(context).size.width - videoWidth!) / 2;
                    }

                    //We start from the same place where we left off when changing quality
                    if (_seek && _controller!.value.duration.inSeconds > 2) {
                      _controller!.seekTo(Duration(seconds: position!));
                      _seek = false;
                    }

                    //Draws player's elements
                    return Stack(
                      children: <Widget>[
                        Container(
                          height: videoHeight,
                          width: videoWidth,
                          margin: EdgeInsets.only(left: videoMargin),
                          child: VisibilityDetector(
                              key: ValueKey(_id),
                              onVisibilityChanged: (visibleInfo) {
                                final visiblePercentage = visibleInfo.visibleFraction * 100;
                                if (visiblePercentage == 0) {
                                  _controller?.pause();
                                }
                              },
                              child: VideoPlayer(_controller!)),
                        ),
                        if (_overlay) _videoOverlay(),
                      ],
                    );
                  } else {
                    return Container(
                      color: widget.backgroundLoadingColor,
                      child: Center(heightFactor: 6, child: widget.spinner),
                    );
                  }
                }),
            onTap: () {
              //Редактируем размер области дабл тапа при показе оверлея.
              // Сделано для открытия кнопок "Во весь экран" и "Качество"
              setState(() {
                _overlay = !_overlay;
              });
            },
          ),
        ],
      ),
    );
  }

  //================================ Quality ================================//
  void _settingModalBottomSheet(context) {
    showModalBottomSheet(
        context: context,
        builder: (BuildContext bc) {
          //Формирования списка качества
          final children = <Widget>[];
          _qualityValues.forEach((elem, value) => (children.add(new ListTile(
              title: new Text(" ${elem.toString()} fps"),
              onTap: () => {
                    //Обновление состояние приложения и перерисовка
                    setState(() {
                      _controller!.pause();
                      _qualityValue = value;
                      _controller = VideoPlayerController.network(_qualityValue);
                      _controller!.setLooping(true);
                      _seek = true;
                      initFuture = _controller!.initialize();
                      _controller!.play();
                    }),
                  }))));
          //Вывод элементов качество списком
          return Container(
            child: Wrap(
              children: children,
            ),
          );
        });
  }

  //================================ OVERLAY ================================//
  Widget _videoOverlay() {
    return Stack(
      children: <Widget>[
        GestureDetector(
          child: Center(
            child: Container(
              width: videoWidth,
              height: videoHeight,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
              ),
            ),
          ),
        ),
        Center(
          child: IconButton(
              padding: EdgeInsets.only(top: videoHeight! / 2 - 30, bottom: videoHeight! / 2 - 30),
              icon: _controller!.value.isPlaying
                  ? Icon(
                      Icons.pause,
                      size: 60.0,
                      color: Colors.white,
                    )
                  : Icon(
                      Icons.play_arrow,
                      size: 60.0,
                      color: Colors.white,
                    ),
              onPressed: () {
                setState(() {
                  // If video is playing, pause
                  // If video is not playing, then play and close overlay after a delay
                  if (_controller!.value.isPlaying) {
                    _controller!.pause();
                  } else {
                    _controller!.play();
                    Future.delayed(const Duration(seconds: 2), () {
                      setState(() {
                        _overlay = false;
                      });
                    });
                  }
                });
              }),
        ),
        Container(
          margin: EdgeInsets.only(left: videoWidth! + videoMargin - 48),
          child: IconButton(
              icon: Icon(
                Icons.settings,
                size: 26.0,
                color: Colors.white,
              ),
              onPressed: () {
                position = _controller!.value.position.inSeconds;
                _seek = true;
                _settingModalBottomSheet(context);
                setState(() {});
              }),
        ),
        Positioned(
          bottom: 2,
          child: Container(
            //===== Ползунок =====//
            margin: EdgeInsets.only(left: videoMargin), //CHECK IT
            child: _videoOverlaySlider(),
          ),
        )
      ],
    );
  }

  //=================== ПОЛЗУНОК ===================//
  Widget _videoOverlaySlider() {
    return ValueListenableBuilder(
      valueListenable: _controller!,
      builder: (context, VideoPlayerValue value, child) {
        if (!value.hasError && value.isInitialized) {
          return Row(
            children: <Widget>[
              const SizedBox(
                width: 22,
              ),
              Container(
                width: 46,
                alignment: Alignment(0, 0),
                child: Text(
                  value.position.inMinutes.toString() +
                      ':' +
                      (value.position.inSeconds - value.position.inMinutes * 60).toString().padLeft(2, '0'),
                  style: TextStyle(color: Colors.white),
                ),
              ),
              Container(
                height: 20,
                width: videoWidth! - (22 + 46 + 46 + 60),
                child: VideoProgressIndicator(
                  _controller!,
                  allowScrubbing: true,
                  colors: VideoProgressColors(
                    playedColor: Colors.white,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    bufferedColor: Colors.white.withOpacity(0.6),
                  ),
                  padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
                ),
              ),
              Container(
                width: 46,
                alignment: Alignment(0, 0),
                child: Text(
                  value.duration.inMinutes.toString() +
                      ':' +
                      (value.duration.inSeconds - value.duration.inMinutes * 60).toString().padLeft(2, '0'),
                  style: TextStyle(color: Colors.white),
                ),
              ),
              Container(
                width: 60,
                child: Center(
                  child: IconButton(
                      alignment: AlignmentDirectional.center,
                      icon: Icon(
                        Icons.fullscreen,
                        size: 30,
                        color: Colors.white,
                      ),
                      onPressed: () async {
                        //Создание новой страницы с плеером во весь экран,
                        // предача данных в плеер и возвращение позиции при
                        // возвращении обратно. Пока что мы не вернулись из
                        // фуллскрина - программа в ожидании
                        position = await Navigator.of(
                          context,
                          rootNavigator: true,
                        ).push(PageRouteBuilder(
                            opaque: false,
                            pageBuilder: (BuildContext context, _, __) => FullscreenPlayer(
                                id: _id,
                                autoPlay: true,
                                controller: _controller,
                                position: _controller!.value.position.inSeconds,
                                initFuture: initFuture,
                                qualityValue: _qualityValue),
                            transitionsBuilder: (___, Animation<double> animation, ____, Widget child) {
                              return FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(scale: animation, child: child),
                              );
                            }));
                        setState(() {
                          _seek = true;
                        });
                      }),
                ),
              )
            ],
          );
        } else {
          return Container();
        }
      },
    );
  }

  @override
  void dispose() {
    _controller!.dispose();
    super.dispose();
  }
}
