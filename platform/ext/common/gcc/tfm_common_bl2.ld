;/*
; * SPDX-FileCopyrightText: Copyright The TrustedFirmware-M Contributors
; *
; * Licensed under the Apache License, Version 2.0 (the "License");
; * you may not use this file except in compliance with the License.
; * You may obtain a copy of the License at
; *
; *     http://www.apache.org/licenses/LICENSE-2.0
; *
; * Unless required by applicable law or agreed to in writing, software
; * distributed under the License is distributed on an "AS IS" BASIS,
; * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
; * See the License for the specific language governing permissions and
; * limitations under the License.
; *
; *
; * This file is derivative of CMSIS V5.00 gcc_arm.ld
; */

/* Linker script to configure memory regions. */
/* This file will be run through the pre-processor. */

#include "region_defs.h"

/* Include file with definitions for section alignments.
 * Note: it should be included after region_defs.h to let platform define
 * default values if needed. */
#include "tfm_s_linker_alignments.h"

MEMORY
{
    FLASH (rx)  : ORIGIN = BL2_CODE_START, LENGTH = BL2_CODE_SIZE
    RAM   (rwx) : ORIGIN = BL2_DATA_START, LENGTH = BL2_DATA_SIZE
}

__heap_size__  = BL2_HEAP_SIZE;
__msp_stack_size__ = BL2_MSP_STACK_SIZE;

ENTRY(Reset_Handler)

SECTIONS
{
    .text (READONLY) :
    {
        KEEP(*(.vectors))
        __Vectors_End = .;
        __Vectors_Size = __Vectors_End - __Vectors;
        __end__ = .;

        *(.text*)

        . = ALIGN(4);
        /* preinit data */
        PROVIDE_HIDDEN (__preinit_array_start = .);
        KEEP(*(.preinit_array))
        PROVIDE_HIDDEN (__preinit_array_end = .);

        . = ALIGN(4);
        /* init data */
        PROVIDE_HIDDEN (__init_array_start = .);
        KEEP(*(SORT(.init_array.*)))
        KEEP(*(.init_array))
        PROVIDE_HIDDEN (__init_array_end = .);

        . = ALIGN(4);
        /* finit data */
        PROVIDE_HIDDEN (__fini_array_start = .);
        KEEP(*(SORT(.fini_array.*)))
        KEEP(*(.fini_array))
        PROVIDE_HIDDEN (__fini_array_end = .);

        /* .copy.table */
        . = ALIGN(4);
        __copy_table_start__ = .;
#ifdef CODE_SHARING
        LONG (LOADADDR(.tfm_shared_symbols))
        LONG (ADDR(.tfm_shared_symbols))
        LONG (SIZEOF(.tfm_shared_symbols) / 4)    /* Aligment checked after the section */
#endif
        LONG (LOADADDR(.data))
        LONG (ADDR(.data))
        LONG (SIZEOF(.data) / 4)    /* Aligment checked after the section */
        __copy_table_end__ = .;

        /* .zero.table */
        . = ALIGN(4);
        __zero_table_start__ = .;
        LONG (ADDR(.bss))
        LONG (SIZEOF(.bss) / 4)    /* Aligment checked after the section */
        __zero_table_end__ = .;

        KEEP(*(.init))
        KEEP(*(.fini))

        /* .ctors */
        *crtbegin.o(.ctors)
        *crtbegin?.o(.ctors)
        *(EXCLUDE_FILE(*crtend?.o *crtend.o) .ctors)
        *(SORT(.ctors.*))
        *(.ctors)

        /* .dtors */
         *crtbegin.o(.dtors)
         *crtbegin?.o(.dtors)
         *(EXCLUDE_FILE(*crtend?.o *crtend.o) .dtors)
         *(SORT(.dtors.*))
         *(.dtors)

        *(.rodata*)

        KEEP(*(.eh_frame*))
    } > FLASH

#ifdef CODE_SHARING
    CHECK_ALIGNMENT_4(SIZEOF(.tfm_shared_symbols))
#endif
    CHECK_ALIGNMENT_4(SIZEOF(.data))
    CHECK_ALIGNMENT_4(SIZEOF(.bss))

    .ARM.extab :
    {
        *(.ARM.extab* .gnu.linkonce.armextab.*)
    } > FLASH

    __exidx_start = .;
    .ARM.exidx :
    {
        *(.ARM.exidx* .gnu.linkonce.armexidx.*)
    } > FLASH
    __exidx_end = .;

#ifdef CODE_SHARING
    /* The code sharing between bootloader and runtime firmware requires to
     * share the global variables. Section size must be equal with
     * SHARED_SYMBOL_AREA_SIZE defined in region_defs.h
     */
    .tfm_shared_symbols : ALIGN(4)
    {
        *(.data.mbedtls_calloc_func)
        *(.data.mbedtls_free_func)
        *(.data.mbedtls_exit)
        *(.data.memset_func)
        . = ALIGN(SHARED_SYMBOL_AREA_SIZE);
    } > RAM AT > FLASH

    ASSERT(SHARED_SYMBOL_AREA_SIZE % 4 == 0, "SHARED_SYMBOL_AREA_SIZE must be divisible by 4")
#endif

#ifdef BOOT_TFM_SHARED_DATA_SIZE
    .tfm_bl2_shared_data : ALIGN(32)
    {
        . += BOOT_TFM_SHARED_DATA_SIZE;
    } > RAM
    Image$$SHARED_DATA$$RW$$Base = ADDR(.tfm_bl2_shared_data);
    Image$$SHARED_DATA$$RW$$Limit = ADDR(.tfm_bl2_shared_data) + SIZEOF(.tfm_bl2_shared_data);
#endif

    .data : ALIGN(4)
    {
        *(vtable)
        *(.data*)

        KEEP(*(.jcr*))
        . = ALIGN(4);

    } > RAM AT > FLASH
    Image$$ER_DATA$$Base = ADDR(.data);

    .bss : ALIGN(4)
    {
        . = ALIGN(4);
        __bss_start__ = .;
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end__ = .;
    } > RAM

#if defined (__ARM_FEATURE_CMSE) && (__ARM_FEATURE_CMSE == 3U)
    .msp_stack (NOLOAD) : ALIGN(32)
    {
        . += __msp_stack_size__ - 0x8;
    } > RAM
    Image$$ARM_LIB_STACK$$ZI$$Base = ADDR(.msp_stack);
    Image$$ARM_LIB_STACK$$ZI$$Limit = ADDR(.msp_stack) + SIZEOF(.msp_stack);

    .msp_stack_seal_res :
    {
        . += 0x8;
    } > RAM
    __StackSeal = ADDR(.msp_stack_seal_res);

#else
    .msp_stack (NOLOAD) : ALIGN(32)
    {
        . += __msp_stack_size__;
    } > RAM
    Image$$ARM_LIB_STACK$$ZI$$Base = ADDR(.msp_stack);
    Image$$ARM_LIB_STACK$$ZI$$Limit = ADDR(.msp_stack) + SIZEOF(.msp_stack);

#endif /* defined (__ARM_FEATURE_CMSE) && (__ARM_FEATURE_CMSE == 3U) */

    .heap (NOLOAD): ALIGN(8)
    {
        . = ALIGN(8);
        __end__ = .;
        PROVIDE(end = .);
        __HeapBase = .;
        . += __heap_size__;
        __HeapLimit = .;
        __heap_limit = .; /* Add for _sbrk */
    } > RAM
    Image$$ARM_LIB_HEAP$$ZI$$Limit = ADDR(.heap) + SIZEOF(.heap);

    PROVIDE(__stack = Image$$ARM_LIB_STACK$$ZI$$Limit);
}
