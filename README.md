picoDB - a brief tutorial and guide
===================================

1. What is picoDB ?

picoDB is a data organization tool for microcontrollers. In effect, it's a simple No-SQL database
tool that can be used in a computational environment with limited resources. It is made up of two
basic components: metaverse and dbverse. The former defines the elements of a data base and the latter
contains the data corresponding to defined databases.

2. How is picoDB implemented ?

picoDB is implemented as an API that creates and manages picoDB databases. The API is built as
an eLua chunk. That is, it uses the Lua programming language and is deployed using the eLua variant.
Both Lua and eLua are open source software. 

For more details on Lua, see:

http://www.lua.org

For more details on eLua including access to the source code, see

http://www.eluaproject.net/

For details on setting up a toolchain for eLua and implementing an eLua application, see the Wiki
in the eLua site.

3. How is picoDB used ?

picoDB can be used with any eLua module by adding picoDB.lua to the ROM file system sub-directory
(romfs) along with the application source, when building a ROMable eLua application package.

4. What is the minimum hardware for running an application with picoDB ?

picoDB, along with eLua and any application code, must run, at a minimum, on an ARM Cortex M3 MCU with
512 KB of flash and 64 KB of RAM, or equivalent.

5. What is included in the picoDB package ?

Two files: 

picoDB.lua - the API and plenty of comments

SeeTables.lua - a useful debugging tool for displaying the content Lua tables

pE_TMP102_sim - a sample application using picoDB with plenty of comments

_____________________________________________________________________________________________

Sample eLua toolchain installation for ARM processors (Ubuntu Linux) 
====================================================================

1. Make sure that you are in your home directory (cd ~) and are at the root level (sudo -i)

2. Add the libraries needed by eLua as follows:

   $ apt-get install flex bison curl libgmp3 libmpfr-dev libelf-dev autoconf texinfo build-essential libncurses5-dev libmpc-dev

3. Make sure that git is installed. If not, do the following:

   $ apt-get install git

4. Install the ARM toolchain as follows:

   $ git clone git://github.com/jsnyder/arm-eabi-toolchain.git

   NOTE - This creates a directory called arm-eabi-toolchain/ under your home directory. 

5. Build the ARM toolchain by doing the following (will take a long time !):

   $ make install-cross

6. Add $HOME/arm-cs-tools/bin to the PATH environment variable

7. Test the ARM compiler by typing the following:

   $ arm-none-eabi-gcc

   NOTE - The output should be exactly:

   arm-none-eabi-gcc: fatal error: no input files

8. Install the Lua dependencies by entering the following:

   $ apt-get install luarocks
   $ luarocks install lpack
   $ luarocks install luafilesystem

   NOTE - Make sure that luarocks install completes successfully before proceeding to
          the next 2 commands

7. Install the eLua source as follows:

   $ git clone git://github.com/elua/elua.git

   NOTE - This creates the elua directory under your home directory

8. Create eLua cross-compiler by entering the following:

   $ cd $HOME/elua
   $ lua cross-lua.lua

Installation complete !
_____________________________________________________________________________________________

Building a ROMable app package with picoDB using the ARM toolchain (Ubuntu Linux)
=================================================================================

1. Clear the contents of the $HOME/elua/romfs directory

2. Copy the eLua application modules (chunks) and picoDB.lua to $HOME/elua/romfs

3. Perform the following:

   $ cd $HOME/elua/
   $ lua build_elua.lua board=<board> romfs=compile

   where  <board> = a board name as found in the tables within build_eLua.lua
                    (e.g., MBED, ET-STM32)

   NOTE - The output of this module create a file in the elua directory 
          whose name is in the format:

          elua_lua_<mcu>.elf

    where  <mcu> = the name of a microcontroller model (e.g., lpc1768, stm32f103re)

4. Convert the *.elf file file to a *.bin ready for loading into the microcontroller
   through the following command:

   $ arm-none-eabi-objcopy -O binary elua_lua_<mcu>.elf <app>.bin

   where  <mcu> = (as in the above step)

          <app> = a suitable name for the application

                  NOTE - <app> must be a set of contiguous non-blank letters and numbers

          



