// Copyright © 2014 Dmitry Rodionov i.am.rodionovd@gmail.com
// This work is free. You can redistribute it and/or modify it
// under the terms of the Do What The Fuck You Want To Public License, Version 2,
// as published by Sam Hocevar. See the COPYING file for more details.

#import <stdio.h>          // fprintf()
#import <dlfcn.h>          // dladdr()
#import <mach/mach_vm.h>   // mach_vm_*
#import <mach-o/dyld.h>    // _dyld_*
#import <mach/mach_init.h> // mach_task_self()
#import "rd_route.h"


#if defined(__x86_64__)
	typedef struct mach_header_64     mach_header_t;
	typedef struct segment_command_64 segment_command_t;
	#define LC_SEGMENT_ARCH_INDEPENDENT   LC_SEGMENT_64
#else
	typedef struct mach_header        mach_header_t;
	typedef struct segment_command    segment_command_t;
	#define LC_SEGMENT_ARCH_INDEPENDENT   LC_SEGMENT
#endif

typedef struct rd_injection {
	mach_vm_address_t injected_mach_header;
	mach_vm_address_t target_address;
} rd_injection_t;

#define kRDInjectionHistoryCapacity 10
static rd_injection_t injection_history[kRDInjectionHistoryCapacity] = {{0}};
static uint16_t       injection_history_length = 0;

static void             *image = NULL;
static mach_vm_size_t    image_slide = 0;
static mach_vm_address_t target = 0;

static mach_vm_size_t _get_image_size(void);
static kern_return_t  _remap_image(void);
static kern_return_t  _hard_hook_function(void* function, void* replacement);


int rd_route(void *function, void *replacement, void **original_ptr)
{
	kern_return_t err = KERN_FAILURE;

	/* Obtain the macho header image which contains the function */
	Dl_info image_info = {0};
	if (dladdr(function, &image_info)) {
		image = image_info.dli_fbase;
	}
	for (uint32_t i = 0; i < _dyld_image_count(); i++) {
		if (image == _dyld_get_image_header(i)) {
			image_slide = _dyld_get_image_vmaddr_slide(i);
			break;
		}
	}

	/* Look up the injections history if we already have this image remapped. */
	for (uint16_t i = 0; i < injection_history_length; i++) {
		if (injection_history[i].injected_mach_header == (mach_vm_address_t)image) {
			if (original_ptr) {
				*original_ptr = (void *)injection_history[i].target_address + (function - image);
			}
			return _hard_hook_function(function, replacement);
		}
	}

	mach_vm_size_t image_size = _get_image_size();

	/**
	 * For some reason we need a more free space when in 64-bit mode.
	 * Looks like _remap_image() remaps a "__DATA" section BEFORE `target` — SO BUG.
	 * FIX OR DIE.
	 */
	target = 0;
#if defined(__x86_64__)
	err = mach_vm_allocate(mach_task_self(), &target, image_size*3, VM_FLAGS_ANYWHERE);
	mach_vm_size_t lefover = image_size * 2;
	target += lefover;
	mach_vm_deallocate(mach_task_self(), (target - lefover), lefover);
#else
	err = mach_vm_allocate(mach_task_self(), &target, image_size, VM_FLAGS_ANYWHERE);
#endif

	if (KERN_SUCCESS != err) {
		fprintf(stderr, "ERROR: Failed allocating memory region for the copy. %d\n", err);
    	return (err);
	}

	err = _remap_image();
	if (KERN_SUCCESS != err) {
		fprintf(stderr, "ERROR: Failed remapping segements into the target [0x%x]\n", err);
    	return (err);
	}

	/**
	 * Take a note that we have already remapped this mach-o image, so won't do this
	 * again when routing another function from the image.
	 */
	injection_history[injection_history_length].injected_mach_header = (mach_vm_address_t)image;
	injection_history[injection_history_length].target_address = target;
	++injection_history_length;

	if (original_ptr) {
		*original_ptr = (void *)(target + (function - image));
	}

	return _hard_hook_function(function, replacement);
}


static mach_vm_size_t _get_image_size(void)
{
	const mach_header_t *header = (mach_header_t *)image;

	struct load_command *cmd = (struct load_command *)(header + 1);

	mach_vm_address_t image_addr = (mach_vm_address_t)image - image_slide;
	mach_vm_address_t image_end = image_addr;


	for (uint32_t i = 0; (i < header->ncmds) && (NULL != cmd); i++) {
		if (cmd->cmd == LC_SEGMENT_ARCH_INDEPENDENT) {
			segment_command_t *segment = (segment_command_t *)cmd;
			if ((segment->vmaddr + segment->vmsize) > image_end) {

				image_end = segment->vmaddr + segment->vmsize;
			}
		}
		cmd = (struct load_command *)((uintptr_t)cmd + cmd->cmdsize);
	}

	return (image_end - image_addr);
}

__attribute__((noinline))
static kern_return_t _remap_image(void)
{
	const mach_header_t *header = (mach_header_t *)image;
	struct load_command *cmd = (struct load_command *)(header + 1);
	kern_return_t err = KERN_SUCCESS;

	/**
	 * Remap each segment of the mach-o image into a new location.
	 * New location is:
	 * -> target + segment.offset_in_image;
	 */
	for (uint32_t i = 0; (i < header->ncmds) && (NULL != cmd); i++) {
		if (cmd->cmd == LC_SEGMENT_ARCH_INDEPENDENT) {
			segment_command_t *segment = (segment_command_t *)cmd;
			{
				mach_vm_address_t vmaddr = segment->vmaddr;
				mach_vm_size_t    vmsize = segment->vmsize;

				if (vmsize == 0) {
					continue;
				}

				mach_vm_address_t seg_source = vmaddr + image_slide;
				mach_vm_address_t seg_target = (mach_vm_address_t)target + (seg_source - (mach_vm_address_t)header);

       			vm_prot_t cur_protection, max_protection;

        		err = mach_vm_remap(mach_task_self(),
                      &seg_target,
                      vmsize,
                      0x0,
                      (VM_FLAGS_FIXED | VM_FLAGS_OVERWRITE),
                      mach_task_self(),
                      seg_source,
                      false,
                      &cur_protection,
                      &max_protection,
                      VM_INHERIT_SHARE);

        		// if (err != KERN_SUCCESS) {
        		// 	fprintf(stderr, "ERROR: Failed remapping segement (#%d) into the target [0x%x]\n", i, err);
        		// }
			}
		}
		cmd = (struct load_command *)((uintptr_t)cmd + cmd->cmdsize);
	}

	return (err);
}

static kern_return_t
	_hard_hook_function(void* function, void* replacement)
{

	/**
	 * We are going to use an absolute JMP instruction for x86_64
	 * and a relative one for i386.
	 */
#if defined (__x86_64__)
	size_t size_of_jump = (sizeof(uintptr_t) * 2);
#else
	size_t size_of_jump = (sizeof(int) + 1);
#endif

	kern_return_t err = KERN_SUCCESS;
    err = mach_vm_protect(mach_task_self(),
    	(mach_vm_address_t)function,
    	size_of_jump,
    	false,
    	(VM_PROT_ALL | VM_PROT_COPY));
    if (KERN_SUCCESS != err) {
    	fprintf(stderr, "ERROR: Failed while vm_protect'ing original implementation\n");
    	return (err);
    }

	unsigned char opcodes[size_of_jump];
#if defined(__x86_64__)
	opcodes[0] = 0xFF;
	opcodes[1] = 0x25;
	*((int*)&opcodes[2]) = 0;
	*((uintptr_t*)&opcodes[6]) = (uintptr_t)replacement;
	memcpy((void*)function, opcodes, size_of_jump);
#else
	int offset = (int)(replacement - function - size_of_jump);
	opcodes[0] = 0xE9;
	*((int*)&opcodes[1]) = offset;
	memcpy((void*)function, opcodes, size_of_jump);
#endif

	return KERN_SUCCESS;
}
