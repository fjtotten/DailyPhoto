//
//  ViewController.swift
//  DailyPhoto
//
//  Created by fjtotten on 12/17/15.
//  Copyright © 2015 fjtotten. All rights reserved.
//

import UIKit
import MobileCoreServices
import SwiftyDropbox

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextViewDelegate
 {
    @IBOutlet weak var acceptTextButton: UIButton!
    @IBOutlet weak var captionLabel: UILabel!
    @IBOutlet weak var captionText: UITextView!
    @IBOutlet weak var uploadButton: UIButton!
    @IBOutlet weak var takePicture: UIButton!
    @IBOutlet weak var chooseFromCameraRoll: UIButton!
    @IBOutlet weak var imageView: UIImageView!
    var newMedia: Bool?
    let offlineMode = true
    let defaultAlertString = "18:00,20:00,21:00,22:00,22:30,23:00,23:30"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.captionText.delegate = self
        self.captionText.layer.borderWidth = 5.0
        self.captionText.layer.borderColor = UIColor.grayColor().CGColor
        let defaults = NSUserDefaults.standardUserDefaults()
        if let photosToUpload = defaults.arrayForKey("dailyphoto_photos_to_upload") {
            setUploadButtonText(photosToUpload.count)
        } else {
            setUploadButtonText(0)
        }
        showScreen1()
        cancelAllNotifications()
        if !setNotifications(defaults.stringForKey("dailyphoto_alert_times"), doToday: true) {
            cancelAllNotifications()
            print("ERROR: Could not find/use alert times setting")
            setNotifications(defaultAlertString, doToday: true)
        }
        
        if !offlineMode {
            setupDropboxConnection()
        }
    }
    
    func showScreen1() {
        takePicture.alpha = 1
        takePicture.enabled = true
        uploadButton.alpha = 1
        uploadButton.enabled = !uploadButton.titleLabel!.text!.containsString("Upload 0 Saved Images")
        chooseFromCameraRoll.alpha = 1
        chooseFromCameraRoll.enabled = true
        imageView.alpha = 0
        acceptTextButton.alpha = 0
        acceptTextButton.enabled = false
        captionLabel.alpha = 0
        captionText.alpha = 0
        captionText.editable = false
    }
    
    func showScreen2() {
        takePicture.alpha = 0
        takePicture.enabled = false
        uploadButton.alpha = 0
        uploadButton.enabled = false
        chooseFromCameraRoll.alpha = 0
        chooseFromCameraRoll.enabled = false
        imageView.alpha = 1
        acceptTextButton.alpha = 1
        acceptTextButton.enabled = true
        captionLabel.alpha = 1
        captionText.alpha = 1
        captionText.editable = true
    }
    
    func textView(textView: UITextView, shouldChangeTextInRange range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            textView.resignFirstResponder()
            return false
        }
        return true
    }

    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }


    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func useCamera(sender: AnyObject) {
        loadCamera()
    }
    
    func loadCamera() {
        if UIImagePickerController.isSourceTypeAvailable(
            UIImagePickerControllerSourceType.Camera) {
                let imagePicker = UIImagePickerController()
                
                imagePicker.delegate = self
                imagePicker.sourceType =
                    UIImagePickerControllerSourceType.Camera
                imagePicker.mediaTypes = [kUTTypeImage as String]
                imagePicker.allowsEditing = false
                
                self.presentViewController(imagePicker, animated: true,
                    completion: nil )
                newMedia = true
        }
    }
    
    func setupDropboxConnection() {
        if Dropbox.authorizedClient == nil {
            Dropbox.authorizeFromController(self)
        }
        if let client = Dropbox.authorizedClient {
            
            // Get the current user's account info
            client.users.getCurrentAccount().response { response, error in
                print("*** Get current account ***")
                if let account = response {
                    print("Hello \(account.name.givenName)!")
                } else {
                    print(error!)
                }
            }
            
            // List folder
            client.files.listFolder(path: "").response { response, error in
                print("*** List folder ***")
                if let result = response {
                    print("Folder contents:")
                    for entry in result.entries {
                        print(entry.name)
                    }
                } else {
                    print(error!)
                }
            }
        }
    }
    
    func saveImage(image: UIImage) {
        // Compress to NSData and get date formatted for a folder name
        let fileData = UIImageJPEGRepresentation(image, 1)
        let date = NSDate()
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "MMdd"
        let folder = dateFormatter.stringFromDate(date)
        let timeFormatter = NSDateFormatter()
        timeFormatter.dateFormat = "HH-mm-ss"
        let defaults = NSUserDefaults.standardUserDefaults()
        let userName = defaults.stringForKey("dailyphoto_name_setting")
        let fileName = "\(userName)-\(timeFormatter.stringFromDate(date))"
        
        // Check/Update current date setting to see if we've taken a picture yet today
        let dateString = defaults.stringForKey("dailyphoto_date_string")
        var dailyFileCount = 0
        if dateString == nil || dateString != folder {
            defaults.setObject(folder, forKey: "dailyphoto_date_string")
        } else {
            dailyFileCount = defaults.integerForKey("dailyphoto_filecount") + 1
        }
        defaults.setInteger(dailyFileCount, forKey: "dailyphoto_filecount")
        
        // Encode picture with metadata
        let picture = StorablePicture.init(imageData: fileData!, fileName: fileName, folder: folder)
        let encodedPicture = NSKeyedArchiver.archivedDataWithRootObject(picture)
        
        // Get next save count, create full path, write to file
        let nextSaveCount = defaults.integerForKey("dailyphoto_next_save_count")
        var photosToUpload = defaults.arrayForKey("dailyphoto_photos_to_upload") as? [Int]
        if photosToUpload == nil {
            photosToUpload = [Int]()
        }
        defaults.setInteger(nextSaveCount+1, forKey: "dailyphoto_next_save_count")
        var newPhotosToUpload = photosToUpload!
        newPhotosToUpload.append(nextSaveCount)
        
        let relativePath = "/image_\(nextSaveCount).jpg"
        let path = self.documentsPathForFileName(relativePath)
        print("*** full path = \(path) ***")
        encodedPicture.writeToFile(path, atomically: true)
        defaults.setObject(newPhotosToUpload, forKey: "dailyphoto_photos_to_upload")

        defaults.synchronize()
        setUploadButtonText(newPhotosToUpload.count)
    }
    
    func documentsPathForFileName(name: String) -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true);
        let path = paths[0] as String;
        let fullPath = path.stringByAppendingString(name)
        
        return fullPath
    }
    
    func setUploadButtonText(num: Int) {
        uploadButton.setTitle("Upload \(num) Saved Images", forState: UIControlState.Normal)
        if(num == 0) {
            uploadButton.enabled = false
        }
    }
    
    @IBAction func acceptAndWriteCaption(sender: AnyObject) {
        let defaults = NSUserDefaults.standardUserDefaults()
        let nextSaveCount = defaults.integerForKey("dailyphoto_next_save_count") - 1
        if nextSaveCount >= 0 {
            defaults.setObject(captionText.text, forKey: "dailyphoto_caption_for_save_\(nextSaveCount)")
            defaults.synchronize()
        }
        captionText.text = ""
        showScreen1()
    }
    
    @IBAction func uploadImages() {
        let defaults = NSUserDefaults.standardUserDefaults()
        let photosToUpload = defaults.arrayForKey("dailyphoto_photos_to_upload") as? [Int]
        if photosToUpload == nil {
            return
        }
        for var i in photosToUpload! {
            let oldFullPath = self.documentsPathForFileName("/image_\(i).jpg")
            print("*** found element \(i) ***")
            print("*** full path = \(oldFullPath) ***")
            let encodedPic = NSData(contentsOfFile: oldFullPath)
            if encodedPic == nil {
                print("encoded pic is nil, skipping")
                continue
            }
            let decoded = NSKeyedUnarchiver.unarchiveObjectWithData(encodedPic!) as? StorablePicture
            if decoded == nil {
                print("decoded is nil, skipping")
                continue
            }
            let caption = defaults.stringForKey("dailyphoto_caption_for_save_\(i)") as String!
            if (offlineMode) {
                print("Decoded folder = \(decoded!.folder)")
                print("Decoded filename = \(decoded!.fileName)")
                if caption == nil {
                    print("caption is nil, caption upload would be skipped")
                } else {
                    print("Caption = \(caption)")
                }
            } else {
                if let client = Dropbox.authorizedClient {
                    let imagePath = "/\(decoded!.folder)/\(decoded!.fileName).jpg"
                    upload(decoded!.imageData, path: imagePath, client: client, deleteOnSuccess:i)
                    if caption == nil {
                        print("caption is nil, skipping caption upload")
                    } else {
                        let captionPath = "/\(decoded!.folder)/\(decoded!.fileName).txt"
                        let captionData = caption!.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
                        upload(captionData!, path: captionPath, client: client, deleteOnSuccess:-1)
                        defaults.removeObjectForKey("dailyphoto_caption_for_save_\(i)")
                        defaults.synchronize()
                    }
                } else {
                    print("Client not authorized. Cannot upload images")
                }
            }
        }
        defaults.synchronize()
    }
    
    func upload(data: NSData, path: String, client: DropboxClient, deleteOnSuccess: Int) {
        client.files.upload(path: path, body: data).response { response, error in
            if let metadata = response {
                print("*** Upload file ****")
                print("Uploaded file name: \(metadata.name)")
                print("Uploaded file revision: \(metadata.rev)")
                if deleteOnSuccess >= 0 {
                    do {
                        let defaults = NSUserDefaults.standardUserDefaults()
                        let photosToUpload = defaults.arrayForKey("dailyphoto_photos_to_upload") as? [Int]
                        if photosToUpload != nil {
                            var newPhotosToUpload = photosToUpload!
                            let toRemove = newPhotosToUpload.indexOf(deleteOnSuccess)
                            if toRemove != nil {
                                newPhotosToUpload.removeAtIndex(toRemove!)
                                defaults.setObject(newPhotosToUpload, forKey: "dailyphoto_photos_to_upload")
                                defaults.synchronize()
                                self.setUploadButtonText(newPhotosToUpload.count)
                            }
                        }
                        try NSFileManager.defaultManager().removeItemAtPath(self.documentsPathForFileName("/image_\(deleteOnSuccess).jpg"))
                    } catch {
                        print("Could not delete file at \(path)")
                    }
                }
                
                // Get file (or folder) metadata
                client.files.getMetadata(path: path).response { response, error in
                    print("*** Get file metadata ***")
                    if let metadata = response {
                        if let file = metadata as? Files.FileMetadata {
                            print("This is a file with path: \(file.pathLower)")
                            print("File size: \(file.size)")
                        } else if let folder = metadata as? Files.FolderMetadata {
                            print("This is a folder with path: \(folder.pathLower)")
                        }
                    } else {
                        print(error!)
                    }
                }
            } else {
                print(error!)
            }
        }
    }
    
    @IBAction func useCameraRoll(sender: AnyObject) {
        
        if UIImagePickerController.isSourceTypeAvailable(
            UIImagePickerControllerSourceType.SavedPhotosAlbum) {
                let imagePicker = UIImagePickerController()
                
                imagePicker.delegate = self
                imagePicker.sourceType =
                    UIImagePickerControllerSourceType.PhotoLibrary
                imagePicker.mediaTypes = [kUTTypeImage as String]
                imagePicker.allowsEditing = false
                self.presentViewController(imagePicker, animated: true,
                    completion: nil)
                newMedia = false
        }
    }
    
    func imagePickerController(picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        
        let mediaType = info[UIImagePickerControllerMediaType] as! String
        
        self.dismissViewControllerAnimated(true, completion: nil)
        
        if mediaType == (kUTTypeImage as String) {
            let image = info[UIImagePickerControllerOriginalImage]
                as! UIImage
            
            imageView.image = image
            
            showScreen2()
            if (newMedia == true) {
                UIImageWriteToSavedPhotosAlbum(image, self,
                    "image:didFinishSavingWithError:contextInfo:", nil)
            }
            saveImage(image)
            cancelAllNotifications()
            if !setNotifications(NSUserDefaults.standardUserDefaults().stringForKey("dailyphoto_alert_times"), doToday: false) {
                cancelAllNotifications()
                setNotifications(defaultAlertString, doToday: false)
            }
        } else if mediaType == (kUTTypeMovie as String) {
            // Code to support video here
        }
    }
    
    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }

    
    func image(image: UIImage, didFinishSavingWithError error: NSErrorPointer, contextInfo:UnsafePointer<Void>) {
        
        if error != nil {
            let alert = UIAlertController(title: "Save Failed",
                message: "Failed to save image",
                preferredStyle: UIAlertControllerStyle.Alert)
            
            let cancelAction = UIAlertAction(title: "OK",
                style: .Cancel, handler: nil)
            
            alert.addAction(cancelAction)
            self.presentViewController(alert, animated: true,
                completion: nil)
        }
    }
    
    func cancelAllNotifications() {
        for notification in UIApplication.sharedApplication().scheduledLocalNotifications! {
            UIApplication.sharedApplication().cancelLocalNotification(notification) // cancel old notification
        }
    }
    
    func setNotifications(alertString: String?, doToday: Bool) -> Bool {
        if alertString == nil {
            return false
        }
        let alertTimes = alertString!.componentsSeparatedByString(",")
        if alertTimes.count == 0 {
            return false
        }
        for var alertTime in alertTimes {
            let hourmin = alertTime.componentsSeparatedByString(":")
            if hourmin.count != 2 {
                return false
            }
            let hour = Int(hourmin[0])
            let min = Int(hourmin[1])
            if hour == nil || min == nil {
                return false
            }
            startRepeatingNotificationTomorrow(hour!, min: min!, doToday: doToday)
        }
        return true
    }

    func startRepeatingNotificationTomorrow(hour: Int, min: Int, doToday: Bool) {
        var localNotif = UILocalNotification()
        localNotif.alertBody = "Don't forget to take a picture today!";
        localNotif.alertAction = "DO IT NOW!";
        
        // Set a date of today for the date components
        // start tomorrow if after 3am
        var date: NSDate
        if(!doToday && NSCalendar.autoupdatingCurrentCalendar().components([.Hour], fromDate: NSDate()).hour > 3) {
            date = NSCalendar.autoupdatingCurrentCalendar().dateByAddingUnit([.Day], value: 1, toDate: NSDate(), options: [])!
        } else {
            date = NSDate()
        }
        var dateComponents = NSCalendar.autoupdatingCurrentCalendar().components([.Year, .Month, .Day, .Hour, .Minute, .TimeZone], fromDate: date)
        // Set the date components time to 9pm for notification
        dateComponents.hour = hour;
        dateComponents.minute = min;
        
        // Pass in userInfo dict
        //        self.localnotif.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"mood rating", @"notification", nil];
        
        let fireDate = NSCalendar.autoupdatingCurrentCalendar().dateFromComponents(dateComponents);
        
        // Set fireDate for notification and schedule it
        localNotif.fireDate = fireDate;
        localNotif.timeZone = NSTimeZone.systemTimeZone();
        
        // Make the notification repeat every day
        localNotif.repeatInterval = NSCalendarUnit.Day
        UIApplication.sharedApplication().scheduleLocalNotification(localNotif)
    }

}

