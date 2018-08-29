# RecogID
**카메라로 주민등록증에 있는 이름, 주민등록번호를 추출하는 앱으로 Tesseract OCR 사용**


# 시작하기
TesseractOCR을 사용하기 위해 프레임워크를 설치합니다. [TesseractOCR](https://github.com/gali8/Tesseract-OCR-iOS/blob/master/README.md)에서 자세한 내용이 있습니다.
```
pod install
```
한국어를 인식하기 위해 [tessdata](https://github.com/tesseract-ocr/tessdata)가 필요한데 **한국어는 현재 8월 29일기준 TesseractOCR 4.0버전에서 tessdata 3.0.4버전만 지원합니다.**

위 프로젝트에는 tessdata폴더에 kor.traineddata가 있습니다.

**RecogID.xcworkspace** 파일이 생겼다면 프로젝트를 엽니다. Pods 프로젝트 **TesseractOCRiOS** 타겟에 **BuildSetting/Build Option/Enable Bircode** 를 **NO** 로 변경합니다. 이 과정을 RecogID 프로젝트 RecogID 타겟에도 똑같이 적용합니다.

그리고 빌드하시면 됩니다.

# 소스 수정하기
```swift
func captureOutput(_ output: AVCaptureOutput, 
                   didOutput sampleBuffer: CMSampleBuffer, 
                   from connection: AVCaptureConnection) {
  ...
  
  if let imageBuf: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
    let ciImage: CIImage = CIImage(cvImageBuffer: imageBuf)
            
        if let images = self.DetectCard(image: ciImage), images.count == 2 {
            self.tesseract.image = images[1].g8_blackAndWhite()!
            self.tesseract.recognize()
            let text = self.tesseract.recognizedText!.GetLines()

            if text.count >= 2 {
                if let name = text[0].GetName(), let id = text[1].GetId() {
                    print("\(name)  \(id)")
                }
            }
            
            // TODO:
            
            G8Tesseract.clearCache()
        }
    }
  }
}
```
위 TODO 부분에서 추가로 작업하시면 됩니다.

```swift
func DetectCard(image: CIImage) -> [UIImage]?
```
해당 함수에서 이미지에 사각형을 탐지하여 이미지를 자른 후 탐지한 사각형을 직각사각형으로 변환한 합니다.

이름 주민등록번호가 기재된 이미지를 자른 후 TesseratOCR로 문자를 추출합니다.
