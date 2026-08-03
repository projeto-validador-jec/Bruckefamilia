import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

const int zegoAppId = 1607164961;
const String zegoAppSign = "52762dec2c3841f4201e46ef0fd89ed778d765830914e8a08e1d0175489f60a7";

class TelaChamada extends StatelessWidget {
  final String callID;
  final String userID;
  final String userName;
  final bool isVideo;

  const TelaChamada({super.key, required this.callID, required this.userID, required this.userName, required this.isVideo});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ZegoUIKitPrebuiltCall(
        appID: zegoAppId,
        appSign: zegoAppSign,
        userID: userID,
        userName: userName,
        callID: callID,
        config: isVideo ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall() : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall(),
      ),
    );
  }
}
