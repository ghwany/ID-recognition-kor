//
//  ViewController.swift
//  TesseractOCR
//
//  Created by jwan on 2018. 8. 29..
//  Copyright © 2018년 jwan. All rights reserved.
//

import UIKit
import AVKit
import TesseractOCR
import AVFoundation


extension String {
    func RegExp(filter:String) -> Bool {
        let regex = try! NSRegularExpression(pattern: filter, options: [])
        let list = regex.matches(in:self, options: [], range:NSRange.init(location: 0, length:self.count))
        return (list.count >= 1)
    }
    
    func Replace(of: String, with: String) -> String {
        return self.replacingOccurrences(of: of, with: with, options: NSString.CompareOptions.literal, range: nil)
    }
    
    func IsRightId() -> Bool {
        if !self.RegExp(filter: "^(?:[0-9]{2}(?:0[1-9]|1[0-2])(?:0[1-9]|[1,2][0-9]|3[0,1]))-?([1-4][0-9]{6})$") {
            return false
        }
        
        let arrCode:Array<Int> = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
        var nId:Int = (Int)(self.Replace(of: "-", with: ""))!
        
        let nLastCode = nId % 10
        var nSum = 0;
        
        for code in arrCode {
            nId /= 10
            nSum += code * (nId % 10)
        }
        
        return ((11 - (nSum % 11)) % 10 == nLastCode)
    }
    
    func GetLines () -> Array<String> {
        let stringRet = self.replacingOccurrences(of: " ", with: "", options: NSString.CompareOptions.literal, range: nil)
            .replacingOccurrences(of: "\n\n", with: "\n", options: NSString.CompareOptions.literal, range: nil)
            .replacingOccurrences(of: "(", with: "", options: NSString.CompareOptions.literal, range: nil)
            .replacingOccurrences(of: ")", with: "", options: NSString.CompareOptions.literal, range: nil)
        let arr = stringRet.split{$0 == "\n"}.map(String.init)
        
        return arr
    }
    
    func GetName () -> String? {
        if self.RegExp(filter: "^([이은추송주소오류육장석김나진곽백방황강서성명금인전현도조민선국노함양하채변탁고왕공심지엄라위천맹권손배어문신모염길제편옥우한최정구원표반임연홍윤여박유설기남안허마차]{1})([가-힣]{1,})$") {
            return String(self[self.startIndex ..< self.index(self.startIndex, offsetBy: Int(self.count / 2))])
        }
        return nil
    }
    
    func GetId () -> String? {
        var convertId = self
        
        if self.count == 14 {
            convertId = self.Replace(of: String(self[self.index(self.startIndex, offsetBy: 6)]), with: "-")
        } else if self.count == 13 {
            convertId.insert("-", at: self.index(self.startIndex, offsetBy: 6))
        }
        // 올바른 식별번호인지 검사
        if convertId.IsRightId() {
            return convertId
        }
        
        return nil
    }
}


class ViewController: UIViewController,
    AVCaptureVideoDataOutputSampleBufferDelegate, G8TesseractDelegate {

    @IBOutlet weak var imageView: UIImageView!
    
    var tesseract: G8Tesseract = G8Tesseract(language: "kor")
    var beforeSeconds: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.tesseract.delegate = self
        self.tesseract.maximumRecognitionTime = 0.45
        
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo
        
        guard let captureDevice = AVCaptureDevice.default(for: .video) else { return }
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        captureSession.addInput(input)
        captureSession.startRunning()
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        view.layer.addSublayer(previewLayer)
        previewLayer.frame = view.frame
    
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        captureSession.addOutput(dataOutput)
        
        imageView.layer.zPosition = .greatestFiniteMagnitude
    }

    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        let seconds = Int(CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds * 10)
        
        if seconds % 5 != 0 || beforeSeconds == seconds {
            return
        } else {
            beforeSeconds = seconds
        }
        if connection.videoOrientation != .portrait {
            connection.videoOrientation = .portrait
            return
        }
        
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
                
                G8Tesseract.clearCache()
            }
        }
    }
    
    
    private func DetectCard(image: CIImage) -> [UIImage]? {
        let detectorRectangle = CIDetector(ofType: CIDetectorTypeRectangle, context: nil,
                                           options: [CIDetectorAccuracy: CIDetectorAccuracyHigh,
                                                     CIDetectorAspectRatio: 8560 / 5398])
        let featuresRectangle = detectorRectangle?.features(in: image)
        
        for feature in featuresRectangle as! [CIRectangleFeature] {
            let perspectiveCorrection = CIFilter(name: "CIPerspectiveCorrection")
            
            perspectiveCorrection?.setValue(image, forKey: "inputImage")
            perspectiveCorrection?.setValue(CIVector(cgPoint: feature.topLeft), forKey: "inputTopLeft")
            perspectiveCorrection?.setValue(CIVector(cgPoint: feature.topRight), forKey: "inputTopRight")
            perspectiveCorrection?.setValue(CIVector(cgPoint: feature.bottomLeft), forKey: "inputBottomLeft")
            perspectiveCorrection?.setValue(CIVector(cgPoint: feature.bottomRight), forKey: "inputBottomRight")
            
            if let outputImage = perspectiveCorrection?.outputImage {
                let y    = outputImage.extent.size.height / 4.75
                let rect = CGRect(x: outputImage.extent.size.width / 12, y: y,
                                  width: outputImage.extent.size.width / 2,
                                  height: outputImage.extent.size.height / 2 - y)
                let context  = CIContext(options: nil)
                let cgImage  = context.createCGImage(outputImage, from: outputImage.extent)
                let cutImage = UIImage(cgImage: cgImage!.cropping(to: rect)!)
                let originalImage = UIImage(cgImage: cgImage!)
                return [originalImage, cutImage]
            }
        }
        
        return nil
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

