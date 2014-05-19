// Copyright © 2014 Dmitry Rodionov i.am.rodionovd@gmail.com
// This work is free. You can redistribute it and/or modify it
// under the terms of the Do What The Fuck You Want To Public License, Version 2,
// as published by Sam Hocevar. See the COPYING file for more details.
#import <stdlib.h>         // realloc()
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

static mach_vm_size_t _get_image_size(void *image, mach_vm_size_t image_slide);
static kern_return_t  _remap_image(void *image,  mach_vm_size_t image_slide, mach_vm_address_t *new_location);
static kern_return_t  _insert_jmp(void* where, void* to);
static kern_return_t  _patch_memory(void *address, mach_vm_size_t count, uint8_t *new_bytes);


int rd_route(void *function, void *replacement, void **original_ptr)
{
	int ret = rd_duplicate_function(function, original_ptr);
	if (ret == KERN_SUCCESS) {
		ret =  _insert_jmp(function, replacement);
	}

	return (ret);
}


int rd_duplicate_function(void *function, void **duplicate)
{
	kern_return_t err = KERN_FAILURE;

	if (!function) {
		return (err);
	}
	if (!duplicate) {
		/* Copy to nowhere == not to copy */
		return KERN_SUCCESS;
	}

	void *image = NULL;
	mach_vm_size_t image_slide = 0;

	/* Obtain the macho header image which contains the function */
	Dl_info image_info = {0};
	if (dladdr(function, &image_info)) {
		image = image_info.dli_fbase;
	}

	if (!image) {
		fprintf(stderr, "Could not found an appropriate image\n");
		return KERN_FAILURE;
	}


	for (uint32_t i = 0; i < _dyld_image_count(); i++) {
		if (image == _dyld_get_image_header(i)) {
			image_slide = _dyld_get_image_vmaddr_slide(i);
			break;
		}
	}

	static rd_injection_t *injection_history = NULL;
	static uint16_t history_size = 0;
	/* Look up the injection history if we already have this image remapped. */
	for (uint16_t i = 0; i < history_size; i++) {
		if (injection_history[i].injected_mach_header == (mach_vm_address_t)image) {
			if (duplicate) {
				*duplicate = (void *)injection_history[i].target_address + (function - image);
			}
			return KERN_SUCCESS;
		}
	}

	/**
	 * Take a note that we have already remapped this mach-o image, so won't do this
	 * again when routing another function from the image.
	 */
	size_t new_size = history_size + 1;
	injection_history = realloc(injection_history, sizeof(*injection_history) * new_size);
	injection_history[history_size].injected_mach_header = (mach_vm_address_t)image;
	injection_history[history_size].target_address = ({
		mach_vm_address_t target = 0;
		err = _remap_image(image, image_slide, &target);
		if (KERN_SUCCESS != err) {
			fprintf(stderr, "ERROR: Failed remapping segements of the image [0x%x]\n", err);
			return (err);
		}
		/* Backup an original function implementation if needed */
		if (duplicate) {
			*duplicate = (void *)(target + (function - image));
		}

		target;
	});

	history_size = new_size;

	return KERN_SUCCESS;
}


__attribute__((noinline))
static kern_return_t _remap_image(void *image, mach_vm_size_t image_slide, mach_vm_address_t *new_location)
{
	if (image == NULL) {
		return KERN_FAILURE;
	}

	mach_vm_size_t image_size = _get_image_size(image, image_slide);
	kern_return_t err = KERN_FAILURE;
	/**
	 * For some reason we need more free space when for 64-bit code.
	 * Looks like _remap_image() remaps a "__DATA" section BEFORE target — SO BUG.
	 *
	 * FIX OR DIE.
	 */
	*new_location = 0;
#if defined(__x86_64__)
	err = mach_vm_allocate(mach_task_self(), new_location, image_size*3, VM_FLAGS_ANYWHERE);
	mach_vm_size_t lefover = image_size * 2;
	*new_location += lefover;
	mach_vm_deallocate(mach_task_self(), (*new_location - lefover), lefover);
#else
	err = mach_vm_allocate(mach_task_self(), new_location, image_size, VM_FLAGS_ANYWHERE);
#endif

	if (KERN_SUCCESS != err) {
		fprintf(stderr, "ERROR: Failed allocating memory region for the copy. %d\n", err);
		return (err);
	}

	const mach_header_t *header = (mach_header_t *)image;
	struct load_command *cmd = (struct load_command *)(header + 1);

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
				mach_vm_address_t seg_target = *new_location + (seg_source - (mach_vm_address_t)header);

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
			}
		}
		cmd = (struct load_command *)((uintptr_t)cmd + cmd->cmdsize);
	}

	return (err);
}


static mach_vm_size_t _get_image_size(void *image, mach_vm_size_t image_slide)
{
	if (!image) {
		return 0;
	}
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


static kern_return_t _insert_jmp(void* where, void* to)
{
	/**
	 * We are going to use an absolute JMP instruction for x86_64
	 * and a relative one for i386.
	 */
#if defined (__x86_64__)
	mach_vm_size_t size_of_jump = (sizeof(uintptr_t) * 2);
#else
	mach_vm_size_t size_of_jump = (sizeof(int) + 1);
#endif

	kern_return_t err = KERN_SUCCESS;
	uint8_t opcodes[size_of_jump];
#if defined(__x86_64__)
	opcodes[0] = 0xFF;
	opcodes[1] = 0x25;
	*((int*)&opcodes[2]) = 0;
	*((uintptr_t*)&opcodes[6]) = (uintptr_t)to;
	err = _patch_memory((void *)where, size_of_jump, opcodes);
#else
	int offset = (int)(to - where - size_of_jump);
	opcodes[0] = 0xE9;
	*((int*)&opcodes[1]) = offset;
	err = _patch_memory((void *)where, size_of_jump, opcodes);
#endif

	return (err);
}


static kern_return_t _patch_memory(void *address, mach_vm_size_t count, uint8_t *new_bytes)
{
	if (count == 0) {
		return KERN_SUCCESS;
	}
	if (!address || !new_bytes) {
		return KERN_INVALID_ARGUMENT;
	}
	kern_return_t kr = 0;

	kr = mach_vm_protect(mach_task_self(), (mach_vm_address_t)address, (mach_vm_size_t)count, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE | VM_PROT_COPY);
	if (kr != KERN_SUCCESS) {
		fprintf(stderr, "ERROR: mach_vm_protect() failed with error: %d [Line %d]\n", kr, __LINE__);
		return (kr);
	}
	kr = mach_vm_write(mach_task_self(), (mach_vm_address_t)address, (vm_offset_t)new_bytes, count);
	if (kr != KERN_SUCCESS) {
		fprintf(stderr, "ERROR: mach_vm_write() failed with error: %d [Line %d]\n", kr, __LINE__);
		return (kr);
	}
	kr = mach_vm_protect(mach_task_self(), (mach_vm_address_t)address, (mach_vm_size_t)count, FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
	if (kr != KERN_SUCCESS) {
		fprintf(stderr, "ERROR: mach_vm_protect() failed with error: %d [Line %d]\n", kr, __LINE__);
	}

	return (kr);
}
