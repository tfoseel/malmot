import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ChatMessage {
  final String speaker; // "나" 또는 "상대방"
  final String text;
  final double yPosition;
  final double xPosition;
  
  ChatMessage({
    required this.speaker,
    required this.text,
    required this.yPosition,
    required this.xPosition,
  });
}

class OcrService {
  final TextRecognizer? _textRecognizer = kIsWeb ? null : TextRecognizer(script: TextRecognitionScript.korean);

  // 기본 텍스트 추출 (기존 기능 유지)
  Future<String> extractText(String imagePath) async {
    // 웹 플랫폼 체크
    if (kIsWeb) {
      throw Exception('웹 브라우저에서는 OCR 기능을 사용할 수 없습니다.\n'
          'Android 또는 iOS 앱을 사용해주세요. 📱');
    }
    
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer!.processImage(inputImage);
      
      String extractedText = '';
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          extractedText += line.text + '\n';
        }
      }
      
      return extractedText.trim();
    } catch (e) {
      throw Exception('OCR 처리 중 오류가 발생했습니다: $e');
    }
  }

  // 대화 형식으로 텍스트 추출 (화자 구분)
  Future<String> extractChatText(String imagePath, {String partnerName = '상대방'}) async {
    // 웹 플랫폼 체크
    if (kIsWeb) {
      throw Exception('웹 브라우저에서는 OCR 기능을 사용할 수 없습니다.\n'
          'Android 또는 iOS 앱을 사용해주세요. 📱\n\n'
          '현재 말못 앱은 모바일 환경에 최적화되어 있습니다.');
    }
    
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer!.processImage(inputImage);
      
      // 디버깅: 인식된 블록 수
      print('📊 OCR 디버깅: 인식된 텍스트 블록 수: ${recognizedText.blocks.length}');
      
      if (recognizedText.blocks.isEmpty) {
        print('⚠️ OCR 경고: 텍스트 블록이 없습니다.');
        return '';
      }

      // 이미지 전체 크기 계산 (바운딩 박스들로부터 추정)
      double maxX = 0;
      double minX = double.infinity;
      
      for (TextBlock block in recognizedText.blocks) {
        if (block.boundingBox.right > maxX) {
          maxX = block.boundingBox.right;
        }
        if (block.boundingBox.left < minX) {
          minX = block.boundingBox.left;
        }
      }
      
      // 화면의 중심점 계산
      final centerX = (maxX + minX) / 2;
      print('📐 화면 중심점: $centerX (왼쪽: $minX, 오른쪽: $maxX)');
      
      // 모든 텍스트 라인을 추출하고 위치 정보와 함께 저장
      List<ChatMessage> messages = [];
      
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          // 바운딩 박스의 중심점 계산
          final lineCenterX = (line.boundingBox.left + line.boundingBox.right) / 2;
          final lineCenterY = (line.boundingBox.top + line.boundingBox.bottom) / 2;
          
          // 중심점 기준으로 왼쪽/오른쪽 판단
          // 왼쪽: 상대방, 오른쪽: 나
          String speaker;
          if (lineCenterX < centerX) {
            speaker = partnerName;
          } else {
            speaker = '나';
          }
          
          // 디버깅: 각 라인 정보 출력
          print('💬 텍스트: "${line.text.trim()}" | 위치 X: $lineCenterX | 화자: $speaker');
          
          messages.add(ChatMessage(
            speaker: speaker,
            text: line.text.trim(),
            yPosition: lineCenterY,
            xPosition: lineCenterX,
          ));
        }
      }
      
      print('✅ 총 ${messages.length}개의 메시지 라인 추출됨');
      
      // Y 위치(위에서 아래)로 정렬
      messages.sort((a, b) => a.yPosition.compareTo(b.yPosition));
      
      // 연속된 같은 화자의 메시지를 그룹화
      List<ChatMessage> groupedMessages = [];
      for (var message in messages) {
        if (groupedMessages.isEmpty) {
          groupedMessages.add(message);
        } else {
          var lastMessage = groupedMessages.last;
          // 같은 화자이고 Y 위치가 가까우면 합치기 (같은 말풍선)
          if (lastMessage.speaker == message.speaker && 
              (message.yPosition - lastMessage.yPosition).abs() < 100) {
            // 기존 메시지에 추가
            groupedMessages[groupedMessages.length - 1] = ChatMessage(
              speaker: lastMessage.speaker,
              text: '${lastMessage.text}\n${message.text}',
              yPosition: lastMessage.yPosition,
              xPosition: lastMessage.xPosition,
            );
          } else {
            groupedMessages.add(message);
          }
        }
      }
      
      // 최종 대화 텍스트 생성
      StringBuffer result = StringBuffer();
      for (var message in groupedMessages) {
        result.writeln('[${message.speaker}] ${message.text}');
      }
      
      final finalResult = result.toString().trim();
      print('📝 최종 추출 결과:\n$finalResult');
      
      return finalResult;
    } catch (e) {
      throw Exception('OCR 처리 중 오류가 발생했습니다: $e');
    }
  }

  void dispose() {
    _textRecognizer?.close();
  }
}
