import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
//        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

typedef dialogCallback = void Function(String param, String phone);
typedef feedbackCallback = void Function(String param, String phone, String descr);

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final PlatformWebViewController _controller;
  late bool showIcon = false;
  late bool deleteAccount = false;

  void onshowIcon(bool _showIcon) {
    setState(() {
      showIcon = _showIcon;
    });
  }

  @override
  void initState() {
    super.initState();

    _controller = PlatformWebViewController(
      AndroidWebViewControllerCreationParams(),
    )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x80000000))
      ..setPlatformNavigationDelegate(
        PlatformNavigationDelegate(
          const PlatformNavigationDelegateCreationParams(),
        )
          ..setOnProgress((int progress) {
            debugPrint('WebView is loading (progress : $progress%)');
          } as ProgressCallback)
          ..setOnPageStarted((String url) {
            debugPrint('Page started loading: $url');
//            onshowIcon(url == 'https://lk.mpkvc.ru/#/');
          })
          ..setOnPageFinished((String url) {
            debugPrint('Page finished loading: $url');
            onshowIcon(url == 'https://lk.mpkvc.ru/#/');
            debugPrint('showIcon: $showIcon');
//Page finished loading: https://lk.mpkvc.ru/#/login
//Page finished loading: https://lk.mpkvc.ru/#/
          })
          ..setOnWebResourceError((WebResourceError error) {
            debugPrint('''
Page resource error:
  code: ${error.errorCode}
  description: ${error.description}
  errorType: ${error.errorType}
  isForMainFrame: ${error.isForMainFrame}
          ''');
          })
          ..setOnNavigationRequest((NavigationRequest request) {
            if (request.url.startsWith('https://www.youtube.com/')) {
              debugPrint('blocking navigation to ${request.url}');
              return NavigationDecision.prevent;
            }
            debugPrint('allowing navigation to ${request.url}');
            return NavigationDecision.navigate;
          })
          ..setOnUrlChange((UrlChange change) {
            debugPrint('url change to ${change.url}');
            if (change.url == 'https://lk.mpkvc.ru/#/') {
              showIcon = true;
            } else {
              showIcon = false;
            }
          }),
      )
      ..addJavaScriptChannel(JavaScriptChannelParams(
        name: 'Toaster',
        onMessageReceived: (JavaScriptMessage message) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message.message)),
          );
        },
      ))
      ..setOnPlatformPermissionRequest(
        (PlatformWebViewPermissionRequest request) {
          debugPrint(
            'requesting permissions for ${request.types.map((WebViewPermissionResourceType type) => type.name)}',
          );
          request.grant();
        },
      )
      ..loadRequest(LoadRequestParams(
        uri: Uri.parse('https://lk.mpkvc.ru/'),
      ));
  }

  int selectedMenu = 0;

  Future<void> sendMail(String text, String subject) async {
    String username = 'kvc24062023@gmail.com';
    String password = '!q2w#e4r';
    String to = 'al1707@mail.ru';

    final message = Message()
      ..from = username
      ..recipients.add(to)
      ..text = text
      ..subject = subject;

    try {
//      final smtpServer = gmail(username, password);
      final smtpServer = SmtpServer(
        'smtp.gmail.com',
        username: username,
        password: password,
        ignoreBadCertificate: true,
      );
      final sendReport = await send(message, smtpServer);
      debugPrint('Message sent: $sendReport');
    } on MailerException catch (e) {
      debugPrint('Message not sent.$e');
      for (var p in e.problems) {
        debugPrint('Problem: ${p.code}: ${p.msg}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        bottomNavigationBar: BottomNavigationBar(
          items: [
            const BottomNavigationBarItem(
                icon: Icon(Icons.phone), label: 'Позвонить'),
            BottomNavigationBarItem(
                label: 'Обратный звонок',
                icon: IconButton(
                    onPressed: () {
                      _feedback(context, (String param, String phone, String descr) {
                        sendMail('$param\n$phone\n\n$descr', 'feedback');
                      });
                    },
                    icon: const Icon(Icons.phone_callback)))
          ],
        ),
        body: Stack(
          children: [
            PlatformWebViewWidget(
              PlatformWebViewWidgetCreationParams(controller: _controller),
            ).build(context),
            if (showIcon)
              PopupMenuButton<int>(
                icon: Container(
                    color: const Color(0xFF44AAFF),
                    width: 80,
                    height: 35,
                    child: const Icon(Icons.add, color: Colors.white,)
                ),
                initialValue: selectedMenu,
                  color: const Color(0xFF44AAFF),
                // Callback that sets the selected popup menu item.
                onSelected: (int item) {
                  setState(() {
                    selectedMenu = item;
                    switch (selectedMenu) {
                      case 0:
                        _controller.loadRequest(LoadRequestParams(
                          uri: Uri.parse('https://mpkvc.ru/useragreement/'),
                        ));
                      case 1:
                        _controller.loadRequest(LoadRequestParams(
                          uri: Uri.parse(
                              'https://mpkvc.ru/политика-конфиденциальности/'),
                        ));
                      case 2:
                        {
                          _deleteAccount(context, (String param, String phone) {
                            sendMail('$param\n$phone', 'delete account');
                            deleteAccount = true;
                          });
                          if (deleteAccount) {
                            _thankyou(context);
                            deleteAccount = false;
                          }
                        }
                    }
                  });
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
                  const PopupMenuItem<int>(
                    value: 0,
                    child: Row(
                      children: [
                        Icon(Icons.access_time),
                        SizedBox(
                          width: 10,
                        ),
                        Text('Пользовательское соглашение', style: TextStyle(fontSize: 12, color: Colors.white),),
                      ],
                    ),
                  ),
                  const PopupMenuItem<int>(
                    value: 1,
                    child: Row(
                      children: [
                        Icon(Icons.accessible_sharp),
                        SizedBox(
                          width: 10,
                        ),
                        Text('Политика конфиденциальности', style: TextStyle(fontSize: 12, color: Colors.white),),
                      ],
                    ),
                  ),
                  const PopupMenuItem<int>(
                    value: 2,
                    child: Row(
                      children: [
                        Icon(Icons.delete),
                        SizedBox(
                          width: 10,
                        ),
                        Text('Удалить аккаунт', style: TextStyle(fontSize: 12, color: Colors.white),),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> _feedback(BuildContext context, feedbackCallback onPressed) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      TextEditingController _name = TextEditingController();
      TextEditingController _phone = TextEditingController();
      TextEditingController _descr = TextEditingController();
      return Dialog(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('X Закрыть', style: TextStyle(fontSize: 12, color: Color(0xFF939393),))),
              ),
              const SizedBox(height: 20,),
              const Text(
                'Оставьте ваши контактные данные, и наш оператор свяжется с вами в ближайшее время',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Color(0xFF3076B9),)
              ),
              const SizedBox(height: 20,),
              const Text(
                'Как к Вам обращаться?',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              Container(
                decoration: BoxDecoration(border: Border.all(width: 1)),
                child: TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                      border: InputBorder.none, filled: true),
                ),
              ),
              const SizedBox(height: 20,),
              const Text(
                'Ваш номер телефона',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              Container(
                decoration: BoxDecoration(border: Border.all(width: 1)),
                child: TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        border: InputBorder.none,
                        filled: true)),
              ),
              const SizedBox(height: 20,),
              const Text(
                'Комментарий',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              Container(
                decoration: BoxDecoration(border: Border.all(width: 1)),
                child: TextField(
                    controller: _descr,
                    maxLines: 5,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        border: InputBorder.none,
                        filled: true)),
              ),
              const SizedBox(height: 20,),
              InkWell(
                onTap: () {
                  onPressed(_name.value.text, _phone.value.text, _descr.value.text);
                  Navigator.of(context).pop();
                  },
                child: Container(
                  width: double.infinity,
                  height: 45,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                  ),
                  child: const Center(
                    child: Text(
                      'Отправить',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20,),
              const Text(
                'Нажимая на кнопку “Отправить”, вы соглашаетесь с условиями пользовательского соглашения и политики конфиденциальности',
                textAlign: TextAlign.center,
                maxLines: 5,
                style: TextStyle(fontSize: 12, color: Color(0xFF939393),)
              ),
              const SizedBox(height: 40,),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _deleteAccount(BuildContext context, dialogCallback onPressed) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      TextEditingController _email = TextEditingController();
      TextEditingController _phone = TextEditingController();
      return Dialog(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('X Закрыть', style: TextStyle(fontSize: 12, color: Color(0xFF939393),))),
              ),
              const SizedBox(height: 20,),
              const Text(
                'Внимание! Вы собираетесь удалить аккаунт. Данное действие нельзя будет отменить.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.red,)
              ),
              const SizedBox(height: 20,),
              const Text(
                'Ваш email',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              Container(
                decoration: BoxDecoration(border: Border.all(width: 1)),
                child: TextField(
                    controller: _email,
                    decoration: const InputDecoration(
                        border: InputBorder.none,
                        filled: true)),
              ),
              const SizedBox(height: 20,),
              const Text(
                'Ваш номер телефона',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              Container(
                decoration: BoxDecoration(border: Border.all(width: 1)),
                child: TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        border: InputBorder.none,
                        filled: true)),
              ),
              const SizedBox(height: 20,),
              InkWell(
                onTap: () {
                  onPressed(_email.value.text, _phone.value.text);
                  Navigator.of(context).pop();
                  },
                child: Container(
                  width: double.infinity,
                  height: 45,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                  ),
                  child: const Center(
                    child: Text(
                      'УДАЛИТЬ АККАУНТ',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20,),
              const Text(
                  'Нажимая на кнопку “Отправить”, вы соглашаетесь с условиями пользовательского соглашения и политики конфиденциальности',
                  textAlign: TextAlign.center,
                  maxLines: 5,
                  style: TextStyle(fontSize: 12, color: Color(0xFF939393),)
              ),
              const SizedBox(height: 40,),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _thankyou(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('X Закрыть', style: TextStyle(fontSize: 12, color: Color(0xFF939393),))),
              const SizedBox(
                height: 20,
              ),
              const Text(
                'Спасибо за ваше обращение!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Color(0xFF3076B9),)
              ),
              const SizedBox(
                height: 20,
              ),
              const Text(
                'Мы получили ваш запрос на удаление аккаунта.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Color(0xFF3076B9),)
              ),
              const SizedBox(
                height: 20,
              ),
              const Text(
                'Ваш аккаунт и все связанные с ним данные будут удалены в течение 24 часов.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Color(0xFF3076B9),)
              ),
              const SizedBox(
                height: 20,
              ),
            ],
          ),
        ),
      );
    },
  );
}
