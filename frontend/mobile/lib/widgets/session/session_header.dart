import 'package:flutter/material.dart';
import '../../constants/colors.dart';

class SessionHeader extends StatelessWidget {
  final String title;
  final String date;
  final String duration;
  final String category;
  final bool isAudioPlaying;
  final VoidCallback onPlayAudio;

  const SessionHeader({
    Key? key,
    required this.title,
    required this.date,
    required this.duration,
    required this.category,
    required this.isAudioPlaying,
    required this.onPlayAudio,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0F0F0), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 제목
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(top: 2, bottom: 3),
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Color(0xFF212121),
                      fontSize: 22,
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(height: 4),
                // 날짜 (아이콘 포함)
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      child: Stack(), // 아이콘 자리 (Figma에서는 시계 아이콘)
                    ),
                    SizedBox(width: 6),
                    Text(
                      date,
                      style: TextStyle(
                        color: Color(0xFF757575),
                        fontSize: 14,
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 카테고리 태그
          Container(
            padding: EdgeInsets.only(left: 10),
            child: Container(
              padding: EdgeInsets.only(top: 6, left: 10, right: 10, bottom: 6.50),
              decoration: BoxDecoration(
                color: Color(0xFF3F51B5),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    child: Stack(), // 아이콘 자리 (Figma에서는 특별한 아이콘)
                  ),
                  SizedBox(width: 5),
                  Text(
                    category,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
