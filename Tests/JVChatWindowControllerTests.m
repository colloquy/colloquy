#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import <ChatCore/ChatCore.h>

#import "JVChatWindowController.h"
#import "JVDirectChatPanel.h"

@interface JVTestChatViewController : NSObject <JVChatViewController>
{
	JVChatWindowController *_windowController;
	NSUInteger _newMessages;
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
	return [[NSView alloc] init];
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
	return [NSImage imageNamed:@"roomIcon"];
}

- (NSString *) title {
	return @"Test";
}

- (NSUInteger) newMessagesWaiting {
	return _newMessages;
}

- (void) setNewMessagesWaiting:(NSUInteger) new {
	_newMessages = new;
}

- (NSString *) toolbarIdentifier {
	return @"It's a test";	
}
@end

@interface JVChatWindowControllerTests : XCTestCase
{
	JVChatWindowController *windowController;
}
@end

@implementation JVChatWindowControllerTests
- (void) setUp {
	windowController = [[JVChatWindowController alloc] init];
	XCTAssertNotNil( windowController);
}

- (void) tearDown {
	windowController = nil;
}

- (void) testAddChatViewController {
	id panel = [[JVTestChatViewController alloc] init];
	XCTAssertNotNil( panel);

	id panelTwo = [[JVTestChatViewController alloc] init];
	XCTAssertNotNil( panelTwo);

	// there should no active panel
	XCTAssertNil( [windowController activeChatViewController]);
	XCTAssertNil( [windowController selectedListItem]);

	[windowController showWindow:nil];

	// there should still be no active panel
	XCTAssertNil( [windowController activeChatViewController]);
	XCTAssertNil( [windowController selectedListItem]);

	[windowController addChatViewController:panel];

	// panel should be the active panel
	XCTAssertTrue( [panel isEqual:[windowController activeChatViewController]]);
	XCTAssertTrue( [panel isEqual:[windowController selectedListItem]]);
	XCTAssertTrue( [[windowController allChatViewControllers] count] == 1);

	[windowController addChatViewController:panelTwo];

	// panel should still be the active panel after adding panelTwo
	XCTAssertTrue( [panel isEqual:[windowController activeChatViewController]]);
	XCTAssertTrue( [panel isEqual:[windowController selectedListItem]]);
	XCTAssertTrue( [[windowController allChatViewControllers] count] == 2);

	// check duplicate add
	XCTAssertThrows( [windowController addChatViewController:panelTwo]);

	// nothing should have changed
	XCTAssertTrue( [panel isEqual:[windowController activeChatViewController]]);
	XCTAssertTrue( [panel isEqual:[windowController selectedListItem]]);
	XCTAssertTrue( [[windowController allChatViewControllers] count] == 2);

	// check nil add
	XCTAssertThrows( [windowController addChatViewController:nil]);

	// nothing should have changed
	XCTAssertTrue( [panel isEqual:[windowController activeChatViewController]]);
	XCTAssertTrue( [panel isEqual:[windowController selectedListItem]]);
	XCTAssertTrue( [[windowController allChatViewControllers] count] == 2);

}

- (void) testInsertChatViewController {
	[windowController showWindow:nil];

	id panel = [[JVTestChatViewController alloc] init];
	XCTAssertNotNil( panel);

	id panelTwo = [[JVTestChatViewController alloc] init];
	XCTAssertNotNil( panelTwo);

	id panelThree = [[JVTestChatViewController alloc] init];
	XCTAssertNotNil( panelThree);

	id panelFour = [[JVTestChatViewController alloc] init];
	XCTAssertNotNil( panelFour);

	[windowController insertChatViewController:panel atIndex:0];

	// panel should be the active panel
	XCTAssertTrue( [panel isEqual:[windowController activeChatViewController]]);
	XCTAssertTrue( [panel isEqual:[windowController selectedListItem]]);
	XCTAssertTrue( [[windowController allChatViewControllers] count] == 1);

	[windowController insertChatViewController:panelTwo atIndex:1];

	// panel should still be the active panel
	XCTAssertTrue( [panel isEqual:[windowController activeChatViewController]]);
	XCTAssertTrue( [panel isEqual:[windowController selectedListItem]]);
	XCTAssertTrue( [[windowController allChatViewControllers] count] == 2);

	[windowController insertChatViewController:panelThree atIndex:0];

	// panel should still be the active panel
	XCTAssertTrue( [panel isEqual:[windowController activeChatViewController]]);
	XCTAssertTrue( [panel isEqual:[windowController selectedListItem]]);
	XCTAssertTrue( [[windowController allChatViewControllers] count] == 3);

	// check index out of bounds
	XCTAssertThrows( [windowController insertChatViewController:panelFour atIndex:4]);

	// nothing should have changed
	XCTAssertTrue( [panel isEqual:[windowController activeChatViewController]]);
	XCTAssertTrue( [panel isEqual:[windowController selectedListItem]]);
	XCTAssertTrue( [[windowController allChatViewControllers] count] == 3);

	// check duplicate insert
	XCTAssertThrows( [windowController insertChatViewController:panelThree atIndex:0]);

	// nothing should have changed
	XCTAssertTrue( [panel isEqual:[windowController activeChatViewController]]);
	XCTAssertTrue( [panel isEqual:[windowController selectedListItem]]);
	XCTAssertTrue( [[windowController allChatViewControllers] count] == 3);

	// check nil insert
	XCTAssertThrows( [windowController insertChatViewController:nil atIndex:0]);

	// nothing should have changed
	XCTAssertTrue( [panel isEqual:[windowController activeChatViewController]]);
	XCTAssertTrue( [panel isEqual:[windowController selectedListItem]]);
	XCTAssertTrue( [[windowController allChatViewControllers] count] == 3);

}

- (void) testRemoveChatViewController {
	[windowController showWindow:nil];

	id panel = [[JVTestChatViewController alloc] init];
	XCTAssertNotNil( panel);

	id panelTwo = [[JVTestChatViewController alloc] init];
	XCTAssertNotNil( panelTwo);

	id panelThree = [[JVTestChatViewController alloc] init];
	XCTAssertNotNil( panelThree);

	[windowController insertChatViewController:panel atIndex:0];
	[windowController insertChatViewController:panelTwo atIndex:1];
	[windowController insertChatViewController:panelThree atIndex:2];

	// panel should be the active panel
	XCTAssertTrue( [panel isEqual:[windowController activeChatViewController]]);
	XCTAssertTrue( [panel isEqual:[windowController selectedListItem]]);
	XCTAssertTrue( [[windowController allChatViewControllers] count] == 3);

	[windowController removeChatViewController:panel];

	// panelTwo should now be the active panel
	XCTAssertTrue( [panelTwo isEqual:[windowController activeChatViewController]]);
	XCTAssertTrue( [panelTwo isEqual:[windowController selectedListItem]]);
	XCTAssertTrue( [[windowController allChatViewControllers] count] == 2);

	[windowController removeChatViewController:panelThree];

	// panelTwo should still be the active panel
	XCTAssertTrue( [panelTwo isEqual:[windowController activeChatViewController]]);
	XCTAssertTrue( [panelTwo isEqual:[windowController selectedListItem]]);
	XCTAssertTrue( [[windowController allChatViewControllers] count] == 1);

	// check nil remove
	XCTAssertThrows( [windowController removeChatViewController:nil]);

	// nothing should have changed
	XCTAssertTrue( [panelTwo isEqual:[windowController activeChatViewController]]);
	XCTAssertTrue( [panelTwo isEqual:[windowController selectedListItem]]);
	XCTAssertTrue( [[windowController allChatViewControllers] count] == 1);

	// check duplicate remove
	XCTAssertThrows( [windowController removeChatViewController:panelThree]);

	// nothing should have changed
	XCTAssertTrue( [panelTwo isEqual:[windowController activeChatViewController]]);
	XCTAssertTrue( [panelTwo isEqual:[windowController selectedListItem]]);
	XCTAssertTrue( [[windowController allChatViewControllers] count] == 1);

	[windowController removeAllChatViewControllers];

	// there should be no active panel
	XCTAssertNil( [windowController activeChatViewController]);
	XCTAssertNil( [windowController activeChatViewController]);
	XCTAssertTrue( [[windowController allChatViewControllers] count] == 0);
}

- (void) testSelectChatViewController {
	[windowController showWindow:nil];

	id panel = [[JVTestChatViewController alloc] init];
	XCTAssertNotNil( panel);

	id panelTwo = [[JVTestChatViewController alloc] init];
	XCTAssertNotNil( panelTwo);

	id panelThree = [[JVTestChatViewController alloc] init];
	XCTAssertNotNil( panelThree);

	[windowController insertChatViewController:panel atIndex:0];
	[windowController insertChatViewController:panelTwo atIndex:1];
	[windowController insertChatViewController:panelThree atIndex:2];

	// panel should be the active panel
	XCTAssertTrue( [panel isEqual:[windowController activeChatViewController]]);
	XCTAssertTrue( [panel isEqual:[windowController selectedListItem]]);
	XCTAssertTrue( [[windowController allChatViewControllers] count] == 3);

	[windowController showChatViewController:panelTwo];

	// panelTwo should now be the active panel
	XCTAssertTrue( [panelTwo isEqual:[windowController activeChatViewController]]);
	XCTAssertTrue( [panelTwo isEqual:[windowController selectedListItem]]);

	[windowController selectNextPanel:nil];

	// panelThree should now be the active panel
	XCTAssertTrue( [panelThree isEqual:[windowController activeChatViewController]]);
	XCTAssertTrue( [panelThree isEqual:[windowController selectedListItem]]);

	[windowController selectPreviousPanel:nil];

	// panelTwo should now be the active panel
	XCTAssertTrue( [panelTwo isEqual:[windowController activeChatViewController]]);
	XCTAssertTrue( [panelTwo isEqual:[windowController selectedListItem]]);

	[windowController showChatViewController:panel];

	// panel should now be the active panel
	XCTAssertTrue( [panel isEqual:[windowController activeChatViewController]]);
	XCTAssertTrue( [panel isEqual:[windowController selectedListItem]]);

	[windowController selectPreviousPanel:nil];

	// panelThree should now be the active panel (it should loop to the end)
	XCTAssertTrue( [panelThree isEqual:[windowController activeChatViewController]]);
	XCTAssertTrue( [panelThree isEqual:[windowController selectedListItem]]);

	[windowController selectNextPanel:nil];

	// panel should now be the active panel (it should loop to the beginning)
	XCTAssertTrue( [panel isEqual:[windowController activeChatViewController]]);
	XCTAssertTrue( [panel isEqual:[windowController selectedListItem]]);

	[panelThree setNewMessagesWaiting:1];
	[windowController selectNextActivePanel:nil];

	// panelThree should now be the active panel
	XCTAssertTrue( [panelThree isEqual:[windowController activeChatViewController]]);
	XCTAssertTrue( [panelThree isEqual:[windowController selectedListItem]]);

	[panelThree setNewMessagesWaiting:0];
	[panelTwo setNewMessagesWaiting:2];
	[windowController selectPreviousActivePanel:nil];

	// panelTwo should now be the active panel
	XCTAssertTrue( [panelTwo isEqual:[windowController activeChatViewController]]);
	XCTAssertTrue( [panelTwo isEqual:[windowController selectedListItem]]);
}

@end
