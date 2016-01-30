//
//  ApplicationController.swift
//  mac-app
//
//  Created by Alexander Kempgen on 2016-01-24.
//  Copyright © 2016 Colloquy Project. All rights reserved.
//

import Cocoa

@NSApplicationMain
class ApplicationController: NSObject, NSApplicationDelegate
{
    let windowController = ChatWindowController(windowNibName: "ChatWindowController")
  
    func applicationDidFinishLaunching(aNotification: NSNotification)
    {
        // Insert code here to initialize your application
        
        windowController.showWindow(self)
        
        
        
    }

    func applicationWillTerminate(aNotification: NSNotification)
    {
        // Insert code here to tear down your application
    }


}
