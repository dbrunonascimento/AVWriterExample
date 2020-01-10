//
//  CameraViewController.swift
//  AVWriterExample
//
//  Created by Ken Torimaru on 1/8/20.
//  Copyright © 2020 Torimaru & Williamson, LLC. All rights reserved.
// https://stackoverflow.com/questions/51670428/avassetwriter-capturing-video-but-no-audio
//

import UIKit
import AVFoundation
import Photos
import SwiftUI
import Vision

class CameraViewController: UIViewController,
    AVCaptureVideoDataOutputSampleBufferDelegate,
    AVCaptureAudioDataOutputSampleBufferDelegate {
    
    var captureSession: AVCaptureSession = AVCaptureSession()
    var videoDataOutput: AVCaptureVideoDataOutput = AVCaptureVideoDataOutput()
    var audioDataOutput: AVCaptureAudioDataOutput = AVCaptureAudioDataOutput()
    
    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!

    private var sessionQueue: DispatchQueue!
    private var assetWriter: AVAssetWriter!
    private var videoWriterInput: AVAssetWriterInput!
    private var audioWriterInput: AVAssetWriterInput!
    private var assetWriterInputPixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    
    private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera],
           mediaType: .video, position: .unspecified)
    
    private var isRecording = false {
        didSet {
            DispatchQueue.main.async {
                if self.isRecording {
                    self.playButton.setImage(self.stopImage, for: .normal)
                    self.playButton.tintColor = .white
                } else {
                    self.playButton.setImage(self.playImage, for: .normal)
                    self.playButton.tintColor = .red
                }
            }
        }
    }
    private var time: Double = 0
    private var filename: String = ""
    private let videoFileType = AVFileType.m4v

    private let playImage = UIImage(systemName: "play.circle")
    private let stopImage = UIImage(systemName: "stop.circle")
    
    @IBOutlet var previewView: PreviewView!
    @IBOutlet var playButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Setup the video preview
        previewView.session = captureSession
        // Do any additional setup after loading the view.
        setupCamera()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sessionQueue.async {
            self.captureSession.startRunning()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        sessionQueue.async {
                self.captureSession.stopRunning()
        }
        super.viewWillDisappear(animated)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        if let videoPreviewLayerConnection = previewView.videoPreviewLayer.connection {
            let deviceOrientation = UIDevice.current.orientation
            guard let newVideoOrientation = AVCaptureVideoOrientation(rawValue: deviceOrientation.rawValue),
                deviceOrientation.isPortrait || deviceOrientation.isLandscape else {
                    return
            }
            videoPreviewLayerConnection.videoOrientation = newVideoOrientation
            if assetWriter != nil {
                assetWriter = nil
                videoWriterInput = nil
                audioWriterInput = nil
            }
        }
    }
    
    fileprivate func setupCamera() {
        //Set queues
        sessionQueue = DispatchQueue(label: "myqueue", qos: .utility, attributes: .concurrent, autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit, target: DispatchQueue.global())

        //The size of output video will be 720x1280
        print("Established AVCaptureSession")
        captureSession.sessionPreset = AVCaptureSession.Preset.high

        //Setup your camera
        //Detect which type of camera should be used via `isUsingFrontFacingCamera`
        let videoDevice: AVCaptureDevice
        videoDevice = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: AVMediaType.video, position: AVCaptureDevice.Position.front)!
        print("Created AVCaptureDeviceInput: video")

        //Setup your microphone
        var audioDevice: AVCaptureDevice
        //audioDevice = AVCaptureDevice.default(for: AVMediaType.audio)!
        audioDevice = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInMicrophone, for: AVMediaType.audio, position: AVCaptureDevice.Position.unspecified)!
        print("Created AVCaptureDeviceInput: audio")

        do {
            captureSession.beginConfiguration()
            captureSession.automaticallyConfiguresApplicationAudioSession = false
            captureSession.usesApplicationAudioSession = true

            // Add camera to your session
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
                print("Added AVCaptureDeviceInput: video")
                self.videoDeviceInput = videoInput
                
                DispatchQueue.main.async {
                    /*
                     Dispatch video streaming to the main queue because AVCaptureVideoPreviewLayer is the backing layer for PreviewView.
                     You can manipulate UIView only on the main thread.
                     Note: As an exception to the above rule, it's not necessary to serialize video orientation changes
                     on the AVCaptureVideoPreviewLayer’s connection with other session manipulation.
                     
                     Use the window scene's orientation as the initial video orientation. Subsequent orientation changes are
                     handled by CameraViewController.viewWillTransition(to:with:).
                     */
                    var initialVideoOrientation: AVCaptureVideoOrientation = .portrait
                    let deviceOrientation = UIDevice.current.orientation
                    if deviceOrientation != .unknown {
                        if let videoOrientation = AVCaptureVideoOrientation(rawValue: deviceOrientation.rawValue) {
                            initialVideoOrientation = videoOrientation
                        }
                    }

                    self.previewView.videoPreviewLayer.connection?.videoOrientation = initialVideoOrientation
                    print("Initial Orientation Set")
                }
            } else {
                print("Could not add VIDEO!!!")
            }

            // Add microphone to your session
            let audioInput = try AVCaptureDeviceInput(device: audioDevice)
            if captureSession.canAddInput(audioInput) {
                captureSession.addInput(audioInput)
                print("Added AVCaptureDeviceInput: audio")
            } else {
                print("Could not add MIC!!!")
            }


            //Define your video output
            let videoSettings = videoDataOutput.recommendedVideoSettingsForAssetWriter(writingTo: videoFileType )
            videoDataOutput.videoSettings = videoSettings
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            if captureSession.canAddOutput(videoDataOutput) {
                videoDataOutput.setSampleBufferDelegate(self, queue: sessionQueue)
                captureSession.addOutput(videoDataOutput)
                print("Added AVCaptureDataOutput: video")
            }


            //Define your audio output
            if captureSession.canAddOutput(audioDataOutput) {
                audioDataOutput.setSampleBufferDelegate(self, queue: sessionQueue)
                captureSession.addOutput(audioDataOutput)
                print("Added AVCaptureDataOutput: audio")
            }

            //Set up the AVAssetWriter (to write to file)
            setupAssetWriter()

            previewView.videoPreviewLayer.position = CGPoint.init(x: CGFloat(self.view.frame.width/2), y: CGFloat(self.view.frame.height/2))
            previewView.videoPreviewLayer.bounds = self.view.bounds
            previewView.videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
            print("Created AVCaptureVideoPreviewLayer")

            //Don't forget start running your session
            //this doesn't mean start record!
            captureSession.commitConfiguration()
            captureSession.startRunning()
        }
        catch let error {
            debugPrint(error.localizedDescription)
        }
    }
    
    private func setupAssetWriter(){
        do {
            assetWriter = try AVAssetWriter(outputURL: getURL()!, fileType: videoFileType)
            print("Setup AVAssetWriter")

            //Video Settings
            let videoSettings = videoDataOutput.recommendedVideoSettingsForAssetWriter(writingTo: videoFileType )
            videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
            videoWriterInput?.expectsMediaDataInRealTime = true;
            
            //Orientation
            let orientation = exifOrientationForDeviceOrientation(UIDevice.current.orientation)
            let position = videoDeviceInput.device.position
            switch orientation {
            case .leftMirrored:
                videoWriterInput?.transform = CGAffineTransform(rotationAngle: .pi/2)
            case .rightMirrored:
                videoWriterInput?.transform = CGAffineTransform(rotationAngle: 270 * .pi/180)
            case .upMirrored, .up:
                if position == .back {
                    videoWriterInput?.transform = CGAffineTransform(rotationAngle: .pi)
                }
            case .downMirrored, .down:
                if position == .front {
                    videoWriterInput?.transform = CGAffineTransform(rotationAngle: .pi)
                }
            case .left:
                videoWriterInput?.transform = CGAffineTransform(rotationAngle: 270 * .pi/180)
            case .right:
                videoWriterInput?.transform = CGAffineTransform(rotationAngle: .pi/2)
            }
            
            print("Setup AVAssetWriterInput: Video")
            if (assetWriter?.canAdd(videoWriterInput!))!
            {
                assetWriter?.add(videoWriterInput!)
                print("Added AVAssetWriterInput: Video")
            } else{
                print("Could not add VideoWriterInput to VideoWriter")
            }

            // Add the audio input
            //Audio Settings
            let audioSettings = audioDataOutput.recommendedAudioSettingsForAssetWriter(writingTo: videoFileType)
            audioWriterInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: audioSettings as? [String : Any])
            audioWriterInput?.expectsMediaDataInRealTime = true;
            print("Setup AVAssetWriterInput: Audio")
            if (assetWriter?.canAdd(audioWriterInput!))!
            {
                assetWriter?.add(audioWriterInput!)
                print("Added AVAssetWriterInput: Audio")
            } else{
                print("Could not add AudioWriterInput to VideoWriter")
            }
        }
        catch {
            print("ERROR")
            return
        }
        
        //PixelWriter
        assetWriterInputPixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput!, sourcePixelBufferAttributes: nil)
        print("Created AVAssetWriterInputPixelBufferAdaptor")
    }
    
    func getURL() -> URL? {
        self.filename = UUID().uuidString
        let videoPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("\(self.filename).mov")
        return videoPath
    }
    
    @IBAction func playButtonAction(sender: UIButton) {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func startRecording() {
        print("Begin Recording... \(assetWriter.debugDescription)")
        if assetWriter == nil {
            setupAssetWriter()
        }
        let recordingClock = self.captureSession.masterClock
        isRecording = true
        assetWriter?.startWriting()
        assetWriter?.startSession(atSourceTime: CMClockGetTime(recordingClock!))
    }
    
    func stopRecording() {
        if (assetWriter?.status.rawValue == 1) {
            videoWriterInput?.markAsFinished()
            audioWriterInput?.markAsFinished()
            print("video finished")
            print("audio finished")
            
            self.assetWriter?.finishWriting(){
                self.isRecording = false
                print("finished writing")
                DispatchQueue.main.async{
                    if self.assetWriter?.status == AVAssetWriter.Status.failed {
                        print("status: failed")
                    }else if self.assetWriter?.status == AVAssetWriter.Status.completed{
                        print("status: completed")
                        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("\(self.filename).mov")
                        self.fileToPhotos(outputFileURL: url)
                    } else if self.assetWriter?.status == AVAssetWriter.Status.cancelled{
                        print("status: cancelled")
                    } else {
                        print("status: unknown")
                    }
                    if let e = self.assetWriter?.error{
                        print("stop record error:", e)
                    }
                    self.assetWriter = nil
                    self.videoWriterInput = nil
                    self.audioWriterInput = nil
                }
            }
        } else {
            print("not writing")
            self.isRecording = false
            self.assetWriter = nil
            self.videoWriterInput = nil
            self.audioWriterInput = nil

        }
        print("Stop Recording!")
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if !self.isRecording {
            return
        }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        if let audio = self.audioWriterInput {
            if connection.audioChannels.count > 0 {
                if audio.isReadyForMoreMediaData {
                    sessionQueue!.async() {
                        audio.append(sampleBuffer)
                    }
                    return
                }
            }
        }
        if let camera = self.videoWriterInput, camera.isReadyForMoreMediaData, output == videoDataOutput {
            sessionQueue!.async() {
                let time = CMTime(seconds: timestamp - self.time, preferredTimescale: CMTimeScale(600))
                if self.assetWriter.status == .writing {
                    self.assetWriterInputPixelBufferAdaptor.append(CMSampleBufferGetImageBuffer(sampleBuffer)!, withPresentationTime: time)
                } else {
                    print("\(self.assetWriter.status.rawValue)!!!!!!!!!!!!!!\n")
                    //assetWriter was not ready and would have crashed the app
                    self.stopRecording()
                }
            }
        }
    }
    
    func fileToPhotos ( outputFileURL: URL ) {
        // Note: Because we use a unique file path for each recording, a new recording won't overwrite a recording mid-save.
        func cleanup() {
            let path = outputFileURL.path
            if FileManager.default.fileExists(atPath: path) {
                do {
                    try FileManager.default.removeItem(atPath: path)
                } catch {
                    print("Could not remove file at url: \(outputFileURL)")
                }
            }
        }
        
        // Check the authorization status.
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                // Save the movie file to the photo library and cleanup.
                PHPhotoLibrary.shared().performChanges({
                    let options = PHAssetResourceCreationOptions()
                    options.shouldMoveFile = true
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    creationRequest.addResource(with: .video, fileURL: outputFileURL, options: options)
                }, completionHandler: { success, error in
                    if !success {
                        print("AVCam couldn't save the movie to your photo library: \(String(describing: error))")
                    }
                    cleanup()
                }
                )
            } else {
                cleanup()
            }
        }
    }
    
    func exifOrientationForDeviceOrientation(_ deviceOrientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
        switch videoDeviceInput.device.position {
        case .back:
            switch deviceOrientation {
            case .portraitUpsideDown:
                return .rightMirrored
            case .landscapeLeft:
                return .downMirrored
            case .landscapeRight:
                return .upMirrored
            default:
                return .right
            }
        case .front:
            switch deviceOrientation {
            case .portraitUpsideDown:
                return .rightMirrored
            case .landscapeLeft:
                return .downMirrored
            case .landscapeRight:
                return .upMirrored
            default:
                return .leftMirrored
            }
        case .unspecified:
            return .right
        @unknown default:
            fatalError()
        }
    }
    
    func exifOrientationForCurrentDeviceOrientation() -> CGImagePropertyOrientation {
        return exifOrientationForDeviceOrientation(UIDevice.current.orientation)
    }
    
    /// - Tag: ChangeCamera
    @IBAction private func changeCamera(_ cameraButton: UIButton) {
        sessionQueue.async {
            let currentVideoDevice = self.videoDeviceInput.device
            let currentPosition = currentVideoDevice.position
            
            let preferredPosition: AVCaptureDevice.Position
            let preferredDeviceType: AVCaptureDevice.DeviceType
            
            switch currentPosition {
            case .unspecified, .front:
                preferredPosition = .back
                preferredDeviceType = .builtInDualCamera
                
            case .back:
                preferredPosition = .front
                preferredDeviceType = .builtInTrueDepthCamera
                
            @unknown default:
                print("Unknown capture position. Defaulting to back, dual-camera.")
                preferredPosition = .back
                preferredDeviceType = .builtInDualCamera
            }
            let devices = self.videoDeviceDiscoverySession.devices
            var newVideoDevice: AVCaptureDevice? = nil
            
            // First, seek a device with both the preferred position and device type. Otherwise, seek a device with only the preferred position.
            if let device = devices.first(where: { $0.position == preferredPosition && $0.deviceType == preferredDeviceType }) {
                newVideoDevice = device
            } else if let device = devices.first(where: { $0.position == preferredPosition }) {
                newVideoDevice = device
            }
            
            if let videoDevice = newVideoDevice {
                do {
                    let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
                    
                    self.captureSession.beginConfiguration()
                    
                    // Remove the existing device input first, because AVCaptureSession doesn't support
                    // simultaneous use of the rear and front cameras.
                    self.captureSession.removeInput(self.videoDeviceInput)
                    
                    if self.captureSession.canAddInput(videoDeviceInput) {
                        self.captureSession.addInput(videoDeviceInput)
                        self.videoDeviceInput = videoDeviceInput
                    } else {
                        self.captureSession.addInput(self.videoDeviceInput)
                    }
                    
                    self.captureSession.commitConfiguration()
                } catch {
                    print("Error occurred while creating video device input: \(error)")
                }
            }
        }
    }
}

