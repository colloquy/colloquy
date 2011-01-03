#include <Carbon/Carbon.r>

#define Reserved8   reserved, reserved, reserved, reserved, reserved, reserved, reserved, reserved
#define Reserved12  Reserved8, reserved, reserved, reserved, reserved
#define Reserved13  Reserved12, reserved
#define dp_none__   noParams, "", directParamOptional, singleItem, notEnumerated, Reserved13
#define reply_none__   noReply, "", replyOptional, singleItem, notEnumerated, Reserved13
#define synonym_verb__ reply_none__, dp_none__, { }
#define plural__    "", {"", kAESpecialClassProperties, cType, "", reserved, singleItem, notEnumerated, readOnly, Reserved8, noApostrophe, notFeminine, notMasculine, plural}, {}

resource 'aete' (0, "Colloquy Terminology") {
	0x1,  // major version
	0x0,  // minor version
	english,
	roman,
	{
		"Type Names Suite",
		"Hidden terms",
		kASTypeNamesSuite,
		1,
		1,
		{
			/* Events */

			"add event message",
			"Add an event message to a chat room panel or direct chat panel. This will add a line to the display that is only visible to the local user. Defaults to the active panel of the front window if no other tell block specifies the target.",
			'coRC', 'aEvX',
			reply_none__,
			'TEXT',
			"Message to add (visible to the user). (Plain text with HTML formatting. Must entity encode HTML special characters.)",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{
				"message", 'aEv1', 'TEXT',
				"Message to add. Can include HTML formatting. This parameter is deprecated, the message is now the direct parameter.",
				optional,
				singleItem, notEnumerated, Reserved13
			},

			"process incoming chat message",
			"Called when an incoming message is sent to us or a room we are in. (Any messages echoed to the screen that are sent from the local user will also be passed through this handler.)",
			'cplG', 'piMX',
			reply_none__,
			'cmsM',
			"The incoming message. Message and properties are modifiable.",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{
				"as", 'piM1', 'bool',
				"Is this message an action?",
				optional,
				singleItem, notEnumerated, Reserved13
			},

			"process outgoing chat message",
			"Called when a message is sent from us to a user or room we are in.",
			'cplG', 'poMX',
			reply_none__,
			'cmsM',
			"The outgoing message. Message and properties are modifiable.",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{
				"as", 'poM1', 'bool',
				"Is this message an action?",
				optional,
				singleItem, notEnumerated, Reserved13
			}
		},
		{
			/* Classes */

			"item", 'cobj',
			"A scriptable object.",
			{
			},
			{
			},

			"application", 'capp',
			"The Colloquy application.",
			{
				"<Inheritance>", pInherits, 'capp',
				"inherits elements and properties of the application class.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12
			},
			{
			},

			"panel", 'chvC',
			"Generic window panel that all panels inherit from (e.g. direct chat panel, chat room panel, etc.)",
			{
				"<Inheritance>", pInherits, 'cliM',
				"inherits elements and properties of the list item class.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12
			},
			{
			},

			"chat room or chat user", 't002', "", { }, { },

			"chat room panel, console panel, direct chat panel, panel or transcript panel", 't007', "", { }, { },

			"chat user, member or text", 't001', "", { }, { },

			"chat user or member", 't011', "", { }, { },

			"chat room panel, direct chat panel, panel or transcript panel", 't008', "", { }, { },

			"chat room panel, console panel, direct chat panel or panel", 't003', "", { }, { },

			"chat room panel or direct chat panel", 't006', "", { }, { }
		},
		{
			/* Comparisons */
		},
		{
			/* Enumerations */
		},

		"Standard Suite",
		"Common classes and commands.",
		'????',
		1,
		1,
		{
			/* Events */

			"open",
			"Open an object.",
			'aevt', 'odoc',
			reply_none__,
			'file',
			"The file(s) to be opened.",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{

			},

			"print",
			"Print an object.",
			'aevt', 'pdoc',
			reply_none__,
			'file',
			"The file(s) or document(s) to be printed.",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{

			},

			"quit",
			"Quit an application.",
			'aevt', 'quit',
			reply_none__,
			dp_none__,
			{
				"saving", 'savo', 'savo',
				"Specifies whether changes should be saved before quitting.",
				optional,
				singleItem, enumerated, Reserved13
			},

			"close",
			"Close an object.",
			'core', 'clos',
			reply_none__,
			'obj ',
			"the object to close",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{
				"saving", 'savo', 'savo',
				"Specifies whether changes should be saved before closing.",
				optional,
				singleItem, enumerated, Reserved13,
				"saving in", 'kfil', 'file',
				"The file in which to save the object.",
				optional,
				singleItem, notEnumerated, Reserved13
			},

			"count",
			"Return the number of elements of a particular class within an object.",
			'core', 'cnte',
			'long',
			"the number of elements",
			replyRequired, singleItem, notEnumerated, Reserved13,
			'obj ',
			"the object whose elements are to be counted",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{
				"each", 'kocl', 'type',
				"The class of objects to be counted.",
				optional,
				singleItem, notEnumerated, Reserved13
			},

			"delete",
			"Delete an object.",
			'core', 'delo',
			reply_none__,
			'obj ',
			"the object to delete",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{

			},

			"duplicate",
			"Copy object(s) and put the copies at a new location.",
			'core', 'clon',
			reply_none__,
			'obj ',
			"the object(s) to duplicate",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{
				"to", 'insh', 'insl',
				"The location for the new object(s).",
				required,
				singleItem, notEnumerated, Reserved13,
				"with properties", 'prdt', 'reco',
				"Properties to be set in the new duplicated object(s).",
				optional,
				singleItem, notEnumerated, Reserved13
			},

			"exists",
			"Verify if an object exists.",
			'core', 'doex',
			'bool',
			"true if it exists, false if not",
			replyRequired, singleItem, notEnumerated, Reserved13,
			'obj ',
			"the object in question",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{

			},

			"get",
			"Get the data for an object.",
			'core', 'getd',
			'****',
			"",
			replyRequired, singleItem, notEnumerated, Reserved13,
			'obj ',
			"",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{

			},

			"make",
			"Make a new object.",
			'core', 'crel',
			'obj ',
			"to the new object",
			replyRequired, singleItem, notEnumerated, Reserved13,
			dp_none__,
			{
				"new", 'kocl', 'type',
				"The class of the new object.",
				required,
				singleItem, notEnumerated, Reserved13,
				"at", 'insh', 'insl',
				"The location at which to insert the object.",
				optional,
				singleItem, notEnumerated, Reserved13,
				"with data", 'data', '****',
				"The initial data for the object.",
				optional,
				singleItem, notEnumerated, Reserved13,
				"with properties", 'prdt', 'reco',
				"The initial values for properties of the object.",
				optional,
				singleItem, notEnumerated, Reserved13
			},

			"move",
			"Move object(s) to a new location.",
			'core', 'move',
			reply_none__,
			'obj ',
			"the object(s) to move",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{
				"to", 'insh', 'insl',
				"The new location for the object(s).",
				required,
				singleItem, notEnumerated, Reserved13
			},

			"save",
			"Save an object.",
			'core', 'save',
			reply_none__,
			'obj ',
			"the object to save, usually a document or window",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{
				"in", 'kfil', 'file',
				"The file in which to save the object.",
				optional,
				singleItem, notEnumerated, Reserved13,
				"as", 'fltp', 'TEXT',
				"The file type in which to save the data.",
				optional,
				singleItem, notEnumerated, Reserved13
			},

			"set",
			"Set an object's data.",
			'core', 'setd',
			reply_none__,
			'obj ',
			"",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{
				"to", 'data', '****',
				"The new value.",
				required,
				singleItem, notEnumerated, Reserved13
			}
		},
		{
			/* Classes */

			"item", 'cobj',
			"A scriptable object.",
			{
				"class", 'pcls', 'type',
				"The class of the object.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"properties", 'pALL', 'reco',
				"All of the object's properties.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12
			},
			{
			},
			"items", 'cobj', plural__,

			"application", 'capp',
			"An application's top level scripting object.",
			{
				"name", 'pnam', 'TEXT',
				"The name of the application.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"frontmost", 'pisf', 'bool',
				"Is this the frontmost (active) application?",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"version", 'vers', 'TEXT',
				"The version of the application.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12
			},
			{
				'cwin', { }
			},
			"applications", 'capp', plural__,

			"window", 'cwin',
			"A window.",
			{
				"name", 'pnam', 'TEXT',
				"The full title of the window.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"id", 'ID  ', 'nmbr',
				"The unique identifier of the window.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"bounds", 'pbnd', 'qdrt',
				"The bounding rectangle of the window.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"closeable", 'hclb', 'bool',
				"Whether the window has a close box.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"titled", 'ptit', 'bool',
				"Whether the window has a title bar.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"index", 'pidx', 'nmbr',
				"The index of the window in the back-to-front window ordering.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"floating", 'isfl', 'bool',
				"Whether the window floats.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"miniaturizable", 'ismn', 'bool',
				"Whether the window can be miniaturized.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"miniaturized", 'pmnd', 'bool',
				"Whether the window is currently miniaturized.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"modal", 'pmod', 'bool',
				"Whether the window is the application's current modal window.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"resizable", 'prsz', 'bool',
				"Whether the window can be resized.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"visible", 'pvis', 'bool',
				"Whether the window is currently visible.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"zoomable", 'iszm', 'bool',
				"Whether the window can be zoomed.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"zoomed", 'pzum', 'bool',
				"Whether the window is currently zoomed.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12
			},
			{
			},
			"windows", 'cwin', plural__,

			"color", 'colr',
			"A color.",
			{
			},
			{
			},
			"colors", 'colr', plural__
		},
		{
			/* Comparisons */
		},
		{
			/* Enumerations */
			'savo',
			{
				"yes", 'yes ', "Save the file.",
				"no", 'no  ', "Do not save the file.",
				"ask", 'ask ', "Ask the user whether or not to save the file."
			}
		},

		"Colloquy Suite",
		"Classes and commands for Colloquy high-level scripting.",
		'coRC',
		1,
		1,
		{
			/* Events */

			"add event message",
			"Add an event message to a chat room panel or direct chat panel. This will add a line to the display that is only visible to the local user. Defaults to the active panel of the front window if no other tell block specifies the target.",
			'coRC', 'aEvX',
			reply_none__,
			'TEXT',
			"Message to add (visible to the user). (Plain text with HTML formatting. Must entity encode HTML special characters.)",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{
				"with name", 'aEv2', 'TEXT',
				"A name for this type of event message. This is not visible to the user, and should be fairly unique. Defaults to a name based on the calling script.",
				optional,
				singleItem, notEnumerated, Reserved13,
				"and attributes", 'aEv3', 'reco',
				"Custom information to be stored with this event message. Can be used by chat styles and is saved in transcripts.",
				optional,
				singleItem, notEnumerated, Reserved13
			},

			"display new connection dialog",
			"Prompts to make a new connection.",
			'coRC', 'nwcX',
			reply_none__,
			dp_none__,
			{

			},

			"display direct chat panel",
			"Open a direct chat panel to chat with another user.  Focuses an existing panel or makes a new panel.",
			'coRC', 'sChX',
			'dchM',
			"The direct chat panel.",
			replyRequired, singleItem, notEnumerated, Reserved13,
			dp_none__,
			{
				"for", 'sCh1', 't001',
				"The member or chat user. You may also pass a string nickname if you also provide the connection.",
				required,
				singleItem, notEnumerated, Reserved13,
				"on", 'sCh2', 'conM',
				"Only required if the user is a string. The connection where to find the user by nickname.",
				optional,
				singleItem, notEnumerated, Reserved13
			},

			"display chat room browser",
			"Displays a new chat room browser window. Users can select a room from an expanded browser, or type a room in manually.",
			'coRC', 'dRbX',
			reply_none__,
			dp_none__,
			{
				"for", 'dRb1', 'conM',
				"The connection to select. No selection by default.",
				optional,
				singleItem, notEnumerated, Reserved13,
				"with filter", 'dRb2', 'TEXT',
				"A search filter to use. No filter by default.",
				optional,
				singleItem, notEnumerated, Reserved13,
				"expanded", 'dRb3', 'bool',
				"Should the browser be expanded? Default is no. The room list will be refreshed if the browser is expanded.",
				optional,
				singleItem, notEnumerated, Reserved13
			}
		},
		{
			/* Classes */

			"application", 'capp',
			"The Colloquy application.",
			{
				"<Inheritance>", pInherits, 'capp',
				"inherits elements and properties of the application class.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12
			},
			{
				'chvC', { },
				'ccoM', { },
				'ctrM', { },
				'strM', { },
				'dchM', { },
				'crmM', { },
				'conM', { },
				'budM', { },
				'flTx', { }
			},
			"applications", 'capp', plural__,

			"window", 'cwin',
			"A window that can contain panels.",
			{
				"<Inheritance>", pInherits, 'cwin',
				"inherits elements and properties of the window class.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"selected list item", 'SclM', 'cliM',
				"Current selection in the drawer list.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"active panel", 'AcvC', 'chvC',
				"Current visible panel for this chat window.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12
			},
			{
				'chvC', { },
				'ccoM', { },
				'ctrM', { },
				'strM', { },
				'dchM', { },
				'crmM', { }
			},
			"windows", 'cwin', plural__,

			"list item", 'cliM',
			"Generic chat list item that all drawer items inherit from (e.g. members, etc.).",
			{
				"name", 'pnam', 'TEXT',
				"Title to show in the list.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"subtitle", 'infA', 'TEXT',
				"Subtitle information to show when list has space.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"enabled", 'enBA', 'bool',
				"Is the list item enabled?",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"tooltip", 'toLA', 'TEXT',
				"The tooltip for the listem item.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"container", 'pArA', 'cliM',
				"This list item's parent.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12
			},
			{
				'cliM', { }
			},
			"list items", 'cliM', plural__,

			"panel", 'chvC',
			"Generic window panel that all panels inherit from (e.g. direct chat panel, chat room panel, etc.)",
			{
				"<Inheritance>", pInherits, 'cliM',
				"inherits elements and properties of the list item class.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"id", 'ID  ', 'long',
				"The unique identifier of the chat view controller.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"connection", 'conM', 'conM',
				"Connection this view uses.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"window", 'cwin', 'cwin',
				"Parent window.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"description", 'idtA', 'TEXT',
				"Concise description of the chat view and what it represents.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12
			},
			{
			},
			"panels", 'chvC', plural__,

			"transcript panel", 'ctrM',
			"A log panel of some previous conversation.",
			{
				"<Inheritance>", pInherits, 'chvC',
				"inherits elements and properties of the panel class.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"transcript", 'traM', 'traM',
				"The transcript shown in the panel.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"transcript", 'traM', 'traM',
				"The transcript shown in the panel. (Default sub-container.)",
				reserved, singleItem, notEnumerated, readOnly, Reserved12
			},
			{
			},
			"transcript panels", 'ctrM', plural__,

			"smart transcript panel", 'strM',
			"A smart log panel with conversation filters.",
			{
				"<Inheritance>", pInherits, 'ctrM',
				"inherits elements and properties of the transcript panel class.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12
			},
			{
			},
			"smart transcript panels", 'strM', plural__,

			"console panel", 'ccoM',
			"Direct server console for advanced users.",
			{
				"<Inheritance>", pInherits, 'chvC',
				"inherits elements and properties of the panel class.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12
			},
			{
			},
			"console panels", 'ccoM', plural__,

			"direct chat panel", 'dchM',
			"Direct (private) chat panel with another user.",
			{
				"<Inheritance>", pInherits, 'ctrM',
				"inherits elements and properties of the transcript panel class.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"encoding", 'eNcA', 'encE',
				"The encoding to use when reading and sending messages.",
				reserved, singleItem, enumerated, readWrite, Reserved12,

				"current message", 'cRmA', 'cmsM',
				"The current message that is being passed to plugins to process.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"new messages waiting", 'nemA', 'long',
				"The number of new messages since the panel was last active.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"new highlight messages waiting", 'nhmA', 'long',
				"The number of new highlight messages since the panel was last active.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"unavailable", 'csmA', 'bool',
				"Can send messages?",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"active", 'iacA', 'bool',
				"Is the active (visible) view?",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"target", 'trgA', 't002',
				"The user or room that we engaged in conversation with.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12
			},
			{
			},
			"direct chat panels", 'dchM', plural__,

			"chat room panel", 'crmM',
			"Chat room panel.",
			{
				"<Inheritance>", pInherits, 'dchM',
				"inherits elements and properties of the direct chat panel class.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12
			},
			{
				'chmM', { }
			},
			"chat room panels", 'crmM', plural__,

			"member", 'chmM',
			"Chat room member list item represented in the drawer list.",
			{
				"<Inheritance>", pInherits, 'cliM',
				"inherits elements and properties of the list item class.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"chat user", 'chUs', 'chUs',
				"The chat user for this member.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"id", 'ID  ', 'long',
				"The unique identifier of the member. Unique even if member changes nicknames.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"name", 'pnam', 'TEXT',
				"Member's nickname.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"chat room panel", 'crmM', 'crmM',
				"The chat room panel this member is part of.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"chat user", 'chUs', 'chUs',
				"The chat user for this member. (Default sub-container.)",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"buddy", 'budM', 'budM',
				"The buddy (if any) this member represents.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12
			},
			{
			},
			"members", 'chmM', plural__,

			"buddy", 'budM',
			"A buddy.",
			{
				"id", 'ID  ', 'TEXT',
				"The unique identifier of the buddy. Same as the associated AddressBook entry.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"name", 'pnam', 'TEXT',
				"The buddy's full name in the user's preferred order.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"given nickname", 'gvnA', 'TEXT',
				"Given nickname from AddressBook.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"preferred name", 'prnA', 'TEXT',
				"Returns the user's preferred name. Either the active nickname, given nickname, or first and last name.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"first name", 'fsnA', 'TEXT',
				"First name from AddressBook.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"last name", 'lsnA', 'TEXT',
				"Last name from AddressBook.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"idle time", 'iDlA', 'doub',
				"Current idle time in seconds for the active nickname.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"away message", 'aStA', 'TEXT',
				"Away message for active nickname.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"primary email", 'pemA', 'TEXT',
				"Primary email address from AddressBook.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"status", 'stsA', 'bstE',
				"The current status of the active nickname.",
				reserved, singleItem, enumerated, readOnly, Reserved12
			},
			{
			},
			"buddies", 'budM', plural__,

			"transcript", 'traM',
			"A log of a previous conversation.",
			{
				"id", 'ID  ', 'long',
				"The unique identifier of the transcript.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"file", 'kfil', 'file',
				"The file (if any) this transcript represents.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"auto save", 'atSA', 'bool',
				"Save any changes to disk as they occur? Always false when there is no file association.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12
			},
			{
				'cmsM', { }
			},
			"transcripts", 'traM', plural__,

			"message", 'cmsM',
			"A chat message.",
			{
				"body", 'maPA', 'ctxt',
				"The body of the message.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"id", 'ID  ', 'long',
				"The id of this message.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"sender", 'sNdA', 'cobj',
				"The sender of this message",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"timestamp", 'dteA', 'ldt ',
				"The date and time this message occurred.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"highlighted", 'iHlt', 'bool',
				"Was the message highlighted for some reason?",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"action tense", 'isAc', 'bool',
				"Does the message have action tense?",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"body", 'maPA', 'ctxt',
				"The body of the message. (Default sub-container.)",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"HTML", 'maHA', 'TEXT',
				"The message with possible HTML formatting.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"ignore status", 'iGsA', 'igsE',
				"If the message was ignored with one of the ignore rules.",
				reserved, singleItem, enumerated, readWrite, Reserved12,

				"transcript", 'traM', 'traM',
				"The transcript (log) this message belongs to.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12
			},
			{
			},
			"messages", 'cmsM', plural__
		},
		{
			/* Comparisons */
		},
		{
			/* Enumerations */
			'bstE',
			{
				"away", 'awaY', "",
				"offline", 'oflN', "",
				"available", 'avaL', "",
				"idle", 'idlE', ""
			},

			'igsE',
			{
				"message ignored", 'msIg', "",
				"not ignored", 'noIg', "",
				"user ignored", 'usIg', ""
			}
		},

		"Chat Core Suite",
		"Classes and commands for Chat Core scripting. Chat Core is the the lowest level of Colloquy.",
		'ccoR',
		1,
		1,
		{
			/* Events */

			"connect",
			"Connect to the server.",
			'ccoR', 'conX',
			reply_none__,
			'conM',
			"The connection to connect.",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{

			},

			"disconnect",
			"Disconnect from the server.",
			'ccoR', 'dscX',
			reply_none__,
			'conM',
			"The connection to disconnect.",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{

			},

			"send message",
			"Send a message to a room or user.",
			'ccoR', 'sCmX',
			reply_none__,
			'TEXT',
			"The message to send. (Plain text with HTML formatting. Must entity encode HTML special characters.)",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{
				"to", 'sCm1', 't002',
				"The chat user or chat room to send to. Optional if the nearest enclosing tell block responds to this command.",
				optional,
				singleItem, notEnumerated, Reserved13,
				"encoded as", 'sCm2', 'encE',
				"The encoding to send the message as (will default to the room or connection encoding if omitted).",
				optional,
				singleItem, enumerated, Reserved13,
				"action tense", 'sCm3', 'bool',
				"Send as an action?",
				optional,
				singleItem, notEnumerated, Reserved13,
				"local echo", 'sCm4', 'bool',
				"Show the message locally on screen? (Defaults on.)",
				optional,
				singleItem, notEnumerated, Reserved13
			},

			"send raw command",
			"Send raw server command (message) to server.",
			'ccoR', 'sRmX',
			reply_none__,
			'TEXT',
			"The raw server command (message) to send. (This is protocol specific.)",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{
				"to", 'sRm1', 'conM',
				"The connection to send to. Optional if the nearest enclosing tell block responds to this command.",
				optional,
				singleItem, notEnumerated, Reserved13,
				"priority", 'sRm2', 'bool',
				"Send this command now? (This will bypass any queued commands.)",
				optional,
				singleItem, notEnumerated, Reserved13
			},

			"join chat room",
			"Join a chat room.",
			'ccoR', 'jCrX',
			reply_none__,
			'TEXT',
			"Chat room(s) to join.",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{
				"on", 'jCr1', 'conM',
				"The connection to join on. Optional if the nearest enclosing tell block responds to this command.",
				optional,
				singleItem, notEnumerated, Reserved13
			},

			"refresh information",
			"Refresh various properties of a chat user.",
			'ccoR', 'rfsX',
			reply_none__,
			'chUs',
			"The chat user.",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{

			},

			"reload plugins",
			"Reloads all plugins that are in the search paths. Plugins that have been deleted or moved will be unloaded.",
			'ccoR', 'rLdX',
			reply_none__,
			dp_none__,
			{

			}
		},
		{
			/* Classes */

			"chat user", 'chUs',
			"Represents a user on a chat server. Many properties of this class require the refresh information command to be called first on the instance.",
			{
				"id", 'ID  ', 'TEXT',
				"The unique identifier of the user on the server.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"name", 'pnam', 'TEXT',
				"The current nickname.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"display name", 'dNmA', 'TEXT',
				"Display name, almost always the nickname.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"real name", 'rElA', 'TEXT',
				"The real name supplied by the user, not always a person's real name.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"user name", 'uSnA', 'TEXT',
				"The user name supplied by the user.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"address", 'adRA', 'TEXT',
				"The address the user connected to the server from. Sometimes this is a fake (masked) address.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"server address", 'sevA', 'TEXT',
				"The server address the user is connected to. This might be a different address than you are connected to, since servers are sometimes clustered.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"idle time", 'iDlA', 'doub',
				"The number of seconds the user has been idle on the server.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"date updated", 'uPdA', 'ldt ',
				"The last time the refresh information command finished.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"date connected", 'dCoA', 'ldt ',
				"The date the user connected to the server.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"date disconnected", 'dDcA', 'ldt ',
				"The date the user disconnected from the server. This will not be available for all users.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"status", 'stsA', 'cusE',
				"The current status of the user.",
				reserved, singleItem, enumerated, readOnly, Reserved12,

				"away message", 'aStA', 'ctxt',
				"The user's away message.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"attributes", 'atRA', 'reco',
				"User attributes containing various items.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12
			},
			{
			},
			"chat users", 'chUs', plural__,

			"chat room", 'chRm',
			"Represents a join chat room.",
			{
				"id", 'ID  ', 'TEXT',
				"The unique identifier of the room.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"name", 'pnam', 'TEXT',
				"Full room name.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"display name", 'dNmA', 'TEXT',
				"Full room name without any prefixes.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"URL", 'url ', 'TEXT',
				"The full room URL containing the server and room name.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"banned users", 'bnSA', 'chUs',
				"Current chat room members.",
				reserved, listOfItems, notEnumerated, readOnly, Reserved12,

				"encoding", 'eNcA', 'encE',
				"Default encoding for outgoing messages.",
				reserved, singleItem, enumerated, readWrite, Reserved12,

				"attributes", 'atRA', 'reco',
				"Room attributes containing various items.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"joined", 'joIA', 'bool',
				"Are we currently in the room?",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"date joined", 'daJA', 'ldt ',
				"Date we joined the room. Missing value if we haven't joined yet.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"date parted", 'daPA', 'ldt ',
				"Date we parted the room. Missing value if we haven't parted yet.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12
			},
			{
				'chUs', { }
			},
			"chat rooms", 'chRm', plural__,

			"connection", 'conM',
			"Manages all chat communication with a chat server.",
			{
				"id", 'ID  ', 'long',
				"The unique identifier of the connection.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"URL", 'url ', 'TEXT',
				"Chat URL containing nickname, server and port.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"server address", 'sevA', 'TEXT',
				"Server IP address or domain name.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"port number", 'prtA', 'long',
				"Port to connect on.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"local user", 'lcuA', 'chUs',
				"Current local user when connected.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"nickname", 'nicA', 'TEXT',
				"Current nickname on the server.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"nickname password", 'ncpA', 'TEXT',
				"The nickname's password.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"password", 'pasA', 'TEXT',
				"Password to connect to the server.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"proxy", 'pxyA', 'pxyE',
				"What system proxy server to use.",
				reserved, singleItem, enumerated, readWrite, Reserved12,

				"status", 'stsA', 'cnsE',
				"Current connection status.",
				reserved, singleItem, enumerated, readOnly, Reserved12,

				"away message", 'aStA', 'ctxt',
				"Away message for other users to see that your not there.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"encoding", 'eNcA', 'encE',
				"The default connection encoding that is used when sending raw messages or chat messages without a specific encoding.",
				reserved, singleItem, enumerated, readWrite, Reserved12
			},
			{
				'chRm', { },
				'chUs', { }
			},
			"connections", 'conM', plural__,

			"file transfer", 'flTx',
			"Represents a file transfer with another chat user.",
			{
				"id", 'ID  ', 'long',
				"The unique identifier of the file transfer.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"type", 'typA', 'ftTE',
				"The type of this transfer.",
				reserved, singleItem, enumerated, readOnly, Reserved12,

				"file", 'kfil', 'file',
				"The file this transfer is associated with.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"status", 'stsA', 'ftSt',
				"The current status of the transfer.",
				reserved, singleItem, enumerated, readOnly, Reserved12,

				"start date", 'sDtA', 'ldt ',
				"The date and time this file transfer started.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"start offset", 'sOfA', 'long',
				"The location (offset) in the file where transfer was resumed.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"chat user", 'chUs', 'chUs',
				"The chat user this transfer is with.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"host address", 'HoSA', 'TEXT',
				"The address of the other user engaged in the transfer.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"port", 'pOrA', 'long',
				"The port this the transfer is using.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"passive", 'pAsA', 'bool',
				"Is the transfer using passive mode?",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"final size", 'fSzA', 'long',
				"The final expected size (in bytes) of the file.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"transferred size", 'TrzA', 'long',
				"The current size (in bytes) this file has transferred.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12
			},
			{
			},
			"file transfers", 'flTx', plural__
		},
		{
			/* Comparisons */
		},
		{
			/* Enumerations */
			'scTE',
			{
				"request", 'sreQ', "A subcode command request.",
				"reply", 'srpL', "A subcode command reply."
			},

			'cnsE',
			{
				"connected", 'conD', "Connected status.",
				"connecting", 'conG', "Connecting status.",
				"disconnected", 'disC', "Disconnected status.",
				"suspended", 'susP', "Suspended status."
			},

			'cusE',
			{
				"offline", 'oflN', "Offline status.",
				"detached", 'detA', "Detached status.",
				"available", 'avaL', "Available status.",
				"away", 'awaY', "Away status."
			},

			'pxyE',
			{
				"none", 'nonE', "No proxy.",
				"secure HTTP", 'htpS', "Secure HTTP proxy.",
				"SOCKS firewall", 'sokS', "SOCKS firewall proxy."
			},

			'encE',
			{
				"UTF8", 'utF8', "",
				"ASCII", 'ascI', "",
				"Nonlossy ASCII", 'nlAs', "",
				"ISO Latin 1", 'isL1', "",
				"ISO Latin 2", 'isL2', "",
				"ISO Latin 3", 'isL3', "",
				"ISO Latin 4", 'isL4', "",
				"ISO Latin 5", 'isL5', "",
				"ISO Latin 9", 'isL9', "",
				"Mac OS Roman", 'mcRo', "",
				"Mac OS European", 'mcEu', "",
				"Mac OS Cyrllic", 'mcCy', "",
				"Mac OS Japanese", 'mcJp', "",
				"Mac OS Simp. Chinese", 'mcSc', "",
				"Mac OS Trad. Chinese", 'mcTc', "",
				"Mac OS Korean", 'mcKr', "",
				"Windows Latin 2", 'cp50', "",
				"Windows Cyrllic", 'cp51', "",
				"Windows Latin 1", 'cp52', "",
				"Windows Simp. Chinese", 'wnSc', "",
				"Windows Trad. Chinese", 'wnTc', "",
				"Windows Korean", 'wnKr', "",
				"Japanese EUC", 'jpUC', "",
				"Simp. Chinese EUC", 'scUC', "",
				"Trad. Chinese EUC", 'tcUC', "",
				"Korean EUC", 'krUC', "",
				"KOI8R", 'ko8R', "",
				"Shift JIS", 'sJiS', "",
				"GB 18030", 'gb30', "",
				"GBK", 'gbKK', "",
				"Big 5", 'biG5', "",
				"Big 5 HKSCS", 'bG5H', ""
			},

			'ftTE',
			{
				"upload", 'fTtU', "",
				"download", 'fTtD', ""
			},

			'ftSt',
			{
				"done", 'trDn', "",
				"in progress", 'trNo', "",
				"waiting", 'trHo', "",
				"stopped", 'trSt', "",
				"error", 'trEr', ""
			}
		},

		"Chat Plug-In Suite",
		"Commands to be implemented by plug-ins.",
		'cplG',
		1,
		1,
		{
			/* Events */

			"process user command",
			"Called when the user types an unhandled \"/command\". Return true to prevent other plugins from processing this command. If no plugins return true, the command is sent \"raw\"",
			'cplG', 'pcCX',
			'bool',
			"Return true to prevent other plugins from processing this command. If no plugins return true, the command is sent \"raw\"",
			replyRequired, singleItem, notEnumerated, Reserved13,
			'TEXT',
			"Command to process.",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{
				"with", 'pcC1', 'TEXT',
				"Any arguments given with the command.",
				optional,
				singleItem, notEnumerated, Reserved13,
				"for", 'pcC2', 't003',
				"The panel the command was entered in.",
				optional,
				singleItem, notEnumerated, Reserved13
			},

			"process incoming chat message",
			"Called when an incoming message is sent to us or a room we are in. (Any messages echoed to the screen that are sent from the local user will also be passed through this handler.)",
			'cplG', 'piMX',
			reply_none__,
			'cmsM',
			"The incoming message. Message and properties are modifiable.",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{
				"from", 'piM2', 't011',
				"The user this message came from.",
				optional,
				singleItem, notEnumerated, Reserved13,
				"in", 'piM3', 't006',
				"The chat room or direct chat this message is in.",
				optional,
				singleItem, notEnumerated, Reserved13
			},

			"process outgoing chat message",
			"Called when a message is sent from us to a user or room we are in.",
			'cplG', 'poMX',
			reply_none__,
			'cmsM',
			"The outgoing message. Message and properties are modifiable.",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{
				"in", 'poM2', 't006',
				"The chat room or direct chat this message is in.",
				optional,
				singleItem, notEnumerated, Reserved13
			},

			"process subcode request",
			"Called when an unhandled CTCP request gets sent to us from another user. Return true to prevent other plugins from processing this request.",
			'cplG', 'psRX',
			'bool',
			"Return true to prevent other plugins from processing this request.",
			replyRequired, singleItem, notEnumerated, Reserved13,
			'TEXT',
			"CTCP request to process.",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{
				"with", 'psR1', 'TEXT',
				"Any arguments given with the request.",
				optional,
				singleItem, notEnumerated, Reserved13,
				"from", 'psR2', 'chUs',
				"The user this request came from.",
				optional,
				singleItem, notEnumerated, Reserved13,
				"on", 'psR3', 'conM',
				"The connection this request came on.",
				optional,
				singleItem, notEnumerated, Reserved13
			},

			"process subcode reply",
			"Called when an unhandled CTCP reply gets sent to us from another user. Return true to prevent other plugins from processing this reply.",
			'cplG', 'psLX',
			'bool',
			"Return true to prevent other plugins from processing this reply.",
			replyRequired, singleItem, notEnumerated, Reserved13,
			'TEXT',
			"CTCP request to process.",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{
				"with", 'psL1', 'TEXT',
				"Any arguments given with the reply.",
				optional,
				singleItem, notEnumerated, Reserved13,
				"from", 'psL2', 'chUs',
				"The user this reply came from.",
				optional,
				singleItem, notEnumerated, Reserved13,
				"on", 'psL3', 'conM',
				"The connection this reply came on.",
				optional,
				singleItem, notEnumerated, Reserved13
			},

			"build contextual menu for item",
			"Called for every object that the user can access a contextual/action menu. This handler is called when the selection changes in a table or right before the menu is shown, allowing you to provide a list of titles to show.",
			'cplG', 'cMiX',
			reply_none__,
			'****',
			"Object that the user has requested a contextual menu for. Can be a member, chat room, direct chat, transcript, connection, text, etc.",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{
				"in", 'cMi1', 't007',
				"The chat panel this context menu is associated with, if any.",
				optional,
				singleItem, notEnumerated, Reserved13
			},

			"handle clicked contextual menu item",
			"Called when the user clicks on one of the supplied menu item titles you returned from the \"build contextual menu for item\".",
			'cplG', 'pcMX',
			reply_none__,
			'TEXT',
			"Menu item title you returned from the \"build contextual menu for item\"",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{
				"for", 'pcM1', '****',
				"Item the menu item was built for, can be a member, chat room, direct chat, transcript, chat connection, etc.",
				optional,
				singleItem, notEnumerated, Reserved13,
				"within", 'pcM2', 'TEXT',
				"A list of parent menu item titles the clicked menu item was when displayed. You only need to reference this when you use multiple items with the same name in different sub-menus.",
				optional,
				listOfItems, notEnumerated, Reserved13
			},

			"handle clicked link",
			"Called when a (currently unhandled) link is clicked in a conversation. Return true to prevent Colloquy and other plugins from handling this clicked link.",
			'cplG', 'hClX',
			'bool',
			"Return true to prevent other plugins from handling this link.",
			replyRequired, singleItem, notEnumerated, Reserved13,
			'TEXT',
			"The URL of the clicked link.",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{
				"in", 'hCl1', 't008',
				"The chat panel this link was clicked in.",
				optional,
				singleItem, notEnumerated, Reserved13
			},

			"perform notification",
			"Called for every notification event like Buddy Offline, Name Mentioned, Message Ignored, etc. If you want to trigger on select events you should use a more specific handler; this handler is intended for limited context, high-level notifications only.",
			'cplG', 'nOtX',
			reply_none__,
			'TEXT',
			"Identifier of the notification to perform.",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{
				"with", 'nOt1', 'reco',
				"Notification specific context information. Usually contains a human-readable message to display.",
				optional,
				singleItem, notEnumerated, Reserved13,
				"and", 'nOt2', 'reco',
				"Preferences for the notification. From the Notification preferences panel.",
				optional,
				singleItem, notEnumerated, Reserved13
			},

			"joined chat room",
			"Called when we join a room.",
			'cplG', 'jRmX',
			reply_none__,
			'crmM',
			"The chat room.",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{

			},

			"parting chat room",
			"Called when we are in the process of leaving a room. Messages can still be sent.",
			'cplG', 'pRmX',
			reply_none__,
			'crmM',
			"The chat room.",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{

			},

			"connected",
			"Called when we have just finished connecting to a chat server.",
			'cplG', 'cTsX',
			reply_none__,
			'conM',
			"The chat connection.",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{

			},

			"disconnecting",
			"Called when we are in the process of disconnecting from a chat server. Commands and messages can still be sent to the server.",
			'cplG', 'dFsX',
			reply_none__,
			'conM',
			"The chat connection.",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{

			},

			"kicked from room",
			"Called when we are kicked out of a room by another member.",
			'cplG', 'kRmX',
			reply_none__,
			'crmM',
			"The chat room.",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{
				"by", 'kRm1', 't011',
				"The member who kicked us out.",
				optional,
				singleItem, notEnumerated, Reserved13,
				"for", 'kRm2', 'ctxt',
				"The reason given for kicking us out.",
				optional,
				singleItem, notEnumerated, Reserved13
			},

			"member joined",
			"Called when a member joins a room we are also a member of.",
			'cplG', 'mJrX',
			reply_none__,
			'chmM',
			"The member.",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{
				"in", 'mJr1', 'crmM',
				"The chat room.",
				optional,
				singleItem, notEnumerated, Reserved13
			},

			"member parted",
			"Called when a member leaves a room we are also a member of.",
			'cplG', 'mPrX',
			reply_none__,
			'chmM',
			"The member.",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{
				"from", 'mPr1', 'crmM',
				"The chat room.",
				optional,
				singleItem, notEnumerated, Reserved13,
				"for", 'mPr2', 'ctxt',
				"The reason the member left.",
				optional,
				singleItem, notEnumerated, Reserved13
			},

			"member kicked",
			"Called when a member is kicked out of a room we are also a member of.",
			'cplG', 'mKrX',
			reply_none__,
			'chmM',
			"The member.",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{
				"from", 'mKr1', 'crmM',
				"The chat room.",
				optional,
				singleItem, notEnumerated, Reserved13,
				"by", 'mKr2', 't011',
				"The member who kicked the other member out.",
				optional,
				singleItem, notEnumerated, Reserved13,
				"for", 'mKr3', 'ctxt',
				"The reason the member was kicked.",
				optional,
				singleItem, notEnumerated, Reserved13
			},

			"topic changed",
			"Called when a member changes the room topic.",
			'cplG', 'rTcX',
			reply_none__,
			dp_none__,
			{
				"in", 'rTc3', 'crmM',
				"The chat room.",
				optional,
				singleItem, notEnumerated, Reserved13,
				"by", 'rTc2', 't011',
				"The member who changed the topic.",
				optional,
				singleItem, notEnumerated, Reserved13,
				"to", 'rTc1', 'ctxt',
				"The new room topic.",
				optional,
				singleItem, notEnumerated, Reserved13
			},

			"idle",
			"Automatically starts firing as soon as the script initializes, it will continue to fire periodically until the user quits the application. The default interval is 5 seconds, return a new interval to change the wait period for the next call.",
			'cplG', 'iDlX',
			'doub',
			"Return a new interval to change the wait period for the next call.",
			replyRequired, singleItem, notEnumerated, Reserved13,
			dp_none__,
			{

			},

			"load",
			"Called when the script is loaded into the host application.",
			'cplG', 'lOdX',
			reply_none__,
			dp_none__,
			{
				"from", 'lOd1', 'file',
				"The path the script was loaded from.",
				optional,
				singleItem, notEnumerated, Reserved13
			},

			"unload",
			"Called right before the script is unloaded from the host application. The script might be loaded again if a reload is being performed.",
			'cplG', 'uldX',
			reply_none__,
			dp_none__,
			{

			}
		},
		{
			/* Classes */

		},
		{
			/* Comparisons */
		},
		{
			/* Enumerations */
		},

		"Text Suite",
		"A set of basic classes for text processing.",
		'????',
		1,
		1,
		{
			/* Events */

		},
		{
			/* Classes */

			"rich text", 'ctxt',
			"Rich (styled) text",
			{
				"color", 'colr', 'colr',
				"The color of the first character.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"background color", 'bCol', 'colr',
				"The background color of the first character.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"font", 'font', 'TEXT',
				"The name of the font of the first character.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"size", 'ptsz', 'long',
				"The size in points of the first character.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"HTML start", 'htMs', 'TEXT',
				"The HTML that directly proceeds the first character. This would include start tags or self-closing tags.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"HTML end", 'htMe', 'TEXT',
				"The HTML that directly follows the first character or end of the attribute run. This would include end tags.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"style classes", 'stYc', 'TEXT',
				"The stylesheet classes of the first character.",
				reserved, listOfItems, notEnumerated, readWrite, Reserved12,

				"link", 'liNk', 'TEXT',
				"The Internet link of the first character.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"bold", 'bOld', 'bool',
				"The bold state of the first character.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"italic", 'iTlc', 'bool',
				"The italic state of the first character.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"underline", 'unDl', 'bool',
				"The underline state of the first character.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12
			},
			{
				'cpar', { },
				'cwor', { },
				'cha ', { },
				'catr', { },
				'atts', { }
			},
			"rich text", 'ctxt', plural__,

			"attachment", 'atts',
			"Represents an inline text attachment. This class is used mainly for make commands.",
			{
				"<Inheritance>", pInherits, 'ctxt',
				"inherits elements and properties of the rich text class.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12,

				"file name", 'atfn', 'ctxt',
				"The path to the file for the attachment",
				reserved, singleItem, notEnumerated, readWrite, Reserved12
			},
			{
			},
			"attachments", 'atts', plural__,

			"paragraph", 'cpar',
			"This subdivides the text into paragraphs.",
			{
				"<Inheritance>", pInherits, 'ctxt',
				"inherits elements and properties of the rich text class.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12
			},
			{
			},
			"paragraphs", 'cpar', plural__,

			"word", 'cwor',
			"This subdivides the text into words.",
			{
				"<Inheritance>", pInherits, 'ctxt',
				"inherits elements and properties of the rich text class.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12
			},
			{
			},
			"words", 'cwor', plural__,

			"character", 'cha ',
			"This subdivides the text into characters.",
			{
				"<Inheritance>", pInherits, 'ctxt',
				"inherits elements and properties of the rich text class.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12
			},
			{
			},
			"characters", 'cha ', plural__,

			"attribute run", 'catr',
			"This subdivides the text into chunks that all have the same attributes.",
			{
				"<Inheritance>", pInherits, 'ctxt',
				"inherits elements and properties of the rich text class.",
				reserved, singleItem, notEnumerated, readOnly, Reserved12
			},
			{
			},
			"attribute runs", 'catr', plural__
		},
		{
			/* Comparisons */
		},
		{
			/* Enumerations */
		}
	}
};
