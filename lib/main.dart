import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

void main() async {
  //QuerySnapshot snapshot = await Firestore.instance.collection("usuarios").getDocuments();
  //print(snapshot.documents);
  runApp(MyApp());
}

final ThemeData KIOSTheme = ThemeData(
    primarySwatch: Colors.orange,
    primaryColor: Colors.grey[100],
    primaryColorBrightness: Brightness.light);

final ThemeData KDefaultTheme =
    ThemeData(primarySwatch: Colors.orange, accentColor: Colors.orange[400]);


final googleSignIn = GoogleSignIn();
final auth = FirebaseAuth.instance;

Future<Null> _ensureLoggedIn() async {
  GoogleSignInAccount user = googleSignIn.currentUser; // verifica se existe algum usuário logado 
  if (user == null) {
   user = await googleSignIn.signInSilently(); // faz a autenticação silenciosa no google
  }
  if (user == null) {
    user = await googleSignIn.signIn(); // mostra uma janela para fazer autenticação com o google
  }
  if (await auth.currentUser() == null) { // Autentica o usuário no firebase
    GoogleSignInAuthentication credentials = await googleSignIn.currentUser.authentication;
    //await auth.signInWithGoogle(idToken: credentials.idToken, accessToken: credentials.accessToken);
    await auth.linkWithGoogleCredential(
    idToken: credentials.idToken, accessToken: credentials.accessToken);
  }
}

_handleSubmit(String text) {
  _ensureLoggedIn();
  _sendMessage(text: text);
}

_sendMessage({String text, String imgUrl}) {
    Firestore.instance.collection("mensagens").add(
      {
        "text": text,
        "imgUrl": imgUrl,
        "senderName": googleSignIn.currentUser.displayName,
        "senderPhotoUrl": googleSignIn.currentUser.photoUrl
      }
    );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Mettricx Chat Online",
      debugShowCheckedModeBanner: false,
      theme: Theme.of(context).platform == TargetPlatform.iOS
          ? KIOSTheme
          : KDefaultTheme,
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      top: false,
      child: Scaffold(
        appBar: AppBar(
          title:
              Text("Mettricx Chat ", style: TextStyle(color: Colors.white)),
          centerTitle: true,
          elevation:
              Theme.of(context).platform == TargetPlatform.iOS ? 0.0 : 4.0,
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              child: StreamBuilder(
                stream: Firestore.instance.collection("mensagens").snapshots(),
                builder: (context, snapshot) {
                  switch (snapshot.connectionState) {
                    case ConnectionState.none:
                    case ConnectionState.waiting:
                      return Center(
                        child: CircularProgressIndicator(),
                      );
                    default:
                      return ListView.builder(
                        reverse: true,
                        itemCount: snapshot.data.documents.length,
                        itemBuilder: (context, index ) {
                          List reverseList = snapshot.data.documents.reversed.toList();
                          return ChatMessage(reverseList[index].data);
                        },
                      );
                  }
                },
              )
            ),
            Divider(height: 1),
            Container(
              decoration: BoxDecoration(color: Theme.of(context).cardColor),
              child: TextComposer(),
            )
          ],
        ),
      ),
    );
  }
}

class TextComposer extends StatefulWidget {
  @override
  _TextComposerState createState() => _TextComposerState();
}

class _TextComposerState extends State<TextComposer> {
  
  final  _textController = TextEditingController();
  bool _isComposing = false;

  void _reset() {
    this._textController.clear();
    setState(() {
     _isComposing = false; 
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).accentColor),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: Theme.of(context).platform == TargetPlatform.iOS
            ? BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200])))
            : null,
        child: Row(
          children: <Widget>[
            /*
            Container(
              child: IconButton(
                icon: Icon(Icons.photo_camera),
                onPressed: () async {
                  await _ensureLoggedIn();
                  File imgFile = await ImagePicker.pickImage(source: ImageSource.camera);
                  if (imgFile == null) return;
                    StorageUploadTask task = FirebaseStorage.instance.ref()
                        .child(googleSignIn.currentUser.id.toString() + DateTime.now().millisecondsSinceEpoch.toString()).putFile(imgFile);
                    StorageTaskSnapshot taskSnapshot = await task.onComplete;
                    String url = await taskSnapshot.ref.getDownloadURL();
                    _sendMessage(imgUrl: url);
                },
              ),
            ),
            */
            Expanded(
              child: TextField(
                controller: _textController,
                onChanged: (text) {
                  setState(() {
                    _isComposing = text.length > 0;
                  });
                },
                decoration:
                    InputDecoration.collapsed(hintText: "Enviar uma mensagem"),
              ),
            ),
            Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: Theme.of(context).platform == TargetPlatform.iOS
                    ? CupertinoButton(
                        child: Text("Enviar"),
                        onPressed: _isComposing ? () { 
                          _handleSubmit(_textController.text); 
                          _reset();
                        } : null,
                      )
                    : IconButton(
                        icon: Icon(Icons.send),
                        onPressed: _isComposing ? () { 
                          _handleSubmit(_textController.text); 
                          _reset();
                          } : null,
                      ))
          ],
        ),
      ),
    );
  }
}


class ChatMessage extends StatelessWidget {

  Map<String, dynamic> data;
  
  ChatMessage(this.data);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(right: 16),
            child:  CircleAvatar(
              backgroundImage: NetworkImage(data["senderPhotoUrl"]),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(data["senderName"], style: Theme.of(context).textTheme.subhead),
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  child: data["imgUrl"] != null ?
                    Image.network(data["imgUrl"], width: 250.0,) :
                      Text(data["text"])
                ),
              ],
            ),
          )

        ],
      ),
    );
  }
}
