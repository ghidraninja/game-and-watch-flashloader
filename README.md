# game-and-watch-flashloader
A small tool to flash the SPI-flash using OpenOCD.

## Usage

- (Optional) Initialize using STM32CubeMX or dowload all SDK files using `make download_sdk -j`
- Build the code using `make`
- Run `flash.sh`, point it to the image you want to flash
- Wait until your device blinks once a second
- Done
