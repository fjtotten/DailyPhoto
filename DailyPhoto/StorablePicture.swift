//
//  StorablePicture.swift
//  DailyPhoto
//
//  Created by fjtotten on 12/20/15.
//  Copyright © 2015 fjtotten. All rights reserved.
//

import Foundation

class StorablePicture : NSObject, NSCoding {
    var imageData: NSData!
    var fileName: String!
    var folder: String!
    
    init(imageData: NSData, fileName: String, folder: String) {
        self.imageData = imageData
        self.fileName = fileName
        self.folder = folder
    }
    
    required convenience init(coder decoder: NSCoder) {
        let imageData = decoder.decodeObjectForKey("imageData") as! NSData
        let fileName = decoder.decodeObjectForKey("fileName") as! String
        let folder = decoder.decodeObjectForKey("folder") as! String
        self.init(imageData: imageData, fileName: fileName, folder: folder)
    }
    
    func encodeWithCoder(encoder: NSCoder) {
        //Encode properties, other class variables, etc
        encoder.encodeObject(self.imageData, forKey: "imageData")
        encoder.encodeObject(self.fileName, forKey:"fileName")
        encoder.encodeObject(self.folder, forKey:"folder")
    }
}
