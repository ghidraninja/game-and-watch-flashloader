#ifndef _FLASH_H_
#define _FLASH_H_

#include "stm32h7xx_hal.h"
void OSPI_EnableMemoryMappedMode(OSPI_HandleTypeDef *hospi1, uint32_t quad_mode);

#endif
