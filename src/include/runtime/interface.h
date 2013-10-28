/* IBM_PROLOG_BEGIN_TAG                                                   */
/* This is an automatically generated prolog.                             */
/*                                                                        */
/* $Source: src/include/runtime/interface.h $                             */
/*                                                                        */
/* IBM CONFIDENTIAL                                                       */
/*                                                                        */
/* COPYRIGHT International Business Machines Corp. 2013                   */
/*                                                                        */
/* p1                                                                     */
/*                                                                        */
/* Object Code Only (OCO) source materials                                */
/* Licensed Internal Code Source Materials                                */
/* IBM HostBoot Licensed Internal Code                                    */
/*                                                                        */
/* The source code for this program is not published or otherwise         */
/* divested of its trade secrets, irrespective of what has been           */
/* deposited with the U.S. Copyright Office.                              */
/*                                                                        */
/* Origin: 30                                                             */
/*                                                                        */
/* IBM_PROLOG_END_TAG                                                     */
#ifndef __RUNTIME__INTERFACE_H
#define __RUNTIME__INTERFACE_H

/** @file interface.h
 *  @brief Interfaces between Hostboot Runtime and Sapphire.
 *
 *  This file has two structures of function pointers: hostInterfaces_t and
 *  runtimeInterfaces_t.  hostInterfaces are provided by Sapphire (or a
 *  similar environment, such as Hostboot IPL's CxxTest execution).
 *  runtimeInterfaces are provided by Hostboot Runtime to Sapphire.
 *
 *  @note This file must be in C rather than C++.
 */

#include <stdint.h>

/** @typedef hostInterfaces_t
 *  @brief Interfaces provided by the underlying environment (ex. Sapphire).
 *
 *  @note Some of these functions are not required (marked optional) and
 *        may be NULL.
 */
typedef struct hostInterfaces
{
    /** Put a string to the console. */
    void (*puts)(const char*);
    /** Critical failure in runtime execution. */
    void (*assert)();

    /** OPTIONAL. Hint to environment that the page may be executed. */
    int (*set_page_execute)(void*);

    /** malloc */
    void* (*malloc)(size_t);
    /** free */
    void (*free)(void*);
    /** realloc */
    void* (*realloc)(void*, size_t);

    /** sendErrorLog 
     * @param[in] plid Platform Log identifier
     * @param[in] data size in bytes
     * @param[in] pointer to data
     * @return 0 on success else error code
     */
    int (*sendErrorLog)(uint32_t,uint32_t,void *); 

    /** Scan communication read
     * @param[in] chip_id (based on devtree defn)
     * @param[in] address
     * @param[in] pointer to 8-byte data buffer
     * @return 0 on success else return code
     */
    int (*scom_read)(uint32_t, uint32_t, void*);

    /** Scan communication write
     * @param[in] chip_id (based on devtree defn)
     * @param[in] address
     * @param[in] pointer to 8-byte data buffer
     * @return 0 on success else return code
     */
    int (*scom_write)(uint32_t, uint32_t, void* );

} hostInterfaces_t;

typedef struct runtimeInterfaces
{
    /** Execute CxxTests that may be contained in the image.
     *
     *  @param[in] - Pointer to CxxTestStats structure for results reporting.
     */
    void (*cxxtestExecute)(void*);

} runtimeInterfaces_t;

#ifdef __HOSTBOOT_RUNTIME
extern hostInterfaces_t* g_hostInterfaces;
runtimeInterfaces_t* getRuntimeInterfaces();
#endif

#endif