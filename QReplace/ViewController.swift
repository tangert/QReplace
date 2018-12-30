//
//  ViewController.swift
//  QReplace
//
//  Created by Tyler Angert on 12/30/18.
//  Copyright © 2018 Tyler Angert. All rights reserved.
//

import UIKit
import AVKit

class ViewController: UIViewController {
    
    // MARK: Global vars
    let labelOpacity: CGFloat = 0.5
    let urlStrings = ["http", "https", ":", "/"] // replace in the scanned value
    let defaults = UserDefaults.standard
    let supportedCodeTypes = [AVMetadataObject.ObjectType.upce,
                              AVMetadataObject.ObjectType.code39,
                              AVMetadataObject.ObjectType.code39Mod43,
                              AVMetadataObject.ObjectType.code93,
                              AVMetadataObject.ObjectType.code128,
                              AVMetadataObject.ObjectType.ean8,
                              AVMetadataObject.ObjectType.ean13,
                              AVMetadataObject.ObjectType.aztec,
                              AVMetadataObject.ObjectType.pdf417,
                              AVMetadataObject.ObjectType.itf14,
                              AVMetadataObject.ObjectType.dataMatrix,
                              AVMetadataObject.ObjectType.interleaved2of5,
                              AVMetadataObject.ObjectType.qr]
    
    var captureSession = AVCaptureSession()
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var qrCodeFrameView: UIView?
    
    // MARK: IBOutlets
    @IBOutlet weak var urlEntryField: UITextField! {
        didSet {
            
            urlEntryField.backgroundColor = UIColor.white.withAlphaComponent(labelOpacity)
            urlEntryField.textColor = UIColor.white
            urlEntryField.delegate = self
        }
    }
    
    @IBOutlet var messageLabel:UILabel! {
        didSet {
            messageLabel.layer.cornerRadius = 5
            messageLabel.backgroundColor = UIColor.white.withAlphaComponent(labelOpacity)
            messageLabel.textColor = UIColor.white
            messageLabel.clipsToBounds = true
        }
    }
    @IBOutlet weak var urlEntryDescriptionLabel: UILabel! {
        didSet {
            urlEntryDescriptionLabel.textColor = UIColor.white
        }
    }
    
    @IBOutlet weak var baseURLLabel: UILabel! {
        didSet {
            baseURLLabel.textColor = UIColor.white
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    func setupCamera(){
        let status = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        switch (status) {
        case .authorized:
            self.camApproved()
            
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: AVMediaType.video) { (granted) in
                if (granted) {
                    self.camApproved()
                } else {
                    self.camDenied()
                }
            }
            
        case .denied:
            self.camDenied()
            
        case .restricted:
            let alert = UIAlertController(title: "Restricted",
                                          message: "You've been restricted from using the camera on this device. Without camera access this feature won't work. Please contact the device owner so they can give you access.",
                                          preferredStyle: .alert)
            
            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            var cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)

            alert.addAction(okAction)
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                if let popoverController = alert.popoverPresentationController {
                    alert.addAction(cancelAction)
                    popoverController.sourceView = self.view
                    popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                    popoverController.permittedArrowDirections = []
                }
            }
            
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func camApproved() {
        // Get the back-facing camera for capturing videos
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInWideAngleCamera], mediaType: AVMediaType.video, position: .back)
        
        guard let captureDevice = deviceDiscoverySession.devices.first else {
            print("Failed to get the camera device")
            return
        }
        
        do {
            // Get an instance of the AVCaptureDeviceInput class using the previous device object.
            let input = try AVCaptureDeviceInput(device: captureDevice)
            
            // Set the input device on the capture session.
            captureSession.addInput(input)
            
            // Initialize a AVCaptureMetadataOutput object and set it as the output device to the capture session.
            let captureMetadataOutput = AVCaptureMetadataOutput()
            captureSession.addOutput(captureMetadataOutput)
            
            // Set delegate and use the default dispatch queue to execute the call back
            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            captureMetadataOutput.metadataObjectTypes = supportedCodeTypes
        } catch {
            // If any error occurs, simply print it out and don't continue any more.
            print(error)
            return
        }
        
        // Initialize the video preview layer and add it as a sublayer to the viewPreview view's layer.
        DispatchQueue.main.async {
            self.videoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
            self.videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
            self.videoPreviewLayer?.frame = self.view.layer.bounds
            self.view.layer.addSublayer(self.videoPreviewLayer!)
            
            // Start video capture.
            self.captureSession.startRunning()
            
            // Move the labels to the front
            self.view.bringSubviewToFront(self.messageLabel)
            self.view.bringSubviewToFront(self.urlEntryField)
            self.view.bringSubviewToFront(self.baseURLLabel)
            self.view.bringSubviewToFront(self.urlEntryDescriptionLabel)
            
            // Initialize QR Code Frame to highlight the QR code
            self.qrCodeFrameView = UIView()
            if let qrCodeFrameView = self.qrCodeFrameView {
                qrCodeFrameView.layer.borderColor = UIColor.green.cgColor
                qrCodeFrameView.layer.borderWidth = 2
                self.view.addSubview(qrCodeFrameView)
                self.view.bringSubviewToFront(qrCodeFrameView)
            }
            
            if let urlText = self.defaults.object(forKey: "QReplaceURLText") {
                self.urlEntryField.text = (urlText as! String)
            }
        }
    }
    
    func camDenied() {
        DispatchQueue.main.async {
            var alertText = "It looks like your privacy settings are preventing us from accessing your camera to do barcode scanning. You can fix this by doing the following:\n\n1. Close this app.\n\n2. Open the Settings app.\n\n3. Scroll to the bottom and select this app in the list.\n\n4. Turn the Camera on.\n\n5. Open this app and try again."
            
            var goAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            var cancelAction = UIAlertAction(title: "cancel", style: .cancel, handler: nil)
            
            if UIApplication.shared.canOpenURL(URL(string: UIApplication.openSettingsURLString)!) {
                alertText = "It looks like your privacy settings are preventing us from accessing your camera to do barcode scanning. You can fix this by doing the following:\n\n1. Touch the Go button below to open the Settings app.\n\n2. Turn the Camera on.\n\n3. Open this app and try again."
                
                goAction = UIAlertAction(title: "Go", style: .default, handler: {(alert: UIAlertAction!) -> Void in
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
                })
            }
            
            let alert = UIAlertController(title: "Error", message: alertText, preferredStyle: .alert)
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                if let popoverController = alert.popoverPresentationController {
                    alert.addAction(cancelAction)
                    popoverController.sourceView = self.view
                    popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                    popoverController.permittedArrowDirections = []
                }
            }
            
            alert.addAction(goAction)
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    
    // MARK: - Helper methods
    func launchApp(ogURL: String, scannedValue: String) {
        
        let decodedURL = ogURL.replacingOccurrences(of: "QRC", with: scannedValue, options: .regularExpression)
        
        if presentedViewController != nil {
            return
        }
        
        let alertPrompt = UIAlertController(title: "",
                                            message: "Base URL: \n\(ogURL)\n\n\n Scanned value: \n\(scannedValue).\n\n\n  Formatted URL: \n\(decodedURL)", preferredStyle: .actionSheet)
        
        let confirmAction = UIAlertAction(title: "Open \(decodedURL)", style: UIAlertAction.Style.default, handler: { (action) -> Void in
            
            if let url = URL(string: decodedURL) {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
        })
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alertPrompt.addAction(confirmAction)
        alertPrompt.addAction(cancelAction)
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            if let popoverController = alertPrompt.popoverPresentationController {
                popoverController.sourceView = self.view
                popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                popoverController.permittedArrowDirections = []
            }
        }
        
        present(alertPrompt, animated: true, completion: nil)
    }


}

extension ViewController: AVCaptureMetadataOutputObjectsDelegate {
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // Check if the metadataObjects array is not nil and it contains at least one object.
        if metadataObjects.count == 0 {
            qrCodeFrameView?.frame = CGRect.zero
            messageLabel.text = "No QR code detected"
            messageLabel.backgroundColor = UIColor.white.withAlphaComponent(labelOpacity)
            return
        }
        
        // Get the metadata object.
        let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
        
        if supportedCodeTypes.contains(metadataObj.type) {
            // If the found metadata is equal to the QR code metadata (or barcode) then update the status label's text and set the bounds
            let barCodeObject = videoPreviewLayer?.transformedMetadataObject(for: metadataObj)
            qrCodeFrameView?.frame = barCodeObject!.bounds
            
            if metadataObj.stringValue != nil {
                messageLabel.text = "Got a QR code!"
                messageLabel.backgroundColor = UIColor.green.withAlphaComponent(labelOpacity)
                guard var scannedValue = metadataObj.stringValue else { print("No URL"); return }
                // replace all instances of any URL related strings/characters
                // This is just in case the scanned value is a URL and not text
                for e in urlStrings {
                    scannedValue = scannedValue.replacingOccurrences(of: e, with: "", options: .regularExpression)
                }
                guard let ogURL = urlEntryField.text else { return }
                launchApp(ogURL: ogURL, scannedValue: scannedValue)
            }
        }
    }
    
}

extension ViewController: UITextFieldDelegate {
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        guard let text = textField.text else { return }
        defaults.set(text, forKey: "QReplaceURLText")
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // gets the whole range
        guard let text = self.urlEntryField.text else { return false }
        defaults.set(text, forKey: "QReplaceURLText")
        return true
    }
}
