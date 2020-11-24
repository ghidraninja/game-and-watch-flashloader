#include "flash.h"

void  OSPI_Reset(OSPI_HandleTypeDef *hospi)
{
  OSPI_RegularCmdTypeDef  sCommand;
  memset(&sCommand, 0x0, sizeof(sCommand));
  sCommand.OperationType         = HAL_OSPI_OPTYPE_COMMON_CFG;
  sCommand.FlashId               = 0;
  sCommand.Instruction           = 0x66; // 10-1
  sCommand.InstructionMode       = HAL_OSPI_INSTRUCTION_1_LINE;
  sCommand.InstructionSize       = HAL_OSPI_INSTRUCTION_8_BITS;
  
  sCommand.AddressMode           = HAL_OSPI_ADDRESS_NONE;
  sCommand.AlternateBytesMode    = HAL_OSPI_ALTERNATE_BYTES_NONE;
  sCommand.DataMode              = HAL_OSPI_DATA_NONE;
  sCommand.DummyCycles           = 0;
  sCommand.DQSMode               = HAL_OSPI_DQS_DISABLE;
  sCommand.SIOOMode              = HAL_OSPI_SIOO_INST_EVERY_CMD;
  sCommand.InstructionDtrMode    = HAL_OSPI_INSTRUCTION_DTR_DISABLE;
  if (HAL_OSPI_Command(hospi, &sCommand, HAL_OSPI_TIMEOUT_DEFAULT_VALUE) != HAL_OK)
  {
    Error_Handler();
  }

  HAL_Delay(2);
  sCommand.Instruction           = 0x99; // 10-1
   if (HAL_OSPI_Command(hospi, &sCommand, HAL_OSPI_TIMEOUT_DEFAULT_VALUE) != HAL_OK)
  {
    Error_Handler();
  }
  HAL_Delay(20);
}

void  OSPI_ChipErase(OSPI_HandleTypeDef *hospi)
{
  OSPI_RegularCmdTypeDef  sCommand;
  memset(&sCommand, 0x0, sizeof(sCommand));
  sCommand.OperationType         = HAL_OSPI_OPTYPE_COMMON_CFG;
  sCommand.FlashId               = 0;
  sCommand.Instruction           = 0x60;
  sCommand.InstructionMode       = HAL_OSPI_INSTRUCTION_1_LINE;
  sCommand.InstructionSize       = HAL_OSPI_INSTRUCTION_8_BITS;
  sCommand.AddressMode           = HAL_OSPI_ADDRESS_NONE;
  sCommand.AlternateBytesMode    = HAL_OSPI_ALTERNATE_BYTES_NONE;
  sCommand.DataMode              = HAL_OSPI_DATA_NONE;
  sCommand.DummyCycles           = 0;
  sCommand.DQSMode               = HAL_OSPI_DQS_DISABLE;
  sCommand.SIOOMode              = HAL_OSPI_SIOO_INST_EVERY_CMD;
  sCommand.InstructionDtrMode    = HAL_OSPI_INSTRUCTION_DTR_DISABLE;

  if (HAL_OSPI_Command(hospi, &sCommand, HAL_OSPI_TIMEOUT_DEFAULT_VALUE) != HAL_OK)
  {
    Error_Handler();
  }
  // yolo
  HAL_Delay(10000);
}



void  _OSPI_Program(OSPI_HandleTypeDef *hospi, uint32_t address, uint8_t *buffer, size_t buffer_size)
{
  char data[256+3];
  memset(data, 0x00, 259);
  OSPI_RegularCmdTypeDef  sCommand;
  memset(&sCommand, 0x0, sizeof(sCommand));
  sCommand.OperationType         = HAL_OSPI_OPTYPE_COMMON_CFG;
  sCommand.FlashId               = 0;
  sCommand.Instruction           = 0x02;
  sCommand.InstructionMode       = HAL_OSPI_INSTRUCTION_1_LINE;
  sCommand.InstructionSize       = HAL_OSPI_INSTRUCTION_8_BITS;
  sCommand.Address        = address;
  sCommand.AddressMode    = HAL_OSPI_ADDRESS_1_LINE;
  sCommand.AddressSize    = HAL_OSPI_ADDRESS_24_BITS;
  sCommand.AlternateBytesMode    = HAL_OSPI_ALTERNATE_BYTES_NONE;
  sCommand.DataMode              = HAL_OSPI_DATA_1_LINE;
  sCommand.NbData = buffer_size;
  sCommand.DummyCycles           = 0;
  sCommand.DQSMode               = HAL_OSPI_DQS_DISABLE;
  sCommand.SIOOMode              = HAL_OSPI_SIOO_INST_ONLY_FIRST_CMD;
  sCommand.InstructionDtrMode    = HAL_OSPI_INSTRUCTION_DTR_DISABLE;

  if(buffer_size > 256) {
    Error_Handler();
  }

  if (HAL_OSPI_Command(hospi, &sCommand, HAL_OSPI_TIMEOUT_DEFAULT_VALUE) != HAL_OK)
  {
    Error_Handler();
  }

  if(HAL_OSPI_Transmit(hospi, buffer, HAL_OSPI_TIMEOUT_DEFAULT_VALUE) != HAL_OK) {
    Error_Handler();
  }
}

void  OSPI_Program(OSPI_HandleTypeDef *hospi, uint32_t address, uint8_t *buffer, size_t buffer_size) {
  unsigned iterations = buffer_size / 256;
  
  for(int i=0; i < iterations; i++) {
    OSPI_NOR_WriteEnable(hospi);
    _OSPI_Program(hospi, i * 256, buffer + (i * 256), buffer_size > 256 ? 256 : buffer_size);
    buffer_size -= 256;
    HAL_Delay(2);
  }
}

void  OSPI_NOR_WriteEnable(OSPI_HandleTypeDef *hospi)
{
  OSPI_RegularCmdTypeDef  sCommand;
  OSPI_AutoPollingTypeDef sConfig;
  uint8_t reg[2];

  /* Enable write operations */
  sCommand.OperationType         = HAL_OSPI_OPTYPE_COMMON_CFG;
  sCommand.FlashId               = 0;
  sCommand.Instruction           = 0x06; // 10-1
  sCommand.InstructionMode       = HAL_OSPI_INSTRUCTION_1_LINE;
  sCommand.InstructionSize       = HAL_OSPI_INSTRUCTION_8_BITS;
  sCommand.AddressMode           = HAL_OSPI_ADDRESS_NONE;
  sCommand.AlternateBytesMode    = HAL_OSPI_ALTERNATE_BYTES_NONE;
  sCommand.DataMode              = HAL_OSPI_DATA_NONE;
  sCommand.DummyCycles           = 0;
  sCommand.DQSMode               = HAL_OSPI_DQS_DISABLE;
  sCommand.SIOOMode              = HAL_OSPI_SIOO_INST_EVERY_CMD;
  sCommand.InstructionDtrMode    = HAL_OSPI_INSTRUCTION_DTR_DISABLE;

  if (HAL_OSPI_Command(hospi, &sCommand, HAL_OSPI_TIMEOUT_DEFAULT_VALUE) != HAL_OK)
  {
    Error_Handler();
  }
}


void flash_memory_map(OSPI_HandleTypeDef *spi) {
  OSPI_MemoryMappedTypeDef sMemMappedCfg;

  OSPI_RegularCmdTypeDef sCommand = {
    .Instruction = 0xeb, // 4READ
    .InstructionMode = HAL_OSPI_INSTRUCTION_1_LINE,
    .SIOOMode = HAL_OSPI_SIOO_INST_EVERY_CMD,
    .AlternateBytesMode = HAL_OSPI_ALTERNATE_BYTES_NONE,
    .AddressMode = HAL_OSPI_ADDRESS_4_LINES,
    .OperationType = HAL_OSPI_OPTYPE_READ_CFG,
    .FlashId = 0,
    .InstructionDtrMode = HAL_OSPI_INSTRUCTION_DTR_DISABLE,
    .InstructionSize = HAL_OSPI_INSTRUCTION_8_BITS,
    .AddressDtrMode = HAL_OSPI_ADDRESS_DTR_DISABLE,
    .DataMode = HAL_OSPI_DATA_4_LINES,
    .DataDtrMode = HAL_OSPI_DATA_DTR_DISABLE,
    .DQSMode = HAL_OSPI_DQS_DISABLE,
    .AddressSize = HAL_OSPI_ADDRESS_24_BITS,
    .SIOOMode = HAL_OSPI_SIOO_INST_EVERY_CMD, // HAL_OSPI_SIOO_INST_ONLY_FIRST_CMD
    // .SIOOMode = HAL_OSPI_SIOO_INST_ONLY_FIRST_CMD,
    .DummyCycles = 4,
    // .AlternateBytesSize = 1, //HAL_OSPI_ALTERNATE_BYTES_8_BITS, // ??? firmware uses '1' ??
    .AlternateBytesSize = HAL_OSPI_ALTERNATE_BYTES_8_BITS, // ??? firmware uses '1' ??
    .NbData = 1, // Data length
    .AlternateBytes = 0x00,
  };

  sCommand.OperationType = HAL_OSPI_OPTYPE_WRITE_CFG;
  sCommand.Instruction = 0x38; /* 4PP / 4 x page program */ // LINEAR_BURST_WRITE;
  sCommand.DummyCycles = 0; //DUMMY_CLOCK_CYCLES_SRAM_WRITE;
  if (HAL_OSPI_Command(spi, &sCommand, HAL_OSPI_TIMEOUT_DEFAULT_VALUE) !=
      HAL_OK) {
    Error_Handler();
  }
  /* Memory-mapped mode configuration for Linear burst read operations */
  sCommand.OperationType = HAL_OSPI_OPTYPE_READ_CFG;
  sCommand.Instruction = 0xEB; /* 4READ */  //LINEAR_BURST_READ;
  sCommand.DummyCycles = 6; //DUMMY_CLOCK_CYCLES_SRAM_READ;

  if (HAL_OSPI_Command(spi, &sCommand, HAL_OSPI_TIMEOUT_DEFAULT_VALUE) !=
      HAL_OK) {
    Error_Handler();
  }
  /*Disable timeout counter for memory mapped mode*/
  sMemMappedCfg.TimeOutActivation = HAL_OSPI_TIMEOUT_COUNTER_DISABLE;
  sMemMappedCfg.TimeOutPeriod = 0;
  /*Enable memory mapped mode*/
  if (HAL_OSPI_MemoryMapped(spi, &sMemMappedCfg) != HAL_OK) {
    Error_Handler();
  }
}