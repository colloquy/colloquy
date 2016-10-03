#include <AvailabilityMacros.h>

#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFPlugInCOM.h>
#include <CoreServices/CoreServices.h>
#include "GetMetadataForFile.h"

#define PLUGIN_ID "BEB8A52D-7759-4331-9C3D-088295CF7E97"

// The layout for an instance of MetaDataImporterPlugIn
typedef struct __MetadataImporterPluginType
{
	void        *interface;
	CFUUIDRef    factoryID;
	UInt32       refCount;
} MDImportPlug;


static MDImportPlug *AllocMetadataImporterPluginType(CFUUIDRef inFactoryID);
static void          DeallocMetadataImporterPluginType(MDImportPlug *thisInstance);
static HRESULT       MetadataImporterQueryInterface(void *thisInstance,REFIID iid,LPVOID *ppv);
extern void         *MetadataImporterPluginFactory(CFAllocatorRef allocator,CFUUIDRef typeID);
static ULONG         MetadataImporterPluginAddRef(void *thisInstance);
static ULONG         MetadataImporterPluginRelease(void *thisInstance);

static MDImporterInterfaceStruct testInterfaceFtbl = {
	NULL,
	MetadataImporterQueryInterface,
	MetadataImporterPluginAddRef,
	MetadataImporterPluginRelease,
	GetMetadataForFile
};

static MDImporterURLInterfaceStruct testURLInterfaceFtbl = {
	NULL,
	MetadataImporterQueryInterface,
	MetadataImporterPluginAddRef,
	MetadataImporterPluginRelease,
	GetMetadataForURL
};

MDImportPlug *AllocMetadataImporterPluginType(CFUUIDRef inFactoryID)
{
	MDImportPlug *theNewInstance;
	
	theNewInstance = (MDImportPlug *)calloc(sizeof(MDImportPlug), 1);
	
	/* Point to the function table */
	theNewInstance->interface = malloc(sizeof(MDImporterInterfaceStruct));
	memcpy(theNewInstance->interface, &testInterfaceFtbl, sizeof(MDImporterInterfaceStruct));
	
	/*  Retain and keep an open instance refcount for each factory. */
	theNewInstance->factoryID = CFRetain(inFactoryID);
	CFPlugInAddInstanceForFactory(inFactoryID);
	
	/* This function returns the IUnknown interface so set the refCount to one. */
	theNewInstance->refCount = 1;
	return theNewInstance;
}

void DeallocMetadataImporterPluginType(MDImportPlug *thisInstance)
{
	free(thisInstance->interface);
	CFUUIDRef theFactoryID = thisInstance->factoryID;
	
	free(thisInstance);
	if (theFactoryID){
		CFPlugInRemoveInstanceForFactory(theFactoryID);
		CFRelease(theFactoryID);
	}
}

HRESULT MetadataImporterQueryInterface(void *thisInstance,REFIID iid,LPVOID *ppv)
{
	CFUUIDRef interfaceID;
	
	interfaceID = CFUUIDCreateFromUUIDBytes(kCFAllocatorDefault, iid);
	
	if (CFEqual(interfaceID, kMDImporterURLInterfaceID)) {
		/* If the right interface was requested, bump the ref count,
		 * set the ppv parameter equal to the instance, and
		 * return good status.
		 */
		memcpy(((MDImportPlug *)thisInstance)->interface, &testURLInterfaceFtbl, sizeof(MDImporterURLInterfaceStruct));
		((MDImporterURLInterfaceStruct*)((MDImportPlug *)thisInstance)->interface)->AddRef(thisInstance);
		*ppv = thisInstance;
		CFRelease(interfaceID);
		return S_OK;
	} else if (CFEqual(interfaceID, kMDImporterInterfaceID)) {
		/* If the right interface was requested, bump the ref count,
		 * set the ppv parameter equal to the instance, and
		 * return good status.
		 */
		memcpy(((MDImportPlug *)thisInstance)->interface, &testInterfaceFtbl, sizeof(MDImporterInterfaceStruct));
		((MDImporterInterfaceStruct*)((MDImportPlug *)thisInstance)->interface)->AddRef(thisInstance);
        *ppv = thisInstance;
        CFRelease(interfaceID);
        return S_OK;
	} else if (CFEqual(interfaceID, IUnknownUUID)) {
		/* If the IUnknown interface was requested, same as above. */
		memcpy(((MDImportPlug *)thisInstance)->interface, &testInterfaceFtbl, sizeof(MDImporterInterfaceStruct));
		((MDImporterInterfaceStruct*)((MDImportPlug *)thisInstance)->interface)->AddRef(thisInstance);
		*ppv = thisInstance;
		CFRelease(interfaceID);
		return S_OK;
	} else {
		/* Requested interface unknown, bail with error. */
		*ppv = NULL;
		CFRelease(interfaceID);
		return E_NOINTERFACE;
	}
}

ULONG MetadataImporterPluginAddRef(void *thisInstance)
{
	return ++((MDImportPlug *)thisInstance)->refCount;
}

ULONG MetadataImporterPluginRelease(void *thisInstance)
{
	((MDImportPlug*)thisInstance)->refCount--;
	if (((MDImportPlug*)thisInstance)->refCount == 0) {
		DeallocMetadataImporterPluginType((MDImportPlug*)thisInstance );
		return 0;
	} else {
		return ((MDImportPlug*) thisInstance )->refCount;
	}
}

void *MetadataImporterPluginFactory(CFAllocatorRef allocator,CFUUIDRef typeID)
{
	MDImportPlug    *result;
	CFUUIDRef        uuid;
	
	/* If correct type is being requested, allocate an
	 * instance of TestType and return the IUnknown interface.
	 */
	if (CFEqual(typeID, kMDImporterTypeID)){
		uuid = CFUUIDCreateFromString(kCFAllocatorDefault, CFSTR(PLUGIN_ID));
		result = AllocMetadataImporterPluginType(uuid);
		CFRelease(uuid);
		return result;
	}
	/* If the requested type is incorrect, return NULL. */
	return NULL;
}
