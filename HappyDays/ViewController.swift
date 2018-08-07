//
//  ViewController.swift
//  HappyDays
//
//  Created by CURTIS DUNNE on 8/7/18.
//  Copyright © 2018 CURTIS DUNNE. All rights reserved.
//

import UIKit
import AVFoundation
import Photos
import Speech

class ViewController: UIViewController {

    @IBOutlet weak var helpLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func requestPermissions(_ sender: Any) {
        requestPhotoPermissions()
    }
    
    func requestPhotoPermissions() {
        PHPhotoLibrary.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                if authStatus == .authorized {
                    self.requestRecordPermission()
                } else {
                    self.helpLabel.text = "Phot permission was declined; please enable it in Settings then tap Continue again."
                }
            }
        }
    }
    
    func requestRecordPermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { (allowed) in
            DispatchQueue.main.async {
                if allowed {
                    self.requestTranscribePosition()
                } else {
                    self.helpLabel.text = "Recording permission was declined; please enable it in Settings then tap Continue again."
                }
            }
        }
    }
    
    func requestTranscribePosition() {
        SFSpeechRecognizer.requestAuthorization { (authStatus) in
            DispatchQueue.main.async {
                if authStatus == .authorized {
                    self.authorizationComplete()
                } else {
                    self.helpLabel.text = "Transcribing permission was declined; please enable it in Settings then tap Continue again."
                }
            }
        }
    }

    func authorizationComplete() {
        dismiss(animated: true, completion: nil)
    }
    
}

