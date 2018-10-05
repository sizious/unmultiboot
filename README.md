# UnMultiBoot

This program let you extract games from a multi-boot **Nintendo GameCube** image.
This is the opposite of **GCMUtility**, which merge games into a single multi-boot
image.

## Usage

	unmboot <command> [X] <multi.gcm> [dir]

Where:
* `-l` : List all the contents of `<multi.gcm>`.
* `-a` : Extract all contained GCM into `<multi.gcm>` to `[dir]`.
* `-e [X]` : Extract from `<multi.gcm>` the `[X]`th image to `[dir]`.

Example:

	unmboot -e 1 c:\temp\yo.gcm .

This will extract the 1st game from `yo.gcm` to the current directory.

## Credits

Thanks to **Ghoom**, **groepaz/HiTMEN** and **CRAZY NATiON**.
