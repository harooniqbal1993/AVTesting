//
//  VideoCapture.swift
//  TestingProject
//
//  Created by iMac on 04/09/2020.
//  Copyright © 2020 iMac. All rights reserved.
//

import UIKit
import AVFoundation
import AssetsLibrary
import CoreMedia
import Photos

class VideoCapture: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    var captureSession: AVCaptureSession!

    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var recordButtton: UIButton!
    @IBOutlet weak var imageView: UIImageView!
    
    var assetWriter: AVAssetWriter?
    var assetWriterPixelBufferInput: AVAssetWriterInputPixelBufferAdaptor?
    var isWriting = false
    var currentSampleTime: CMTime?
    var currentVideoDimensions: CMVideoDimensions?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    var assetWriterAudioInput : AVAssetWriterInput?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        captureSession = AVCaptureSession()
        if AVCaptureDevice.authorizationStatus(for: .video) ==  .authorized {
            //already authorized
            self.setupCaptureSession()
        } else {
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) in
                if granted {
                    //access allowed
                    self.setupCaptureSession()
                } else {
                    //access denied
                    print("access denied")
                }
            })
        }
        
        
    }
    
    func setupCaptureSession() {
//        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSession.Preset.medium
        
        let videoCapture = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)//AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)!
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoCapture!)
            if captureSession?.canAddInput(videoInput) ?? false {
                captureSession?.addInput(videoInput)
            }
        } catch {
            print("Error setting device video input: \(error)")
        }
        
        let microphone = AVCaptureDevice.default(for: .audio)//AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)!
        
        do {
            let micInput = try AVCaptureDeviceInput(device: microphone!)
            if captureSession?.canAddInput(micInput) ?? false {
                captureSession?.addInput(micInput)
            }
        } catch {
            print("Error setting device audio input: \(error)")
        }
        
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
        videoPreviewLayer.videoGravity = .resizeAspectFill
        videoPreviewLayer.connection?.videoOrientation = .portrait
        previewView.layer.addSublayer(videoPreviewLayer)
        
//        captureSession.beginConfiguration()
        
        let q = DispatchQueue.main
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: q)
        captureSession.addOutput(videoOutput)
        
        let audioOutput = AVCaptureAudioDataOutput()
        audioOutput.setSampleBufferDelegate(self, queue: q)
        captureSession.addOutput(audioOutput)
        
//        captureSession.commitConfiguration()
        
        DispatchQueue.global(qos: .userInitiated).async { //[weak self] in
            self.captureSession.startRunning()
            DispatchQueue.main.async {
                self.videoPreviewLayer.frame = self.previewView.bounds
                self.imageView.frame = self.videoPreviewLayer.frame
            }
        }
        
    }

    @IBAction func record(_ sender: UIButton) {
        if isWriting {
            print("stop record")
            self.isWriting = false
            assetWriterPixelBufferInput = nil
            assetWriter?.finishWriting(completionHandler: {[unowned self] () -> Void in
                self.saveMovieToCameraRoll()
            })
        } else {
            print("start record")
            
            
            
            createWriter()
            assetWriter?.startWriting()
            assetWriter?.startSession(atSourceTime: currentSampleTime!)
            isWriting = true
        }
    }
    
    func saveMovieToCameraRoll() {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: self.getFileUrl(index: 1) as URL)
        }) { saved, error in
            if saved {
                print("saved")
            }
        }
    }
    
    func getFileUrl(index: Int) -> URL
    {
        let filename = "myVideoRecording\(index).mp4"
        let filePath = getRecordingsDirectory().appendingPathComponent(filename)
        print("filePath: ",filePath)
        return filePath
    }
    
    func getRecordingsDirectory() -> URL
    {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let DirPath = paths[0].appendingPathComponent("Recordings")
        do
        {
            try FileManager.default.createDirectory(atPath: DirPath.path, withIntermediateDirectories: true, attributes: nil)
        }
        catch let error as NSError
        {
            print("Unable to create directory \(error.debugDescription)")
        }
        print("DirPath: ",DirPath)
        
        return DirPath
    }
    
    func movieURL() -> NSURL {
        let tempDir = NSTemporaryDirectory()
        let url = NSURL(fileURLWithPath: tempDir).appendingPathComponent("tmpMov.mp4")
        return url! as NSURL
    }

    func checkForAndDeleteFile() {
        let fm = FileManager.default
        let url = getFileUrl(index: 1)
        let exist = fm.fileExists(atPath: url.path)

        if exist {
            do {
                try fm.removeItem(at: url as URL)
            } catch let error as NSError {
                print(error.localizedDescription)
            }
        }
    }
    
    func createWriter() {
        self.checkForAndDeleteFile()

        do {
            assetWriter = try AVAssetWriter(outputURL: getFileUrl(index: 1) as URL, fileType: AVFileType.mp4)
        } catch let error as NSError {
            print(error.localizedDescription)
            return
        }

        let videoOutputSettings = [ // video
            AVVideoCodecKey : AVVideoCodecH264,
            AVVideoWidthKey : Int(currentVideoDimensions!.width),
            AVVideoHeightKey : Int(currentVideoDimensions!.height)
        ] as [String : Any]
        
        let audioOutoutSettings = [
        AVFormatIDKey : kAudioFormatMPEG4AAC,
        AVNumberOfChannelsKey : 2,
        AVSampleRateKey : 44100.0,
        AVEncoderBitRateKey: 192000
        ] as [String : Any]

        let assetWriterVideoInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoOutputSettings as? [String : AnyObject])
        assetWriterVideoInput.expectsMediaDataInRealTime = true
//        assetWriterVideoInput.transform = CGAffineTransform(rotationAngle: CGFloat(M_PI / 2.0))
        
        assetWriterAudioInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: audioOutoutSettings as? [String : AnyObject])
        assetWriterAudioInput?.expectsMediaDataInRealTime = true

        let sourcePixelBufferAttributesDictionary = [
            String(kCVPixelBufferPixelFormatTypeKey) : Int(kCVPixelFormatType_32BGRA),
            String(kCVPixelBufferWidthKey) : Int(currentVideoDimensions!.width),
            String(kCVPixelBufferHeightKey) : Int(currentVideoDimensions!.height),
            String(kCVPixelFormatOpenGLESCompatibility) : kCFBooleanTrue
        ] as [String : Any]

        assetWriterPixelBufferInput = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterVideoInput,
                                                                           sourcePixelBufferAttributes: sourcePixelBufferAttributesDictionary)
        
//        assetWriterPixelBufferInput = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterAudioInput, sourcePixelBufferAttributes: <#T##[String : Any]?#>)

        if assetWriter!.canAdd(assetWriterVideoInput) {
            assetWriter!.add(assetWriterVideoInput)
        } else {
            print("no way\(assetWriterVideoInput)")
        }
        
        if (assetWriter?.canAdd(assetWriterAudioInput!))! {
            assetWriter?.add(assetWriterAudioInput!)
        } else {
            print("audio no way\(assetWriterVideoInput)")
        }
    }
}

extension VideoCapture {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        print("didOutputSampleBuffer")
        
        autoreleasepool {

//            connection.videoOrientation = .portrait
            
            guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
            let mediaType = CMFormatDescriptionGetMediaType(formatDesc)
            
            if mediaType == kCMMediaType_Audio {
                print("Audio")
                audioSampleUpdated(sampleBuffer: sampleBuffer)
            } else {
                connection.videoOrientation = .portrait
                print("Video")
            }

            // COMMENT: This line makes sense - this is your pixelbuffer from the camera.
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            // COMMENT: OK, so you turn pixelBuffer into a CIImage...
            let cameraImage = CIImage(cvPixelBuffer: pixelBuffer)

            // COMMENT: And now you've create a CIImage with a Filter instruction...
            let filter = CIFilter(name: "CISepiaTone")!
            filter.setValue(cameraImage, forKey: kCIInputImageKey)


            let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)!
            self.currentVideoDimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
            self.currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer)
            
            if self.isWriting {
                if self.assetWriterPixelBufferInput?.assetWriterInput.isReadyForMoreMediaData == true {
                    // COMMENT: Here's where it gets weird. You've declared a new, empty pixelBuffer... but you already have one (pixelBuffer) that contains the image you want to write...
                    var newPixelBuffer: CVPixelBuffer? = nil

                    // COMMENT: And you grabbed memory from the pool.
                    CVPixelBufferPoolCreatePixelBuffer(nil, self.assetWriterPixelBufferInput!.pixelBufferPool!, &newPixelBuffer)

                    // COMMENT: And now you wrote an empty pixelBuffer back <-- this is what's causing the black frame.
                    let success = self.assetWriterPixelBufferInput?.append(pixelBuffer, withPresentationTime: self.currentSampleTime!)

                    if success == false {
                        print("Pixel Buffer failed")
                    }
                }
            }
            
            

            // COMMENT: And now you're sending the filtered image back to the screen.
            DispatchQueue.main.async {

                if let outputValue = filter.value(forKey: kCIOutputImageKey) as? CIImage {
                    let filteredImage = UIImage(ciImage: outputValue)
                    self.imageView.image = filteredImage
                    self.previewView.bringSubviewToFront(self.imageView)
                }
            }
        }
    }
    
    func audioSampleUpdated(sampleBuffer: CMSampleBuffer) {
        
//            while !(assetWriterPixelBufferInput?.assetWriterInput.isReadyForMoreMediaData)! {}
//            if assetWriterAudioInput.
//            if (!(assetWriterPixelBufferInput?.assetWriterInput.append(sampleBuffer))!) {
//                print("Unable to write to audio input");
//            }
            
            guard let input = assetWriterAudioInput else { return }
            if input.isReadyForMoreMediaData {
                let success = input.append(sampleBuffer)
                if !success {
                    print("audio sampling went wrong")
//                    DispatchQueue.main.async {
//                        self.delegate?.recorderDidFail(with: RecorderError.couldNotWriteAudioData)
//                    }
//                    abortRecording()
                }
            }
        
    }
    
}
