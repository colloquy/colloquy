#  Notes for the WIP Reorganization of the Repository

The goal is to clearly separate the sources, resources and supporting files away from the top level into the directories of the project that they actually belong to. This will make it easier to
- Share code through frameworks between iOS and Mac, instead of having source files that belong to two projects at the same time
- Keep Mac-Old (2.x) on maintenance mode, while re-starting work on Mac (3.x)

## /Resources
- Most files will move / have moved to /Mac-Old/Mac-Old/Resources
- To be decided:
	- Used by Mac-Old and ChatCore:
		- /Resources/ChatCore.scriptTerminology
		- /Resources/ChatCore.scriptSuite
	- Used by Mac-Old and iOS:
		- /Resources/Sounds	
