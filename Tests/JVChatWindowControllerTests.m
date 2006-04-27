#import <Cocoa/Cocoa.h>
#import <SenTestingKit/SenTestingKit.h>
#import <AGRegex/AGRegex.h>

#import "JVChatWindowController.h"
#import "MVChatUser.h"
#import "JVDirectChatPanel.h"

@interface JVTestChatViewController : NSObject <JVChatViewController> {
	JVChatWindowController *_windowController;
	unsigned _newMessages;
}
@end

@implementation JVTestChatViewController
- (MVChatConnection *) connection {
	return nil;
}

- (JVChatWindowController *) windowController {
	return _windowController;
}

- (void) setWindowController:(JVChatWindowController *) controller {
	_windowController = controller;
}

- (NSView *) view {
	return [[[NSView alloc] init] autorelease];
}

- (NSResponder *) firstResponder {
	return [self view];
}

- (NSToolbar *) toolbar {
	return nil;
}

- (NSString *) windowTitle {
	return @"Test";
}

- (NSString *) identifier {
	return @"testView";
}

- (id <JVChatListItem>) parent {
	return nil;
}

- (NSImage *) icon {
	[NSImage imageNamed:@"room"];
}

- (NSString *) title {
	return @"Test";
}

- (unsigned) newMessagesWaiting {
	return _newMessages;
}

- (void) setNewMessagesWaiting:(unsigned) new {
	_newMessages = new;
}
@end

@interface JVChatWindowControllerTests : SenTestCase {
	JVChatWindowController *windowController;
}
@end

@implementation JVChatWindowControllerTests
- (void) setUp {
	windowController = [[JVChatWindowController alloc] init];
	STAssertNotNil( windowController, nil );
}

- (void) tearDown {
	[windowController release];
	windowController = nil;
}

- (void) testAddChatViewController {
	id panel = [[JVTestChatViewController alloc] init];
	STAssertNotNil( panel, nil );

	id panelTwo = [[JVTestChatViewController alloc] init];
	STAssertNotNil( panelTwo, nil );

	// there should no active panel
	STAssertNil( [windowController activeChatViewController], nil );
	STAssertNil( [windowController selectedListItem], nil );

	[windowController showWindow:nil];

	// there should still be no active panel
	STAssertNil( [windowController activeChatViewController], nil );
	STAssertNil( [windowController selectedListItem], nil );

	[windowController addChatViewController:panel];

	// panel should be the active panel
	STAssertTrue( [panel isEqual:[windowController activeChatViewController]], nil );
	STAssertTrue( [panel isEqual:[windowController selectedListItem]], nil );
	STAssertTrue( [[windowController allChatViewControllers] count] == 1, nil );

	[windowController addChatViewController:panelTwo];

	// panel should still be the active panel after adding panelTwo
	STAssertTrue( [panel isEqual:[windowController activeChatViewController]], nil );
	STAssertTrue( [panel isEqual:[windowController selectedListItem]], nil );
	STAssertTrue( [[windowController allChatViewControllers] count] == 2, nil );

	// check duplicate add
	STAssertThrows( [windowController addChatViewController:panelTwo], nil );

	// nothing should have changed
	STAssertTrue( [panel isEqual:[windowController activeChatViewController]], nil );
	STAssertTrue( [panel isEqual:[windowController selectedListItem]], nil );
	STAssertTrue( [[windowController allChatViewControllers] count] == 2, nil );

	// check nil add
	STAssertThrows( [windowController addChatViewController:nil], nil );

	// nothing should have changed
	STAssertTrue( [panel isEqual:[windowController activeChatViewController]], nil );
	STAssertTrue( [panel isEqual:[windowController selectedListItem]], nil );
	STAssertTrue( [[windowController allChatViewControllers] count] == 2, nil );

	[panel release];
	[panelTwo release];
}

- (void) testInsertChatViewController {
	[windowController showWindow:nil];

	id panel = [[JVTestChatViewController alloc] init];
	STAssertNotNil( panel, nil );

	id panelTwo = [[JVTestChatViewController alloc] init];
	STAssertNotNil( panelTwo, nil );

	id panelThree = [[JVTestChatViewController alloc] init];
	STAssertNotNil( panelThree, nil );

	id panelFour = [[JVTestChatViewController alloc] init];
	STAssertNotNil( panelFour, nil );

	[windowController insertChatViewController:panel atIndex:0];

	// panel should be the active panel
	STAssertTrue( [panel isEqual:[windowController activeChatViewController]], nil );
	STAssertTrue( [panel isEqual:[windowController selectedListItem]], nil );
	STAssertTrue( [[windowController allChatViewControllers] count] == 1, nil );

	[windowController insertChatViewController:panelTwo atIndex:1];

	// panel should still be the active panel
	STAssertTrue( [panel isEqual:[windowController activeChatViewController]], nil );
	STAssertTrue( [panel isEqual:[windowController selectedListItem]], nil );
	STAssertTrue( [[windowController allChatViewControllers] count] == 2, nil );

	[windowController insertChatViewController:panelThree atIndex:0];

	// panel should still be the active panel
	STAssertTrue( [panel isEqual:[windowController activeChatViewController]], nil );
	STAssertTrue( [panel isEqual:[windowController selectedListItem]], nil );
	STAssertTrue( [[windowController allChatViewControllers] count] == 3, nil );

	// check index out of bounds
	STAssertThrows( [windowController insertChatViewController:panelFour atIndex:4], nil );

	// nothing should have changed
	STAssertTrue( [panel isEqual:[windowController activeChatViewController]], nil );
	STAssertTrue( [panel isEqual:[windowController selectedListItem]], nil );
	STAssertTrue( [[windowController allChatViewControllers] count] == 3, nil );

	// check duplicate insert
	STAssertThrows( [windowController insertChatViewController:panelThree atIndex:0], nil );

	// nothing should have changed
	STAssertTrue( [panel isEqual:[windowController activeChatViewController]], nil );
	STAssertTrue( [panel isEqual:[windowController selectedListItem]], nil );
	STAssertTrue( [[windowController allChatViewControllers] count] == 3, nil );

	// check nil insert
	STAssertThrows( [windowController insertChatViewController:nil atIndex:0], nil );

	// nothing should have changed
	STAssertTrue( [panel isEqual:[windowController activeChatViewController]], nil );
	STAssertTrue( [panel isEqual:[windowController selectedListItem]], nil );
	STAssertTrue( [[windowController allChatViewControllers] count] == 3, nil );

	[panel release];
	[panelTwo release];
	[panelThree release];
	[panelFour release];
}

- (void) testRemoveChatViewController {
	[windowController showWindow:nil];

	id panel = [[JVTestChatViewController alloc] init];
	STAssertNotNil( panel, nil );

	id panelTwo = [[JVTestChatViewController alloc] init];
	STAssertNotNil( panelTwo, nil );

	id panelThree = [[JVTestChatViewController alloc] init];
	STAssertNotNil( panelThree, nil );

	[windowController insertChatViewController:panel atIndex:0];
	[windowController insertChatViewController:panelTwo atIndex:1];
	[windowController insertChatViewController:panelThree atIndex:2];

	// panel should be the active panel
	STAssertTrue( [panel isEqual:[windowController activeChatViewController]], nil );
	STAssertTrue( [panel isEqual:[windowController selectedListItem]], nil );
	STAssertTrue( [[windowController allChatViewControllers] count] == 3, nil );

	[windowController removeChatViewController:panel];

	// panelTwo should now be the active panel
	STAssertTrue( [panelTwo isEqual:[windowController activeChatViewController]], nil );
	STAssertTrue( [panelTwo isEqual:[windowController selectedListItem]], nil );
	STAssertTrue( [[windowController allChatViewControllers] count] == 2, nil );

	[windowController removeChatViewController:panelThree];

	// panelTwo should still be the active panel
	STAssertTrue( [panelTwo isEqual:[windowController activeChatViewController]], nil );
	STAssertTrue( [panelTwo isEqual:[windowController selectedListItem]], nil );
	STAssertTrue( [[windowController allChatViewControllers] count] == 1, nil );

	// check nil remove
	STAssertThrows( [windowController removeChatViewController:nil], nil );

	// nothing should have changed
	STAssertTrue( [panelTwo isEqual:[windowController activeChatViewController]], nil );
	STAssertTrue( [panelTwo isEqual:[windowController selectedListItem]], nil );
	STAssertTrue( [[windowController allChatViewControllers] count] == 1, nil );

	// check duplicate remove
	STAssertThrows( [windowController removeChatViewController:panelThree], nil );

	// nothing should have changed
	STAssertTrue( [panelTwo isEqual:[windowController activeChatViewController]], nil );
	STAssertTrue( [panelTwo isEqual:[windowController selectedListItem]], nil );
	STAssertTrue( [[windowController allChatViewControllers] count] == 1, nil );

	[panel release];
	[panelTwo release];
	[panelThree release];
}

- (void) testSelectChatViewController {
	[windowController showWindow:nil];

	id panel = [[JVTestChatViewController alloc] init];
	STAssertNotNil( panel, nil );

	id panelTwo = [[JVTestChatViewController alloc] init];
	STAssertNotNil( panelTwo, nil );

	id panelThree = [[JVTestChatViewController alloc] init];
	STAssertNotNil( panelThree, nil );

	[windowController insertChatViewController:panel atIndex:0];
	[windowController insertChatViewController:panelTwo atIndex:1];
	[windowController insertChatViewController:panelThree atIndex:2];

	// panel should be the active panel
	STAssertTrue( [panel isEqual:[windowController activeChatViewController]], nil );
	STAssertTrue( [panel isEqual:[windowController selectedListItem]], nil );
	STAssertTrue( [[windowController allChatViewControllers] count] == 3, nil );

	[windowController showChatViewController:panelTwo];

	// panelTwo should now be the active panel
	STAssertTrue( [panelTwo isEqual:[windowController activeChatViewController]], nil );
	STAssertTrue( [panelTwo isEqual:[windowController selectedListItem]], nil );

	[windowController selectNextPanel:nil];

	// panelThree should now be the active panel
	STAssertTrue( [panelThree isEqual:[windowController activeChatViewController]], nil );
	STAssertTrue( [panelThree isEqual:[windowController selectedListItem]], nil );

	[windowController selectPreviousPanel:nil];

	// panelTwo should now be the active panel
	STAssertTrue( [panelTwo isEqual:[windowController activeChatViewController]], nil );
	STAssertTrue( [panelTwo isEqual:[windowController selectedListItem]], nil );

	[windowController showChatViewController:panel];

	// panel should now be the active panel
	STAssertTrue( [panel isEqual:[windowController activeChatViewController]], nil );
	STAssertTrue( [panel isEqual:[windowController selectedListItem]], nil );

	[windowController selectPreviousPanel:nil];

	// panelThree should now be the active panel (it should loop to the end)
	STAssertTrue( [panelThree isEqual:[windowController activeChatViewController]], nil );
	STAssertTrue( [panelThree isEqual:[windowController selectedListItem]], nil );

	[windowController selectNextPanel:nil];

	// panel should now be the active panel (it should loop to the beginning)
	STAssertTrue( [panel isEqual:[windowController activeChatViewController]], nil );
	STAssertTrue( [panel isEqual:[windowController selectedListItem]], nil );

	[panelThree setNewMessagesWaiting:1];
	[windowController selectNextActivePanel:nil];

	// panelThree should now be the active panel
	STAssertTrue( [panelThree isEqual:[windowController activeChatViewController]], nil );
	STAssertTrue( [panelThree isEqual:[windowController selectedListItem]], nil );

	[panelThree setNewMessagesWaiting:0];
	[panelTwo setNewMessagesWaiting:2];
	[windowController selectPreviousActivePanel:nil];

	// panelTwo should now be the active panel
	STAssertTrue( [panelTwo isEqual:[windowController activeChatViewController]], nil );
	STAssertTrue( [panelTwo isEqual:[windowController selectedListItem]], nil );

	[panel release];
	[panelTwo release];
	[panelThree release];
}
@end
