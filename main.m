//
//  main.m
//  ultra43
//
//  Created by msftguy on 1/17/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//
#include "substrate.h"
#include <mach-o/dyld.h>
#include <mach-o/getsect.h>
#include <stdio.h>
//#include <unistd.h>
#include <sys/sysctl.h>

static FILE * (*s_orig_fopen) ( const char * filename, const char * mode );

static const char* xgold_libname = "/usr/share/ultrasn0w/ultrasn0w-xgold608.dylib";
static const char* i4_libname = "/Library/MobileSubstrate/DynamicLibraries/ultrasn0w.dylib";
static const char* ultrasnow_log = "/var/wireless/Library/Logs/ultrasn0w-dylib.log";

static void* s_orig_findReference;
static size_t (*s_orig_FindLastThumbFunction)(size_t, int);

#define LOGPREFIX "ultrasn0w_fixer: "

typedef struct {size_t symOff; size_t refOff; size_t thumbFn_start;} REF_ENTRY;

#include "ref_table.h"

static size_t my_FindReference(size_t addr)
{
	int slide = _dyld_get_image_vmaddr_slide(0);
	size_t symOff = addr - slide;
	size_t refOff = 0;
	for (int i = 0; i < sizeof(ref_table) / sizeof(REF_ENTRY); ++i) {
		if (ref_table[i].symOff == symOff) {
			refOff = ref_table[i].refOff;
			break;
		}
	}
	if (refOff == 0) {
		fprintf(stderr, LOGPREFIX "my_FindReference failed for 0x%lx\n", symOff);
		return 0;
	}
	fprintf(stderr, LOGPREFIX "my_FindReference OK for 0x%lx: 0x%x + 0x%lx\n", symOff, slide, refOff);
	return slide + refOff;
}

static size_t my_FindLastThumbFunction(size_t start, int maxlen)
{
    size_t result = 0;
    int slide = _dyld_get_image_vmaddr_slide(0);
    size_t refOff = start - slide;
    size_t fnStart = 0;
    // FindLastThumbFunction doesn't want to detect 0xF0 0xB5 as a prolog ?
	for (int i = 0; i < sizeof(ref_table) / sizeof(REF_ENTRY); ++i) {
		if (ref_table[i].refOff == refOff) {
			fnStart = ref_table[i].thumbFn_start;
			break;
		}
	}

    if (fnStart != 0)
        result = slide + fnStart;
    else
        result = s_orig_FindLastThumbFunction(start, maxlen);
    fprintf(stderr, LOGPREFIX "FindLastThumbFunction(0x%lx, 0x%x) = 0x%lx [+0x%x]%s", 
            start - slide, maxlen, result - slide, slide, fnStart ? " **fixed**":"");
    return result;
}

static void hook_ultrasn0w(const char* target_dylib)
{
	static bool hooked = false;
	if (hooked)
		return;

	fprintf(stderr, LOGPREFIX "Target dylib: %s", target_dylib);
    void* us_lib = dlopen(target_dylib, RTLD_LAZY);
	if (!us_lib) {
		fprintf(stderr, LOGPREFIX "dlopen(%s) FAILED\n", target_dylib);
		return;
	}
	void* pfnFindReference = dlsym(us_lib, "FindReference");
	if (!pfnFindReference) {
		fprintf(stderr, LOGPREFIX "dlsym('FindReference') FAILED\n");
		return;
	}
	MSHookFunction(pfnFindReference, my_FindReference, &s_orig_findReference);
	fprintf(stderr, LOGPREFIX "hooked FindReference\n");
    
	void* pfnFindLastThumbFunction = dlsym(us_lib, "FindLastThumbFunction");
	if (!pfnFindLastThumbFunction) {
		fprintf(stderr, LOGPREFIX "dlsym('FindLastThumbFunction') FAILED\n");
		return;
	}
	MSHookFunction(pfnFindLastThumbFunction, my_FindLastThumbFunction, (void**)&s_orig_FindLastThumbFunction);
	fprintf(stderr, LOGPREFIX "hooked FindLastThumbFunction\n");
    
	hooked = true;	
}

static int is_3gs()
{
    char namebuf[0x100];
    int mib[2] = {CTL_HW, HW_MODEL};
    unsigned long size = sizeof(namebuf);
    int result = sysctl(mib, sizeof(mib)/sizeof(*mib), namebuf, &size, nil, 0);
    if (result != 0) {
        fprintf(stderr, LOGPREFIX "sysctl({CTL_HW, HW_MODEL}) failed, unknown model\n");        
        return NO;
    }
    namebuf[sizeof(namebuf)-1] = '\0';
    fprintf(stderr, LOGPREFIX "sysctl({CTL_HW, HW_MODEL}) = '%s'\n", namebuf);        
    return 0 == strcasecmp(namebuf, "N88AP");
}

static FILE * my_fopen ( const char * filename, const char * mode )
{
	if ((filename != NULL) && 
        (0 == strcmp(filename, ultrasnow_log))) 
    {
        hook_ultrasn0w(is_3gs() ? xgold_libname : i4_libname);
    }
	return s_orig_fopen(filename, mode);
}

static void entry(void)  __attribute__ ((constructor));

static void entry(void) {
	fprintf(stderr, LOGPREFIX "loaded\n");
	MSHookFunction(fopen, my_fopen, (void*)&s_orig_fopen);
}
