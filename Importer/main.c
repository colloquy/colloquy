#include <AvailabilityMacros.h>

#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFPlugInCOM.h>
#include <CoreServices/CoreServices.h>
#include "GetMetadataForFile.h"

#define PLUGIN_ID "BEB8A52D-7759-4331-9C3D-088295CF7E97"

// The layout for an instance of MetaDataImporterPlugIn
typedef struct __MetadataImporterPluginType
{
	union _iface {
		MDImporterInterfaceStruct *fileInterface;
		MDImporterURLInterfaceStruct *URLInterface;
	} interface;
	CFUUIDRef                 factoryID;
	UInt32                    refCount;
} MetadataImporterPluginType;


static MetadataImporterPluginType	*AllocMetadataImporterPluginType(CFUUIDRef inFactoryID);
static void							 DeallocMetadataImporterPluginType(MetadataImporterPluginType *thisInstance);
static HRESULT						 MetadataImporterQueryInterface(void *thisInstance,REFIID iid,LPVOID *ppv);
extern void							*MetadataImporterPluginFactory(CFAllocatorRef allocator,CFUUIDRef typeID);
static ULONG						 MetadataImporterPluginAddRef(void *thisInstance);
static ULONG						 MetadataImporterPluginRelease(void *thisInstance);

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

MetadataImporterPluginType *AllocMetadataImporterPluginType(CFUUIDRef inFactoryID)
{
	MetadataImporterPluginType *theNewInstance;
	
	theNewInstance = (MetadataImporterPluginType *)calloc(sizeof(MetadataImporterPluginType), 1);
	
	/* Point to the function table */
	theNewInstance->interface.fileInterface = &testInterfaceFtbl;
	
	/*  Retain and keep an open instance refcount for each factory. */
	theNewInstance->factoryID = CFRetain(inFactoryID);
	CFPlugInAddInstanceForFactory(inFactoryID);
	
	/* This function returns the IUnknown interface so set the refCount to one. */
	theNewInstance->refCount = 1;
	return theNewInstance;
}

void DeallocMetadataImporterPluginType(MetadataImporterPluginType *thisInstance)
{
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
	
	interfaceID = CFUUIDCreateFromUUIDBytes(kCFAllocatorDefault,iid);
	
	if (CFEqual(interfaceID, kMDImporterURLInterfaceID)) {
		/* If the right interface was requested, bump the ref count,
		 * set the ppv parameter equal to the instance, and
		 * return good status.
		 */
		((MetadataImporterPluginType *)thisInstance)->interface.URLInterface = &testURLInterfaceFtbl;
		((MetadataImporterPluginType *)thisInstance)->interface.URLInterface->AddRef(thisInstance);
		*ppv = thisInstance;
		CFRelease(interfaceID);
		return S_OK;
	} else if (CFEqual(interfaceID, kMDImporterInterfaceID)){
		/* If the right interface was requested, bump the ref count,
		 * set the ppv parameter equal to the instance, and
		 * return good status.
		 */
        ((MetadataImporterPluginType*)thisInstance)->interface.fileInterface = &testInterfaceFtbl;
        ((MetadataImporterPluginType*)thisInstance)->interface.fileInterface->AddRef(thisInstance);
        *ppv = thisInstance;
        CFRelease(interfaceID);
        return S_OK;
	} else if (CFEqual(interfaceID, IUnknownUUID)) {
		/* If the IUnknown interface was requested, same as above. */
		((MetadataImporterPluginType*)thisInstance)->interface.fileInterface = &testInterfaceFtbl;
		((MetadataImporterPluginType*)thisInstance)->interface.fileInterface->AddRef(thisInstance);
		*ppv = thisInstance;
		CFRelease(interfaceID);
		return S_OK;
	}else{
		/* Requested interface unknown, bail with error. */
		*ppv = NULL;
		CFRelease(interfaceID);
		return E_NOINTERFACE;
	}
}

ULONG MetadataImporterPluginAddRef(void *thisInstance)
{
	return ++((MetadataImporterPluginType *)thisInstance)->refCount;
}

ULONG MetadataImporterPluginRelease(void *thisInstance)
{
	((MetadataImporterPluginType*)thisInstance)->refCount--;
	if (((MetadataImporterPluginType*)thisInstance)->refCount == 0) {
		DeallocMetadataImporterPluginType((MetadataImporterPluginType*)thisInstance );
		return 0;
	}else{
		return ((MetadataImporterPluginType*) thisInstance )->refCount;
	}
}

void *MetadataImporterPluginFactory(CFAllocatorRef allocator,CFUUIDRef typeID)
{
	MetadataImporterPluginType *result;
	CFUUIDRef					uuid;
	
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
