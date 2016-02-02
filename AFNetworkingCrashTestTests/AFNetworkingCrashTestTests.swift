//
//  AFNetworkingCrashTestTests.swift
//  AFNetworkingCrashTestTests
//
//  Created by Artjoms Haleckis on 02/02/16.
//  Copyright © 2016 Artjoms Haleckis. All rights reserved.
//

import Quick
import Nimble
import Nocilla
import AFNetworking
import FLAnimatedImage

class AFNetworkingCrashTestTests: QuickSpec {

    override func spec() {

        beforeEach {
            LSNocilla.sharedInstance().start()

            let bundle = NSBundle(forClass: AFNetworkingCrashTestTests.self)
            let path = bundle.pathForResource("broken", ofType: "gif")
            let data = NSData(contentsOfFile: path!)

            stubRequest("GET", "http://test.fm/test.gif").withHeaders(["Accept": "image/*"]).andReturn(200).withBody(data)
            let defaultSharedSerializer = UIImageView.sharedImageDownloader().sessionManager.responseSerializer;
            var types = defaultSharedSerializer.acceptableContentTypes
            types?.insert("image/pjpeg")
            types?.insert("image/x-png")
            types?.insert("image/jpg")
            defaultSharedSerializer.acceptableContentTypes = types

            let gifDownloader: AFImageDownloader = AFImageDownloader()
            // First option produces crash
            let compound: AFCompoundResponseSerializer = AFCompoundResponseSerializer.compoundSerializerWithResponseSerializers([FLImageResponseSerializer(), defaultSharedSerializer])
            // It can be fixed by using AlwaysFailingSerializer
            //let compound: AFCompoundResponseSerializer = AFCompoundResponseSerializer.compoundSerializerWithResponseSerializers([FLImageResponseSerializer(), defaultSharedSerializer], AlwaysFailingSerializer())
            gifDownloader.sessionManager.responseSerializer = compound
            FLAnimatedImageView.setSharedImageDownloader(gifDownloader)
        }

        afterEach {
            LSNocilla.sharedInstance().clearStubs()
            LSNocilla.sharedInstance().stop()
        }


        it("should handle bad data correctly") {
            var succeeded: Bool?
            let imageView = FLAnimatedImageView()
            let request = NSMutableURLRequest(URL: NSURL(string: "http://test.fm/test.gif")!)
            request.addValue("image/*", forHTTPHeaderField: "Accept")

            imageView.setImageWithURLRequest(request, placeholderImage: nil, success: { _, _, _ in
                succeeded = true
                }, failure: { _, _, _ in
                succeeded = false
            })

            expect(succeeded).toNotEventually(beNil())
            expect(succeeded).toEventually(beFalsy())
        }
    }
}

class AlwaysFailingSerializer: AFImageResponseSerializer {

    override func responseObjectForResponse(response: NSURLResponse?, data: NSData?, error: NSErrorPointer) -> AnyObject? {
        error.memory = NSError(domain: "test", code: 42, userInfo: [NSLocalizedDescriptionKey: "Serialization failed due to corrupted data"])
        return NSObject()
    }
}

class FLImageResponseSerializer: AFImageResponseSerializer {
    override init() {
        super.init()
        self.acceptableContentTypes = ["image/gif"]
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.acceptableContentTypes = ["image/gif"]
    }

    override func responseObjectForResponse(response: NSURLResponse?, data: NSData?, error: NSErrorPointer) -> AnyObject? {
        do {
            try self.validateResponse(response as? NSHTTPURLResponse, data: data)
            return FLAnimatedImage(animatedGIFData: data)
        } catch let validationError as NSError {
            if error != nil {
                error.memory = validationError
            }
            return nil
        }
    }
}


