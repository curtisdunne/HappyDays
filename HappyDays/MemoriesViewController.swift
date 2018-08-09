//
//  MemoriesViewController.swift
//  HappyDays
//
//  Created by CURTIS DUNNE on 8/7/18.
//  Copyright © 2018 CURTIS DUNNE. All rights reserved.
//

import UIKit
import AVFoundation
import Photos
import Speech
import CoreSpotlight
import MobileCoreServices

class MemoriesViewController: UICollectionViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UICollectionViewDelegateFlowLayout, AVAudioRecorderDelegate, UISearchBarDelegate {
    
    var memories = [URL]()
    var filteredMemories = [URL]()
    var activeMemory: URL!
    
    var audioRecorder: AVAudioRecorder?
    var recordingURL: URL!
    
    var audioPlayer: AVAudioPlayer?
    var searchQuery: CSSearchQuery?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addTapped))
        
        recordingURL = getDocumentsDirectory().appendingPathComponent("recording.m4a")
        
        loadMemories()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        checkPermissions()
    }
    
    @objc func addTapped() {
        let vc = UIImagePickerController()
        vc.modalPresentationStyle = .formSheet
        vc.delegate = self
        navigationController?.present(vc, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        dismiss(animated: true, completion: nil)
        
        if let image = info[UIImagePickerControllerOriginalImage] as? UIImage {
            saveMemory(image: image)
            loadMemories()
        }
    }
    
    func saveMemory(image: UIImage) {
        let memoryName = "memory-\(Date().timeIntervalSince1970)"
        
        let imageName = memoryName + ".jpg"
        let thumbnailName = memoryName + ".thumb"
        
        do {
            let imagePath = getDocumentsDirectory().appendingPathComponent(imageName)
            
            if let jpegData = UIImageJPEGRepresentation(image, 80) {
                try jpegData.write(to: imagePath, options: [.atomicWrite])
            }
            
            if let thumbnail = resize(image: image, to: 200) {
                let imagePath = getDocumentsDirectory().appendingPathComponent(thumbnailName)
                
                if let jpegData = UIImageJPEGRepresentation(thumbnail, 80) {
                    try jpegData.write(to: imagePath, options: [.atomicWrite])
                }
            }
        } catch {
            print("Failed to save image to disk")
        }
    }
    
    func resize(image: UIImage, to width: CGFloat) -> UIImage? {
        let scale = width / image.size.width
        
        let height = image.size.height * scale
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 0)
        
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    func checkPermissions() {
        let photosAuth = PHPhotoLibrary.authorizationStatus() == .authorized
        let recordingAuth = AVAudioSession.sharedInstance().recordPermission() == .granted
        let transcribeAuth = SFSpeechRecognizer.authorizationStatus() == .authorized
        
        let auth = photosAuth && recordingAuth && transcribeAuth
        
        if auth == false {
            if let vc = storyboard?.instantiateViewController(withIdentifier: "FirstRun") {
                navigationController?.present(vc, animated: true, completion: nil)
            }
        }
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDir = paths[0]
        
        return documentsDir
    }
    
    func loadMemories() {
        memories.removeAll()
        
        guard let files = try?
            FileManager.default.contentsOfDirectory(at: getDocumentsDirectory(), includingPropertiesForKeys: nil, options: [])
            else { return }
        
        for file in files {
            let filename = file.lastPathComponent
            
            if filename.hasSuffix(".thumb") {
                let noExtension = filename.replacingOccurrences(of: ".thumb", with: "")
                
                let memoryPath = getDocumentsDirectory().appendingPathComponent(noExtension)
                memories.append(memoryPath)
            }
        }
        filteredMemories = memories
        
        collectionView?.reloadSections(IndexSet(integer: 1))
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: UICollectionViewDelegate methods
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            return 0
        } else {
            return filteredMemories.count
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Memory", for: indexPath) as! MemoryCell
        
        let memory = filteredMemories[indexPath.row]
        let imageName = thumbnailURL(for: memory).path
        let image = UIImage.init(contentsOfFile: imageName)
        
        cell.imageView.image = image
        
        if cell.gestureRecognizers == nil {
            let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(memoryLongPress))
            recognizer.minimumPressDuration = 0.25
            
            cell.addGestureRecognizer(recognizer)
            
            cell.layer.borderColor = UIColor.white.cgColor
            cell.layer.borderWidth = 3
            cell.layer.cornerRadius = 10
        }
        
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let memory = filteredMemories[indexPath.row]
        let fm = FileManager.default
        
        do {
            let audioName = audioURL(for: memory)
            let transcriptionName = transcriptionURL(for: memory)
            
            if fm.fileExists(atPath: audioName.path) {
                audioPlayer = try AVAudioPlayer(contentsOf: audioName)
                audioPlayer?.play()
            }
            
            if fm.fileExists(atPath: transcriptionName.path) {
                let contents = try String(contentsOf: transcriptionName)
                print(contents)
            }
        } catch {
            print("Error loading Audio playback")
        }
    }
    
    @objc func memoryLongPress(sender: UILongPressGestureRecognizer) {
        if sender.state == .began {
            let cell = sender.view as! MemoryCell
            
            if let index = collectionView?.indexPath(for: cell) {
                activeMemory = filteredMemories[index.row]
                recordMemory()
            }
        } else if sender.state == .ended {
            finishRecording(success: true)
        }
    }
    
    // MARK: Search bar methods
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        filteredMemories(text: searchText)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func filteredMemories(text: String) {
        guard text.count > 0 else {
            filteredMemories = memories

            UIView.performWithoutAnimation {
                self.collectionView?.reloadSections(IndexSet(integer: 1))
            }

            return
        }
        
        var allItems = [CSSearchableItem]()
        
        searchQuery?.cancel()
        
        let queryString = "contentDescription == \"*\(text)*\"c"
        
        searchQuery = CSSearchQuery(queryString: queryString, attributes: nil)
        
        searchQuery?.foundItemsHandler = { items in
            allItems.append(contentsOf: items)
        }
        
        searchQuery?.completionHandler = { error in
            DispatchQueue.main.async {
                self.activateFilter(matches: allItems)
            }
        }
        
        searchQuery?.start()
    }
    
    func activateFilter(matches: [CSSearchableItem]) {
        self.filteredMemories = matches.map { item in
            return URL(fileURLWithPath: item.uniqueIdentifier)
        }
        
        UIView.performWithoutAnimation {
            self.collectionView?.reloadSections(IndexSet(integer: 1))
        }
    }
    
    func recordMemory() {
        audioPlayer?.stop()
        
        collectionView?.backgroundColor = UIColor(red: 0.5, green: 0, blue: 0, alpha: 1.0)
        
        let recordingSession = AVAudioSession.sharedInstance()
        
        do {
            try recordingSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with: .defaultToSpeaker)
            
            let settings = [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 44100, AVNumberOfChannelsKey: 2, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue]
            
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
        } catch {
            print("Failed to record: \(error)")
            
            finishRecording(success: false)
        }
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            finishRecording(success: false)
        }
    }
    
    func finishRecording(success: Bool) {
        collectionView?.backgroundColor = UIColor.darkGray
        
        audioRecorder?.stop()
        
        if success {
            do {
                let memoryAudioURL = activeMemory.appendingPathExtension("m4a")
                let fm = FileManager.default
                
                if fm.fileExists(atPath: memoryAudioURL.path) {
                    try fm.removeItem(at: memoryAudioURL)
                }
                
                try fm.moveItem(at: recordingURL, to: memoryAudioURL)
                
                transcribeAudio(memory: activeMemory)
            } catch {
                print("Failure finishing recording: \(error)")
            }
        }
    }
    
    func transcribeAudio(memory: URL) {
        let audio = audioURL(for: memory)
        let transcription = transcriptionURL(for: memory)
        
        let recognizer = SFSpeechRecognizer()
        let request = SFSpeechURLRecognitionRequest(url: audio)
        
        recognizer?.recognitionTask(with: request, resultHandler: { (result, error) in
            guard let result = result else {
                print("There was an error doing the transcription: \(error ?? "transcription Error!" as! Error)")
                return
            }
            
            if result.isFinal {
                let text = result.bestTranscription.formattedString
                
                do {
                    try text.write(to: transcription, atomically: true, encoding: String.Encoding.utf8)
                    
                    self.indexMemory(memory: memory, text: text)
                } catch {
                    print("Failed to save the transcription.")
                }
            }
        })
    }
    
    func indexMemory(memory: URL, text: String) {
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeText as String)
        
        attributeSet.title = "Happy Days Memory"
        attributeSet.contentDescription = text
        attributeSet.thumbnailURL = thumbnailURL(for: memory)
        
        let item = CSSearchableItem(uniqueIdentifier: "\(memory.path)", domainIdentifier: "com.neutrinoSoftwareCompany", attributeSet: attributeSet)
        item.expirationDate = Date.distantFuture
        
        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error = error {
                print("Indexing Error: \(error.localizedDescription)")
            } else {
                print("Search Item successfully indexed: \(text)")
            }
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {

        return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "Header", for: indexPath)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        if section == 1 {
            return CGSize.zero
        } else {
            return CGSize(width: 0, height: 50)
        }
    }
    
    func imageURL(for memory: URL) -> URL {
        return memory.appendingPathExtension("jpg")
    }
    
    func thumbnailURL(for memory: URL) -> URL {
        return memory.appendingPathExtension("thumb")
    }
    
    func audioURL(for memory: URL) -> URL {
        return memory.appendingPathExtension("m4a")
    }
    
    func transcriptionURL(for memory: URL) -> URL {
        return memory.appendingPathExtension("txt")
    }

}
