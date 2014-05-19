// Copyright © 2014 Dmitry Rodionov i.am.rodionovd@gmail.com
// This work is free. You can redistribute it and/or modify it
// under the terms of the Do What The Fuck You Want To Public License, Version 2,
// as published by Sam Hocevar. See the COPYING file for more details.


#ifndef RD_ROUTE
	#define RD_ROUTE

/**
 * Override `function` to jump directly into `replacement` location. Caller can later
 * access an original function's implementation via `original_ptr` (if passed).
 * Note that `original_ptr` won't be equal to `function` due to remapping the latter
 * into a different memory space.
 *
 * @param  function    pointer to a function to override;
 * @param  replacement pointer to new implementation;
 * @param  original    will be set to an address of the original implementation's copy;
 *
 * @return             KERN_SUCCESS if succeeded, or other value if failed
 */
	int rd_route(void *function, void *replacement, void **original);
/**
 * Copy `function` implementation into another (first available) memory region.
 * @param  function  pointer to a function to override;
 * @param  duplicate will be set to an address of the function's implementation copy
 *
 * @return KERN_SUCCESS if succeeded, or other value if failed
 */
	int rd_duplicate_function(void *function, void **duplicate);
#endif


