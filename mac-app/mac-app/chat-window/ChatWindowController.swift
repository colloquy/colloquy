//
//  ChatWindowController.swift
//  mac-app
//
//  Created by Alexander Kempgen on 2016-01-27.
//  Copyright © 2016 Colloquy Project. All rights reserved.
//

import Cocoa

class ChatWindowController: NSWindowController
{
    let splitViewController = NSSplitViewController()
    
    let chatlistViewController = ChatListViewController()
    let chatViewController = ChatViewController()
    let userListViewController = UserListViewController()
    
    
    override func windowWillLoad()
    {
        // Set up split view interface of window content.
        let sourelistViewControllerItem = NSSplitViewItem(sidebarWithViewController: chatlistViewController)
        let chatViewControllerItem = NSSplitViewItem(viewController: chatViewController)
        let userListViewControllerItem = NSSplitViewItem(contentListWithViewController: userListViewController)
        
        splitViewController.addSplitViewItem(sourelistViewControllerItem)
        splitViewController.addSplitViewItem(chatViewControllerItem)
        splitViewController.addSplitViewItem(userListViewControllerItem)
        contentViewController = splitViewController
    }
    
    override func windowDidLoad()
    {
        super.windowDidLoad()
        window?.titleVisibility = .Hidden
    }
}
